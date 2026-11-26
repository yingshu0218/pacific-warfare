extends Node3D

const PREVIEW_PLATE_SIZE: Vector3 = Vector3(8.0, 0.2, 8.0)

@onready var mount: USNBofors40mmQuadMark2Mod5 = $Mount
var _capture_path: String = ""
var _view_name: String = "isometric"


func _ready() -> void:
	_add_preview_deck()
	_add_preview_lighting()
	_add_camera()
	_apply_command_line()


func _apply_command_line() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		match args[index]:
			"--view":
				if index + 1 < args.size():
					_view_name = args[index + 1]
			"--capture":
				if index + 1 < args.size():
					_capture_path = args[index + 1]
			"--elevation":
				if index + 1 < args.size():
					mount.set_elevation(float(args[index + 1]))
			"--train":
				if index + 1 < args.size():
					mount.set_train_angle(float(args[index + 1]))

	var camera: Camera3D = $Camera3D
	var target: Vector3 = Vector3(0.0, 2.0, 0.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.4
	match _view_name:
		"top":
			camera.position = Vector3(0.0, 12.0, 0.0)
			camera.look_at(target, Vector3(0.0, 0.0, -1.0))
			camera.size = 6.8
		"side":
			camera.position = Vector3(9.0, 3.4, 0.0)
			camera.look_at(Vector3(0.0, 1.8, 0.0), Vector3.UP)
			camera.size = 6.7
		"front":
			camera.position = Vector3(0.0, 2.9, -8.0)
			camera.look_at(Vector3(0.0, 1.7, -0.7), Vector3.UP)
			camera.size = 5.5
		"detail":
			camera.position = Vector3(3.8, 3.1, 3.7)
			camera.look_at(Vector3(0.0, 1.7, -0.25), Vector3.UP)
			camera.size = 4.4
		_: 
			camera.position = Vector3(7.5, 5.4, 8.5)
			camera.look_at(target, Vector3.UP)
			camera.size = 7.8

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
		push_error("Failed to save inspection capture at %s (error %d)." % [absolute_path, error])
	else:
		print("Inspection capture saved: %s" % absolute_path)
	get_tree().quit()


func _add_preview_deck() -> void:
	var deck := MeshInstance3D.new()
	deck.name = "InspectionOnlyFlatDeck"
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = PREVIEW_PLATE_SIZE
	deck.mesh = deck_mesh
	deck.position = Vector3(0.0, -0.1, 0.0)
	var deck_material := StandardMaterial3D.new()
	deck_material.albedo_color = Color(0.35, 0.38, 0.39)
	deck_material.roughness = 0.9
	deck.material_override = deck_material
	add_child(deck)


func _add_preview_lighting() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2, 0.225, 0.245)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.8, 0.82)
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	add_child(environment_node)

	var key_light := DirectionalLight3D.new()
	key_light.name = "NeutralKeyLight"
	key_light.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	key_light.light_color = Color(1.0, 0.97, 0.9)
	key_light.light_energy = 1.4
	key_light.shadow_enabled = false
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "NeutralFillLight"
	fill_light.rotation_degrees = Vector3(-25.0, 148.0, 0.0)
	fill_light.light_color = Color(0.73, 0.82, 0.9)
	fill_light.light_energy = 0.55
	add_child(fill_light)


func _add_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)
