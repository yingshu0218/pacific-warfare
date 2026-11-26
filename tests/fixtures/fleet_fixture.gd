class_name FleetFixture
extends RefCounted

class ContactPublisher extends SimulationModule:
	func _init() -> void:
		module_id = "test_fleet_contact_publisher"
		priority = 100
	func fixed_update(world_ref: RefCounted, _dt: float) -> void:
		var world_ref_typed: SimulationWorld = world_ref as SimulationWorld
		for faction: String in world_ref_typed.shared_state.get("combat_contacts", {}):
			# Controlled sensor fixture, supplied pure records only. No enemy reads.
			world_ref_typed.set_contacts(faction, world_ref_typed.shared_state.combat_contacts[faction].values())

static func spawn(id: String, position: Vector3, speed: float = 0.0, yaw: float = 0.0, definition: String = "jp_yukikaze_1942_06", faction: String = "jp", initial: Dictionary = {}) -> Dictionary:
	return {"id": id, "unit_definition_id": definition, "faction_id": faction, "position_m": SimData.array3(position),
		"velocity_mps": SimData.array3(Basis(Vector3.UP, yaw) * Vector3(0, 0, -speed)), "rotation_rad": [0.0, yaw, 0.0], "module_data": {"ship_initial": initial}}

static func config() -> FleetConfig:
	var result: FleetConfig = FleetConfig.new()
	assert(result.load_file().is_empty())
	return result

static func world(spawns: Array, groups: Array = [], commanders: bool = false, combat: bool = false, settings: FleetConfig = null, tick_hz: int = 60) -> SimulationWorld:
	var result: SimulationWorld = SimulationWorld.new()
	assert(result.configure(AircraftFixture.catalog(), {"id": "S06_fleet_test", "seed": 606, "tick_hz": tick_hz,
		"factions": ["jp", "us"], "spawns": spawns, "groups": groups}).is_empty())
	assert(AircraftSuite.install(result).is_empty())
	if combat:
		var c: CombatConfig = CombatConfig.new()
		assert(c.load_file("res://data/combat/showcase.json").is_empty())
		assert(CombatSuite.install(result, c).is_empty())
	else:
		assert(result.register_module(ContactPublisher.new()).accepted)
	assert(FleetSuite.install(result, settings, commanders).is_empty())
	return result

static func order(world_ref: SimulationWorld, id: String, recipients: Array, kind: String, target: String = "", center: Vector3 = Vector3(0, 0, -3000), radius: float = 600.0, source: String = "ai", intent: String = "test_mission") -> BattleOrder:
	var result: BattleOrder = BattleOrder.new()
	result.order_id = id
	result.issuer_id = "fleet_test_commander"
	result.source = source
	result.faction_id = world_ref.get_unit(world_ref.recipient_unit_ids(recipients[0])[0]).faction_id
	result.recipient_ids.assign(recipients)
	result.order_type = kind
	result.target_id = target
	result.area = {"center_m": SimData.array3(center), "radius_m": radius}
	result.intent = intent
	assert(world_ref.submit_order(result).accepted)
	return result

static func run(world_ref: SimulationWorld, seconds: float) -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for i: int in range(roundi(seconds / world_ref.fixed_delta_s())):
		world_ref.step_ticks(1)
		result.append_array(world_ref.drain_events())
	return result

static func contact(world_ref: SimulationWorld, id: String, point: Vector3, fresh: bool = true, faction: String = "jp", domain: String = "ship") -> void:
	AircraftFixture.contacts(world_ref, faction, [{"entity_id": id, "domain": domain, "classification": domain, "position_m": point, "velocity_mps": Vector3.ZERO,
		"observed_tick": world_ref.tick, "observed_time_s": world_ref.time_s(), "fresh": fresh, "valid": true, "sensor": "visual", "uncertainty_m": 0.0}])

static func cancel(world_ref: SimulationWorld, order_id: String) -> void:
	var command: BattleCommand = BattleCommand.new()
	command.command_id = "cancel:" + order_id
	command.issuer_id = "fleet_test_commander"
	command.faction_id = "jp"
	command.source = "human"
	command.kind = BattleCommand.CANCEL_ORDER
	command.payload = {"order_id": order_id, "reason": "observer_test_cancel"}
	assert(world_ref.submit_command(command).accepted)

static func record(world_ref: SimulationWorld, id: String) -> Dictionary:
	for order_record: Dictionary in world_ref.orders_snapshot():
		if str(order_record.order_id) == id:
			return order_record
	return {}

static func json_data(value: Variant) -> Variant:
	if value is Vector3:
		return SimData.array3(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value:
			result[key] = json_data(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(json_data(item))
		return result
	return value
