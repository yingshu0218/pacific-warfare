class_name AircraftSpatialFixture
extends RefCounted

static func build(kind: String = "standard", baseline: bool = false) -> SimulationWorld:
	if kind == "current":
		var session: FirstPlayableSession = FirstPlayableSession.new()
		var scene: PackedScene = load("res://showcase/first_playable.tscn")
		var entry: Node = scene.instantiate()
		var scenario_path: String = str(entry.get("scenario_path"))
		entry.free()
		var errors: PackedStringArray = session.load_battle(scenario_path)
		assert(errors.is_empty(),str(errors))
		return session.world
	var scenario: Dictionary
	if kind == "standard":
		scenario = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/first_playable.json"))
	else:
		var count: int = 4 if kind == "four" else 2
		var spawns: Array = []
		for i: int in range(count):
			var offset: Vector3 = Vector3(-350*(i/2)+90*(i%2),1500,330*(i/2)+180*(i%2))
			spawns.append(AircraftFixture.spawn("jp_%d" % i,"jp",offset,"jp_a6m5a_1944",0,120))
			spawns.append(AircraftFixture.spawn("us_%d" % i,"us",Vector3(-offset.x,offset.y,-3800-offset.z),"us_f6f5_1944",PI,120))
		scenario = {"id":"spatial_"+kind,"seed":404,"tick_hz":60,"factions":["jp","us"],"spawns":spawns,"groups":[]}
	var world: SimulationWorld = SimulationWorld.new()
	assert(world.configure(AircraftFixture.catalog(),scenario).is_empty())
	if baseline:
		assert(world.register_module(BaselineAircraftTasks.new()).accepted)
		assert(world.register_module(BaselineAircraftMotion.new()).accepted)
	else:
		assert(AircraftSuite.install(world).is_empty())
	var combat: CombatConfig = CombatConfig.new()
	assert(combat.load_file("res://data/combat/showcase.json").is_empty())
	if kind == "standard":
		combat.data.environment = scenario.environment.duplicate(true)
	assert(CombatSuite.install(world,combat).is_empty())
	if kind == "standard":
		var fleet: FleetConfig = FleetConfig.new()
		assert(fleet.load_file().is_empty())
		fleet.data.navigation.solids = scenario.environment.solids.duplicate(true)
		assert(FleetSuite.install(world,fleet,true).is_empty())
	else:
		issue(world,4 if kind == "four" else 2)
	return world

static func issue(world: SimulationWorld, count: int) -> void:
	var jp: Array[String] = []
	var us: Array[String] = []
	for i: int in range(count):
		jp.append("jp_%d" % i)
		us.append("us_%d" % i)
	AircraftFixture.order(world,"jp_engage",jp,"engage","us_0")
	AircraftFixture.order(world,"us_engage",us,"engage","jp_0")
