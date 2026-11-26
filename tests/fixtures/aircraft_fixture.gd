class_name AircraftFixture
extends RefCounted

const CHECK: Script = preload("res://tests/fixtures/combat_fixture.gd")

static func catalog() -> DefinitionCatalog:
	var records: Array[String] = []
	var ammunition: Array[String] = []
	var weapons: Array[String] = []
	for file: String in DirAccess.get_files_at("res://data/units"):
		if file.ends_with(".json"):
			records.append("res://data/units/" + file)
	for file: String in DirAccess.get_files_at("res://data/ammunition"):
		if file.ends_with(".json"):
			ammunition.append("res://data/ammunition/" + file)
	for file: String in DirAccess.get_files_at("res://data/units/weapons"):
		if file.ends_with(".json"):
			weapons.append("res://data/units/weapons/" + file)
	var result: DefinitionCatalog = DefinitionCatalog.new()
	var errors: PackedStringArray = result.load_files(records, ammunition, weapons)
	if not CHECK.require_ok(errors.is_empty(),str(errors)): return null
	return result

static func spawn(id: String, faction: String, position: Vector3, definition: String = "jp_a6m5a_1944", yaw: float = 0.0, speed: float = 110.0, initial: Dictionary = {}) -> Dictionary:
	return {"id": id, "unit_definition_id": definition, "faction_id": faction, "position_m": SimData.array3(position),
		"velocity_mps": SimData.array3(Basis(Vector3.UP, yaw) * Vector3(0, 0, -speed)), "rotation_rad": [0.0, yaw, 0.0],
		"module_data": {"aircraft_initial": initial}}

static func world(spawns: Array, combat: bool = false, groups: Array = []) -> SimulationWorld:
	var result: SimulationWorld = SimulationWorld.new()
	var errors: PackedStringArray = result.configure(catalog(), {"id": "S04_air_test", "seed": 404, "tick_hz": 60,
		"factions": ["jp", "us"], "spawns": spawns, "groups": groups})
	if not CHECK.require_ok(errors.is_empty(),str(errors)): return null
	errors = AircraftSuite.install(result)
	if not CHECK.require_ok(errors.is_empty(),str(errors)): return null
	if combat:
		var config: CombatConfig = CombatConfig.new()
		errors = config.load_file("res://data/combat/showcase.json")
		if not CHECK.require_ok(errors.is_empty(),str(errors)): return null
		errors = CombatSuite.install(result, config)
		if not CHECK.require_ok(errors.is_empty(),str(errors)): return null
	return result

static func order(world_ref: SimulationWorld, id: String, recipients: Array[String], kind: String, target: String = "", center: Vector3 = Vector3(0, 1500, 0), radius: float = 1500.0) -> BattleOrder:
	var result: BattleOrder = BattleOrder.new()
	result.order_id = id
	result.issuer_id = "air_test_commander"
	result.faction_id = world_ref.get_unit(recipients[0]).faction_id
	result.recipient_ids = recipients
	result.order_type = kind
	result.target_id = target
	result.area = {"center_m": SimData.array3(center), "radius_m": radius}
	var receipt: Dictionary = world_ref.submit_order(result)
	if not CHECK.require_accepted(receipt,"submit aircraft order"): return null
	return result

static func cancel(world_ref: SimulationWorld, id: String) -> void:
	var command: BattleCommand = BattleCommand.new()
	command.command_id = "cancel:" + id
	command.issuer_id = "air_test_commander"
	command.faction_id = "jp"
	command.kind = BattleCommand.CANCEL_ORDER
	command.payload = {"order_id": id, "reason": "test_cancel"}
	var receipt: Dictionary = world_ref.submit_command(command)
	CHECK.require_accepted(receipt,"cancel aircraft order")

static func run(world_ref: SimulationWorld, seconds: float) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for i: int in range(int(seconds * 60.0)):
		world_ref.step_ticks(1)
		events.append_array(world_ref.drain_events())
	return events

static func contacts(world_ref: SimulationWorld, faction: String, records: Array) -> void:
	if not world_ref.shared_state.has("combat_contacts"):
		world_ref.shared_state["combat_contacts"] = {}
	var index: Dictionary = {}
	for record: Dictionary in records:
		index[record.entity_id] = record
	world_ref.shared_state.combat_contacts[faction] = index
	world_ref.set_contacts(faction, records)

static func contact(id: String, point: Vector3, velocity: Vector3 = Vector3(0, 0, -100), tick: int = 0, fresh: bool = true) -> Dictionary:
	return {"entity_id": id, "domain": "aircraft", "classification": "aircraft", "position_m": point, "velocity_mps": velocity,
		"observed_tick": tick, "observed_time_s": float(tick) / 60.0, "fresh": fresh, "valid": true, "sensor": "visual", "uncertainty_m": 0.0}
