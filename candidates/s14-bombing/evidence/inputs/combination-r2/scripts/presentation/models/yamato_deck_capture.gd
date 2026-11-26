extends Node3D

## Fixed inspection cameras only. No simulation, ocean, or changes to the model pose.
const ADAPTER: Script = preload("res://scripts/presentation/models/capital_ship_adapter.gd")
const VIEWS: Array[Dictionary] = [
	{"id":"port_side", "from":Vector3(-340,16,0), "target":Vector3(0,16,0), "size":177.0},
	{"id":"starboard_side", "from":Vector3(340,16,0), "target":Vector3(0,16,0), "size":177.0},
	{"id":"port_elevated", "from":Vector3(-340,105,0), "target":Vector3(0,12,0), "size":177.0},
	{"id":"fore_transition", "from":Vector3(-160,24,-65), "target":Vector3(0,8,-65), "size":80.0},
	{"id":"aft_transition", "from":Vector3(-160,24,85), "target":Vector3(0,8,85), "size":66.0},
	{"id":"fore_hull_side", "from":Vector3(-160,8,-65), "target":Vector3(0,8,-65), "size":80.0, "hull_only":true},
	{"id":"aft_hull_side", "from":Vector3(-160,8,85), "target":Vector3(0,8,85), "size":66.0, "hull_only":true}
]

var model: CapitalShipAdapter
var camera: Camera3D
var output_dir: String = "res://docs/showcase/evidence/S02-deck/before"
var _web: bool = false
var _view_index: int = 0
var _command_id: int = 0
var _frames: int = 0
var _socket_count: int = 0

func _ready() -> void:
	_web = OS.has_feature("web")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	model = ADAPTER.new() as CapitalShipAdapter
	model.model_id = "jp_yamato_1944_04"
	add_child(model)
	_socket_count = model.mount_sockets().size()
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("d8dce0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cbd4df")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.far = 2000
	add_child(camera)
	get_viewport().size = Vector2i(1600,1000)
	set_view(0)
	if _web:
		JavaScriptBridge.eval("window.S02Deck={commands:[],latest:null};document.title='S02 Yamato deck inspection';")
	else:
		set_process(false)
		call_deferred("_capture")

func set_view(index: int) -> void:
	_view_index = clampi(index,0,VIEWS.size()-1)
	var record: Dictionary = VIEWS[_view_index]
	camera.position = record.from
	camera.size = float(record.size)
	camera.look_at(record.target)
	for child: Node in model.model_root.get_children():
		if child is Node3D:
			(child as Node3D).visible = not bool(record.get("hull_only",false)) or child.name == "Hull"
	# Main-deck mount markers are under Hull; isolate the hull without their foundations.
	for child: Node in model.model_root.find_children("Station_*","Marker3D",true,false):
		(child as Node3D).visible = not bool(record.get("hull_only",false))

func _process(_delta: float) -> void:
	_frames += 1
	var raw: String = str(JavaScriptBridge.eval("JSON.stringify(window.S02Deck.commands.splice(0))"))
	var commands: Variant = JSON.parse_string(raw)
	if commands is Array:
		for command: Dictionary in commands:
			if str(command.get("kind","")) == "view":
				set_view(int(command.value))
				_command_id = int(command.id)
	var state: Dictionary = {"view":VIEWS[_view_index].id,"index":_view_index,"command_id":_command_id,
		"frames":_frames,"model_id":model.model_id,"sockets":_socket_count,
		"viewport":[get_viewport().size.x,get_viewport().size.y],
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	JavaScriptBridge.eval("window.S02Deck.latest="+JSON.stringify(state))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT: set_view((_view_index+1)%VIEWS.size())
		if event.keycode == KEY_LEFT: set_view((_view_index+VIEWS.size()-1)%VIEWS.size())

func _capture() -> void:
	var absolute: String = ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(absolute)
	var views: Array[Dictionary] = []
	for index: int in range(VIEWS.size()):
		set_view(index)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var record: Dictionary = VIEWS[index]
		var path: String = absolute.path_join(str(record.id)+".png")
		var error: Error = get_viewport().get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Could not save deck inspection: "+path)
			get_tree().quit(1)
			return
		views.append({"id":record.id,"position_m":_vector(record.from),"target_m":_vector(record.target),
			"orthographic_size_m":record.size,"hull_only":record.get("hull_only",false),"file":path,
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var raw_triangles: int = 0
	var meshes: int = 0
	for child: Node in model.find_children("*","MeshInstance3D",true,false):
		var part: MeshInstance3D = child as MeshInstance3D
		if part.mesh != null:
			raw_triangles += part.mesh.get_faces().size()/3
			meshes += 1
	var file: FileAccess = FileAccess.open(absolute.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"model_id":model.model_id,"render_size":[1600,1000],"views":views,
		"sockets":model.mount_sockets(),"raw_mesh_triangles":raw_triangles,"mesh_instances":meshes},"\t"))
	file.close()
	print("PASS S02-deck: seven fixed cameras; "+str(raw_triangles)+" raw triangles; "+str(meshes)+" meshes")
	get_tree().quit(0)

func _vector(value: Vector3) -> Array[float]:
	return [value.x,value.y,value.z]
