extends SimulationModule

const WAVE_ORDER: String = "qj01:wave:01"
const WITHDRAW_ORDER: String = "qj01:withdraw"
const LOST_CARRIER_PHASES: Array[String] = ["sinking", "wreck", "removed"]

var carrier_id: String
var airframe_ids: Array[String] = []
var exit_center_m: Vector3
var exit_radius_m: float
var patrol_area: Dictionary
var window_s: float
var deadline_tick: int
var roster: Dictionary = {}
var result: Dictionary = {}

func _init(settings: Dictionary) -> void:
	module_id = "qingjia_recovery"
	priority = 900
	carrier_id = str(settings.carrier_id)
	airframe_ids.assign(settings.airframe_ids)
	exit_center_m = SimData.vec3(settings.exit_center_m)
	exit_radius_m = float(settings.exit_radius_m)
	patrol_area = settings.patrol_area.duplicate(true)
	window_s = float(settings.window_s)

func validate(world: SimulationWorld, operations: CarrierOperations) -> PackedStringArray:
	var carrier: UnitState = world.get_unit(carrier_id)
	if carrier == null or operations == null or operations.carrier_id != carrier_id:
		return ["qingjia_carrier_missing"]
	if world.unit_definition(carrier.definition_id).domain != "ship" or _in_exit(carrier.position_m):
		return ["qingjia_carrier_must_start_outside_exit"]
	if airframe_ids.size() != 2 or airframe_ids[0] == airframe_ids[1]:
		return ["qingjia_requires_two_distinct_airframes"]
	for id: String in airframe_ids:
		var unit: UnitState = world.get_unit(id)
		if unit == null or unit.definition_id != "us_f6f5_1944" or unit.faction_id != carrier.faction_id or not operations.roster.has(id):
			return ["qingjia_invalid_airframe:" + id]
	if not is_finite(window_s) or window_s <= 0.0 or not is_finite(exit_radius_m) or exit_radius_m <= 0.0 or not exit_center_m.is_finite():
		return ["qingjia_invalid_window_or_exit"]
	return []

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	deadline_tick = floori(window_s / world.fixed_delta_s() + 0.000001)
	result.clear()
	roster.clear()
	var carrier: UnitState = world.get_unit(carrier_id)
	for id: String in airframe_ids:
		roster[id] = {"unit_id":id, "sortie_serial":0, "launch_tick":-1, "recovery_tick":-1,
			"last_known_tick":0, "last_known":"initial_deck", "carrier_id":carrier_id}
		world.get_unit(id).module_data["command_assignment"] = {"manager_id":module_id, "mission_id":WAVE_ORDER, "phase":"active"}
	var patrol: BattleOrder = _order(WAVE_ORDER, carrier.faction_id, "patrol", airframe_ids)
	patrol.target_id = carrier_id
	patrol.area = patrol_area.duplicate(true)
	var withdraw: BattleOrder = _order(WITHDRAW_ORDER, carrier.faction_id, "retreat", [carrier_id])
	withdraw.area = {"center_m":SimData.array3(exit_center_m), "radius_m":exit_radius_m}
	for order: BattleOrder in [patrol, withdraw]:
		var receipt: Dictionary = world.submit_order(order)
		if not receipt.accepted: push_error("QJ01 initial order rejected: " + str(receipt))

func _order(id: String, faction: String, kind: String, recipients: Array[String]) -> BattleOrder:
	var order: BattleOrder = BattleOrder.new()
	order.order_id = id
	order.faction_id = faction
	order.issuer_id = "scenario_%s_command" % faction
	order.order_type = kind
	order.recipient_ids = recipients.duplicate()
	order.intent = WAVE_ORDER if kind == "patrol" else WITHDRAW_ORDER
	return order

func fixed_update(world_ref: RefCounted, _delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	if not result.is_empty(): return
	for event: BattleEvent in world.events_for_tick(world.tick):
		if roster.has(event.entity_id): _observe_event(event)
	var carrier: UnitState = world.get_unit(carrier_id)
	for id: String in airframe_ids:
		_observe_airframe(world, id)
	var phase: String = _damage_phase(carrier)
	if phase in LOST_CARRIER_PHASES:
		_freeze(world, "failed", "carrier_lost")
	elif (carrier.active or phase == "disabled") and _in_exit(carrier.position_m):
		_freeze(world, "arrived", "exit_reached")
	elif world.tick >= deadline_tick:
		_freeze(world, "failed", "deadline")

func interrupt(world: SimulationWorld) -> void:
	if result.is_empty(): _freeze(world, "interrupted", "manual")

func _observe_event(event: BattleEvent) -> void:
	var row: Dictionary = roster[event.entity_id]
	if event.kind == "unit_impact":
		_mark(row, event.tick, "lost" if event.data.get("destroyed", false) else "ditched")
	elif event.kind == "aircraft_exit":
		_mark(row, event.tick, "withdrawn")
	elif event.kind == "carrier_operation_phase" and event.target_id == carrier_id and event.data.get("sortie_order_id", "") == WAVE_ORDER:
		var serial: int = int(event.data.get("sortie_serial", 0))
		if event.data.reason == "airspeed_and_deck_run_complete" and serial > 0 and row.launch_tick < 0:
			row.launch_tick = event.tick
			row.sortie_serial = serial
		elif event.data.reason == "recovered_and_parked" and event.tick > row.launch_tick and row.launch_tick >= 0 and serial == row.sortie_serial and row.recovery_tick < 0:
			row.recovery_tick = event.tick

func _observe_airframe(world: SimulationWorld, id: String) -> void:
	var unit: UnitState = world.get_unit(id)
	if unit == null: return
	var row: Dictionary = roster[id]
	if row.last_known in ["lost", "ditched", "withdrawn"]: return
	if _damage_phase(unit) == "crashing":
		_mark(row, world.tick, "crashing")
	elif _damage_phase(unit) in ["wreck", "removed"]:
		_mark(row, world.tick, "lost")
	elif unit.active:
		var ops: Dictionary = unit.module_data.get("carrier_ops", {})
		var host: String = str(ops.get("carrier_id", ""))
		var on_deck: bool = bool(ops.get("on_deck", false))
		var state: String = "airborne"
		if on_deck and not host.is_empty():
			if host != carrier_id: state = "other_carrier"
			elif _aboard(unit, row): state = "recovered_aboard"
			elif row.launch_tick < 0 and int(ops.get("sorties", 0)) == 0: state = "initial_deck"
			else: state = "deck_without_qualifying_recovery"
		else:
			var phase: String = str(ops.get("phase", ""))
			if phase in ["return", "holding", "approach", "go_around", "diverted"]: state = phase
		_mark(row, world.tick, state, host if on_deck else "")

func _mark(row: Dictionary, tick: int, state: String, host: String = "") -> void:
	row.last_known_tick = tick
	row.last_known = state
	row.carrier_id = host

func _aboard(unit: UnitState, row: Dictionary) -> bool:
	if unit == null or not unit.active or row.recovery_tick < 0 or _damage_phase(unit) in ["crashing", "wreck", "removed"]:
		return false
	var ops: Dictionary = unit.module_data.get("carrier_ops", {})
	return bool(ops.get("on_deck", false)) and ops.get("carrier_id", "") == carrier_id and ops.get("sortie_order_id", "") == WAVE_ORDER and int(ops.get("sorties", 0)) == row.sortie_serial

func _in_exit(position: Vector3) -> bool:
	return Vector2(position.x - exit_center_m.x, position.z - exit_center_m.z).length_squared() <= exit_radius_m * exit_radius_m

func _damage_phase(unit: UnitState) -> String:
	return str(unit.module_data.get("damage", {}).get("phase", "operational"))

func _freeze(world: SimulationWorld, outcome: String, reason: String) -> void:
	result = _report(world, outcome, reason)
	world.set_paused(true)

func report(world: SimulationWorld) -> Dictionary:
	return _report(world, "pending", "") if result.is_empty() else result.duplicate(true)

func _report(world: SimulationWorld, outcome: String, reason: String) -> Dictionary:
	var carrier: UnitState = world.get_unit(carrier_id)
	var rows: Array[Dictionary] = []
	var aboard_count: int = 0
	for id: String in airframe_ids:
		var row: Dictionary = roster[id].duplicate(true)
		var unit: UnitState = world.get_unit(id)
		row["aboard"] = _damage_phase(carrier) not in LOST_CARRIER_PHASES and _aboard(unit, row)
		row["withdrew"] = outcome == "arrived" and row.aboard
		row["status"] = row.last_known
		if (unit == null or not unit.active) and row.last_known not in ["crashing", "lost", "ditched", "withdrawn"]:
			row.status = "unknown"
		if row.aboard: aboard_count += 1
		rows.append(row)
	var status: String = outcome
	if outcome == "arrived": status = "complete" if aboard_count == airframe_ids.size() else "partial"
	return {"status":status, "reason":reason, "tick":world.tick, "tick_hz":roundi(1.0 / world.fixed_delta_s()),
		"deadline_tick":deadline_tick, "wave_order_id":WAVE_ORDER, "withdraw_order_id":WITHDRAW_ORDER,
		"carrier_id":carrier_id, "carrier_phase":_damage_phase(carrier), "carrier_active":carrier.active,
		"carrier_position_m":SimData.array3(carrier.position_m), "exit_center_m":SimData.array3(exit_center_m), "exit_radius_m":exit_radius_m,
		"aboard_count":aboard_count, "withdrawn_count":aboard_count if outcome == "arrived" else 0, "airframes":rows}
