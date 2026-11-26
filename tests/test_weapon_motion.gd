extends SceneTree

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func() -> void: quit(1))
	call_deferred("run_test")

func run_test() -> void:
	var isolated: WeaponMount = WeaponMount.new()
	root.add_child(isolated)
	isolated.set_process(false)
	isolated.pose_guard = func(heading: float, _elevation: float) -> bool: return heading <= 0
	isolated.apply_pose(deg_to_rad(0.2),deg_to_rad(0.3))
	assert(is_zero_approx(isolated.rotation.y),"Blocked horizontal axis must hold")
	assert(is_equal_approx(isolated.elevation_axis.rotation.x,deg_to_rad(0.3)),"Safe elevation must remain independently movable")
	isolated.pose_guard = func(_heading: float, elevation: float) -> bool: return elevation <= deg_to_rad(0.3)
	isolated.apply_pose(deg_to_rad(0.2),deg_to_rad(0.5))
	assert(is_equal_approx(isolated.rotation.y,deg_to_rad(0.2)),"Safe horizontal axis must remain independently movable")
	isolated.free()
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene: Node3D = packed.instantiate()
	root.add_child(scene)
	var entries: Array = scene.weapons
	for entry: Dictionary in entries:
		assert((entry.pivot as WeaponMount).pose_guard.is_valid(),"Every weapon must have an obstruction guard")
		(entry.pivot as WeaponMount).pose_guard = Callable()
	assert(entries.size() == 39, "Game fit requires 5 fixed main/secondary + 12 Type89 + 12 triple + 8 single + 2 bridge MG mounts")
	var pivot_ids: Dictionary = {}
	var axis_ids: Dictionary = {}
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/yamato_1944_mounts.json"))
	var expected_by_id: Dictionary = {}
	var closed_light: int = 0
	for record: Dictionary in layout.mounts:
		assert(not expected_by_id.has(record.id),"Duplicate mount ID")
		expected_by_id[record.id] = record
		if record.has("source_pixel"):
			var px: float = record.source_pixel[0]
			var py: float = record.source_pixel[1]
			var expected_x: float = (py-194)*263/2130
			var expected_z: float = 131.5-(px-38)*263/2130
			assert(absf(float(record.position[0])-expected_x) < 0.002,"Source plan x mismatch")
			assert(absf(float(record.position[2])-expected_z) < 0.002,"Source plan z mismatch")
		if record.profile == "light_aa" and record.shield_variant == "enclosed": closed_light += 1
	assert(closed_light == 4,"Four retained enclosed triple 25mm mounts in the documented game fit")
	for entry: Dictionary in entries:
		var mount: WeaponMount = entry.pivot
		assert(not pivot_ids.has(mount.get_instance_id()),"Shared train pivot")
		assert(not axis_ids.has(mount.elevation_axis.get_instance_id()),"Shared elevation axis")
		pivot_ids[mount.get_instance_id()] = true
		axis_ids[mount.elevation_axis.get_instance_id()] = true
		var record: Dictionary = expected_by_id[str(entry.station_id)]
		var ship_position: Vector3 = scene.ship.to_local(mount.global_position)
		assert(is_equal_approx(ship_position.z,float(record.position[2])))
		assert(is_equal_approx(ship_position.y,float(record.position[1])))
		if not record.has("hull_edge_offset"): assert(is_equal_approx(ship_position.x,float(record.position[0])))
		assert(mount.elevation_axis.get_child_count() > 0)
		mount.manual_move(1,1,10000)
		assert(is_equal_approx(rad_to_deg(mount.rotation.y-mount.base_heading),mount.train_limits.y))
		assert(is_equal_approx(rad_to_deg(mount.elevation_axis.rotation.x),mount.elevation_limits.y))
		mount.manual_move(-1,-1,10000)
		assert(is_equal_approx(rad_to_deg(mount.rotation.y-mount.base_heading),mount.train_limits.x))
		assert(is_equal_approx(rad_to_deg(mount.elevation_axis.rotation.x),mount.elevation_limits.x))
		mount.set_process(false)
		for step: int in range(600):
			var previous: float = mount.rotation.y
			var previous_elevation: float = mount.elevation_axis.rotation.x
			mount._process(0.1)
			assert(absf(mount.rotation.y-previous) <= deg_to_rad(mount.train_speed)*0.1+0.00001)
			assert(absf(mount.elevation_axis.rotation.x-previous_elevation) <= deg_to_rad(mount.elevation_speed)*0.1+0.00001)
			var train: float = rad_to_deg(mount.rotation.y-mount.base_heading)
			assert(train >= mount.train_limits.x-0.01 and train <= mount.train_limits.y+0.01)
			var elevation: float = rad_to_deg(mount.elevation_axis.rotation.x)
			assert(elevation >= mount.elevation_limits.x-0.01 and elevation <= mount.elevation_limits.y+0.01)
	var commanded: WeaponMount = entries[0].pivot
	var other: WeaponMount = entries[1].pivot
	var other_rotation: Vector3 = other.rotation
	commanded.aim_at_angles(999,-999)
	for step: int in range(4000): commanded._process(0.1)
	assert(is_equal_approx(rad_to_deg(commanded.rotation.y-commanded.base_heading),commanded.train_limits.y))
	assert(is_equal_approx(rad_to_deg(commanded.elevation_axis.rotation.x),commanded.elevation_limits.x))
	assert(other.rotation == other_rotation,"Command must affect only its target mount")
	commanded.aim_at_angles(0,20)
	for step: int in range(4000): commanded._process(0.1)
	assert(absf(rad_to_deg(commanded.rotation.y-commanded.base_heading)) < 0.001)
	assert(absf(rad_to_deg(commanded.elevation_axis.rotation.x)-20) < 0.001)
	var held_rotation: Vector3 = commanded.rotation
	commanded.aim_at_angles(NAN,0)
	commanded._process(0.1)
	assert(commanded.rotation == held_rotation,"Invalid command must not corrupt orientation")
	commanded.resume_demo()
	assert(commanded.automatic_demo and commanded.moving)
 
	for entry: Dictionary in entries:
		var mount: WeaponMount = entry.pivot
		mount.rotation.y = mount.base_heading
		mount.elevation_axis.rotation.x = 0
	var first: WeaponMount = entries[0].pivot
	assert(scene.weapon_pose_clear(0,0,first),"Neutral forward main gun must be clear")
	var obstacle: MeshInstance3D = MeshInstance3D.new()
	var obstacle_mesh: BoxMesh = BoxMesh.new()
	obstacle_mesh.size = Vector3(12,5,1)
	obstacle.mesh = obstacle_mesh
	scene.add_child(obstacle)
	obstacle.global_position = first.global_transform*Vector3(0,4.4,-10)
	scene.static_clearance.append({"part":obstacle,"triangles":obstacle_mesh.generate_triangle_mesh()})
	assert(not scene.weapon_pose_clear(0,0,first),"Static geometry in barrel path must block movement")
	scene.static_clearance.pop_back()
	obstacle.free()
	assert(not scene.weapon_pose_clear(deg_to_rad(-150),deg_to_rad(10),first),"Known adjacent turret intersection must be rejected")
	first.pose_guard = scene.weapon_pose_clear.bind(first)
	first.apply_pose(deg_to_rad(-150),deg_to_rad(10))
	assert(first.obstructed)
	assert(scene.weapon_pose_clear(first.rotation.y,first.elevation_axis.rotation.x,first),"Blocked motion must leave a clear pose")
	print("PASS: 39 independent mounts, 60 seconds of speed and angle bounds")
	quit()
