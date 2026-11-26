extends SceneTree
## Integration evidence: actual meshes / sockets / world instances, not history claims.
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
var failures: Array[String] = []
var assertions: int = 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_exterior_normals()
	var paths: Array[String] = ["res://data/units/us_fletcher_dd445_1942_07_18.json"]
	if FileAccess.file_exists("res://data/units/jp_yukikaze_1942_06.json"):
		paths.append("res://data/units/jp_yukikaze_1942_06.json")
	var ammunition: Array[String] = []
	for id: String in ["s03_us_127mm_mk32_common","s03_us_28mm_mk1_he","s03_us_20mm_mk3_he","s03_jp_127mm_type1_common","s03_jp_25mm_type96_he"]:
		ammunition.append("res://data/ammunition/" + id + ".json")
	var catalog: DefinitionCatalog = DefinitionCatalog.new()
	var errors: PackedStringArray = catalog.load_files(paths,ammunition)
	_check(errors.is_empty(),"Catalog accepts real S03 definitions: " + str(errors))
	if not errors.is_empty():
		_finish()
		return
	for path: String in paths:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		await _check_model(data,catalog)
	_finish()

func _check_model(data: Dictionary, catalog: DefinitionCatalog) -> void:
	var packed: PackedScene = load(data.model_scene) as PackedScene
	_check(packed != null,"Root project resolves " + str(data.model_scene))
	if packed == null:
		return
	var first: Node3D = packed.instantiate() as Node3D
	var second: Node3D = packed.instantiate() as Node3D
	root.add_child(first)
	root.add_child(second)
	await process_frame
	var definition: UnitDefinition = catalog.unit(data.id)
	var expected_main: int = 5 if data.country_id == "us" else 3
	var expected_barrels: int = 1 if data.country_id == "us" else 2
	var main_count: int = 0
	var sockets: Array[Dictionary] = first.mount_sockets()
	_check(sockets.size() == data.mounts.size(),"Every definition socket has visual instance")
	var mesh_count: int = _check_purity(first)
	var geometry: Array[MeshInstance3D] = []
	_meshes(first,geometry)
	for index: int in range(sockets.size()):
		var socket: Dictionary = sockets[index]
		var r: Dictionary = first.mount_visuals[socket.id]
		var weapon: Node3D = r.weapon
		var ms: MountSocket = definition.mounts[index]
		var wd: WeaponDefinition = catalog.weapon(socket.weapon_definition_id)
		_check(weapon.muzzle_markers.size() == wd.barrel_count,"Actual barrel count " + str(socket.id))
		if socket.role == "main":
			main_count += 1
			_check(wd.barrel_count == expected_barrels,"Historical fixed main tube count " + str(socket.id))
			_check(absf(float(socket.position_m[0])) < 0.001,"Main battery on centreline " + str(socket.id))
			for angle: float in [wd.elevation_limits_rad.x,0.0,wd.elevation_limits_rad.y]:
				first.apply_weapon_state(socket.id,{"train_rad":0.0,"elevation_rad":angle})
				for barrel: int in range(wd.barrel_count):
					_check(_clears_gun_house(weapon,barrel),"Gun opening clears full elevation range " + str(socket.id))
			first.apply_weapon_state(socket.id,{"train_rad":0.0,"elevation_rad":0.0})
		var foundation: Node3D = r.foundation
		var attachment: Marker3D = r.attachment
		var seat: Marker3D = r.seat
		var placement: Dictionary = first.configuration.installations[socket.id]
		_check(foundation.global_position.distance_to(attachment.global_position) < 0.0001,"Foundation bottom contacts named host " + str(socket.id))
		_check(seat.position.y > 0.0 and absf(seat.position.y - float(placement.foundation_height_m)) < 0.0001,"Seat and real foundation agree " + str(socket.id))
		_check(weapon.position == Vector3.ZERO,"Weapon contacts seat without hidden offset " + str(socket.id))
		_check(str(attachment.get_meta("interface_id")) == weapon.mount_kind,"Foundation/weapon interface " + str(socket.id))
		_check(float(placement.foundation_radius_m) >= weapon.seat_radius_m,"Seat covers roller path " + str(socket.id))
		_check(str((r.host as Node3D).get_meta("host_id")) == str(socket.host_id),"Real host identity " + str(socket.id))
		_check(first.to_local(seat.global_position).distance_to(G.vector(socket.position_m)) < 0.0001,"Visual mount location = definition " + str(socket.id))
		_check(_host_contact(r.host,attachment.global_position),"Named attachment actually lies on host mesh top " + str(socket.id))
		for pose: Vector2 in [Vector2.ZERO,Vector2(0.7,0.43),Vector2(-0.65,0.2)]:
			_check(first.apply_weapon_state(socket.id,{"train_rad":pose.x,"elevation_rad":pose.y}),"Pose accepted " + str(socket.id))
			for barrel: int in range(wd.barrel_count):
				var actual: Transform3D = first.muzzle_transform_local(socket.id,barrel)
				var expected: Transform3D = ms.local_muzzle_transform(barrel,pose.x,pose.y)
				_check(actual.origin.distance_to(expected.origin) < 0.0001 and actual.basis.is_equal_approx(expected.basis),"Transformed muzzle contract " + str(socket.id))
				var mesh: MeshInstance3D = weapon.barrel_meshes[barrel]
				var cylinder_mesh: CylinderMesh = mesh.mesh as CylinderMesh
				var tip: Vector3 = mesh.global_transform * Vector3(0,cylinder_mesh.height * 0.5,0)
				var marker: Marker3D = weapon.muzzle_markers[barrel]
				_check(tip.distance_to(marker.global_position) < 0.0001,"Muzzle lies on actual barrel end " + str(socket.id))
				_check((-marker.global_basis.z).dot((tip - mesh.global_position).normalized()) > 0.9999,"Bore and muzzle forward agree " + str(socket.id))
		first.apply_weapon_state(socket.id,{"train_rad":999.0,"elevation_rad":999.0})
		_check(is_equal_approx(weapon.train_axis.rotation.y,r.base_yaw_rad+r.train_limits_rad.y),"Train hard stop " + str(socket.id))
		_check(is_equal_approx(weapon.elevation_axes[0].rotation.x,r.elevation_limits_rad.y),"Elevation hard stop " + str(socket.id))
		var saved: float = weapon.train_axis.rotation.y
		_check(not first.apply_weapon_state(socket.id,{"train_rad":NAN}),"NaN rejected " + str(socket.id))
		_check(weapon.train_axis.rotation.y == saved,"Rejected pose leaves state unchanged")
		_check(is_equal_approx(second.mount_visuals[socket.id].weapon.train_axis.rotation.y,r.base_yaw_rad),"Second instance pose independent " + str(socket.id))
		first.apply_weapon_state(socket.id,{"train_rad":0.0,"elevation_rad":0.0})
		for train_angle: float in [0.0,0.75,-0.75]:
			first.apply_weapon_state(socket.id,{"train_rad":train_angle,"elevation_rad":0.10})
			for barrel: int in range(wd.barrel_count):
				var marker: Marker3D = weapon.muzzle_markers[barrel]
				var axis: Node3D = weapon.elevation_axes[barrel]
				var hits: PackedStringArray = _barrel_collisions(axis.global_position,marker.global_position,weapon,geometry)
				_check(hits.is_empty(),"Barrel sweep clears other modules " + str(socket.id) + " @ " + str(train_angle) + ": " + str(hits))
		first.apply_weapon_state(socket.id,{"train_rad":0.0,"elevation_rad":0.0})
	_check(main_count == expected_main,"Historical main mount count " + str(data.id))
	var copied: Array[Dictionary] = first.mount_sockets()
	copied[0].position_m[0] = 999.0
	_check(first.mount_sockets()[0].position_m[0] != 999.0,"Socket getter is defensive")
	var original_muzzle: Transform3D = first.muzzle_transform_local(sockets[0].id,0)
	first.apply_state({"position_m":[124,2,-80],"rotation_rad":[0.03,0.6,-0.04],"active":true,
		"weapons":{sockets[0].id:{"train_rad":0.4,"elevation_rad":0.3}}})
	var global_muzzle: Transform3D = first.muzzle_transform_global(sockets[0].id,0)
	_check((first.global_transform * first.muzzle_transform_local(sockets[0].id,0)).is_equal_approx(global_muzzle),"World-space muzzle composes unit roll/pitch/yaw")
	_check(original_muzzle.origin.distance_to(first.muzzle_transform_local(sockets[0].id,0).origin) > 0.1,"apply_state drives weapon poses")
	first.apply_state({"active":false})
	_check(not first.visible,"Disabled unit visual hides")
	_check(second.visible and second.position == Vector3.ZERO,"Disabled/position state isolated")
	_check(not first.apply_weapon_state("missing",{}),"Missing station rejected")
	var torpedo_count: int = 0
	for child: Node in first.equipment.get_children():
		if child.has_meta("tube_count"):
			torpedo_count += 1
			_check(int(child.get_meta("tube_count")) == (5 if data.country_id == "us" else 4),"Correct visual torpedo tube count")
			_check(str(child.get_meta("firing_system")) == "not_implemented_in_showcase","Torpedoes explicitly visual only")
	_check(torpedo_count == 2,"Exactly two torpedo launchers")
	if data.country_id == "jp":
		var twin: Node3D = first.mount_visuals.main_a.weapon
		first.apply_weapon_state("main_a",{"gun_elevations_rad":[0.1,0.5]})
		_check(not is_equal_approx(twin.elevation_axes[0].rotation.x,twin.elevation_axes[1].rotation.x),"TypeC barrels have independent elevation axes")
	var world: SimulationWorld = SimulationWorld.new()
	var errors: PackedStringArray = world.configure(catalog,{"id":"s03_instances","seed":3,"tick_hz":60,"factions":[data.country_id],"spawns":[
		{"id":"first","unit_definition_id":data.id,"faction_id":data.country_id},
		{"id":"second","unit_definition_id":data.id,"faction_id":data.country_id}],"groups":[]})
	_check(errors.is_empty(),"Real definition can spawn in frozen world: " + str(errors))
	if errors.is_empty():
		var w1: WeaponState = world.get_unit("first").weapons[sockets[0].id]
		var w2: WeaponState = world.get_unit("second").weapons[sockets[0].id]
		var stock: int = w2.remaining_rounds[0]
		w1.remaining_rounds[0] -= 1
		w1.train_rad = 0.4
		_check(w2.remaining_rounds[0] == stock and w2.train_rad == 0.0,"Per-instance ammunition and motion independent")
		world.reset()
		_check(world.get_unit("first").weapons[sockets[0].id].remaining_rounds[0] == stock,"Reset restores stock from definition")
	# Each source module independently instantiates without the adapter/camera.
	for module_record: Dictionary in first.configuration.module_scenes:
		var module_packed: PackedScene = load(module_record.scene) as PackedScene
		var module: Node3D = module_packed.instantiate() as Node3D
		root.add_child(module)
		_check(module.get_child_count() > 0,"Independent module " + str(module_record.id))
		module.free()
	results.append({"unit":data.id,"mounts":sockets.size(),"main_mounts":main_count,"mesh_instances":mesh_count,"torpedo_launchers":torpedo_count})
	first.free()
	second.free()

func _check_purity(node: Node) -> int:
	_check(not (node is Camera3D or node is Control or node is Timer),"Pure unit contains no camera, UI or clock")
	_check(not node.is_processing() and not node.is_physics_processing(),"Pure unit contains no autonomous processing")
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _check_purity(child)
	return count

func _meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child,result)

func _check_exterior_normals() -> void:
	var parent: Node3D = Node3D.new()
	root.add_child(parent)
	var sample: MeshInstance3D = G.prism(parent,"NormalProbe",G.ellipse(4,6),0,2,G.material(Color.GRAY))
	var arrays: Array = sample.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index: int in range(positions.size()):
		var normal: Vector3 = normals[index]
		if absf(normal.y) < 0.1:
			_check(normal.dot(Vector3(positions[index].x,0,positions[index].z).normalized()) > 0.8,"Exterior loft wall faces outward")
		elif positions[index].y > 1.9:
			_check(normal.y > 0.99,"Roof cap faces upward")
	parent.free()

func _host_contact(host: Node3D, point: Vector3) -> bool:
	var meshes: Array[MeshInstance3D] = []
	# Direct mesh children only: do not accidentally accept another attachment.
	for child: Node in host.get_children():
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
	for mesh: MeshInstance3D in meshes:
		var vertices: PackedVector3Array = mesh.mesh.get_faces()
		var inv: Transform3D = mesh.global_transform.affine_inverse()
		var from: Vector3 = inv * (point + Vector3.UP * 0.02)
		var to: Vector3 = inv * (point - Vector3.UP * 0.02)
		for index: int in range(0,vertices.size(),3):
			if Geometry3D.segment_intersects_triangle(from,to,vertices[index],vertices[index+1],vertices[index+2]) != null:
				return true
	return false

func _barrel_collisions(start: Vector3, end: Vector3, own_weapon: Node3D, meshes: Array[MeshInstance3D]) -> PackedStringArray:
	var hits: PackedStringArray = []
	for mesh: MeshInstance3D in meshes:
		if own_weapon.is_ancestor_of(mesh):
			continue
		var inv: Transform3D = mesh.global_transform.affine_inverse()
		var from: Vector3 = inv * start
		var to: Vector3 = inv * end
		if not mesh.mesh.get_aabb().grow(0.001).intersects_segment(from,to):
			continue
		var vertices: PackedVector3Array = mesh.mesh.get_faces()
		for index: int in range(0,vertices.size(),3):
			if Geometry3D.segment_intersects_triangle(from,to,vertices[index],vertices[index+1],vertices[index+2]) != null:
				hits.append(str(mesh.get_path()))
				break
	return hits

func _clears_gun_house(weapon: Node3D, barrel: int) -> bool:
	var axis: Node3D = weapon.elevation_axes[barrel]
	var marker: Marker3D = weapon.muzzle_markers[barrel]
	for node: Node in weapon.train_axis.get_children():
		if not node is MeshInstance3D or str(node.name) not in ["GunHouseLower","SlopingGunHouseRoof","TypeCGunHouse","TypeCSlopingRoof","DarkGunHouseFloor"]:
			continue
		var mesh: MeshInstance3D = node as MeshInstance3D
		var inv: Transform3D = mesh.global_transform.affine_inverse()
		var a: Vector3 = inv * axis.global_position
		var b: Vector3 = inv * marker.global_position
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2]) != null:
				return false
	return true

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	print(JSON.stringify({"suite":"S03 destroyer models","assertions":assertions,"failures":failures,"results":results}))
	quit(0 if failures.is_empty() else 1)
