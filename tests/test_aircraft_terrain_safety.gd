extends SceneTree
var checks: int = 0
var failures: int = 0
var evidence: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func arena(spawn: Dictionary, combat: bool = true) -> SimulationWorld:
	var world: SimulationWorld = SimulationWorld.new()
	check(world.configure(AircraftFixture.catalog(),{"id":"air_terrain","seed":409,"tick_hz":60,"factions":["jp","us"],"spawns":[spawn],"groups":[]}).is_empty(),"fixture configure")
	check(BattlefieldTerrain.install(world,"res://data/maps/island_harbor.json").is_empty(),"same S09 map installed")
	check(AircraftSuite.install(world).is_empty(),"aircraft install")
	if combat:
		var config: CombatConfig = CombatConfig.new()
		check(config.load_file("res://data/combat/showcase.json").is_empty(),"combat config")
		check(CombatSuite.install(world,config).is_empty(),"combat install")
	return world

func _initialize() -> void:
	var world: SimulationWorld = arena(AircraftFixture.spawn("ridge","jp",Vector3(-8500,430,-4900),"jp_a6m5a_1944",-PI/2,120),false)
	var unit: UnitState = world.get_unit("ridge")
	unit.module_data["aircraft_control"] = {"flight_direction":Vector3.RIGHT,"speed_mps":120.0}
	var minimum_agl: float = 100000.0
	var recoveries: int = 0
	var contact_count: int = 0
	var samples: Array = []
	for tick: int in range(2400):
		world.step_ticks(1)
		for event: BattleEvent in world.drain_events():
			if event.kind == "unit_surface_contact": contact_count += 1
		var flight: Dictionary = unit.module_data.aircraft_motion
		minimum_agl = minf(minimum_agl,unit.position_m.y-TerrainQueries.height_m(world,unit.position_m,true))
		if flight.safety_state == "terrain_recovery": recoveries += 1
		if tick%15 == 0:
			samples.append({"time_s":world.time_s(),"position_m":SimData.array3(unit.position_m),"speed_mps":unit.velocity_mps.length(),"agl_m":flight.height_agl_m,"terrain_ahead_m":flight.terrain_ahead_m,"clearance_ahead_m":flight.terrain_clearance_m,"safety":flight.safety_state})
	check(recoveries > 0,"front ridge is detected before aircraft is directly over it")
	check(contact_count == 0 and minimum_agl > 20,"limited flight avoids the ridge without snapping: "+str(minimum_agl))
	evidence.ridge_avoidance = {"minimum_agl_m":minimum_agl,"recovery_ticks":recoveries,"contacts":contact_count,"samples":samples}
	for surface: String in ["ground","building"]:
		var position: Vector3
		var velocity: Vector3
		if surface == "ground":
			position = Vector3(-5500,0,-4900)
			position.y = TerrainQueries.height_m(world,position,true)+0.35
			velocity = Vector3(55,-45,0)
		else:
			# First authored house, start outside its wall. No synthetic terrain geometry.
			var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/island_harbor.json"))
			var house: Dictionary = map.objects[0]
			var origin: Vector3 = SimData.vec3(house.position_m)
			var size: Vector3 = SimData.vec3(house.size_m)
			position = origin+Vector3(-size.x*0.5-0.7,size.y*0.5,0)
			velocity = Vector3(120,0,0)
		var w: SimulationWorld = arena(AircraftFixture.spawn("impact","jp",position,"jp_a6m5a_1944",0,velocity.length()))
		var actor: UnitState = w.get_unit("impact")
		actor.velocity_mps = velocity
		actor.rotation_rad = AircraftFlightMath.frame(velocity,Vector3.UP).get_euler()
		actor.module_data["aircraft_control"] = {"flight_direction":velocity.normalized(),"speed_mps":velocity.length()}
		var contacts: Array = []
		var impacts: Array = []
		for event: BattleEvent in AircraftFixture.run(w,1):
			if event.kind == "unit_surface_contact": contacts.append(event.snapshot())
			if event.kind == "unit_impact": impacts.append(event.snapshot())
		check(contacts.size() == 1 and impacts.size() == 1,surface+" one swept contact, one S05 impact")
		if contacts.size() == 1:
			check(contacts[0].data.surface == surface,surface+" actual earliest surface classification")
			check(contacts[0].data.reason != "forced_ditch",surface+" never mislabeled as sea/safe exit")
			check(not str(contacts[0].target_id).is_empty(),surface+" contact retains terrain/object id")
		check(not actor.active and actor.module_data.damage.phase == "wreck",surface+" loss remains S05-owned")
		evidence[surface] = {"contacts":contacts,"impacts":impacts}
	check(world.reset(),"terrain and aircraft reset")
	check(TerrainQueries.height_m(world,Vector3(-5500,0,-4900),true)>500,"reset retains frozen common terrain")
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-spatial/terrain-safety.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	print("S04 aircraft terrain ","PASS" if failures == 0 else "FAIL"," checks=",checks," min_agl=",minimum_agl," recovery_ticks=",recoveries)
	quit(0 if failures == 0 else 1)
