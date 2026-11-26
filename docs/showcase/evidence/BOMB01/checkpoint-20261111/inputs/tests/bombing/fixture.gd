extends RefCounted

const BASE: Script = preload("res://tests/fixtures/combat_fixture.gd")

static func parameters() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/bombing/data/parameters.json"))

static func catalog() -> DefinitionCatalog:
	var units: Array = []
	var ammunition: Array = []
	var guns: Array = []
	for pair: Array in [["res://data/units",units],["res://data/ammunition",ammunition],["res://data/units/weapons",guns]]:
		for file: String in DirAccess.get_files_at(pair[0]):
			if file.ends_with(".json"): pair[1].append(JSON.parse_string(FileAccess.get_file_as_string(str(pair[0])+"/"+file)))
	units.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tests/bombing/data/units.json")))
	ammunition.append_array(parameters().ammunition.values())
	var result: DefinitionCatalog = DefinitionCatalog.new()
	var errors: PackedStringArray = result.load_data(units,ammunition,guns)
	assert(errors.is_empty(),str(errors))
	return result

static func config() -> CombatConfig:
	var c: CombatConfig = BASE.config()
	var params: Dictionary = parameters()
	c.data.ammo_profiles.merge(params.ammo_profiles,true)
	var sb: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/s14_sb2c.json"))
	c.data.unit_profiles.merge(sb.unit_profiles,true)
	for id: String in params.aircraft:
		if c.data.unit_profiles.has(id): continue
		var large: bool = "g4m1" in id
		var profile: Dictionary = c.data.unit_profiles.us_f6f5_1944.duplicate(true)
		profile.structure = 160.0 if large else 85.0
		profile.visual_m = 15000.0
		profile.boxes = [
			{"part":"control","center_m":[0,0,0],"half_extents_m":[1.25,1.0,7.8] if large else [.5,.6,3.5],"armor_mm":0.0},
			{"part":"engine","center_m":[-3.85,0,-4.8] if large else [0,0,-3.4],"half_extents_m":[.9,.9,1.3],"armor_mm":0.0},
			{"part":"engine","center_m":[3.85,0,-4.8] if large else [0,0,-3.4],"half_extents_m":[.9,.9,1.3],"armor_mm":0.0},
			{"part":"wing_left","center_m":[-6.6,0,-2.0] if large else [-3.,0,-.5],"half_extents_m":[5.8,.2,1.8] if large else [2.7,.15,1.2],"armor_mm":0.0},
			{"part":"wing_right","center_m":[6.6,0,-2.0] if large else [3.,0,-.5],"half_extents_m":[5.8,.2,1.8] if large else [2.7,.15,1.2],"armor_mm":0.0},
			{"part":"tail","center_m":[0,.4,8.] if large else [0,.4,4.1],"half_extents_m":[4.6,1.2,1.5] if large else [2.2,1.,.8],"armor_mm":0.0}]
		c.data.unit_profiles[id] = profile
	assert(c.load_data(c.data).is_empty())
	return c

static func spawn(id: String, faction: String, position: Vector3, definition: String, velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	var result: Dictionary = BASE.spawn(id,faction,position,definition,velocity)
	if velocity.length() > 1:
		result["rotation_rad"] = SimData.array3(AircraftFlightMath.frame(velocity.normalized(),Vector3.UP).get_euler())
	result["module_data"] = {"aircraft_initial":{"withdrawal_center_m":SimData.array3(Vector3(position.x,1300,position.z+2500))},"combat_intent":{"fire":false,"allow_aa":false,"burst_until_tick":-1}}
	return result

static func arena(spawns: Array, flight_enabled: bool = true, terrain: bool = false, custom: CombatConfig = null) -> Dictionary:
	var c: CombatConfig = config() if custom == null else custom
	var world: SimulationWorld = SimulationWorld.new()
	var errors: PackedStringArray = world.configure(catalog(),{"id":"bomb01_private","seed":1126,"tick_hz":60,"factions":["us","jp"],"spawns":spawns,"groups":[]})
	assert(errors.is_empty(),str(errors))
	if terrain:
		errors = BattlefieldTerrain.install(world,"res://data/maps/island_harbor_expanded.json")
		assert(errors.is_empty(),str(errors))
	var frame: CombatFrame = CombatFrame.new(c)
	var contacts: CombatContacts = CombatContacts.new(c,frame)
	var rounds: CombatProjectiles = CombatProjectiles.new(c,frame)
	var racks: BombStores = BombStores.new(rounds,parameters())
	var delegate: BombingMissionDelegate = BombingMissionDelegate.new(parameters(),racks)
	var tasks: AircraftTasks = AircraftTasks.new()
	tasks.bombing_delegate = delegate
	var modules: Array[SimulationModule] = [frame,contacts,tasks,racks,rounds,CombatDamage.new(c,frame)]
	if flight_enabled: modules.append(AircraftMotion.new())
	for module: SimulationModule in modules: assert(world.register_module(module).accepted)
	return {"world":world,"config":c,"frame":frame,"projectiles":rounds,"stores":racks,"delegate":delegate,"contacts":contacts,"tasks":tasks}

static func order(world: SimulationWorld, ids: Array, mode: String, target: String = "target", area: Dictionary = {}) -> Dictionary:
	var unit: UnitState = world.get_unit(ids[0])
	var data: Dictionary = {"order_id":"bomb_"+str(world.tick),"issuer_id":"test_commander","source":"ai","faction_id":unit.faction_id,"recipient_ids":ids,"order_type":"bombing","target_id":target,"bombing":{"mode":mode},"intent":"Attack with finite bomb load"}
	if not area.is_empty():
		data["area"] = area
		data.bombing["area_id"] = "range"
		world.shared_state["bombing_known_areas"] = {unit.faction_id:{"range":area}}
	return world.submit_order(BattleOrder.from_data(data))

static func json_data(value: Variant) -> Variant:
	if value is Vector3: return SimData.array3(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = json_data(value[key])
		return result
	if value is Array or value is PackedStringArray:
		var result: Array = []
		for item: Variant in value: result.append(json_data(item))
		return result
	return value
