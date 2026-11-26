extends SceneTree
## Bounded neutral single-model views, using the same geometry as the battle.
var camera: Camera3D
var model: GroundUnitModel
var output: String

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_size(Vector2i(1280,800))
	root.content_scale_size=Vector2i(1280,800)
	var id: String = "us_5in51_mk13mod4_1945"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()-1):
		if args[index]=="--model":id=args[index+1]
	output="res://docs/showcase/evidence/S10/models/"+id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var stage: Node3D = Node3D.new();root.add_child(stage)
	var environment: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("bec4c6")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.55
	environment.environment=env;stage.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-42,-30,0);light.light_energy=.85;light.shadow_enabled=true
	stage.add_child(light)
	var p: Script = load("res://scripts/ground/models/parts.gd")
	var m: Script = load("res://scripts/naval/destroyers/mesh_tools.gd")
	m.box(stage,"NeutralFloor",Vector3(100,.02,100),Vector3(0,-.012,0),p.palette().concrete)
	model=(load("res://scenes/ground/"+id+".tscn") as PackedScene).instantiate() as GroundUnitModel
	stage.add_child(model)
	camera=Camera3D.new();stage.add_child(camera);camera.current=true
	camera.near=.05;camera.far=150;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var target: Vector3 = Vector3(0,1,-.8) if id.contains("5in51") else Vector3(0,1.3,0)
	var views: Array[Dictionary] = [
		{"name":"side","offset":Vector3(14,0,0),"size":9.5},
		{"name":"front","offset":Vector3(0,0,-14),"size":8.7},
		{"name":"top","offset":Vector3(.001,16,0),"size":9.5},
		{"name":"front_quarter","offset":Vector3(8,5,-11),"size":9.5},
		{"name":"rear_quarter","offset":Vector3(-8,4,11),"size":9.5},
		{"name":"elevated","offset":Vector3(9,3,-11),"size":9.5}]
	for view: Dictionary in views:
		if view.name=="elevated":model.apply_weapon_state(model.spec.mount.id,{"train_rad":.35,"elevation_rad":deg_to_rad(20 if id.contains("5in51") else 75)})
		camera.position=target+view.offset;camera.size=view.size
		camera.look_at(target,Vector3.FORWARD if view.name=="top" else Vector3.UP)
		await process_frame;await process_frame;RenderingServer.force_draw(false,0)
		var error: Error = root.get_texture().get_image().save_png(output.path_join(view.name+".png"))
		if error!=OK:push_error("S10 capture failed");quit(1);return
	print("S10_MODEL_CAPTURE ",id," six views saved")
	stage.free();quit(0)
