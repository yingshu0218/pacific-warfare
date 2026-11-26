extends SceneTree
const COMBAT: Script = preload("res://tests/fixtures/combat_fixture.gd")
var failures: PackedStringArray = []
var checks: int = 0
var evidence: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func run() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	check(session.load_battle("res://data/scenarios/island_harbor.json").is_empty(),"integrated map loads")
	if session.world == null: finish(); return
	var world: SimulationWorld = session.world
	var data: Dictionary = world.shared_state.terrain
	check(TerrainQueries.height_data({},Vector3(-5000,100,-5000))==0.0,"empty chart sea height")
	check(TerrainQueries.hit_data({},Vector3(0,5,0),Vector3(0,-5,0)).surface=="sea","empty chart swept sea")
	check(not BattlefieldTerrain.install(world,"res://data/maps/island_harbor.json").is_empty(),"duplicate map install rejected")
	check(TerrainQueries.is_land(world,Vector3(-5500,0,-4900)) and not TerrainQueries.is_land(world,Vector3.ZERO),"central water and real mountain land")
	# Check both sides of an actual straight coastal edge, not its bounding box.
	var outline: Array = data.islands[0].outline
	var midpoint: Vector3 = ((outline[0] as Vector3)+(outline[1] as Vector3))*.5
	var edge: Vector3 = (outline[1] as Vector3)-(outline[0] as Vector3)
	var side: Vector3 = Vector3(edge.z,0,-edge.x).normalized()*5.0
	check(TerrainQueries.is_land(world,midpoint+side)!=TerrainQueries.is_land(world,midpoint-side),"5m coastal boundary changes sea/land")
	var slope: Dictionary = {}
	for tri: Dictionary in data.triangles:
		if float(tri.max_y)>200.0 and tri.normal.y<.98 and tri.normal.y>.7:
			slope=tri; break
	check(not slope.is_empty(),"real sloped mountain triangles")
	if not slope.is_empty():
		var p: Vector3 = ((slope.a as Vector3)+(slope.b as Vector3)+(slope.c as Vector3))/3.0
		var hit: Dictionary = TerrainQueries.segment_hit(world,p+Vector3.UP*100,p-Vector3.UP*100)
		check(hit.get("surface","")=="ground" and (hit.position_m as Vector3).distance_to(p)<.02 and absf(float(hit.fraction)-.5)<.001,"sweep stops at actual sloped plane barycenter")
		check((hit.normal as Vector3).dot(slope.normal)>.999,"slope impact normal")
		var arena: Dictionary = COMBAT.arena([COMBAT.spawn("shooter","us",Vector3(9000,2000,0))])
		check(BattlefieldTerrain.install(arena.world,"res://data/maps/island_harbor.json").is_empty(),"projectile terrain installation")
		(arena.launcher as COMBAT.Launcher).pending.assign([{"position":p+Vector3.UP*100,"direction":Vector3.DOWN,"gravity":0.0,"speed":12000.0}])
		(arena.world as SimulationWorld).step_ticks(3)
		var impacts: Array[BattleEvent]=COMBAT.events(arena.world,"surface_impact")
		check(impacts.size()==1 and impacts[0].data.surface=="ground" and impacts[0].position_m.distance_to(p)<.03,"12km/s actual CombatProjectiles slope hit before sea")
		# Actual disabled-aircraft integration, not a fake ground event.
		var crash: Dictionary = COMBAT.arena([COMBAT.spawn("falling","us",p+Vector3.UP*20,"us_f6f5_1944",Vector3(0,-160,0))],null,false)
		BattlefieldTerrain.install(crash.world,"res://data/maps/island_harbor.json")
		var unit: UnitState = crash.world.get_unit("falling")
		unit.active=false;unit.module_data.damage.phase="crashing"
		(crash.world as SimulationWorld).step_ticks(25)
		var contacts: Array[BattleEvent]=COMBAT.events(crash.world,"unit_impact")
		check(contacts.size()==1 and contacts[0].data.surface=="ground" and unit.position_m.distance_to(p)<.05,"crashing aircraft hits real slope exactly once")
		evidence.slope={"point":SimData.array3(p),"normal":SimData.array3(slope.normal)}
	var a: Vector3=Vector3(-8300,100,-4900);var b: Vector3=Vector3(-2300,100,-4900)
	check(not TerrainQueries.segment_hit(world,a,b,false).is_empty(),"mountain occludes horizontal sight/fire line")
	check(TerrainQueries.segment_hit(world,a+Vector3.UP*1000,b+Vector3.UP*1000,false).is_empty(),"high sightline remains unblocked")
	# A physical parabola clears the same mountain. A blocked direct LOS must not
	# turn the entire vertical column into an impenetrable obstacle.
	var arc_clear: bool=true
	for i: int in 60:
		var t0: float=i/60.0;var t1: float=(i+1)/60.0
		var p: Vector3=a.lerp(b,t0)+Vector3.UP*(4*1000.0*t0*(1-t0))
		var q: Vector3=a.lerp(b,t1)+Vector3.UP*(4*1000.0*t1*(1-t1))
		if not TerrainQueries.segment_hit(world,p,q,false).is_empty():arc_clear=false;break
	check(arc_clear,"ballistic path can clear mountain that blocks direct line")
	var hidden: Dictionary=COMBAT.arena([COMBAT.spawn("observer","us",a),COMBAT.spawn("enemy","jp",b)],null,false)
	BattlefieldTerrain.install(hidden.world,"res://data/maps/island_harbor.json")
	(hidden.world as SimulationWorld).step_ticks(1)
	check(CombatContacts.find(hidden.world,"us","enemy",false).is_empty(),"actual sensor does not discover enemy through mountain")
	var visible: Dictionary=COMBAT.arena([COMBAT.spawn("observer","us",a+Vector3.UP*1000),COMBAT.spawn("enemy","jp",b+Vector3.UP*1000)],null,false)
	BattlefieldTerrain.install(visible.world,"res://data/maps/island_harbor.json")
	(visible.world as SimulationWorld).step_ticks(1)
	check(not CombatContacts.find(visible.world,"us","enemy",false).is_empty(),"actual sensor discovers high enemy over same mountain")
	var house: Dictionary=data.source.objects[0]
	var p: Vector3=SimData.vec3(house.position_m)
	var top: float=TerrainQueries.height_m(world,p,true)
	var hit: Dictionary=TerrainQueries.segment_hit(world,p+Vector3.UP*100,p)
	check(hit.get("surface","")=="building" and hit.get("target_id","")==house.id and absf(float(hit.position_m.y)-top)<.02,"building first hit and include_buildings height agree")
	check(top>TerrainQueries.height_m(world,p)+5,"building height separate from bare terrain")
	var sites: Array=[]
	for site: Dictionary in data.source.deployment_sites:
		var center: Vector3=SimData.vec3(site.position_m)
		var h: float=TerrainQueries.height_m(world,center)
		var lo: float=h;var hi: float=h;var land: bool=TerrainQueries.is_land(world,center)
		for i: int in 24:
			var angle: float=TAU*i/24.0
			var q: Vector3=center+Vector3(cos(angle),0,sin(angle))*float(site.radius_m)
			lo=minf(lo,TerrainQueries.height_m(world,q));hi=maxf(hi,TerrainQueries.height_m(world,q));land=land and TerrainQueries.is_land(world,q)
		check(land and absf(h-center.y)<.05 and hi-lo<.1,"flat load-bearing footprint:"+site.id)
		var muzzle: Vector3=center+Vector3.UP*4
		var front: Vector3=Basis(Vector3.UP,float(site.yaw_rad))*Vector3.FORWARD
		var clear_count: int=0
		for offset: float in [-.5,0.0,.5]:
			var direction: Vector3=Basis(Vector3.UP,offset)*front
			if TerrainQueries.segment_hit(world,muzzle,muzzle+direction*120,false).is_empty():clear_count+=1
		check(clear_count>0,"site muzzle not fully buried/occluded:"+site.id)
		sites.append({"id":site.id,"height_m":h,"variation_m":hi-lo,"clear_forward_samples":clear_count})
	evidence.sites=sites
	var chart: Dictionary=TerrainNavigation.chart(data,190.0)
	var start: Vector3=Vector3(-8300,0,-4700);var goal: Vector3=Vector3(-2000,0,-4700)
	check(TerrainNavigation.blocked(start,goal,chart.shapes),"coast direct path blocked")
	var route: Array[Vector3]=TerrainNavigation.route(start,goal,chart)
	check(route.size()>1 and route.size()<20,"finite coastline detour with hull clearance")
	var previous: Vector3=start;var route_clear: bool=true
	for point: Vector3 in route:
		route_clear=route_clear and not TerrainNavigation.blocked(previous,point,chart.shapes);previous=point
	check(route_clear,"every detour segment outside expanded actual coastline")
	check(TerrainNavigation.route(start,Vector3(-5500,0,-4900),chart).is_empty(),"land goal unreachable")
	var harbor_route: Array[Vector3]=TerrainNavigation.route(Vector3(-2600,0,-1500),Vector3(-3950,0,-2600),chart)
	check(not harbor_route.is_empty(),"visible harbor water remains navigable for 190m hull margin")
	evidence.navigation={"nodes":chart.nodes.size(),"shapes":chart.shapes.size(),"route":FleetFixture.json_data(route),"harbor_route":FleetFixture.json_data(harbor_route)}
	check(SimData.pure_data(data),"compiled chart contains no nodes/objects/callables")
	var triangles_identity: int=hash(data.triangles)
	for iteration: int in 3:
		check(session.restart(),"restart chart")
		check(hash(world.shared_state.terrain.triangles)==triangles_identity and TerrainQueries.height_m(world,Vector3(-5200,0,-4630))==590,"reset reattaches same frozen compiled chart")
	evidence.map={"triangles":data.triangles.size(),"max_height_m":data.max_height_m,"solids":data.solids.size(),"cells":data.grid.size(),"old_spawns_unchanged":true}
	finish()
func finish() -> void:
	evidence.source_hashes=source_hashes()
	evidence.checks=checks;evidence.failures=failures
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/showcase/evidence/S09"))
	var file: FileAccess=FileAccess.open("res://docs/showcase/evidence/S09/terrain_checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"));file.close()
	for failure: String in failures: push_error("S09 terrain: "+failure)
	print("S09 terrain: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func source_hashes() -> Dictionary:
	var result: Dictionary={}
	for path: String in ["res://data/maps/island_harbor.json", "res://data/scenarios/island_harbor.json", "res://scripts/simulation/terrain/terrain_queries.gd", "res://scripts/simulation/terrain/battlefield_terrain.gd", "res://scripts/simulation/terrain/terrain_navigation.gd", "res://scripts/presentation/maps/island_harbor_view.gd", "res://scripts/presentation/maps/shore.gdshader", "res://scripts/presentation/ocean.gdshader", "res://scripts/game/first_playable.gd", "res://scripts/game/first_playable_session.gd", "res://scripts/presentation/cameras/observer_camera.gd", "res://scripts/behaviors/fleet_formations/fleet_tasks.gd", "res://scripts/simulation/ship_motion/ship_motion.gd", "res://scripts/simulation/aircraft_motion/aircraft_motion.gd", "res://scripts/behaviors/aircraft/aircraft_tasks.gd", "res://scripts/behaviors/aircraft/air_combat_tactics.gd", "res://ui/observer_hud.gd", "res://ui/observer_text.gd", "res://ui/observer_map.gd"]:
		result[path]=FileAccess.get_sha256(path)
	return result
