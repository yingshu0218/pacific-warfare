extends Node3D

var _capture_path: String = ""
var _view_name: String = "isometric"


func _ready() -> void:
	_read_arguments()
	_add_lighting()
	_add_camera()


func _read_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		match args[index]:
			"--view":
				if index + 1 < args.size():
					_view_name = args[index + 1]
			"--capture":
				if index + 1 < args.size():
					_capture_path = args[index + 1]


func _add_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.55
	var camera_position: Vector3 = Vector3(1.1, 0.8, 1.3)
	var target: Vector3 = Vector3(0.0, 0.0, -0.025)
	var camera_up: Vector3 = Vector3.UP
	match _view_name:
		"top":
			camera_position = Vector3(0.0, 4.0, 0.0)
			target = Vector3.ZERO
			camera_up = Vector3(0.0, 0.0, -1.0)
			camera.size = 1.04
		"side":
			camera_position = Vector3(4.0, 0.62, 0.0)
			target = Vector3.ZERO
			camera.size = 0.98
		"front":
			camera_position = Vector3(0.0, 0.55, -3.5)
			target = Vector3.ZERO
			camera.size = 0.72
		"detail":
			camera_position = Vector3(0.78, 0.55, 0.90)
			target = Vector3(0.0, 0.0, -0.2)
			camera.size = 0.76
		_:
			camera.size = 1.12
	camera.position = camera_position
	add_child(camera)
	camera.look_at(target, camera_up)
	camera.current = true
	if not _capture_path.is_empty():
		_capture_after_draw()


func _capture_after_draw() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var absolute_path: String = ProjectSettings.globalize_path(_capture_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error: Error = image.save_png(absolute_path)
	if error != OK:
		push_error("Failed to save machine-gun inspection capture at %s (error %d)." % [absolute_path, error])
	else:
		print("Inspection capture saved: %s" % absolute_path)
	get_tree().quit()


func _add_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.26, 0.28, 0.30)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.82, 0.84, 0.85)
	environment.ambient_light_energy = 1.45
	world.environment = environment
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34.0, -38.0, 0.0)
	key.light_color = Color(1.0, 0.97, 0.91)
	key.light_energy = 1.8
	key.shadow_enabled = false
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 145.0, 0.0)
	fill.light_color = Color(0.76, 0.84, 0.92)
	fill.light_energy = 0.82
	fill.shadow_enabled = false
	add_child(fill)
