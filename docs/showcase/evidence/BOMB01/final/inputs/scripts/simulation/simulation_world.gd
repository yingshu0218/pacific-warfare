class_name SimulationWorld
extends RefCounted

## Pure state coordinator. Combat, motion and commander policy are injected modules.
var tick: int = 0
var tick_hz: int = 60
var seed_value: int = 0
var paused: bool = false
var time_scale: float = 1.0
var generation: int = 0
## Optional validation timings. Never included in snapshots or decision inputs.
var profile_enabled: bool = false
var profile_us: Dictionary = {}
var profile_calls: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var shared_state: Dictionary = {}

var _catalog: DefinitionCatalog
var _scenario: ScenarioDefinition
var _units: Dictionary = {}
var _groups: Dictionary = {}
var _contacts: Dictionary = {}
var _modules: Array[SimulationModule] = []
var _order_handlers: Dictionary = {}
var _orders: Dictionary = {}
var _commands: Array[Dictionary] = []
var _requests: Dictionary = {}
var _pending_rejections: Array[Dictionary] = []
var _outbox: Array[BattleEvent] = []
var _tick_events: Array[BattleEvent] = []
var _previous_events: Array[BattleEvent] = []
var _command_sequence: int = 0
var _event_sequence: int = 0
var _accumulator_s: float = 0.0
var _in_tick: bool = false

func configure(catalog: DefinitionCatalog, scenario_data: Dictionary) -> PackedStringArray:
	if _in_tick:
		return ["cannot_configure_during_tick"]
	var errors: PackedStringArray = catalog.validate_scenario(scenario_data)
	if not errors.is_empty():
		return errors
	_catalog = catalog.copy()
	_scenario = ScenarioDefinition.from_data(scenario_data)
	tick_hz = _scenario.tick_hz
	reset()
	return []

func fixed_delta_s() -> float:
	return 1.0 / float(tick_hz)

func time_s() -> float:
	return float(tick) / float(tick_hz)

func interpolation_alpha() -> float:
	return minf(1.0, _accumulator_s / fixed_delta_s())

func pending_time_s() -> float:
	return _accumulator_s

func pending_ticks() -> int:
	return int(floor((_accumulator_s + 0.000000001) / fixed_delta_s()))

func set_paused(value: bool) -> void:
	paused = value

func set_time_scale(value: float) -> bool:
	if not is_finite(value) or value < 0.0 or value > 16.0:
		return false
	time_scale = value
	return true

## Never discard accumulated simulation time. The caller supplies elapsed wall seconds.
func advance(external_delta_s: float, max_ticks: int = 240) -> int:
	if _scenario == null or _in_tick or paused or time_scale == 0.0 or not is_finite(external_delta_s) or external_delta_s < 0.0 or max_ticks < -1:
		return 0
	var contribution_s: float = external_delta_s * time_scale
	if not is_finite(contribution_s) or not is_finite(_accumulator_s + contribution_s):
		return 0
	_accumulator_s += contribution_s
	var count: int = 0
	var delta_s: float = fixed_delta_s()
	while _accumulator_s + 0.000000001 >= delta_s and (max_ticks == -1 or count < max_ticks):
		_accumulator_s = maxf(0.0, _accumulator_s - delta_s)
		_fixed_tick()
		count += 1
	return count

## Explicit deterministic stepping, including when paused; for tests/tools only.
func step_ticks(count: int) -> bool:
	if _scenario == null or _in_tick or count < 0:
		return false
	for index: int in range(count):
		_fixed_tick()
	return true

func reset(new_seed: int = -1) -> bool:
	if _scenario == null or _in_tick or new_seed < -1 or new_seed > 2147483647:
		return false
	generation += 1
	tick = 0
	seed_value = _scenario.seed_value if new_seed == -1 else new_seed
	rng.seed = seed_value
	paused = false
	time_scale = 1.0
	_accumulator_s = 0.0
	_command_sequence = 0
	_event_sequence = 0
	_commands.clear()
	_requests.clear()
	_pending_rejections.clear()
	_orders.clear()
	_outbox.clear()
	_tick_events.clear()
	_previous_events.clear()
	shared_state.clear()
	_units.clear()
	_groups.clear()
	_contacts.clear()
	for faction: String in _scenario.factions:
		_contacts[faction] = []
	for spawn: Dictionary in _scenario.spawns:
		var definition: UnitDefinition = _catalog.unit(spawn.unit_definition_id)
		var state: UnitState = UnitState.new()
		state.id = spawn.id
		state.definition_id = definition.id
		state.faction_id = spawn.faction_id
		state.position_m = SimData.vec3(spawn.get("position_m", [0.0, 0.0, 0.0]))
		state.velocity_mps = SimData.vec3(spawn.get("velocity_mps", [0.0, 0.0, 0.0]))
		state.rotation_rad = SimData.vec3(spawn.get("rotation_rad", [0.0, 0.0, 0.0]))
		state.module_data = spawn.get("module_data", {}).duplicate(true)
		for mount: MountSocket in definition.mounts:
			state.weapons[mount.id] = WeaponState.create(state.id, mount, _catalog.weapon(mount.weapon_definition_id))
		_units[state.id] = state
	for group: Dictionary in _scenario.groups:
		_groups[group.id] = group.duplicate(true)
	for module: SimulationModule in _modules:
		module.reset(self)
	return true

func register_module(module: SimulationModule) -> Dictionary:
	if _in_tick or tick != 0 or not SimData.valid_id(module.module_id):
		return {"accepted": false, "reason": "register_before_first_tick_with_valid_id"}
	for existing: SimulationModule in _modules:
		if existing.module_id == module.module_id:
			return {"accepted": false, "reason": "duplicate_module_id"}
	var order_types: PackedStringArray = module.supported_order_types()
	var domains: PackedStringArray = module.order_domains()
	if not order_types.is_empty() and domains.is_empty():
		return {"accepted": false, "reason": "missing_order_domains"}
	var keys: Dictionary = {}
	for order_type: String in order_types:
		for domain: String in domains:
			var key: String = order_type + ":" + domain
			if not order_type in BattleOrder.TYPES or domain not in ["ship", "aircraft", "ground"] or _order_handlers.has(key) or keys.has(key):
				return {"accepted": false, "reason": "invalid_or_duplicate_order_handler"}
			keys[key] = true
	_modules.append(module)
	_modules.sort_custom(func(a: SimulationModule, b: SimulationModule) -> bool:
		return a.priority < b.priority if a.priority != b.priority else a.module_id < b.module_id)
	for key: String in keys:
		_order_handlers[key] = module
	if _scenario != null:
		module.reset(self)
	return {"accepted": true, "reason": "registered"}

func unit_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_units.keys())
	result.sort()
	return result

## Mutable state is for simulation executors. Presentation consumes snapshot().
func get_unit(entity_id: String) -> UnitState:
	return _units.get(entity_id)

func unit_definition(definition_id: String) -> UnitDefinition:
	return _catalog.unit(definition_id)

func weapon_definition(definition_id: String) -> WeaponDefinition:
	return _catalog.weapon(definition_id)

func ammo_definition(definition_id: String) -> AmmoDefinition:
	return _catalog.ammo(definition_id)

func recipient_unit_ids(recipient_id: String, only_active: bool = true) -> Array[String]:
	var candidates: Array = []
	if _units.has(recipient_id):
		candidates.append(recipient_id)
	elif _groups.has(recipient_id):
		candidates = _groups[recipient_id].member_ids
	var result: Array[String] = []
	for entity_id: String in candidates:
		if not only_active or (_units[entity_id] as UnitState).active:
			result.append(entity_id)
	result.sort()
	return result

func submit_order(order: BattleOrder, execute_tick: int = -1) -> Dictionary:
	var command: BattleCommand = BattleCommand.new()
	command.command_id = "issue:" + order.order_id
	command.issuer_id = order.issuer_id
	command.source = order.source
	command.faction_id = order.faction_id
	command.execute_tick = execute_tick
	command.payload = order.request_data()
	return submit_command(command)

## Both AI and future human requests pass this gate and the same fixed-tick queue.
func submit_command(command: BattleCommand) -> Dictionary:
	if _scenario == null:
		return {"accepted": false, "reason": "world_not_configured"}
	var data: Dictionary = command.snapshot()
	if not SimData.pure_data(data):
		return {"accepted": false, "reason": "command_requires_pure_data"}
	if _requests.has(command.command_id):
		var previous: Dictionary = _requests[command.command_id]
		if previous.request != data:
			return _reject(command, "duplicate_id_conflict")
		var duplicate: Dictionary = previous.receipt.duplicate(true)
		duplicate["duplicate"] = true
		return duplicate
	var reason: String = _validate_command(command)
	var due_tick: int = tick + 1 if command.execute_tick == -1 else command.execute_tick
	if due_tick <= tick:
		reason = "execute_tick_must_be_in_future"
	if not reason.is_empty():
		return _reject(command, reason)
	_command_sequence += 1
	_commands.append({"due_tick": due_tick, "sequence": _command_sequence, "command": data})
	var receipt: Dictionary = {"accepted": true, "reason": "queued", "command_id": command.command_id,
		"execute_tick": due_tick, "duplicate": false}
	_requests[command.command_id] = {"request": data, "receipt": receipt.duplicate(true)}
	return receipt

func _reject(command: BattleCommand, reason: String) -> Dictionary:
	_pending_rejections.append({"command_id": command.command_id, "faction_id": command.faction_id,
		"issuer_id": command.issuer_id, "source": command.source, "kind": command.kind,
		"request": command.snapshot(), "reason": reason})
	var receipt: Dictionary = {"accepted": false, "reason": reason, "command_id": command.command_id, "duplicate": false}
	if SimData.valid_id(command.command_id) and not _requests.has(command.command_id):
		_requests[command.command_id] = {"request": command.snapshot(), "receipt": receipt.duplicate(true)}
	return receipt

func _validate_command(command: BattleCommand) -> String:
	if not SimData.valid_id(command.command_id) or not SimData.valid_id(command.issuer_id):
		return "invalid_command_or_issuer_id"
	if command.source not in ["ai", "human"] or not _scenario.factions.has(command.faction_id):
		return "invalid_source_or_faction"
	if command.kind == BattleCommand.ISSUE_ORDER:
		var payload: Dictionary = command.payload
		if payload.get("issuer_id") != command.issuer_id or payload.get("faction_id") != command.faction_id or payload.get("source") != command.source:
			return "order_envelope_mismatch"
		return _validate_order(payload)
	if command.kind == BattleCommand.CANCEL_ORDER:
		var order_id: String = str(command.payload.get("order_id", ""))
		if not _orders.has(order_id):
			return "unknown_order"
		var order: BattleOrder = _orders[order_id]
		if order.faction_id != command.faction_id:
			return "wrong_faction"
		if order.status in BattleOrder.TERMINAL:
			return "order_already_terminal"
		return "" if command.payload.get("reason") is String and not command.payload.reason.is_empty() else "missing_cancel_reason"
	var state: UnitState = get_unit(command.entity_id)
	if state == null or not state.active:
		return "unknown_or_inactive_entity"
	if state.faction_id != command.faction_id:
		return "wrong_faction"
	if command.kind == BattleCommand.SET_TARGET:
		if not command.payload.get("target_id") is String:
			return "invalid_target_id"
		var target_id: String = command.payload.target_id
		if target_id.is_empty():
			return ""
		var target: UnitState = get_unit(target_id)
		return "" if target != null and target.active and target.faction_id != state.faction_id else "invalid_enemy_target"
	if command.kind == BattleCommand.CEASE_FIRE:
		return "" if command.payload.get("enabled") is bool else "invalid_cease_fire_value"
	return "unsupported_command"

func _validate_order(data: Dictionary) -> String:
	for field: String in ["order_id", "issuer_id", "faction_id"]:
		if not SimData.valid_id(data.get(field)):
			return "invalid_order_" + field
	if _orders.has(data.order_id):
		return "duplicate_order_id"
	if not data.get("order_type") is String or not data.order_type in BattleOrder.TYPES:
		return "unsupported_order_type"
	if not data.get("recipient_ids") is Array or data.recipient_ids.is_empty():
		return "missing_recipients"
	var seen: Dictionary = {}
	for recipient: Variant in data.recipient_ids:
		if not recipient is String or seen.has(recipient) or recipient_unit_ids(recipient).is_empty():
			return "invalid_or_inactive_recipient"
		seen[recipient] = true
		for entity_id: String in recipient_unit_ids(recipient, false):
			if (get_unit(entity_id) as UnitState).faction_id != data.faction_id:
				return "wrong_faction"
		for entity_id: String in recipient_unit_ids(recipient):
			var domain: String = unit_definition(get_unit(entity_id).definition_id).domain
			if not _order_handlers.has(data.order_type + ":" + domain):
				return "order_executor_not_registered"
	if not data.get("target_id", "") is String or not data.get("intent", "") is String:
		return "invalid_order_text"
	var bombing: Variant = data.get("bombing", {})
	if not bombing is Dictionary or not SimData.pure_data(bombing): return "invalid_bombing_parameters"
	if data.order_type != "bombing" and not bombing.is_empty(): return "bombing_requires_bombing_order"
	var training: Variant = data.get("training", {})
	if not training is Dictionary or not SimData.pure_data(training): return "invalid_training_parameters"
	if data.order_type != "aircraft_training" and not training.is_empty(): return "training_requires_training_order"
	var target_id: String = data.get("target_id", "")
	if not target_id.is_empty():
		var target: UnitState = get_unit(target_id)
		if target == null or not target.active:
			return "invalid_order_target"
		if data.order_type in ["engage", "intercept", "bombing"] and target.faction_id == data.faction_id:
			return "order_requires_enemy_target"
		if data.order_type == "escort" and target.faction_id != data.faction_id:
			return "escort_requires_friendly_target"
		if data.order_type == "intercept" and unit_definition(target.definition_id).domain != "aircraft":
			return "intercept_requires_aircraft_target"
	if data.order_type in ["escort", "intercept", "engage"] and target_id.is_empty():
		return "missing_order_target"
	var area: Variant = data.get("area", {})
	if not area is Dictionary:
		return "invalid_area"
	if not area.is_empty():
		if not SimData.valid_vector(area.get("center_m")) or not SimData.finite_number(area.get("radius_m")) or float(area.radius_m) <= 0.0:
			return "invalid_area"
	if data.order_type == "bombing" and target_id.is_empty() and area.is_empty(): return "bombing_target_required"
	var waypoints: Variant = data.get("waypoints_m", [])
	if not waypoints is Array:
		return "invalid_waypoints"
	for waypoint: Variant in waypoints:
		if not SimData.valid_vector(waypoint):
			return "invalid_waypoints"
	if data.order_type == "patrol" and area.is_empty() and waypoints.is_empty():
		return "patrol_requires_area_or_waypoints"
	return ""

func _fixed_tick() -> void:
	_in_tick = true
	tick += 1
	_previous_events = _tick_events
	_tick_events = []
	# Loss cannot strand an order with only inactive owners.
	for order: BattleOrder in _orders.values():
		var lost: Array[String] = []
		for entity_id: String in order.assigned_unit_ids:
			if not get_unit(entity_id).active:
				lost.append(entity_id)
		if not lost.is_empty():
			_release_order_units(order, lost, "failed", "recipient_inactive")
	for rejection: Dictionary in _pending_rejections:
		emit_event("command_rejected", "", "", Vector3.ZERO, rejection)
	_pending_rejections.clear()
	_commands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.due_tick < b.due_tick if a.due_tick != b.due_tick else a.sequence < b.sequence)
	var due: Array[Dictionary] = []
	while not _commands.is_empty() and int(_commands[0].due_tick) <= tick:
		due.append(_commands.pop_front())
	for entry: Dictionary in due:
		var command: BattleCommand = BattleCommand.from_data(entry.command)
		var reason: String = _validate_command(command)
		if reason.is_empty():
			_apply_command(command)
		else:
			emit_event("command_rejected", command.entity_id, "", Vector3.ZERO,
				{"command_id": command.command_id, "faction_id": command.faction_id, "issuer_id": command.issuer_id,
				"source": command.source, "kind": command.kind, "request": command.snapshot(), "reason": reason})
	for module: SimulationModule in _modules:
		if profile_enabled:
			var started_us: int = Time.get_ticks_usec()
			module.fixed_update(self, fixed_delta_s())
			profile_us[module.module_id] = int(profile_us.get(module.module_id, 0)) + Time.get_ticks_usec() - started_us
			profile_calls[module.module_id] = int(profile_calls.get(module.module_id, 0)) + 1
		else:
			module.fixed_update(self, fixed_delta_s())
	_in_tick = false

func _apply_command(command: BattleCommand) -> void:
	if command.kind == BattleCommand.ISSUE_ORDER:
		var order: BattleOrder = BattleOrder.from_data(command.payload)
		order.issued_tick = tick
		order.changed_tick = tick
		order.reason = "dispatched"
		order.history.append({"status": "issued", "tick": tick, "reason": order.reason})
		_orders[order.order_id] = order
		emit_event("order_issued", "", "", Vector3.ZERO, order.snapshot(), order.target_id)
		var slices: Dictionary = {}
		for recipient: String in order.recipient_ids:
			for entity_id: String in recipient_unit_ids(recipient):
				var domain: String = unit_definition(get_unit(entity_id).definition_id).domain
				if not slices.has(domain):
					slices[domain] = []
				if not slices[domain].has(entity_id):
					slices[domain].append(entity_id)
		var rejected: String = ""
		var domains: Array = slices.keys()
		domains.sort()
		for domain: String in domains:
			var entity_ids: Array[String] = []
			entity_ids.assign(slices[domain])
			entity_ids.sort()
			var handler: SimulationModule = _order_handlers[order.order_type + ":" + domain]
			# Capability check only; callbacks must not install tasks or change state here.
			var result: Dictionary = handler.accept_order(self, BattleOrder.from_data(order.snapshot()), entity_ids)
			if not result.get("accepted", false):
				rejected = str(result.get("reason", "executor_rejected"))
				break
		if not rejected.is_empty():
			transition_order(order.order_id, "failed", rejected)
		else:
			transition_order(order.order_id, "received", "domain_executors_accepted")
			var replaced: Dictionary = {}
			for domain: String in domains:
				for entity_id: String in slices[domain]:
					var previous_id: String = get_unit(entity_id).active_order_id
					if not previous_id.is_empty():
						if not replaced.has(previous_id):
							replaced[previous_id] = []
						replaced[previous_id].append(entity_id)
			for previous_id: String in replaced:
				var released: Array[String] = []
				released.assign(replaced[previous_id])
				_release_order_units(_orders[previous_id], released, "superseded", "replacement_order_received", order.order_id)
			for domain: String in domains:
				var handler: SimulationModule = _order_handlers[order.order_type + ":" + domain]
				for entity_id: String in slices[domain]:
					order.assigned_unit_ids.append(entity_id)
					order.execution[entity_id] = {"status": "received", "module_id": handler.module_id,
						"reason": "assigned", "progress": "", "changed_tick": tick, "replacement_order_id": ""}
					var state: UnitState = get_unit(entity_id)
					state.active_order_id = order.order_id
					state.task = {"order_id": order.order_id, "order_type": order.order_type}
			order.assigned_unit_ids.sort()
			emit_event("order_assignments_changed", "", "", Vector3.ZERO, order.snapshot(), order.target_id)
	elif command.kind == BattleCommand.CANCEL_ORDER:
		transition_order(command.payload.order_id, "cancelled", command.payload.reason)
	else:
		var state: UnitState = get_unit(command.entity_id)
		if command.kind == BattleCommand.SET_TARGET:
			state.target_id = command.payload.target_id
			emit_event("target_changed", state.id, "", state.position_m, {"target_id": state.target_id})
		elif command.kind == BattleCommand.CEASE_FIRE:
			state.cease_fire = command.payload.enabled
			emit_event("cease_fire_changed", state.id, "", state.position_m, {"enabled": state.cease_fire})
	# This receipt means dispatched, including an order which its executor failed.
	emit_event("command_applied", command.entity_id, "", Vector3.ZERO,
		{"command_id": command.command_id, "kind": command.kind, "faction_id": command.faction_id})

func transition_order(order_id: String, status: String, reason: String, progress: String = "", replacement_order_id: String = "") -> bool:
	if not _in_tick or not _orders.has(order_id) or reason.is_empty():
		return false
	var order: BattleOrder = _orders[order_id]
	if not status in BattleOrder.TRANSITIONS.get(order.status, []):
		return false
	order.status = status
	order.reason = reason
	order.progress = progress
	order.changed_tick = tick
	order.replacement_order_id = replacement_order_id
	if status == "received":
		order.received_tick = tick
	order.history.append({"status": status, "tick": tick, "reason": reason, "progress": progress})
	emit_event("order_status_changed", "", "", Vector3.ZERO, order.snapshot(), order.target_id)
	if status in BattleOrder.TERMINAL:
		var owned: Array[String] = order.assigned_unit_ids.duplicate()
		if not owned.is_empty():
			_release_order_units(order, owned, status, reason, replacement_order_id)
		var notified: Dictionary = {}
		for execution: Dictionary in order.execution.values():
			var module_id: String = execution.module_id
			if not notified.has(module_id):
				for module: SimulationModule in _modules:
					if module.module_id == module_id:
						module.on_order_ended(self, BattleOrder.from_data(order.snapshot()))
				notified[module_id] = true
	return true

func owned_order_unit_ids(order_id: String, domain: String = "") -> Array[String]:
	var started_us: int = Time.get_ticks_usec() if profile_enabled else 0
	var result: Array[String] = []
	if not _orders.has(order_id):
		return result
	for entity_id: String in (_orders[order_id] as BattleOrder).assigned_unit_ids:
		var state: UnitState = get_unit(entity_id)
		if state.active and state.active_order_id == order_id and (domain.is_empty() or _catalog.unit_domain(state.definition_id) == domain):
			result.append(entity_id)
	if profile_enabled:
		profile_us["owned_order_unit_ids"] = int(profile_us.get("owned_order_unit_ids", 0)) + Time.get_ticks_usec() - started_us
	return result

func report_order_unit_status(order_id: String, entity_id: String, status: String, reason: String, progress: String = "") -> bool:
	if not _in_tick or not _orders.has(order_id) or reason.is_empty():
		return false
	var order: BattleOrder = _orders[order_id]
	if not order.assigned_unit_ids.has(entity_id) or get_unit(entity_id).active_order_id != order_id:
		return false
	var record: Dictionary = order.execution[entity_id]
	if not status in BattleOrder.TRANSITIONS.get(record.status, []):
		return false
	if status in BattleOrder.TERMINAL:
		record.progress = progress
		_release_order_units(order, [entity_id], status, reason)
	else:
		record.status = status
		record.reason = reason
		record.progress = progress
		record.changed_tick = tick
		if order.status == "received" and status == "executing":
			transition_order(order_id, "executing", reason, progress)
		emit_event("order_execution_changed", entity_id, "", get_unit(entity_id).position_m, order.snapshot(), order.target_id)
	return true

func report_order_unit_progress(order_id: String, entity_id: String, progress: String, reason: String) -> bool:
	if not _in_tick or not _orders.has(order_id) or progress.is_empty() or reason.is_empty():
		return false
	var order: BattleOrder = _orders[order_id]
	if not order.assigned_unit_ids.has(entity_id) or get_unit(entity_id).active_order_id != order_id:
		return false
	var record: Dictionary = order.execution[entity_id]
	if record.progress == progress and record.reason == reason:
		return true
	record.progress = progress
	record.reason = reason
	record.changed_tick = tick
	order.changed_tick = tick
	emit_event("order_execution_changed", entity_id, "", get_unit(entity_id).position_m, order.snapshot(), order.target_id)
	return true

func _release_order_units(order: BattleOrder, entity_ids: Array[String], status: String, reason: String, replacement_id: String = "") -> void:
	var callbacks: Dictionary = {}
	for entity_id: String in entity_ids:
		if not order.assigned_unit_ids.has(entity_id):
			continue
		var record: Dictionary = order.execution[entity_id]
		record.status = status
		record.reason = reason
		record.changed_tick = tick
		record.replacement_order_id = replacement_id
		if not callbacks.has(record.module_id):
			callbacks[record.module_id] = []
		callbacks[record.module_id].append(entity_id)
		order.assigned_unit_ids.erase(entity_id)
		var state: UnitState = get_unit(entity_id)
		if state.active_order_id == order.order_id:
			state.active_order_id = ""
			state.task.clear()
	order.changed_tick = tick
	order.history.append({"kind": "units_released", "status": order.status, "tick": tick,
		"unit_ids": entity_ids.duplicate(), "unit_status": status, "reason": reason, "replacement_order_id": replacement_id})
	for module: SimulationModule in _modules:
		if callbacks.has(module.module_id):
			var released: Array[String] = []
			released.assign(callbacks[module.module_id])
			module.on_order_units_released(self, BattleOrder.from_data(order.snapshot()), released, reason)
	emit_event("order_assignments_changed", "", "", Vector3.ZERO, order.snapshot(), order.target_id)
	if order.assigned_unit_ids.is_empty() and not order.status in BattleOrder.TERMINAL:
		var terminal: String = "completed"
		for execution: Dictionary in order.execution.values():
			if execution.status == "failed":
				terminal = "failed"
				break
			if execution.status == "cancelled":
				terminal = "cancelled"
			elif execution.status == "superseded" and terminal == "completed":
				terminal = "superseded"
		transition_order(order.order_id, terminal, "all_assignments_released:" + reason, "", replacement_id)

func report_order_progress(order_id: String, progress: String, reason: String) -> bool:
	if not _in_tick or not _orders.has(order_id) or progress.is_empty() or reason.is_empty():
		return false
	var order: BattleOrder = _orders[order_id]
	if order.status in BattleOrder.TERMINAL:
		return false
	if order.progress == progress and order.reason == reason:
		return true
	order.progress = progress
	order.reason = reason
	order.changed_tick = tick
	emit_event("order_progress", "", "", Vector3.ZERO, order.snapshot(), order.target_id)
	return true

func orders_snapshot(faction_id: String = "") -> Array[Dictionary]:
	var started_us: int = Time.get_ticks_usec() if profile_enabled else 0
	var result: Array[Dictionary] = []
	for order: BattleOrder in _orders.values():
		if faction_id.is_empty() or order.faction_id == faction_id:
			result.append(order.snapshot())
	if profile_enabled:
		profile_us["orders_snapshot"] = int(profile_us.get("orders_snapshot", 0)) + Time.get_ticks_usec() - started_us
		profile_calls["orders_snapshot"] = int(profile_calls.get("orders_snapshot", 0)) + 1
	return result

## Contact producer (S05) supplies already-observed information, not real enemy state.
func set_contacts(faction_id: String, contacts: Array) -> bool:
	if not _in_tick or not _contacts.has(faction_id) or not SimData.pure_data(contacts):
		return false
	_contacts[faction_id] = contacts.duplicate(true)
	return true

## Commander input: own units/groups/orders plus supplied contacts, no enemy orders/state.
func commander_snapshot(faction_id: String) -> Dictionary:
	if _scenario == null or not _scenario.factions.has(faction_id):
		return {}
	var own_units: Dictionary = {}
	var own_groups: Dictionary = {}
	for entity_id: String in unit_ids():
		var state: UnitState = get_unit(entity_id)
		if state.faction_id == faction_id:
			own_units[entity_id] = state.snapshot()
	for group_id: String in _groups:
		if _groups[group_id].faction_id == faction_id:
			own_groups[group_id] = _groups[group_id].duplicate(true)
	return {"tick": tick, "time_s": time_s(), "faction_id": faction_id, "units": own_units,
		"groups": own_groups, "orders": orders_snapshot(faction_id), "contacts": _contacts[faction_id].duplicate(true)}

func emit_event(kind: String, entity_id: String = "", weapon_id: String = "", position_m: Vector3 = Vector3.ZERO, data: Dictionary = {}, target_id: String = "") -> BattleEvent:
	if kind.is_empty() or not position_m.is_finite() or not SimData.pure_data(data):
		return null
	_event_sequence += 1
	var event: BattleEvent = BattleEvent.new()
	event.sequence = _event_sequence
	event.event_id = "event_%08d" % _event_sequence
	event.tick = tick
	event.time_s = time_s()
	event.kind = kind
	event.entity_id = entity_id
	event.weapon_id = weapon_id
	event.target_id = target_id
	event.position_m = position_m
	event.data = data.duplicate(true)
	_outbox.append(event)
	_tick_events.append(event)
	return event.copy()

## Independent module mailbox; display draining cannot remove these events.
func events_for_tick(event_tick: int) -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	var source: Array[BattleEvent] = []
	if event_tick == tick:
		source = _tick_events
	elif event_tick == tick - 1:
		source = _previous_events
	for event: BattleEvent in source:
		result.append(event.copy())
	return result

## Presentation outbox only. Drain after advance; never gates mechanics or emission.
func drain_events() -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for event: BattleEvent in _outbox:
		result.append(event.copy())
	_outbox.clear()
	return result

func snapshot() -> Dictionary:
	var units: Dictionary = {}
	var modules: Dictionary = {}
	for entity_id: String in unit_ids():
		units[entity_id] = get_unit(entity_id).snapshot()
	for module: SimulationModule in _modules:
		modules[module.module_id] = module.snapshot_state().duplicate(true)
	return {"tick": tick, "time_s": time_s(), "seed": seed_value, "rng_state": rng.state,
		"units": units, "groups": _groups.duplicate(true), "orders": orders_snapshot(),
		"shared_state": shared_state.duplicate(true), "modules": modules}
