class_name FleetTasks
extends SimulationModule

var config: FleetConfig
var tasks: Dictionary = {}
var fleets: Dictionary = {}
var submitted_targets: Dictionary = {}
var serial: int = 0

func _init(parameters: FleetConfig) -> void:
	module_id = "fleet_tasks"
	priority = 310
	config = parameters

func supported_order_types() -> PackedStringArray:
	return ["patrol", "escort", "intercept", "engage", "regroup", "retreat"]

func order_domains() -> PackedStringArray:
	return ["ship"]

func accept_order(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String]) -> Dictionary:
	var world: SimulationWorld = world_ref as SimulationWorld
	if order.order_type == "intercept":
		return {"accepted": false, "reason": "ship_intercept_unsupported"}
	for id: String in unit_ids:
		if not config.supports(world.get_unit(id).definition_id):
			return {"accepted": false, "reason": "ship_performance_missing:" + id}
	if order.order_type in ["regroup", "retreat"] and order.area.is_empty() and order.waypoints_m.is_empty():
		return {"accepted": false, "reason": "ship_destination_required"}
	# Structural capability check only, exactly like S01 target-kind validation.
	# No live enemy geometry or damage enters execution or commander decisions.
	if order.order_type == "engage" and world.unit_definition(world.get_unit(order.target_id).definition_id).domain not in ["ship","ground"]:
		return {"accepted": false, "reason": "ship_engage_requires_surface_target"}
	return {"accepted": true, "reason": "ship_executor_capable"}

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	tasks.clear()
	fleets.clear()
	submitted_targets.clear()
	serial = 0
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if config.supports(unit.definition_id):
			unit.module_data.erase("ship_control")
			unit.module_data.erase("fleet_formation")
			unit.module_data["combat_intent"] = {"fire": false, "allow_aa": false}

func on_order_units_released(world_ref: RefCounted, _order: BattleOrder, unit_ids: Array[String], _reason: String) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in unit_ids:
		tasks.erase(id)
		var unit: UnitState = world.get_unit(id)
		unit.module_data.erase("ship_control")
		unit.module_data.erase("fleet_formation")
		unit.module_data["combat_intent"] = {"fire": false, "allow_aa": false}
		_set_target(world, unit, "")

func on_order_ended(_world_ref: RefCounted, order: BattleOrder) -> void:
	fleets.erase(order.order_id)

func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for record: Dictionary in world.orders_snapshot():
		var owned: Array[String] = world.owned_order_unit_ids(record.order_id, "ship")
		if owned.is_empty():
			continue
		if not fleets.has(record.order_id):
			fleets[record.order_id] = {"leader_id": "", "roster": owned.duplicate(), "settled_s": -1.0}
		var fleet: Dictionary = fleets[record.order_id]
		var previous: String = str(fleet.leader_id)
		fleet.leader_id = FleetFormations.elect(world, owned, config, previous)
		if str(fleet.leader_id) != previous:
			world.emit_event("fleet_flagship_changed", str(fleet.leader_id), "", world.get_unit(fleet.leader_id).position_m,
				{"order_id": record.order_id, "previous_id": previous, "reason": "flagship_selected" if previous.is_empty() else "flagship_replacement"})
		var leader: UnitState = world.get_unit(fleet.leader_id)
		var speed: float = FleetFormations.speed_limit(world, owned, config)
		var reform: bool = false
		for id: String in owned:
			if world.get_unit(id).position_m.distance_to(leader.position_m) > float(config.data.navigation.reform_distance_m):
				reform = true
		if reform:
			speed *= 0.45
		# One group-wide settlement clock, checked before releasing any member.
		if record.order_type == "regroup":
			var together: bool = true
			for id: String in owned:
				var member: UnitState = world.get_unit(id)
				if member.position_m.distance_to(_destination(record)) > float(record.area.get("radius_m", 500.0)) or member.velocity_mps.length() > 1.0:
					together = false
			fleet.settled_s = (float(fleet.settled_s) if float(fleet.settled_s) >= 0.0 else world.time_s()) if together else -1.0
		for id: String in owned:
			var unit: UnitState = world.get_unit(id)
			if not tasks.has(id):
				tasks[id] = {"order_id": record.order_id, "waypoint": 0, "phase": "", "reason": "", "last_seen_s": world.time_s(),
					"last_point": _destination(record) if not record.area.is_empty() or not record.waypoints_m.is_empty() else unit.position_m,
					"seen": false, "broadside_sign": 0.0}
				world.report_order_unit_status(record.order_id, id, "executing", "ship_task_received", "forming")
			var followers: Array[String] = owned.duplicate()
			followers.erase(leader.id)
			var slot: int = followers.find(id)
			unit.module_data["fleet_formation"] = {"leader_id": leader.id, "slot": slot, "role": "leader" if slot < 0 else "screen", "reforming": reform}
			_update_unit(world, unit, record, owned, leader, slot, speed, reform, fleet)

func _update_unit(world: SimulationWorld, unit: UnitState, order: Dictionary, owned: Array[String], leader: UnitState, slot: int, speed: float, reform: bool, fleet: Dictionary) -> void:
	var task: Dictionary = tasks[unit.id]
	var p: Dictionary = config.profile(unit.definition_id)
	if order.order_type in ["retreat", "regroup"]:
		var center: Vector3 = _destination(order)
		var radius: float = float(order.area.get("radius_m", 500.0))
		var distance: float = unit.position_m.distance_to(center)
		if order.order_type == "regroup" and float(fleet.settled_s) >= 0.0 and world.time_s() - float(fleet.settled_s) >= 2.0:
			world.report_order_unit_status(order.order_id, unit.id, "completed", "regroup_area_reached", "assembled")
			return
		if order.order_type == "retreat" and distance <= radius and unit.velocity_mps.length() < 2.0:
			world.report_order_unit_status(order.order_id, unit.id, "completed", "withdrawal_area_reached", "withdrawn")
			unit.module_data.ship_motion.exited = true
			unit.module_data.ship_motion.exit_reason = "ordered_retreat"
			unit.active = false
			world.emit_event("ship_exit", unit.id, "", unit.position_m, {"order_id": order.order_id, "reason": "ordered_retreat", "destroyed": false, "sunk": false})
			return
		if order.order_type == "retreat" and distance > radius:
			var damage: Dictionary = unit.module_data.get("damage", {})
			var no_propulsion: bool = float(damage.get("propulsion_factor", 1.0)) <= 0.001
			var no_fuel: bool = float(unit.module_data.ship_motion.fuel_fraction) <= 0.0
			if no_propulsion or no_fuel:
				# A blocked retreat remains the same owned mission: no false arrival,
				# no repeated failed orders. Available self-defence still works.
				_steer(unit, center, 0.0)
				var threat: Dictionary = _surface_threat(world, unit, unit.position_m, float(p.engagement_range_m))
				_fire(world, unit, str(threat.get("entity_id", "")), true)
				_progress(world, unit, task, "blocked", "propulsion_unavailable" if no_propulsion else "fuel_exhausted", center)
				return
		# Separate destination stations fit inside the requested area.
		var index: int = owned.find(unit.id)
		var offset: Vector3 = Vector3(float(index) - float(owned.size() - 1) * 0.5, 0, 0) * minf(radius * 0.65 / maxf(1.0, owned.size() * 0.5), float(config.data.navigation.station_spacing_m))
		var goal: Vector3 = center + offset
		var remaining: float = unit.position_m.distance_to(goal)
		var target_speed: float = minf(float(p.cruise_mps), sqrt(2.0 * float(p.braking_mps2) * maxf(0.0, remaining - radius * 0.25)))
		_steer(unit, goal, target_speed)
		_fire(world, unit, "", order.order_type == "retreat")
		_progress(world, unit, task, "withdraw" if order.order_type == "retreat" else "regroup", "ordered_retreat" if order.order_type == "retreat" else "gathering_surviving_members", goal)
		return
	if order.order_type == "engage":
		var contact: Dictionary = CombatContacts.find(world, unit.faction_id, order.target_id)
		if not contact.is_empty():
			task.seen = true
			task.last_seen_s = contact.observed_time_s
			task.last_point = contact.position_m
			var point: Vector3 = contact.position_m + (contact.velocity_mps as Vector3) * maxf(0.0, world.time_s() - float(contact.observed_time_s))
			var delta: Vector3 = point - unit.position_m
			var distance: float = delta.length()
			var bearing: float = atan2(-delta.x, -delta.z)
			var range_m: float = float(p.engagement_range_m)
			var goal: Vector3
			var phase: String
			if distance > range_m * 1.15:
				goal = point
				if contact.domain == "ground":
					goal = unit.position_m + delta.normalized() * (distance - range_m * 0.9)
				phase = "approach"
			else:
				if float(task.broadside_sign) == 0.0:
					task.broadside_sign = 1.0 if absf(wrapf(bearing + PI * 0.5 - unit.rotation_rad.y, -PI, PI)) < absf(wrapf(bearing - PI * 0.5 - unit.rotation_rad.y, -PI, PI)) else -1.0
				var tangent: float = bearing + float(task.broadside_sign) * PI * 0.5
				var radial_correction: float = clampf((range_m - distance) / range_m, -0.5, 0.5) * float(task.broadside_sign)
				var heading: float = tangent + radial_correction
				goal = unit.position_m + Basis(Vector3.UP, heading) * Vector3(0, 0, -2000)
				phase = "broadside" if absf(absf(wrapf(bearing - unit.rotation_rad.y, -PI, PI)) - PI * 0.5) < 0.35 else "deploy"
			if unit.id != leader.id:
				goal = FleetFormations.station(leader, slot, "engage", float(config.data.navigation.station_spacing_m)) + leader.velocity_mps * 15.0
			_steer(unit, goal, minf(float(p.cruise_mps), speed))
			_fire(world, unit, order.target_id if distance < range_m * 1.35 else "", true)
			_progress(world, unit, task, phase, "close_to_gunnery_range" if phase == "approach" else ("turning_to_broadside" if phase == "deploy" else "maintain_gunnery_range"), goal)
			return
		var stale: Dictionary = CombatContacts.find(world, unit.faction_id, order.target_id, false)
		if not stale.is_empty():
			task.seen = true
			task.last_seen_s = stale.observed_time_s
			task.last_point = stale.position_m
		_fire(world, unit, "", true)
		if world.time_s() - float(task.last_seen_s) >= float(config.data.navigation.search_timeout_s):
			world.report_order_unit_status(order.order_id, unit.id, "failed", "contact_not_reacquired", "search_exhausted")
			return
		var goal: Vector3 = task.last_point
		if unit.position_m.distance_to(goal) < 250.0:
			goal += Basis(Vector3.UP, unit.rotation_rad.y - 0.6) * Vector3(0, 0, -900)
		_steer(unit, goal, speed * 0.7)
		_progress(world, unit, task, "search", "last_known_contact" if task.seen else "awaiting_own_contact", goal)
		return
	var goal: Vector3
	var phase: String = "cruise"
	var reason: String = "following_route"
	if order.order_type == "escort":
		var core: UnitState = world.get_unit(order.target_id) # validated friendly
		if not core.active:
			world.report_order_unit_status(order.order_id, unit.id, "failed", "protected_unit_lost", "protection_ended")
			return
		goal = FleetFormations.station(core, owned.find(unit.id), "escort", float(config.data.navigation.station_spacing_m))
		speed = minf(float(p.max_mps), core.velocity_mps.length() + (unit.position_m.distance_to(goal) - 80.0) * 0.015)
		goal += core.velocity_mps * 12.0
		phase = "air_defence" if order.intent == "air_defence_cover" else "guard"
		reason = "air_defence_screen" if phase == "air_defence" else "core_protection"
		var defending: Dictionary = _surface_threat(world, unit, core.position_m, float(p.engagement_range_m))
		_fire(world, unit, str(defending.get("entity_id", "")), true)
	else:
		_fire(world, unit, "", true)
		if unit.id == leader.id:
			goal = _patrol_goal(unit, order, task)
			if reform:
				phase = "regroup"
				reason = "slow_member_reform"
		else:
			goal = FleetFormations.station(leader, slot, "patrol", float(config.data.navigation.station_spacing_m))
			var error: float = unit.position_m.distance_to(goal)
			speed = clampf(leader.velocity_mps.length() + (error - 70.0) * 0.015, 0.0, float(p.max_mps))
			goal += leader.velocity_mps * 12.0
			phase = "forming" if error > 300.0 else "cruise"
			reason = "rejoining_station" if error > 300.0 else "station_keeping"
	_steer(unit, goal, maxf(0.0, speed))
	_progress(world, unit, task, phase, reason, goal)

func _patrol_goal(unit: UnitState, order: Dictionary, task: Dictionary) -> Vector3:
	var route: Array = order.waypoints_m
	if route.is_empty():
		var center: Vector3 = SimData.vec3(order.area.center_m)
		var radius: float = float(order.area.radius_m) * 0.7
		route = [SimData.array3(center + Vector3(-radius, 0, -radius)), SimData.array3(center + Vector3(radius, 0, -radius)), SimData.array3(center + Vector3(radius, 0, radius)), SimData.array3(center + Vector3(-radius, 0, radius))]
	var goal: Vector3 = SimData.vec3(route[int(task.waypoint) % route.size()])
	if unit.position_m.distance_to(goal) < maxf(200.0, unit.velocity_mps.length() * 18.0):
		task.waypoint = (int(task.waypoint) + 1) % route.size()
		goal = SimData.vec3(route[int(task.waypoint)])
	return goal

func _surface_threat(world: SimulationWorld, unit: UnitState, core: Vector3, radius: float) -> Dictionary:
	var contacts: Array = world.shared_state.get("combat_contacts", {}).get(unit.faction_id, {}).values()
	return FleetPlanner.select_surface_contact(contacts, unit.position_m, core, radius, unit.target_id, false)

static func _destination(order: Dictionary) -> Vector3:
	return SimData.vec3(order.area.center_m) if not order.area.is_empty() else SimData.vec3(order.waypoints_m[-1])

static func _steer(unit: UnitState, goal: Vector3, speed: float) -> void:
	goal.y = unit.position_m.y
	unit.module_data["ship_control"] = {"goal_m": goal, "speed_mps": speed}

func _fire(world: SimulationWorld, unit: UnitState, target: String, allow_aa: bool) -> void:
	unit.module_data["combat_intent"] = {"fire": not target.is_empty(), "allow_aa": allow_aa}
	_set_target(world, unit, target)

func _set_target(world: SimulationWorld, unit: UnitState, target: String) -> void:
	# Loss/release is not a valid command recipient. Forget our own cache only.
	if not unit.active:
		submitted_targets.erase(unit.id)
		return
	if str(submitted_targets.get(unit.id, unit.target_id)) == target:
		return
	serial += 1
	var command: BattleCommand = BattleCommand.new()
	command.command_id = "ship_target:%d:%s" % [serial, unit.id]
	command.issuer_id = module_id
	command.faction_id = unit.faction_id
	command.entity_id = unit.id
	command.kind = BattleCommand.SET_TARGET
	command.payload = {"target_id": target}
	if world.submit_command(command).accepted:
		submitted_targets[unit.id] = target

func _progress(world: SimulationWorld, unit: UnitState, task: Dictionary, phase: String, reason: String, goal: Vector3) -> void:
	var avoidance_reason: String = str(unit.module_data.get("ship_motion", {}).get("avoidance_reason", ""))
	if not avoidance_reason.is_empty() and phase != "blocked":
		reason = avoidance_reason
		if avoidance_reason == "coast_unreachable": phase = "blocked"
	unit.task["ship"] = {"order_id": task.order_id, "phase": phase, "reason": reason, "goal_m": goal, "distance_m": unit.position_m.distance_to(goal),
		"leader_id": unit.module_data.fleet_formation.leader_id, "slot": unit.module_data.fleet_formation.slot}
	if str(task.phase) != phase or str(task.reason) != reason:
		task.phase = phase
		task.reason = reason
		world.report_order_unit_progress(task.order_id, unit.id, phase, reason)

func snapshot_state() -> Dictionary:
	return {"tasks": tasks.duplicate(true), "fleets": fleets.duplicate(true), "targets": submitted_targets.duplicate(true), "serial": serial}
