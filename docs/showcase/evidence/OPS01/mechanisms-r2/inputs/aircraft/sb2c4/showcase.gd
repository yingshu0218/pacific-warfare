extends Node3D

const INSPECTION_TARGET: Vector3 = Vector3(0.0, 2.15, 0.0)

var camera: Camera3D
var ground: MeshInstance3D
var selected_view: String = "quarter"
var capture_path: String = ""
var clean_configuration: bool = true
var flight_configuration: bool = false
var inspection_pose: String = "parked"


func _ready() -> void:
	_parse_user_arguments()
	_build_stage()
	_build_camera()
	$SB2C_4.set_showcase_configuration(clean_configuration)
	_set_view(selected_view)
	if not capture_path.is_empty():
		_capture_and_exit()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_set_view("quarter")
		KEY_2:
			_set_view("rear_quarter")
		KEY_3:
			_set_view("side")
		KEY_4:
			_set_view("top")
		KEY_5:
			_set_view("underside")
		KEY_6:
			_set_view("front")
		KEY_7:
			_set_view("rear")
		KEY_8:
			_set_view("front_port")
		KEY_9:
			_set_view("underside_quarter")
		KEY_B:
			_set_view("bomb_bay")
		KEY_D:
			_set_view("wing_root_detail")
		KEY_W:
			_set_view("wing_detail")
		KEY_C:
			_set_view("cockpit_detail")
		KEY_T:
			_set_view("tailwheel_detail")
		KEY_ESCAPE:
			get_tree().quit()


func _parse_user_arguments() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < arguments.size():
		if arguments[index] == "--view" and index + 1 < arguments.size():
			selected_view = arguments[index + 1]
			index += 2
		elif arguments[index] == "--capture" and index + 1 < arguments.size():
			capture_path = arguments[index + 1]
			index += 2
		elif arguments[index] == "--mode" and index + 1 < arguments.size():
			flight_configuration = arguments[index + 1] == "flight"
			clean_configuration = flight_configuration or arguments[index + 1] == "clean"
			index += 2
		elif arguments[index] == "--pose" and index + 1 < arguments.size():
			inspection_pose = arguments[index + 1]
			index += 2
		else:
			index += 1


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("c5ccd2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e4e7e9")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "Neutral hangar inspection lighting"
	world.environment = environment
	add_child(world)

	var key_light := DirectionalLight3D.new()
	key_light.name = "Large soft key light"
	key_light.rotation_degrees = Vector3(-42.0, -26.0, 0.0)
	key_light.light_energy = 0.70
	key_light.light_color = Color("fff4e3")
	key_light.shadow_enabled = false
	add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.name = "Cool fill light"
	fill_light.position = Vector3(8.0, 8.0, 6.0)
	fill_light.light_energy = 0.44
	fill_light.omni_range = 42.0
	fill_light.light_color = Color("c6d7e8")
	add_child(fill_light)
	var rim_light := OmniLight3D.new()
	rim_light.name = "Warm rear rim light"
	rim_light.position = Vector3(-9.0, 5.0, -7.0)
	rim_light.light_energy = 0.26
	rim_light.omni_range = 38.0
	rim_light.light_color = Color("ffd9b0")
	add_child(rim_light)
	var underside_fill := OmniLight3D.new()
	underside_fill.name = "Soft underside fill"
	underside_fill.position = Vector3(-1.0, -4.5, 0.0)
	underside_fill.light_energy = 1.30
	underside_fill.omni_range = 30.0
	underside_fill.light_color = Color("dbe8f1")
	add_child(underside_fill)
	var underside_directional := DirectionalLight3D.new()
	underside_directional.name = "Broad underside bounce"
	underside_directional.rotation_degrees = Vector3(90.0, -20.0, 0.0)
	underside_directional.light_energy = 0.42
	underside_directional.light_color = Color("d7e1e7")
	underside_directional.shadow_enabled = false
	add_child(underside_directional)

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("8b969e")
	floor_material.roughness = 0.88
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(60.0, 60.0)
	ground = MeshInstance3D.new()
	ground.name = "Neutral floor for standing views"
	ground.mesh = floor_mesh
	ground.material_override = floor_material
	ground.position.y = 0.0
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "SB2C-4 inspection camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 300.0
	camera.current = true
	add_child(camera)


func _set_view(view_name: String) -> void:
	selected_view = view_name
	var up_axis: Vector3 = Vector3.UP
	var target: Vector3 = INSPECTION_TARGET
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	ground.visible = inspection_pose == "parked" and view_name != "underside" and view_name != "underside_quarter" and view_name != "bomb_bay" and view_name != "wing_detail" and view_name != "wing_root_detail" and view_name != "cockpit_detail" and view_name != "tailwheel_detail"
	match view_name:
		"observer_follow":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 50.0
			camera.position = Vector3(18.0, 8.0, -24.0)
		"reference_side":
			camera.size = 7.8
			camera.position = Vector3(-25.0, 3.30, -2.5)
			target = Vector3(0.0, 2.30, 0.0)
		"reference_front":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 22.0
			camera.position = Vector3(-13.0, 13.0, -16.0)
		"reference_rear":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 22.0
			camera.position = Vector3(13.0, 13.0, 16.0)
		"gunner_detail":
			camera.size = 2.3
			camera.position = Vector3(-3.4, 3.4, 2.9)
			target = Vector3(0.0, 2.85, 1.70)
		"stores_detail":
			camera.size = 3.8
			camera.position = Vector3(8.5, 0.0, -5.5)
			target = Vector3(5.3, 2.2, -0.5)
		"front":
			camera.size = 11.4
			camera.position = Vector3(0.0, 2.25, -20.0)
		"rear":
			camera.size = 11.4
			camera.position = Vector3(0.0, 2.25, 20.0)
		"side":
			camera.size = 8.0
			camera.position = Vector3(18.0, 2.85, 0.0)
		"top":
			camera.size = 11.8
			camera.position = Vector3(0.0, 22.0, 0.0)
			up_axis = Vector3(0.0, 0.0, -1.0)
		"underside":
			camera.size = 11.8
			camera.position = Vector3(0.0, -20.0, 0.0)
			up_axis = Vector3(0.0, 0.0, -1.0)
		"underside_quarter":
			camera.size = 11.0
			camera.position = Vector3(13.0, -9.0, -16.0)
		"bomb_bay":
			camera.size = 3.8
			camera.position = Vector3(0.0, -4.4, -1.8)
			target = Vector3(0.0, 1.88, 0.59)
			up_axis = Vector3(0.0, 0.0, -1.0)
		"wing_root_detail":
			camera.size = 2.8
			camera.position = Vector3(4.6, 6.5, 2.5)
			target = Vector3(2.8, 2.45, 1.05)
			up_axis = Vector3(0.0, 0.0, -1.0)
		"cockpit_detail":
			camera.size = 2.8
			camera.position = Vector3(-10.0, 3.5, -0.45)
			target = Vector3(0.0, 2.80, -0.45)
		"tailwheel_detail":
			camera.size = 1.8
			camera.position = Vector3(-3.2, 2.2, 5.1)
			target = Vector3(0.0, 1.83, 3.90)
		"wing_detail":
			camera.size = 2.45
			camera.position = Vector3(8.35, 6.65, 2.55)
			target = Vector3(6.20, 2.57, 0.40)
			up_axis = Vector3(0.0, 0.0, -1.0)
		"rear_quarter":
			camera.size = 10.5
			camera.position = Vector3(-13.0, 9.0, 15.0)
		"front_port":
			camera.size = 8.5
			camera.position = Vector3(-13.0, 13.0, -16.0)
		_:
			selected_view = "quarter"
			camera.size = 11.0
			camera.position = Vector3(13.0, 9.0, -16.0)
	$SB2C_4.transform = Transform3D.IDENTITY
	if inspection_pose == "parked":
		$SB2C_4.transform = $SB2C_4.get_parked_transform()
	$SB2C_4.armament_module.visible = true
	$SB2C_4.set_showcase_configuration(clean_configuration)
	$SB2C_4.landing_gear.visible = view_name != "bomb_bay"
	if view_name == "cockpit_detail" or view_name == "wing_detail" or view_name == "wing_root_detail":
		$SB2C_4.landing_gear.visible = false
		$SB2C_4.external_stores_module.visible = false
		$SB2C_4.arrestor_hook.visible = false
	if view_name == "cockpit_detail" or view_name == "wing_detail":
		$SB2C_4.dive_brakes_module.visible = false
	if view_name == "cockpit_detail":
		$SB2C_4.wing_module.visible = false
		$SB2C_4.control_surfaces.visible = false
		$SB2C_4.armament_module.visible = false
	if view_name == "bomb_bay":
		$SB2C_4.dive_brakes_module.visible = false
		$SB2C_4.external_stores_module.visible = false
		$SB2C_4.bay_open_group.visible = true
		$SB2C_4.bay_closed_group.visible = false
		$SB2C_4.arrestor_hook.visible = false
	if view_name == "tailwheel_detail":
		$SB2C_4.arrestor_hook.visible = false
	if view_name in ["gunner_detail", "stores_detail"]:
		ground.visible = false
		$SB2C_4.landing_gear.visible = false
	if flight_configuration:
		$SB2C_4.set_flight_configuration()
		ground.visible = false
	target = $SB2C_4.transform * target
	camera.look_at(target, up_axis)


func _capture_and_exit() -> void:
	await get_tree().create_timer(1.2).timeout
	var screenshot: Image = get_viewport().get_texture().get_image()
	var result: Error = screenshot.save_png(capture_path)
	var model: Node3D = $SB2C_4
	var metadata: Dictionary = {
		"engine": Engine.get_version_info()["string"],
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"view": selected_view,
		"mode": "flight" if flight_configuration else ("clean" if clean_configuration else "detail"),
		"pose": inspection_pose,
		"viewport_px": [screenshot.get_width(), screenshot.get_height()],
		"camera_projection": "perspective" if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else "orthographic",
		"camera_position_m": [camera.position.x, camera.position.y, camera.position.z],
		"camera_rotation_rad": [camera.rotation.x, camera.rotation.y, camera.rotation.z],
		"camera_size_m": camera.size,
		"camera_fov_degrees": camera.fov,
		"model_position_m": [model.position.x, model.position.y, model.position.z],
		"model_rotation_rad": [model.rotation.x, model.rotation.y, model.rotation.z],
		"model_source_sha256": FileAccess.get_sha256("res://aircraft/sb2c4/sb2c4.gd"),
		"showcase_source_sha256": FileAccess.get_sha256("res://aircraft/sb2c4/showcase.gd"),
		"shared_builder_sha256": FileAccess.get_sha256("res://aircraft/scripts/aircraft_builder.gd"),
	}
	var metadata_file: FileAccess = FileAccess.open(capture_path + ".json", FileAccess.WRITE)
	if metadata_file == null:
		push_error("SB2C capture metadata could not be saved.")
		get_tree().quit(1)
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t") + "\n")
	metadata_file.close()
	print("SB2C-4 capture %s: %s" % [capture_path, error_string(result)])
	get_tree().quit(0 if result == OK else 1)
