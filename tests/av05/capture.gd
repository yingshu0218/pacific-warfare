extends SceneTree
## Fixed native views of the two actual model scenes and their stock flight configuration.

const MODELS: Dictionary = {
	"g4m1": preload("res://aircraft/g4m1/g4m1.tscn"),
	"d4y2": preload("res://aircraft/d4y2/d4y2.tscn"),
}
const VIEWS: Dictionary = {
	"side": Vector3(1.0, 0.02, -0.06),
	"front-quarter": Vector3(0.9, 0.34, -1.0),
	"top": Vector3(0.0, 1.0, -0.001),
	"follow": Vector3(sin(0.9) * cos(0.18), sin(0.18), cos(0.9) * cos(0.18)),
	"port-belly": Vector3(-0.90, -0.55, -0.60),
	"starboard-belly": Vector3(0.90, -0.55, 0.60),
}
const SIZE: Vector2i = Vector2i(1440, 900)

func _initialize() -> void:
	call_deferred("_run")

func _stats(node: Node3D) -> Dictionary:
	var counts: Dictionary = {"nodes": 0, "surfaces": 0, "triangles": 0, "visible_surfaces": 0, "visible_triangles": 0}
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		counts.nodes += 1
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			var triangle_count: int = (arrays[Mesh.ARRAY_VERTEX].size() if indices == null else indices.size()) / 3
			counts.surfaces += 1
			counts.triangles += triangle_count
			if instance.is_visible_in_tree():
				counts.visible_surfaces += 1
				counts.visible_triangles += triangle_count
	return counts

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass an absolute output directory after --")
		quit(1)
		return
	var output: String = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.size = SIZE
	root.msaa_3d = Viewport.MSAA_4X
	var world: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b1bdc7")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dde8f4")
	env.ambient_light_energy = 0.63
	world.environment = env
	root.add_child(world)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key.light_energy = 1.15
	root.add_child(key)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.8
	root.add_child(camera)
	var audit: Dictionary = {"size_px": [SIZE.x, SIZE.y], "fov_deg": camera.fov, "models": {}}
	for id: String in MODELS:
		var plane: Node3D = MODELS[id].instantiate()
		root.add_child(plane)
		plane.set_flight_configuration()
		var measurements: Dictionary = {"geometry": _stats(plane), "camera": {}, "markers": {}}
		for marker_id: String in plane.markers:
			var marker: Marker3D = plane.markers[marker_id]
			measurements.markers[marker_id] = [marker.position.x, marker.position.y, marker.position.z,
				marker.global_position.x, marker.global_position.y, marker.global_position.z]
		for view: String in VIEWS:
			var distance_m: float = 23.0 if id == "g4m1" else 11.0
			if view == "follow":
				distance_m = 42.0
			elif view == "top" or view.ends_with("-belly"):
				distance_m = 27.0 if id == "g4m1" else 13.0
			var at: Vector3 = Vector3(0.0, 2.0, 0.0) if view == "follow" else Vector3.ZERO
			camera.position = at + (VIEWS[view] as Vector3).normalized() * distance_m
			camera.look_at(at)
			measurements.camera[view] = {"position_m": [camera.position.x, camera.position.y, camera.position.z],
				"target_m": [at.x, at.y, at.z], "distance_m": distance_m}
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var path: String = output.path_join(id + "-" + view + ".png")
			if root.get_texture().get_image().save_png(path) != OK:
				push_error("Failed to save " + path)
				quit(1)
				return
		audit.models[id] = measurements
		plane.free()
	var report: FileAccess = FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if report == null:
		push_error("Failed to write capture.json")
		quit(1)
		return
	report.store_string(JSON.stringify(audit, "\t") + "\n")
	report.close()
	quit(0)
