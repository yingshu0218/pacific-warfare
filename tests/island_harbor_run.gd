extends SceneTree
var failures: PackedStringArray=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var session: FirstPlayableSession=FirstPlayableSession.new()
	var errors: PackedStringArray=session.load_battle("res://data/scenarios/island_harbor.json")
	if not errors.is_empty():push_error(str(errors));quit(1);return
	var tracks: Array=[];var coast: Dictionary={};var collisions: Array=[];var air_ground: Array=[];var min_agl: float=INF
	for id: String in session.units:
		if session.definition_index[session.units[id].definition_id].domain=="ship":
			var d: UnitDefinition=session.catalog.unit(session.units[id].definition_id)
			coast[id]=TerrainNavigation.chart(session.world.shared_state.terrain,d.dimensions_m.z*.55+45)
	var before: int=Time.get_ticks_usec()
	for tick: int in 21600:
		var events: Array[BattleEvent]=session.advance(1.0/60.0)
		for id: String in coast:
			var view: Dictionary=session.units[id]
			if view.active and TerrainNavigation.blocked(view.position_m,view.position_m,coast[id].shapes):collisions.append({"time_s":session.world.time_s(),"id":id,"position_m":SimData.array3(view.position_m)})
		for view: Dictionary in session.units.values():
			if view.active and session.definition_index[view.definition_id].domain=="aircraft":
				min_agl=minf(min_agl,float(view.module_data.aircraft_motion.get("height_agl_m",view.position_m.y)))
		for event: BattleEvent in events:
			if event.kind=="unit_impact":air_ground.append(FleetFixture.json_data(event.snapshot()))
		if tick%120==0:
			var row: Dictionary={"time_s":session.world.time_s(),"units":{}}
			for id: String in session.units:
				var v: Dictionary=session.units[id];row.units[id]={"position_m":SimData.array3(v.position_m),"active":v.active,"task":FleetFixture.json_data(v.task),"avoidance":v.module_data.get("ship_motion",{}).get("avoidance_reason","")}
			tracks.append(row)
		if not session.ended_reason.is_empty():break
	if session.units.size()!=12:failures.append("lost unit definitions")
	if int(session.counts.get("main_gun_fire",0))==0 or int(session.counts.get("aircraft_fire",0))==0 or int(session.counts.get("airburst",0))==0:failures.append("missing autonomous gunnery/air combat/AA")
	if not collisions.is_empty():failures.append("ship entered expanded coast")
	var result: Dictionary={"source_hashes":source_hashes(),"scenario":session.scenario.id,"seed":session.scenario.seed,"sim_s":session.world.time_s(),"wall_s":(Time.get_ticks_usec()-before)/1000000.0,"ended":session.ended_reason,"counts":session.counts,"outcomes":session.outcomes,"report":session.report(),"tracks":tracks,"coast_violations":collisions,"air_contacts":air_ground,"min_active_agl_m":min_agl,"orders":session.orders,"journal":FleetFixture.json_data(session.journal),"failures":failures}
	var file: FileAccess=FileAccess.open("res://docs/showcase/evidence/S09/natural_run.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	for failure: String in failures:push_error("S09 run: "+failure)
	print("S09 natural run ",result.sim_s," s, ",result.counts," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func source_hashes() -> Dictionary:
	var result: Dictionary={}
	for path: String in ["res://data/maps/island_harbor.json", "res://data/scenarios/island_harbor.json", "res://scripts/simulation/terrain/terrain_queries.gd", "res://scripts/simulation/terrain/battlefield_terrain.gd", "res://scripts/simulation/terrain/terrain_navigation.gd", "res://scripts/presentation/maps/island_harbor_view.gd", "res://scripts/presentation/maps/shore.gdshader", "res://scripts/presentation/ocean.gdshader", "res://scripts/game/first_playable.gd", "res://scripts/game/first_playable_session.gd", "res://scripts/presentation/cameras/observer_camera.gd", "res://scripts/behaviors/fleet_formations/fleet_tasks.gd", "res://scripts/simulation/ship_motion/ship_motion.gd", "res://scripts/simulation/aircraft_motion/aircraft_motion.gd", "res://scripts/behaviors/aircraft/aircraft_tasks.gd", "res://scripts/behaviors/aircraft/air_combat_tactics.gd", "res://ui/observer_hud.gd", "res://ui/observer_text.gd", "res://ui/observer_map.gd"]:
		result[path]=FileAccess.get_sha256(path)
	return result
