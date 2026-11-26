extends SceneTree
const MODEL: PackedScene=preload("res://aircraft/b25j/b25j.tscn")
const G: Script=preload("res://aircraft/b25j/geometry.gd")
const MAP_DATA: Script=preload("res://scripts/map02/expanded_map_data.gd")
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error("AV04 "+message)
func vec(v: Vector3) -> Array:return [v.x,v.y,v.z]
func bounds(node: Node3D,relative: Node3D) -> AABB:
	var first: bool=true;var result: AABB=AABB()
	for mesh: MeshInstance3D in G.meshes(node):
		var box: AABB=(relative.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		if first:result=box;first=false
		else:result=result.merge(box)
	return result
func minimum_y(node: Node3D,exclude_gear: bool=false) -> float:
	var result: float=INF
	for mesh: MeshInstance3D in G.meshes(node):
		var parent: Node=mesh;var gear: bool=false
		while parent!=node and parent!=null:
			if str(parent.name).begins_with("Gear"):gear=true
			parent=parent.get_parent()
		if exclude_gear and gear:continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			for v: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:result=minf(result,(mesh.global_transform*v).y)
	return result
func run() -> void:
	var a: Node3D=MODEL.instantiate() as Node3D;root.add_child(a)
	var b: Node3D=MODEL.instantiate() as Node3D;root.add_child(b)
	check(a.transform==Transform3D.IDENTITY,"body datum moved")
	check(not a.is_processing() and not a.is_physics_processing(),"model must not integrate simulation")
	check(a.guns.size()==10,"ten mount groups, including five fixed forward barrels")
	var barrel_count: int=0
	for gun: Dictionary in a.guns.values():barrel_count+=gun.muzzles.size()
	check(barrel_count==12,"early B-25J must carry exactly twelve .50 barrels")
	check(a.bomb_visuals.size()==6,"six finite internal stores")
	check(a.propellers.size()==2 and a.gear_axes.size()==3,"two engines and three true wheels")
	var markers: Array[Dictionary]=[]
	for id: String in a.markers:
		var marker: Marker3D=a.markers[id]
		check(marker.position.is_finite(),"nonfinite marker "+id)
		markers.append({"id":id,"path":str(a.get_path_to(marker)),"position_m":vec(a.global_transform.affine_inverse()*marker.global_position),"forward":vec(-marker.global_basis.z.normalized()),"radius_m":marker.get_meta("radius_m",0.0),"source_status":marker.get_meta("source_status")})
	for id: String in a.guns:
		var gun: Dictionary=a.guns[id]
		for muzzle: Marker3D in gun.muzzles:
			var forward: Vector3=-muzzle.global_basis.z
			check(is_equal_approx(forward.length(),1.0),"unit direction "+id)
			if id=="tail":check(forward.z>0.99,"tail must face aft")
			elif id.begins_with("waist_"):check(forward.x*(-1 if id=="waist_left" else 1)>0.9,"waist must face outboard")
			else:check(forward.z< -0.9,"nose/cheek/default dorsal must face forward "+id)
	for side: String in ["left","right"]:
		check(a.damage_modules["engine_"+side].get_parent()==a.damage_modules[side+"_wing"],"engine inherits wing loss "+side)
		check(a.gear_axes[side].get_parent()==a.damage_modules["engine_"+side],"main gear inherits correct nacelle "+side)
	var before_b: Transform3D=b.propellers.right.transform
	a.apply_visual_state({"propeller_left_rad":0.7,"propeller_right_rad":1.9,"gear":0.5,"flap":1.0,"bay_door":0.5,"aileron_left_rad":0.2,"rudder_right_rad":0.2})
	check(is_equal_approx(a.propellers.left.rotation.z,0.7) and is_equal_approx(a.propellers.right.rotation.z,1.9),"independent propeller phases")
	check(b.propellers.right.transform==before_b and b.state.gear==1.0,"two instances share state")
	check(a.bay_doors.left.transform!=b.bay_doors.left.transform,"continuous bomb door state")
	for k: String in ["flap_inner_left","flap_outer_left","flap_inner_right","flap_outer_right"]:
		check(minimum_y(a.surfaces[k])<minimum_y(b.surfaces[k])-0.10,"flap trailing edge must lower "+k)
	for gear: float in [0.0,0.25,0.5,0.75,1.0]:
		a.apply_visual_state({"gear":gear})
		for axis: Node3D in a.gear_axes.values():check(axis.transform.is_finite() and axis.visible==(gear>0.001),"finite gear range "+str(gear))
	a.apply_visual_state({"gear":NAN,"flap":-10.0,"bay_door":9.0,"propeller_left_rad":INF,"rudder_right_rad":100.0})
	check(a.state.gear==1.0 and a.state.flap==0.0 and a.state.bay_door==1.0,"invalid numbers and proportion clamps")
	check(is_equal_approx(a.state.propeller_left_rad,0.7) and is_equal_approx(a.surfaces.rudder_right.rotation.y,0.35),"nonfinite phase and control limit")
	for key: String in ["aileron_left","aileron_right","elevator_left","elevator_right","rudder_left","rudder_right"]:
		a.apply_visual_state({key+"_rad":0.21});check(a.surfaces[key].transform!=b.surfaces[key].transform,"independent surface "+key)
	for id: String in a.guns:
		var before: Transform3D=b.guns[id].muzzles[0].global_transform
		a.apply_visual_state({"guns":{id:{"yaw_rad":0.17,"elevation_rad":0.34}}})
		var fixed: bool=a.GUN_SPECS[id].limits==Vector4.ZERO
		check((a.guns[id].muzzles[0].global_transform==before)==fixed,"fixed/traversing mount travel "+id)
		check(b.guns[id].muzzles[0].global_transform==before,"gun state leaked "+id)
	a.apply_visual_state({"bomb_visible":[false,false,true,true,true,true]})
	check(not a.bomb_visuals[0].visible and a.bomb_visuals[2].visible and b.bomb_visuals[0].visible,"per-slot visibility is isolated")
	a.apply_visual_state({"payload_mode":"empty"});check(not a.bomb_visuals[2].visible,"empty load still displays bombs")
	a.apply_visual_state({"payload_mode":"torpedo"});check(a.state.payload_mode=="empty","unsupported load accepted")
	a.apply_visual_state({"payload_mode":"bombs_6x500","bomb_visible":[true,true,true,true,true,true]})
	var slots: Array[Dictionary]=[]
	for i: int in range(6):
		var release: Marker3D=a.markers["BOMB_%02d_RELEASE"%i];var nose: Marker3D=a.markers["BOMB_%02d_NOSE"%i]
		check(nose.global_position.z<release.global_position.z-0.7,"reversed bomb nose "+str(i))
		var box: AABB=bounds(a.bomb_visuals[i],a)
		check(box.position.x>=-0.59 and box.end.x<=0.59 and box.end.y<0.385,"store exceeds bay walls/ceiling "+str(i))
		check(box.position.z>a.BAY_START_M and box.end.z<a.BAY_END_M,"store exceeds bay length "+str(i))
		for j: int in range(i):check(not box.intersects(bounds(a.bomb_visuals[j],a)),"stores overlap "+str([i,j]))
		slots.append({"index":i,"release_marker":"BOMB_%02d_RELEASE"%i,"release_m":vec(release.global_position),"clear_before_release_indices":[] if i<2 else [i-2],"position_status":"conservative fit estimate, not factory station drawing"})
	a.apply_damage_state({"left_wing":false})
	check(not a.propellers.left.is_visible_in_tree() and not a.gear_axes.left.is_visible_in_tree() and b.propellers.left.is_visible_in_tree(),"detached wing leaves floating engine/gear")
	a.apply_damage_state({"left_wing":true,"engine_left":false})
	check(a.damage_modules.left_wing.visible and not a.propellers.left.is_visible_in_tree(),"engine cannot fail independently")
	a.apply_damage_state({"engine_left":true})
	a.apply_visual_state({"gear":1.0,"flap":1.0,"bay_door":1.0,"aileron_left_rad":0.0,"aileron_right_rad":0.0,"elevator_left_rad":0.0,"elevator_right_rad":0.0,"rudder_left_rad":0.0,"rudder_right_rad":0.0})
	a.transform=a.get_parked_transform()
	var contacts: Array[Dictionary]=[];var clearances: Dictionary={}
	for id: String in ["WHEEL_LEFT","WHEEL_RIGHT","WHEEL_NOSE"]:
		var marker: Marker3D=a.markers[id];var radius: float=marker.get_meta("radius_m")
		var error: float=marker.global_position.y-radius
		check(absf(error)<0.0001,"wheel circle ground contact "+id)
		contacts.append({"id":id,"center_m":vec(marker.global_position),"radius_m":radius,"contact_error_m":error})
	check(a.scale.is_equal_approx(Vector3.ONE),"parked fit scaled aircraft")
	for side: String in ["left","right"]:
		var prop: Node3D=a.propellers[side]
		var swept: float=a.PROP_RADIUS_M*sqrt(pow(prop.global_basis.x.y,2)+pow(prop.global_basis.y.y,2))
		clearances["full_prop_disc_"+side]=prop.global_position.y-swept-0.025
		check(clearances["full_prop_disc_"+side]>0.15,"full propeller circle hits ground "+side)
		clearances["open_bay_door_"+side]=minimum_y(a.bay_doors[side])
		check(clearances["open_bay_door_"+side]>0.10,"fully opened door hits ground "+side)
		for kind: String in ["flap_inner","flap_outer"]:
			clearances[kind+"_"+side]=minimum_y(a.surfaces[kind+"_"+side]);check(clearances[kind+"_"+side]>0.10,"fully lowered flap touches ground")
	clearances.body_and_payload=minimum_y(a,true);check(clearances.body_and_payload>0.10,"body or payload touches ground")
	var terrain: Dictionary=MAP_DATA.compile();var airfield: Dictionary=MAP_DATA.regions().airfield
	var placements: Array[Dictionary]=[{"id":"runway_center","position_m":airfield.runway.center_m,"heading_rad":0.0},{"id":"taxi_center","position_m":[6650,8.04,-2400],"heading_rad":0.0}]
	placements.append_array(airfield.parking_stands)
	var installs: Array[Dictionary]=[]
	for placement: Dictionary in placements:
		var station: Vector3=Vector3(placement.position_m[0],placement.position_m[1],placement.position_m[2])
		a.transform=Transform3D(Basis(Vector3.UP,placement.heading_rad),station)*a.get_parked_transform()
		var max_error: float=0.0
		for id: String in ["WHEEL_LEFT","WHEEL_RIGHT","WHEEL_NOSE"]:
			var marker: Marker3D=a.markers[id];var y: float=TerrainQueries.height_data(terrain,marker.global_position,true)
			max_error=maxf(max_error,absf(marker.global_position.y-float(marker.get_meta("radius_m"))-y))
		check(max_error<0.003,"MAP02 real wheel support "+placement.id)
		var obstructions: Array[String]=[];var envelopes: Array[AABB]=[]
		for mesh: MeshInstance3D in G.meshes(a):envelopes.append(mesh.global_transform*mesh.get_aabb())
		for prop: Node3D in a.propellers.values():
			var extent: Vector3=Vector3.ZERO
			for axis: int in range(3):extent[axis]=a.PROP_RADIUS_M*sqrt(pow(prop.global_basis.x[axis],2)+pow(prop.global_basis.y[axis],2))+0.025
			envelopes.append(AABB(prop.global_position-extent,extent*2))
		for box: AABB in envelopes:
			for solid: Dictionary in terrain.solids:
				if solid.surface=="building" and box.intersects(AABB(solid.center-solid.half,solid.half*2)) and not obstructions.has(solid.id):obstructions.append(solid.id)
		check(obstructions.is_empty(),"MAP02 full mesh/prop swept envelope intersects building "+placement.id)
		check(minimum_y(a,true)-station.y>0.10,"MAP02 belly/load/doors/flaps ground envelope "+placement.id)
		installs.append({"id":placement.id,"station_m":vec(station),"heading_rad":placement.heading_rad,"wheel_error_max_m":max_error,"building_intersections":obstructions,"full_prop_swept_disc_checked":true,"flaps_fully_down":true,"bay_doors_fully_open":true,"static_only":true})
	a.transform=Transform3D.IDENTITY;a.set_flight_configuration();a.apply_visual_state({"flap":0.0,"bay_door":0.0,"propeller_left_rad":0.0,"propeller_right_rad":0.0})
	var neutral_aims: Dictionary={}
	for id: String in a.guns:neutral_aims[id]={"yaw_rad":0.0,"elevation_rad":deg_to_rad(12.0 if id=="dorsal" else 0.0)}
	a.apply_visual_state({"guns":neutral_aims})
	var bb: AABB=bounds(a,a);check(absf(bb.size.x-a.SPAN_M)<0.03,"actual visible wing span")
	var triangles: int=0;var mesh_count: int=G.meshes(a,false).size()
	for mesh: MeshInstance3D in G.meshes(a,false):
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array=mesh.mesh.surface_get_arrays(surface)
			triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
	check(mesh_count<160 and triangles<70000,"single-model budget")
	var modules: Array[Dictionary]=[]
	for id: String in a.damage_modules:
		var node: Node3D=a.damage_modules[id];var box: AABB=bounds(node,a)
		modules.append({"id":id,"path":str(a.get_path_to(node)),"parent_path":str(a.get_path_to(node.get_parent())),"bounds_body_m":{"position":vec(box.position),"size":vec(box.size)},"collision_proxy":"proposal; not registered; nested boxes must not double count"})
	var gun_specs: Dictionary={}
	for id: String in a.guns:
		var gun: Dictionary=a.guns[id];var limits: Vector4=gun.limits_deg;var paths: Array[String]=[]
		for muzzle: Marker3D in gun.muzzles:paths.append(str(a.get_path_to(muzzle)))
		gun_specs[id]={"weapon":gun.weapon,"barrels":gun.barrels,"base_path":str(a.get_path_to(gun.base)),"yaw_path":str(a.get_path_to(gun.yaw)),"elevation_path":str(a.get_path_to(gun.elevation)),"muzzle_paths":paths,"visual_limits_deg":[limits.x,limits.y,limits.z,limits.w],"historical_firing_arcs_qualified":false,"host_self_occlusion_required":true}
	var hashes: Dictionary={}
	for f: String in ["aircraft/b25j/b25j.gd","aircraft/b25j/geometry.gd","aircraft/b25j/b25j.tscn","tests/av04/test_b25j.gd","scripts/map02/expanded_map_data.gd","scripts/map02/expanded_map_view.gd","scripts/presentation/maps/island_harbor_view.gd","scripts/simulation/terrain/terrain_queries.gd","data/maps/island_harbor_expanded.json","data/map02/regions.json"]:hashes[f]=FileAccess.get_sha256("res://"+f)
	var report: Dictionary={"status":"native_contract_passed_pending_coordinator" if failures.is_empty() else "failed","checks":checks,"failures":failures,"source_hashes":hashes,"identity":"B-25J-1-NC representative early glazed bomber / 1944-07","origin_is_measured_cg":false,"axes":"+X right/+Y up/-Z forward","scale":[1,1,1],"markers":markers,"damage_modules":modules,"gun_specs":gun_specs,"bomb_slots":slots,"flight_visible_bounds_m":{"position":vec(bb.position),"size":vec(bb.size),"configuration":"gear/flaps/doors stowed; neutral gun yaw, dorsal12deg, other guns0deg"},"parked_transform":{"pitch_rad":a.get_parked_transform().basis.get_euler().x,"position_m":vec(a.get_parked_transform().origin),"contacts":contacts},"ground_clearances_m":clearances,"airport_static_installations":installs,"taxiway":{"width_m":airfield.taxiway.width_m,"wingspan_m":a.SPAN_M,"overhang_each_side_m":(a.SPAN_M-airfield.taxiway.width_m)*0.5,"dynamic_traffic_qualified":false},"stats":{"raw_mesh_nodes":a.raw_mesh_count,"mesh_nodes_after_fixed_merge":mesh_count,"triangles_all_configurations":triangles},"not_implemented":["flight performance registration","BOMB inventory/release","fire control/occlusion","OPS taxi/takeoff/landing","DM terminal motion/fragments","Chrome fleet performance"]}
	for path: String in ["res://aircraft/b25j/data/interfaces.json","res://docs/showcase/evidence/AV04/contracts.json"]:
		var file: FileAccess=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("AV04 checks=%d failures=%d meshes=%d triangles=%d pitch=%.4f clearances=%s"%[checks,failures.size(),mesh_count,triangles,rad_to_deg(a.get_parked_transform().basis.get_euler().x),clearances])
	a.queue_free();b.queue_free();quit(0 if failures.is_empty() else 1)
