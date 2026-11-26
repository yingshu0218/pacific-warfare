extends Node3D

const ADAPTER: Script = preload("res://scripts/presentation/models/capital_ship_adapter.gd")

var model: Node3D
var camera: Camera3D
var output_dir: String = "res://docs/showcase/evidence/S02"
var model_id: String = "jp_yamato_1944_04"
var _metrics: Dictionary = {}
var neutral: bool = false

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="):
			model_id = arg.get_slice("=",1)
		if arg == "--neutral":
			neutral = true
		if arg.begins_with("--output="):
			output_dir = arg.get_slice("=",1)
	model = ADAPTER.new() as Node3D
	model.model_id = model_id
	add_child(model)
	if neutral:
		var neutral_material: StandardMaterial3D = StandardMaterial3D.new()
		neutral_material.albedo_color = Color("68747a")
		neutral_material.roughness = 0.85
		neutral_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		for child: Node in model.find_children("*","MeshInstance3D",true,false):
			var part: MeshInstance3D = child as MeshInstance3D
			part.material_override = neutral_material
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
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 2000
	add_child(camera)
	get_viewport().size = Vector2i(1600,1000)
	call_deferred("_capture")

func _capture() -> void:
	var absolute: String = ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(absolute)
	var views: Dictionary = {
		"side":{"from":Vector3(-340,16,0),"target":Vector3(0,16,0),"size":179.0},
		"top":{"from":Vector3(0,360,0.01),"target":Vector3.ZERO,"size":179.0},
		"bow_quarter":{"from":Vector3(-225,125,-245),"target":Vector3(0,12,0),"size":190.0},
		"stern_quarter":{"from":Vector3(210,120,235),"target":Vector3(0,13,0),"size":192.0},
		"fore_battery":{"from":Vector3(-70,45,-81),"target":Vector3(0,13,-26),"size":70.0},
		"aft_battery":{"from":Vector3(-65,44,90),"target":Vector3(0,13,45),"size":67.0}
	}
	var files: Array[String] = []
	for view: String in views:
		var record: Dictionary = views[view]
		camera.position = record.from
		camera.size = record.size
		camera.look_at(record.target)
		if view == "top":
			camera.rotation.z += PI/2.0
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = absolute.path_join(model_id+("_neutral" if neutral else "")+"_"+view+".png")
		var error: Error = get_viewport().get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Could not save S02 capture: "+path)
			get_tree().quit(1)
			return
		files.append(path)
	_metrics = {"model_id":model_id,"render_size":[1600,1000],"views":files,"sockets":model.mount_sockets(),
		"draw_calls_last_view":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects_last_view":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"triangles_last_view":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"nodes":model.find_children("*","Node",true,false).size()}
	var raw_triangles: int = 0
	var mesh_count: int = 0
	for child: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh: Mesh = (child as MeshInstance3D).mesh
		if mesh != null:
			raw_triangles += mesh.get_faces().size()/3
			mesh_count += 1
	_metrics["raw_mesh_triangles"] = raw_triangles
	_metrics["mesh_instances"] = mesh_count
	var file: FileAccess = FileAccess.open(absolute.path_join(model_id+("_neutral" if neutral else "")+"_audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics,"\t"))
	print("PASS S02 model captures: "+model_id+"; "+str(files.size())+" same-model views")
	get_tree().quit(0)
