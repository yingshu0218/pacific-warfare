extends SceneTree

const ADAPTER: Script = preload("res://scripts/presentation/models/capital_ship_adapter.gd")
var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	for model_id: String in ["jp_yamato_1944_04", "us_iowa_bb61_1944_12_28"]:
		var model: CapitalShipAdapter = ADAPTER.new() as CapitalShipAdapter
		model.model_id = model_id
		root.add_child(model)
		var twin: CapitalShipAdapter = ADAPTER.new() as CapitalShipAdapter
		twin.model_id = model_id
		root.add_child(twin)
		var sockets: Array[Dictionary] = model.mount_sockets()
		var expected_secondary: int = 2 if model_id.begins_with("jp_") else 10
		_check(sockets.filter(func(s: Dictionary) -> bool:return s.role=="main").size()==3,model_id+": all three triple main turrets required")
		_check(sockets.filter(func(s: Dictionary) -> bool:return s.role=="secondary").size()==expected_secondary,model_id+": fixed secondary battery incomplete")
		var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/units/"+model_id+".json"))
		_check(_same_data(stored.mounts,sockets),model_id+": every persisted socket field must equal actual model socket data")
		_check(not stored.model_scene.contains("viewer") and not stored.model_scene.contains("main.tscn"),model_id+": unit points at a viewer")
		var seen: Dictionary = {}
		for socket: Dictionary in sockets:
			_check(not seen.has(socket.id),model_id+": duplicate station "+socket.id)
			seen[socket.id] = true
			var record: Dictionary = model.mount_visuals[socket.id]
			var expected_barrels: int = socket.muzzle_positions_m.size()
			_check(record.muzzles.size()==expected_barrels,model_id+": physical muzzle count differs from socket "+socket.id)
			if socket.role in ["main","secondary"]:
				_check(expected_barrels==(3 if socket.role=="main" or model_id.begins_with("jp_") else 2),model_id+": incorrect main/secondary barrel count "+socket.id)
			# Compare the actual marker chain against the pure S01 MountSocket transform.
			var data: MountSocket = MountSocket.from_data(socket)
			for pose: Vector2 in [Vector2.ZERO,Vector2(0.15,0.3),Vector2(-0.2,0.12)]:
				model.apply_weapon_state(socket.id,{"train_rad":pose.x,"elevation_rad":pose.y})
				for index: int in range(expected_barrels):
					var actual: Transform3D = model.muzzle_transform_local(socket.id,index)
					var expected: Transform3D = data.local_muzzle_transform(index,pose.x,pose.y)
					_check(actual.origin.distance_to(expected.origin)<0.003,model_id+": muzzle position disagrees with data at "+socket.id)
					_check((-actual.basis.z).dot(-expected.basis.z)>0.9999,model_id+": muzzle direction disagrees with data at "+socket.id)
			model.apply_weapon_state(socket.id,{"train_rad":0.0,"elevation_rad":0.0})
		# These source-plan windows are independent of the procedural builder.
		var main_reference_z: Array = [-50.254,-30.498,64.577] if model_id.begins_with("jp_") else [-58.8,-33.1,66.9]
		for index: int in range(3):
			var id: String = "main_%02d" % (index+1)
			var station: Dictionary = sockets.filter(func(v: Dictionary) -> bool:return v.id==id)[0]
			_check(absf(float(station.position_m[0]))<0.01 and absf(float(station.position_m[2])-main_reference_z[index])<0.8,model_id+": main station differs from source plan "+id)
			_check(absf(float(station.base_yaw_deg)-(180.0 if index==2 else 0.0))<0.01,model_id+": main turret faces wrong end "+id)
		if model_id.begins_with("us_"):
			var upper_y: Array[float] = []
			var lower_y: Array[float] = []
			for station: Dictionary in sockets:
				if station.role=="secondary":
					if station.host_id=="battery_deck":
						upper_y.append(float(station.position_m[1]))
					else:
						lower_y.append(float(station.position_m[1]))
			_check(upper_y.size()==6 and lower_y.size()==4,model_id+": secondary tiers must be 3 upper + 2 lower per side")
			if not upper_y.is_empty() and not lower_y.is_empty():
				_check(upper_y.min()>lower_y.max()+3.0,model_id+": upper secondary mounts lack their real deck tier")
		# Ray the actual supporting module's static mesh, excluding the foundation itself.
		if model_id.begins_with("jp_"):
			for entry: Dictionary in model._builder.weapons:
				_check(_host_has_surface(entry.station as Marker3D),model_id+": no actual host face below station "+str(entry.station_id))
		else:
			for mount: IowaWeaponMount in model.model_root.get_weapon_mounts():
				_check(_host_has_surface(mount.station_marker),model_id+": no actual host face below station "+mount.mount_id)
		for id: String in ["main_01","main_02","main_03"]:
			var train_axis: Node3D = model.mount_visuals[id].train_axis as Node3D
			var housing: Node3D = train_axis.get_node("HousingAndControls") as Node3D
			var jp: bool = model_id.begins_with("jp_")
			var check_y: float = 2.5 if jp else 1.5
			_check(_mesh_ray(housing,Vector3(10,check_y,2),Vector3(0,check_y,2)),model_id+": missing main gunhouse side armor "+id)
			_check(_mesh_ray(housing,Vector3(0,check_y,11),Vector3(0,check_y,0)),model_id+": missing main gunhouse rear armor "+id)
			_check(_mesh_ray(housing,Vector3(1.6,1.8 if jp else 0.7,-12),Vector3(1.6,1.8 if jp else 0.7,-4)),model_id+": missing main gunhouse front armor between ports "+id)
		var original: Transform3D = twin.muzzle_transform_local("main_01",0)
		var fixed_neighbor: Transform3D = model.muzzle_transform_local("main_02",0)
		model.apply_weapon_state("main_01",{"train_rad":0.5,"elevation_rad":0.4})
		_check(model.muzzle_transform_local("main_01",0).origin.distance_to(original.origin)>1,model_id+": commanded turret did not move")
		_check(twin.muzzle_transform_local("main_01",0).is_equal_approx(original),model_id+": another ship instance moved")
		_check(model.muzzle_transform_local("main_02",0).is_equal_approx(fixed_neighbor),model_id+": adjacent station moved")
		var held: Transform3D = model.muzzle_transform_local("main_01",0)
		for frame: int in range(3):
			await process_frame
		_check(model.muzzle_transform_local("main_01",0).is_equal_approx(held),model_id+": model contains an autonomous pose clock")
		model.apply_state({"position_m":Vector3(2300,5,-1700),"rotation_rad":Vector3(0.02,1.2,-0.01)})
		_check(model.muzzle_transform_global("main_01",0).is_equal_approx(model.global_transform * held),model_id+": world muzzle does not follow ship transform")
		_check(not model.apply_weapon_state("main_01",{"train_rad":NAN}),model_id+": nonfinite pose accepted")
		model.free()
		twin.free()
	var catalog: DefinitionCatalog = DefinitionCatalog.new()
	var ammo_paths: Array[String] = []
	for id: String in ["jp_460mm_ap","jp_155mm_shell","jp_127mm_type89_shell","jp_25mm_type96_shell","jp_13mm_type93_ball","us_406mm_mk8_ap","us_127mm_5in38_shell","us_40mm_bofors_shell","us_20mm_oerlikon_shell"]:
		ammo_paths.append("res://data/ammunition/"+id+".json")
	var errors: PackedStringArray = catalog.load_files(["res://data/units/jp_yamato_1944_04.json","res://data/units/us_iowa_bb61_1944_12_28.json"],ammo_paths)
	_check(errors.is_empty(),"dated capital ship definitions fail S01 catalog validation: "+str(errors))
	if failures.is_empty():
		print("PASS: both dated capital ships, fixed main/secondary inventory, real muzzle transforms, independent instances and passive presentation")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

func _host_has_surface(station: Marker3D) -> bool:
	var host: Node3D = station.get_parent() as Node3D
	var from_point: Vector3 = station.global_position+Vector3.UP*0.08
	var to_point: Vector3 = station.global_position-Vector3.UP*0.08
	for child: Node in host.get_children():
		if not child is MeshInstance3D:
			continue
		var part: MeshInstance3D = child as MeshInstance3D
		if not part.has_meta("support_test_triangles"):
			part.set_meta("support_test_triangles",part.mesh.generate_triangle_mesh())
		var triangles: TriangleMesh = part.get_meta("support_test_triangles")
		if not triangles.intersect_segment(part.to_local(from_point),part.to_local(to_point)).is_empty():
			return true
	return false

func _mesh_ray(module: Node3D, from_point: Vector3, to_point: Vector3) -> bool:
	for child: Node in module.get_children():
		if child is MeshInstance3D:
			var part: MeshInstance3D = child as MeshInstance3D
			var triangles: TriangleMesh = part.mesh.generate_triangle_mesh()
			if not triangles.intersect_segment(part.to_local(module.to_global(from_point)),part.to_local(module.to_global(to_point))).is_empty():
				return true
	return false

func _same_data(first: Variant, second: Variant) -> bool:
	# JSON arrays are untyped; compare all field values rather than container type tags.
	if (first is int or first is float) and (second is int or second is float):
		return absf(float(first)-float(second))<0.00003
	if first is Array and second is Array:
		if first.size()!=second.size():
			return false
		for index: int in range(first.size()):
			if not _same_data(first[index],second[index]):
				return false
		return true
	if first is Dictionary and second is Dictionary:
		if first.size()!=second.size():
			return false
		for key: Variant in first:
			if not second.has(key) or not _same_data(first[key],second[key]):
				return false
		return true
	return first==second
