extends Node3D
## Bounded native evidence only; unit resources themselves have no viewer contents.
var camera: Camera3D
var model: Node3D

func _ready() -> void:
	_run()

func _run() -> void:
	var id: String = "fletcher_dd445"
	var output: String = "res://.local/s03/captures"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--ship":
			id = args[index + 1]
		if args[index] == "--output":
			output = args[index + 1]
	get_window().size = Vector2i(1440,900)
	var environment: WorldEnvironment = WorldEnvironment.new()
	var world: Environment = Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("c6ccce")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color.WHITE
	world.ambient_light_energy = 0.45
	world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = world
	add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42,-32,0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 300.0
	add_child(light)
	var packed: PackedScene = load("res://scenes/ships/" + id + "/" + id + ".tscn") as PackedScene
	if packed == null:
		get_tree().quit(2)
		return
	model = packed.instantiate() as Node3D
	add_child(model)
	(model.get_node("Hull/UnderwaterHull") as MeshInstance3D).visible = false
	# Neutral waterline mask is a viewer object; never part of model_scene.
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(100000,100000)
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color("c6ccce")
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_material.roughness = 1.0
	var floor_instance: MeshInstance3D = MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = floor_material
	add_child(floor_instance)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 139.0
	camera.far = 1200.0
	add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var views: Array[Dictionary] = [
		{"id":"side","position":Vector3(160,12,0),"target":Vector3(0,11,0),"size":138.0},
		{"id":"top","position":Vector3(0,180,0.01),"target":Vector3(0,0,0),"size":220.0},
		{"id":"bow_quarter","position":Vector3(105,70,-130),"target":Vector3(0,8,0),"size":136.0},
		{"id":"stern_quarter","position":Vector3(-110,60,120),"target":Vector3(0,8,0),"size":136.0},
		{"id":"fore_battery","position":Vector3(42,30,-65),"target":Vector3(0,7,-26),"size":61.0},
		{"id":"aft_battery","position":Vector3(-36,29,62),"target":Vector3(0,6,32),"size":61.0}]
	for view: Dictionary in views:
		camera.position = view.position
		camera.size = view.size
		camera.look_at(view.target, Vector3.FORWARD if view.id == "top" else Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = output.path_join(id + "_" + str(view.id) + ".png")
		var error: Error = get_viewport().get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Capture failed " + path)
			get_tree().quit(3)
			return
		print("S03_CAPTURE " + path)
	get_tree().quit(0)
