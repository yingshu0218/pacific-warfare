extends SceneTree
const DATA: Script=preload("res://scripts/map02/expanded_map_data.gd")
var failures: PackedStringArray=[]
var checks: int=0
var report: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,description: String) -> void:
	checks+=1
	if not ok:failures.append(description)
func run() -> void:
	var data: Dictionary=DATA.compile()
	if data.is_empty():check(false,"expanded map compiles");finish();return
	var regions: Dictionary=DATA.regions()
	var raw: Dictionary=DATA.load_source()
	check(data.id=="island_harbor_expanded","independent map id")
	check(SimData.pure_data(data),"compiled map is pure data")
	var objects: Dictionary={}
	var solids: Dictionary={}
	for obj: Dictionary in data.source.objects:
		check(not objects.has(obj.id),"unique component "+obj.id)
		objects[obj.id]=obj
	for solid: Dictionary in data.solids:solids[solid.id]=solid
	var support_source: Dictionary=raw.duplicate(true)
	support_source.objects=[]
	for obj: Dictionary in raw.objects:
		if obj.kind=="quay":support_source.objects.append(obj)
	var support: Dictionary=TerrainQueries.compile(support_source)
	var modules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map02/facility_modules.json")).modules
	var instances: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/map02/facility_instances.json")).instances
	var footings: Array=[]
	for entry: Dictionary in instances:
		var p: Vector3=SimData.vec3(entry.position_m)
		var module: Dictionary=modules[entry.module_id]
		var supported: bool=true
		var worst: float=0.0
		for part: Dictionary in module.parts:
			if not part.solid or absf(float(part.position_m[1]))>.001:continue
			var size: Vector3=SimData.vec3(part.size_m)
			for x: float in [-.5,.5]:
				for z: float in [-.5,.5]:
					var local: Vector3=SimData.vec3(part.position_m)+Vector3(size.x*x,0,size.z*z)
					for q: int in int(entry.yaw_quarters)%4:local=Vector3(-local.z,local.y,local.x)
					var at: Vector3=p+local
					var h: float=TerrainQueries.height_data(support,at,true)
					worst=maxf(worst,absf(h-p.y))
					if absf(h-p.y)>.035:supported=false
		check(supported,"facility supported on actual ground/deck: "+entry.id)
		if not supported:footings.append({"id":entry.id,"anchor":entry.position_m,"max_height_error_m":worst,"actual_center_m":TerrainQueries.height_data(support,p,true)})
	report.invalid_footings=footings
	var site_rows: Array=[]
	for site: Dictionary in data.source.deployment_sites:
		var p: Vector3=SimData.vec3(site.position_m)
		var low: float=INF;var high: float=-INF;var clear: bool=true
		for i: int in 33:
			var sample: Vector3=p
			if i>0:sample+=Vector3(cos(TAU*i/32.0),0,sin(TAU*i/32.0))*float(site.radius_m)
			var h: float=TerrainQueries.height_data(data,sample)
			low=minf(low,h);high=maxf(high,h)
			clear=clear and TerrainQueries.land_data(data,sample) and absf(h-p.y)<.035 and TerrainQueries.height_data(data,sample,true)<=p.y+.05
		# Reserve the whole installation cylinder, including its interior, against
		# all compiled facility proxies rather than checking its perimeter alone.
		for solid: Dictionary in data.solids:
			var center: Vector3=solid.center;var half: Vector3=solid.half
			var nearest: Vector2=Vector2(clampf(p.x,center.x-half.x,center.x+half.x),clampf(p.z,center.z-half.z,center.z+half.z))
			if nearest.distance_to(Vector2(p.x,p.z))>float(site.radius_m):continue
			if center.y+half.y<=p.y+.05 or center.y-half.y>=p.y+float(site.overhead_clearance_m):continue
			clear=false
		check(clear,"full flat and unobstructed AA02 footprint: "+site.id)
		var line_count: int=0
		var muzzle: Vector3=p+Vector3.UP*3.0
		for offset: float in [-.5,0,.5]:
			var f: Vector3=Basis(Vector3.UP,float(site.yaw_rad)+offset)*Vector3.FORWARD
			if TerrainQueries.hit_data(data,muzzle,muzzle+f*180.0,false).is_empty():line_count+=1
		check(line_count>0,"usable seaward muzzle arc: "+site.id)
		site_rows.append({"id":site.id,"actual_height_m":TerrainQueries.height_data(data,p),"declared_height_m":p.y,"footprint_min_m":low,"footprint_max_m":high,"horizontal_clear_rays":line_count,"land_and_unobstructed":clear})
	report.sites=site_rows
	# Exercise the current ground entry point using accepted US equipment only.
	# JP equipment selection and combat behavior belong to AA02.
	var catalog: DefinitionCatalog=AircraftFixture.catalog()
	var scenario: Dictionary={"id":"map02_support_probe","seed":202,"tick_hz":60,"factions":["us","jp"],"spawns":[],"groups":[],"environment":{"terrain_path":DATA.MAP_PATH},"ground_deployments":[]}
	for site: Dictionary in data.source.deployment_sites:
		if site.suggested_faction!="us":continue
		var equipment: String="us_5in51_mk13mod4_1945" if "coastal_gun" in site.roles else "us_40mm_m1_m2a1_1944"
		scenario.ground_deployments.append({"id":"probe_"+site.id,"site_id":site.id,"unit_definition_id":equipment,"faction_id":"us"})
	var deployment_errors: PackedStringArray=GroundDeployments.expand(scenario,catalog)
	check(deployment_errors.is_empty(),"existing ground resolver accepts MAP02 land sites: "+str(deployment_errors))
	var world: SimulationWorld=SimulationWorld.new()
	check(world.configure(catalog,scenario).is_empty(),"support-only real ground definitions configure")
	check(DATA.load_for_world(world).is_empty(),"existing terrain module installs expanded map")
	deployment_errors=GroundDeployments.validate(world)
	check(deployment_errors.is_empty(),"existing ground installation validates support and physical muzzles: "+str(deployment_errors))
	report.ground_entry={"spawn_count":scenario.spawns.size(),"validation_errors":deployment_errors,"scope":"support and muzzle installation only; no ground suite/combat/AI installed; JP models remain AA02"}
	var contact_rows: Array=[]
	for id: String in ["civil_finger","civil_pier_head","naval_pier_2600","naval_pier_3900","runway_surface","naval_tank_0_0_shell","naval_repair_0_wall"]:
		var obj: Dictionary=objects[id]
		var p: Vector3=SimData.vec3(obj.position_m);var s: Vector3=SimData.vec3(obj.size_m)
		var a: Vector3=p+Vector3.UP*(s.y+100.0)
		var hit: Dictionary=TerrainQueries.hit_data(data,a,p-Vector3.UP*10.0)
		# Tanks may hit their exact cap first. Compare to the highest real solid at xz.
		var top: float=TerrainQueries.height_data(data,p,true)
		check(not hit.is_empty() and absf(float(hit.position_m.y)-top)<.02,"visible top/support/first contact: "+id)
		if id.contains("pier") or id=="civil_finger":check(hit.surface=="ground" and top>0 and not TerrainQueries.land_data(data,p),"water pier is solid deck over sea: "+id)
		contact_rows.append({"id":id,"surface":hit.get("surface",""),"target_id":hit.get("target_id",""),"actual_top_m":top,"hit_m":SimData.array3(hit.get("position_m",Vector3.ZERO))})
	report.contacts=contact_rows
	for id: String in ["naval_repair_0_wall","civil_store_0_wall","air_hangar_0_wall"]:
		var obj: Dictionary=objects[id];var p: Vector3=SimData.vec3(obj.position_m);var s: Vector3=SimData.vec3(obj.size_m)
		var a: Vector3=p+Vector3(-s.x, s.y*.5,0);var b: Vector3=p+Vector3(s.x,s.y*.5,0)
		var hit: Dictionary=TerrainQueries.hit_data(data,a,b,false)
		check(not hit.is_empty() and hit.surface=="building","warehouse/repair/hangar blocks aircraft or shell line: "+id)
	var channels: Array=[]
	for channel: Dictionary in regions.shipping_channels:
		var chart: Dictionary=TerrainNavigation.chart(data,float(channel.clearance_radius_m))
		var points: Array=channel.waypoints_m
		var paths: Array=[]
		for i: int in range(points.size()-1):
			var start: Vector3=SimData.vec3(points[i]);var end: Vector3=SimData.vec3(points[i+1])
			var path: Array[Vector3]=TerrainNavigation.route(start,end,chart)
			check(not path.is_empty(),"published hull-clear shipping lane: "+channel.id+":"+str(i))
			paths.append(FleetFixture.json_data(path))
		channels.append({"id":channel.id,"clearance_m":channel.clearance_radius_m,"navigation_shapes":chart.shapes.size(),"nodes":chart.nodes.size(),"paths":paths})
	report.channels=channels
	for area: Dictionary in regions.carrier_operation_areas:
		var chart: Dictionary=TerrainNavigation.chart(data,float(area.hull_clearance_m))
		var b: Array=area.bounds_xz_m
		var corners: Array[Vector3]=[Vector3(b[0],0,b[1]),Vector3(b[0]+b[2],0,b[1]),Vector3(b[0]+b[2],0,b[1]+b[3]),Vector3(b[0],0,b[1]+b[3])]
		for i: int in 4:check(not TerrainNavigation.blocked(corners[i],corners[(i+1)%4],chart.shapes),"carrier operation perimeter clear: "+area.id)
		check(not TerrainNavigation.blocked(SimData.vec3(area.launch_lane_m[0]),SimData.vec3(area.launch_lane_m[1]),chart.shapes),"carrier straight operation lane clear: "+area.id)
		check(TerrainQueries.hit_data(data,SimData.vec3(area.approach_centerline_m[0]),SimData.vec3(area.approach_centerline_m[1]),false).is_empty(),"carrier approach spatial clearance: "+area.id)
	var airfield: Dictionary=regions.airfield
	# Actual runway strip, parallel taxiway and connectors must be traversable at
	# their declared support height, not merely free on an overhead diagram.
	var ground_paths: Array=[airfield.runway.thresholds_m,airfield.taxiway.centerline_m]
	ground_paths.append_array(airfield.taxiway.connectors_m)
	for path: Array in ground_paths:
		var start: Vector3=SimData.vec3(path[0]);var end: Vector3=SimData.vec3(path[1])
		var right: Vector3=(end-start).normalized().cross(Vector3.UP)
		var half_width: float=28.0 if path==airfield.runway.thresholds_m else 7.0
		for step: int in 25:
			for side: float in [-1.0,0.0,1.0]:
				var at: Vector3=start.lerp(end,step/24.0)+right*half_width*side
				check(absf(TerrainQueries.height_data(data,at,true)-airfield.surface_height_m)<.035,"runway/taxi support and obstacle clearance")
	for stand: Dictionary in airfield.parking_stands:
		var p: Vector3=SimData.vec3(stand.position_m)
		for i: int in 16:
			var at: Vector3=p+Vector3(cos(TAU*i/16.0),0,sin(TAU*i/16.0))*float(stand.radius_m)
			check(absf(TerrainQueries.height_data(data,at,true)-p.y)<.035,"unobstructed parking footprint "+stand.id)
	for corridor: Dictionary in airfield.approach_corridors:
		for side: float in [-1.0,0.0,1.0]:
			var a: Vector3=SimData.vec3(corridor.centerline_m[0])+Vector3.RIGHT*float(corridor.half_width_m)*side
			var b: Vector3=SimData.vec3(corridor.centerline_m[1])+Vector3.RIGHT*float(corridor.half_width_m)*side+Vector3.UP*.1
			check(TerrainQueries.hit_data(data,a,b,false).is_empty(),"static runway approach corridor "+corridor.id)
	report.counts={"components":data.source.objects.size(),"solids":data.solids.size(),"terrain_triangles":data.triangles.size(),"sites":data.source.deployment_sites.size()}
	report.shared_terrain_sha256=FileAccess.get_sha256("res://scripts/simulation/terrain/terrain_queries.gd")
	report.map_sha256=FileAccess.get_sha256(DATA.MAP_PATH)
	finish()
func finish() -> void:
	report.checks=checks;report.failures=failures
	var file: FileAccess=FileAccess.open("res://docs/showcase/evidence/MAP02/terrain_checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	for failure: String in failures:push_error("MAP02: "+failure)
	print("MAP02 shared-query checks: ",checks," / failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
