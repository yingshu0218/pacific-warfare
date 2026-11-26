extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var records: Dictionary = {}
	for row: Array in [["us_essex_cv9_1944_04_15","res://naval/essex_cv9_1944_04_15/essex.tscn"],["jp_shokaku_1941_08_23","res://naval/shokaku_1941_08_23/shokaku.tscn"]]:
		var model: Node3D = (load(row[1]) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var sockets: Array[Dictionary] = model.mount_sockets()
		for socket: Dictionary in sockets:
			model.apply_weapon_state(socket.id,{"train_rad":0.0,"elevation_rad":0.0})
			var points: Array = []
			for index: int in socket.muzzle_positions_m.size():
				var point: Vector3 = model.muzzle_transform_local(socket.id,index).origin
				point = Basis(Vector3.UP,deg_to_rad(float(socket.base_yaw_deg))).inverse()*(point-SimData.vec3(socket.position_m))-SimData.vec3(socket.elevation_pivot_m)
				points.append(SimData.array3(point))
			socket.muzzle_positions_m = points
		records[row[0]] = {"mounts":sockets,"model_scene":row[1],"muzzle_basis":"Actual zero train/elevation markers, removing original default15deg Bofors bake; no geometry changes"}
		model.free()
	var frame: CarrierAirframeGeometry = CarrierAirframeGeometry.new()
	var pose: Transform3D = frame.parked_pose()
	records["f6f_parked"] = {"position_m":SimData.array3(pose.origin),"rotation_rad":SimData.array3(pose.basis.get_euler())}
	DirAccess.make_dir_recursive_absolute("res://data/expansion")
	FileAccess.open("res://data/expansion/carrier_model_interfaces.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit()
