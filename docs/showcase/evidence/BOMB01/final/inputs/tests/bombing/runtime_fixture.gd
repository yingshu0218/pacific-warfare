extends RefCounted
const DATA: Script=preload("res://tests/bombing/data_fixture.gd")

static func arena(spawns: Array, flight_enabled: bool = true, terrain: bool = false, custom: CombatConfig = null, ops: bool = false, combat: bool = false) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.local"))
	var c: CombatConfig = DATA.config() if custom == null else custom
	var world: SimulationWorld = SimulationWorld.new()
	var errors: PackedStringArray = world.configure(DATA.catalog(),{"id":"bomb01_private","seed":1126,"tick_hz":60,"factions":["us","jp"],"spawns":spawns,"groups":[]})
	assert(errors.is_empty(),str(errors))
	if terrain:
		errors = BattlefieldTerrain.install(world,"res://data/maps/island_harbor_expanded.json")
		assert(errors.is_empty(),str(errors))
	var frame: CombatFrame = CombatFrame.new(c)
	var contacts: CombatContacts = CombatContacts.new(c,frame)
	var rounds: CombatProjectiles = CombatProjectiles.new(c,frame)
	var racks: RefCounted = load("res://scripts/bombing/stores.gd").new(rounds,DATA.parameters())
	var delegate: RefCounted = load("res://scripts/bombing/mission_delegate.gd").new(DATA.parameters(),racks)
	var tasks: AircraftTasks = load("res://scripts/bombing/ops_task_bridge.gd").new() if ops else AircraftTasks.new()
	var operations: RefCounted = null
	if ops:
		operations = load("res://scripts/air_operations/carrier_operations.gd").new()
		tasks.set("operations",operations)
		tasks.set("mission_delegate",delegate)
	else: tasks.set("bombing_delegate",delegate)
	var modules: Array[SimulationModule] = [frame,contacts,tasks,racks,rounds,CombatDamage.new(c,frame)]
	if combat:
		modules.append(CombatTargeting.new(c,frame,contacts))
		modules.append(CombatWeapons.new(c,frame,contacts,rounds))
	if ops: modules.append(operations as SimulationModule)
	if flight_enabled:
		var flight: AircraftMotion = load("res://scripts/air_operations/flight_bridge.gd").new() if ops else AircraftMotion.new()
		if ops: flight.set("operations",operations)
		modules.append(flight)
	for module: SimulationModule in modules: assert(world.register_module(module).accepted)
	return {"world":world,"config":c,"frame":frame,"projectiles":rounds,"stores":racks,"delegate":delegate,"contacts":contacts,"tasks":tasks,"operations":operations}

