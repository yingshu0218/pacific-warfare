extends SceneTree
const MODEL: PackedScene=preload("res://aircraft/g4m1/g4m1.tscn")
const G: Script=preload("res://aircraft/g4m1/geometry.gd")
var failures: Array[String]=[]
var checks: int=0

func _initialize() -> void:call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error("AV03 "+message)

func vec(v: Vector3) -> Array:return [v.x,v.y,v.z]

func bounds(node: Node3D, relative: Node3D) -> AABB:
	var first: bool=true;var result: AABB=AABB()
	for mesh: MeshInstance3D in G.meshes(node):
		var box: AABB=(relative.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		if first:result=box;first=false
		else:result=result.merge(box)
	return result

func minimum_y(node: Node3D) -> float:
	var result: float=INF
	for mesh: MeshInstance3D in G.meshes(node):
		for surface: int in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in vertices:result=minf(result,(mesh.global_transform*v).y)
	return result

func run() -> void:
	var a: Node3D=MODEL.instantiate() as Node3D;root.add_child(a)
	var b: Node3D=MODEL.instantiate() as Node3D;root.add_child(b)
	check(a.transform==Transform3D.IDENTITY,"pure model datum moved")
	check(not a.is_processing() and not a.is_physics_processing(),"pure model is driving itself")
	check(a.guns.size()==5,"five independent historical gun positions")
	check(a.bomb_visuals.size()==12,"twelve display bombs")
	check(a.propellers.size()==2,"two propellers")
	var records: Array[Dictionary]=[]
	for id: String in a.markers:
		var marker: Marker3D=a.markers[id]
		records.append({"id":id,"path":str(a.get_path_to(marker)),"position_m":vec(a.global_transform.affine_inverse()*marker.global_position),"forward":vec(-marker.global_basis.z.normalized()),"source_status":marker.get_meta("source_status"),"radius_m":marker.get_meta("radius_m",0.0)})
		check(marker.position.is_finite(),"nonfinite marker "+id)
	for side: String in ["left","right"]:
		check(a.damage_modules["engine_"+side].get_parent()==a.damage_modules[side+"_wing"],"engine must inherit wing detachment")
		check(a.gear_axes[side].get_parent()==a.damage_modules["engine_"+side],"gear must inherit engine detachment")
	var baseline_b: Transform3D=b.propellers.right.transform
	a.apply_visual_state({"propeller_left_rad":0.70,"propeller_right_rad":1.9,"gear":0.5,"flap":1.0,"guns":{"waist_left":{"yaw_rad":0.25},"tail":{"elevation_rad":0.2}}})
	check(is_equal_approx(a.propellers.left.rotation.z,0.7),"left phase not consumed")
	check(is_equal_approx(a.propellers.right.rotation.z,1.9),"right phase not consumed")
	check(b.propellers.right.transform==baseline_b,"instances share prop phase")
	check(is_equal_approx(b.state.gear,1.0),"instances share gear state")
	check(not a.gear_axes.left.transform.is_equal_approx(b.gear_axes.left.transform),"continuous main gear snapshot ignored")
	a.apply_visual_state({"gear":NAN,"flap":-10.0,"propeller_left_rad":INF,"rudder_rad":100.0})
	check(is_equal_approx(a.state.gear,0.5),"NaN gear accepted")
	check(is_equal_approx(a.state.flap,0.0),"negative flap not clamped")
	check(is_equal_approx(a.state.propeller_left_rad,0.7),"infinite phase accepted")
	check(is_equal_approx(a.surfaces.rudder.rotation.y,0.35),"rudder limit ignored")
	var mask: Array=[];mask.resize(12);mask.fill(true);mask[3]=false
	a.apply_visual_state({"bomb_visible":mask})
	check(not a.bomb_visuals[3].visible and b.bomb_visuals[3].visible,"independent per-store snapshot failed")
	a.apply_visual_state({"payload_mode":"ferry"})
	check(a.fairing.visible and not a.bomb_visuals[0].visible,"ferry mode mixed with bombs")
	a.apply_visual_state({"payload_mode":"torpedo"})
	check(a.state.payload_mode=="ferry","unimplemented torpedo mode silently accepted")
	a.apply_visual_state({"payload_mode":"bombs_12x60","gear":1.0,"flap":0.0})
	check(not a.fairing.visible,"combat bay incorrectly covered")
	a.apply_damage_state({"left_wing":false})
	check(not a.propellers.left.is_visible_in_tree() and b.propellers.left.is_visible_in_tree(),"wing loss leaves engine or leaks state")
	a.apply_damage_state({"left_wing":true,"engine_left":false})
	check(a.damage_modules.left_wing.visible and not a.propellers.left.is_visible_in_tree(),"independent engine damage failed")
	a.apply_damage_state({"engine_left":true})
	for id: String in a.guns:
		var before: Transform3D=b.guns[id].muzzle.global_transform
		a.apply_visual_state({"guns":{id:{"yaw_rad":0.17,"elevation_rad":0.34}}})
		check(a.guns[id].muzzle.global_transform!=before,"gun axis ignored "+id)
		check(b.guns[id].muzzle.global_transform==before,"gun leaked into other instance "+id)
		check(is_equal_approx((-a.guns[id].muzzle.global_basis.z).length(),1.0),"muzzle direction not unit "+id)
	for key: String in ["aileron_left","aileron_right","elevator_left","elevator_right","rudder"]:
		a.apply_visual_state({key+"_rad":0.2})
		check(a.surfaces[key].transform!=b.surfaces[key].transform,"independent control axis ignored "+key)
	# Contact is derived from actual wheel centres/radii, with no root scaling.
	a.apply_visual_state({"gear":1.0,"flap":0.0,"aileron_left_rad":0.0,"aileron_right_rad":0.0,"elevator_left_rad":0.0,"elevator_right_rad":0.0,"rudder_rad":0.0})
	a.transform=a.get_parked_transform()
	var contact_records: Array[Dictionary]=[]
	for id: String in ["WHEEL_LEFT","WHEEL_RIGHT","WHEEL_TAIL"]:
		var marker: Marker3D=a.markers[id];var radius: float=marker.get_meta("radius_m")
		var error: float=marker.global_position.y-radius
		check(absf(error)<0.0001,"wheel circle does not touch ground "+id)
		contact_records.append({"id":id,"center_world_m":vec(marker.global_position),"radius_m":radius,"contact_error_m":error})
	check(a.scale.is_equal_approx(Vector3.ONE),"parked fit changed scale")
	var clearances: Dictionary={}
	for side: String in ["left","right"]:
		var prop: Node3D=a.propellers[side]
		var radial_vertical: float=a.PROP_RADIUS_M*sqrt(pow(prop.global_basis.x.y,2)+pow(prop.global_basis.y.y,2))
		var clearance: float=prop.global_position.y-radial_vertical-0.025
		clearances["full_prop_disc_"+side]=clearance
		check(clearance>0.15,"full rotating prop circle hits ground "+side)
	clearances.body_and_bombs=minimum_y(a.damage_modules.center)
	check(clearances.body_and_bombs>0.10,"body or bomb load touches ground")
	a.apply_visual_state({"flap":1.0})
	for side: String in ["left","right"]:
		clearances["flap_"+side]=minimum_y(a.surfaces["flap_"+side])
		check(clearances["flap_"+side]>0.10,"fully lowered flap touches ground")
	a.apply_visual_state({"payload_mode":"ferry"})
	clearances.ferry_fairing=minimum_y(a.fairing)
	check(clearances.ferry_fairing>0.10,"removable fairing touches ground")
	var airport_script: Script=load("res://island_airfield/scripts/woleai_environment.gd")
	var airport: Node3D=airport_script.new() as Node3D
	var installation: Array[Dictionary]=[]
	for station: Vector3 in [Vector3(0,3.5,80),Vector3(-273,3.5,82)]:
		a.transform=Transform3D(Basis.IDENTITY,station)*a.get_parked_transform()
		var maximum_error: float=0.0
		for id: String in ["WHEEL_LEFT","WHEEL_RIGHT","WHEEL_TAIL"]:
			var marker: Marker3D=a.markers[id]
			var floor_y: float=airport.call("_terrain_height",marker.global_position.x,marker.global_position.z)
			maximum_error=maxf(maximum_error,absf(marker.global_position.y-float(marker.get_meta("radius_m"))-floor_y))
		check(maximum_error<0.0001,"existing airport installation is not grounded")
		installation.append({"station_m":vec(station),"maximum_wheel_contact_error_m":maximum_error,"environment_source":"island_airfield/scripts/woleai_environment.gd","static_only":true})
	airport.free()
	a.transform=Transform3D.IDENTITY;a.set_flight_configuration();a.apply_visual_state({"payload_mode":"bombs_12x60","flap":0.0})
	var bb: AABB=bounds(a,a)
	check(absf(bb.size.x-a.SPAN_M)<0.03,"actual wing span changed")
	var mesh_count: int=G.meshes(a,false).size();var triangles: int=0
	for mesh: MeshInstance3D in G.meshes(a,false):
		for s: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array=mesh.mesh.surface_get_arrays(s)
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			triangles+=(indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	check(mesh_count<180,"too many model meshes")
	check(triangles<70000,"too many model triangles")
	var modules: Array[Dictionary]=[]
	for id: String in a.damage_modules:
		var node: Node3D=a.damage_modules[id];var box: AABB=bounds(node,a)
		modules.append({"id":id,"path":str(a.get_path_to(node)),"parent_path":str(a.get_path_to(node.get_parent())),"body_origin_m":vec(node.position),"bounds_body_m":{"position":vec(box.position),"size":vec(box.size)},"collision_proxy":"bounds proposal; not registered physics collider"})
	var hash_records: Dictionary={}
	for f: String in ["aircraft/g4m1/g4m1.gd","aircraft/g4m1/geometry.gd","aircraft/g4m1/g4m1.tscn","tests/av03/test_g4m1.gd","island_airfield/scripts/woleai_environment.gd"]:hash_records[f]=FileAccess.get_sha256("res://"+f)
	var report: Dictionary={"status":"native_contract_checks_passed_pending_coordinator" if failures.is_empty() else "failed","checks":checks,"failures":failures,"source_hashes":hash_records,
		"identity":"G4M1 Model11 / Kasei11 / 1942-07","axes":"+X right/+Y up/-Z forward","origin_m":[0,0,0],"origin_is_measured_cg":false,"scale":[1,1,1],
		"markers":records,"damage_modules":modules,"gun_specs":{},"stats":{"raw_mesh_nodes":a.raw_mesh_count,"mesh_nodes_after_fixed_merge":mesh_count,"triangles_all_configurations":triangles},
		"flight_visible_bounds_m":{"position":vec(bb.position),"size":vec(bb.size)},"parked_transform":{"pitch_rad":a.get_parked_transform().basis.get_euler().x,"position_m":vec(a.get_parked_transform().origin),"contacts":contact_records},
		"ground_clearances_m":clearances,"airport_static_installations":installation,"unimplemented":["flight performance registration","OPS take-off/landing","bomb release and ammunition","defensive fire control and self-occlusion","damage fragment motion","torpedo qualified installation"]}
	for id: String in a.guns:
		var gun: Dictionary=a.guns[id];var limit: Vector4=gun.limits_deg
		report.gun_specs[id]={"weapon":gun.weapon,"yaw_path":str(a.get_path_to(gun.yaw)),"elevation_path":str(a.get_path_to(gun.elevation)),"muzzle_path":str(a.get_path_to(gun.muzzle)),"suggested_limits_deg":[limit.x,limit.y,limit.z,limit.w],"limits_are_measured":false,"requires_host_self_occlusion_check":true}
	var path: String="res://aircraft/g4m1/data/interfaces.json"
	var file: FileAccess=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	var evidence: FileAccess=FileAccess.open("res://docs/showcase/evidence/AV03/contracts.json",FileAccess.WRITE);evidence.store_string(JSON.stringify(report,"\t"));evidence.close()
	print("AV03 checks=%d failures=%d meshes=%d triangles=%d parked_pitch=%.3f clearances=%s"%[checks,failures.size(),mesh_count,triangles,rad_to_deg(a.get_parked_transform().basis.get_euler().x),clearances])
	a.queue_free();b.queue_free()
	quit(0 if failures.is_empty() else 1)
