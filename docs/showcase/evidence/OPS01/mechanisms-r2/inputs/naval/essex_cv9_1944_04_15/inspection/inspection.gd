extends Node3D
## Bounded native capture or interactive isolated model review; never the default scene.
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const MODEL: PackedScene = preload("res://naval/essex_cv9_1944_04_15/essex.tscn")
const FIXTURE: Script = preload("res://naval/essex_cv9_1944_04_15/inspection/deck_fixtures.gd")
const VIEWS: Array[Dictionary] = [
	{"id":"mk32_module","eye":Vector3(9,6,-11),"target":Vector3(0,1.2,0),"size":11.0},
	{"id":"mk24_module","eye":Vector3(7,5,-9),"target":Vector3(0,1.2,0),"size":9.0},
	{"id":"port_side","eye":Vector3(-350,28,0),"target":Vector3(0,15,0),"size":178.0},
	{"id":"starboard_side","eye":Vector3(350,28,0),"target":Vector3(0,15,0),"size":178.0},
	{"id":"top","eye":Vector3(0,350,0),"target":Vector3.ZERO,"size":180.0},
	{"id":"bow_quarter","eye":Vector3(250,180,-280),"target":Vector3(0,13,0),"size":185.0},
	{"id":"stern_quarter","eye":Vector3(-260,160,280),"target":Vector3(0,13,0),"size":185.0},
	{"id":"forward_battery","eye":Vector3(60,44,-82),"target":Vector3(16,20,-39),"size":42.0},
	{"id":"aft_battery","eye":Vector3(67,43,55),"target":Vector3(17,20,21),"size":36.0},
	{"id":"deck_installation","eye":Vector3(-78,83,-145),"target":Vector3(-3,17,-68),"size":84.0},
	{"id":"sb2c_installation","eye":Vector3(-42,51,112),"target":Vector3(-2,19,83),"size":40.0},
	{"id":"sb2c_low_side","eye":Vector3(-38,18.7,83),"target":Vector3(-2,17.7,83),"size":15.0},
	{"id":"elevator_lowered","eye":Vector3(-65,50,-45),"target":Vector3(-18,14,-20),"size":43.0}]
var ship: Node3D
var camera: Camera3D
var fixture: Node3D
var module: Node3D
var sea: MeshInstance3D
var label: Label
var current_view: int = 5
var frames: int = 0
var command_id: int = 0
var output: String = ""
var _browser: JavaScriptObject

func _ready() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("b7c3cb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("e6edf1"); env.ambient_light_energy = .48
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env; add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-30,0); sun.light_energy = .9; sun.shadow_enabled = true; sun.directional_shadow_max_distance = 700
	add_child(sun)
	var ocean: PlaneMesh = PlaneMesh.new(); ocean.size = Vector2(1600,1600)
	sea = MeshInstance3D.new(); sea.mesh = ocean; sea.position.y = -.02
	var water_material: StandardMaterial3D = preload("res://scripts/naval/destroyers/mesh_tools.gd").material(Color("8e9fa8"))
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; water_material.disable_receive_shadows = true
	sea.material_override = water_material; add_child(sea)
	ship = MODEL.instantiate() as Node3D; add_child(ship)
	fixture = FIXTURE.new() as Node3D; ship.add_child(fixture)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.far = 2000; camera.current = true; add_child(camera)
	var canvas: CanvasLayer = CanvasLayer.new(); add_child(canvas)
	var banner: ColorRect = ColorRect.new(); banner.color = Color(0.85,0.89,0.91,.9); banner.size = Vector2(1440,96); canvas.add_child(banner)
	label = Label.new(); label.position = Vector2(24,20); label.add_theme_color_override("font_color",Color("172c3a")); label.add_theme_font_size_override("font_size",20); canvas.add_child(label)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()-1):
		if args[i]=="--capture": output = args[i+1]
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.CV01={commands:[],latest:{}}",true)
		_browser = JavaScriptBridge.get_interface("window")
	_set_view(current_view)
	if not output.is_empty(): call_deferred("_capture")

func _set_view(index: int) -> void:
	current_view = posmod(index,VIEWS.size())
	var view: Dictionary = VIEWS[current_view]
	ship.visible = current_view>=2
	sea.visible = current_view>=2
	fixture.visible = view.id in ["deck_installation","sb2c_installation","sb2c_low_side"]
	ship.call("apply_equipment_state","elevator_port",{"height_m":7.926 if view.id=="elevator_lowered" else 15.85})
	if module != null: remove_child(module); module.free(); module = null
	if current_view<2:
		var scene: PackedScene = load(H.BASE+"weapons/"+("mk32" if current_view==0 else "mk24")+".tscn") as PackedScene
		module = scene.instantiate() as Node3D; add_child(module)
	camera.position = view.eye
	camera.look_at(view.target,Vector3.RIGHT if view.id=="top" else Vector3.UP)
	camera.size = view.size
	label.text = "USS Essex CV-9 | 1944-04-15 | CV01 model review\n"+str(view.id)+"  •  ← / → cameras  |  static deck fit; flight operations pending OPS01"
	_publish()

func _process(_delta: float) -> void:
	frames += 1
	if OS.has_feature("web"):
		var raw: String = JavaScriptBridge.eval("JSON.stringify(window.CV01.commands.splice(0))",true)
		var commands: Array = JSON.parse_string(raw) as Array
		for command: Dictionary in commands:
			command_id = int(command.id)
			if command.kind=="view": _set_view(int(command.value))
			elif command.kind=="elevator": ship.call("apply_equipment_state",command.elevator_id,{"height_m":float(command.value)})
		_publish()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_RIGHT: _set_view(current_view+1)
		elif event.keycode==KEY_LEFT: _set_view(current_view-1)

func _publish() -> void:
	if OS.has_feature("web"):
		var state: Dictionary = {"model_id":"us_essex_cv9_1944_04_15","view":VIEWS[current_view].id,"index":current_view,"frames":frames,"command_id":command_id,"sockets":ship.call("mount_sockets").size(),"elevators":3,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		JavaScriptBridge.eval("window.CV01.latest="+JSON.stringify(state),true)

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var metrics: Array[Dictionary] = []
	for i: int in range(VIEWS.size()):
		_set_view(i)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = output+"/"+str(VIEWS[i].id)+".png"
		var result: Error = img.save_png(path)
		if result != OK: push_error("CV01 capture save failed "+path); get_tree().quit(1); return
		metrics.append({"id":VIEWS[i].id,"file":path,"width":img.get_width(),"height":img.get_height(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var report: FileAccess = FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"views":metrics,"scope":"Static module, ship assembly and deck fit only; no flight operations"},"\t")); report.close()
	print("PASS CV01 captured ",metrics.size()," module/ship/deck views")
	get_tree().quit(0)
