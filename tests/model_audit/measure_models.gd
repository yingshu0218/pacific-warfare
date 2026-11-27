extends SceneTree
## Measurements come from visible triangulated geometry of each assembled scene.
## X = transverse/spans, Y = vertical extent, Z = longitudinal.
const UNIT_DIR: String = "res://data/units"
var results: Array[Dictionary] = []
var failing: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <absolute output directory> [glb] [additional res://scene.tscn ...]")
		quit(2)
		return
	var out: String = args[0]
	var err: Error = DirAccess.make_dir_recursive_absolute(out)
	if err != OK:
		push_error("cannot create output directory")
		quit(2)
		return
	for filename: String in DirAccess.get_files_at(UNIT_DIR):
		if not filename.ends_with(".json"):
			continue
		var unit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UNIT_DIR.path_join(filename)))
		await _measure(str(unit.id), str(unit.domain), str(unit.model_scene), unit.dimensions_m, out, args.has("glb"))
	for entry: String in args:
		if entry.begins_with("res://") and entry.ends_with(".tscn"):
			await _measure(entry.get_file().get_basename(), "environment", entry, [], out,
				args.has("glb") and entry.ends_with("/facilities.tscn"))
	var handle: FileAccess = FileAccess.open(out.path_join("measured.json"), FileAccess.WRITE)
	if handle == null:
		push_error("cannot open measurement report")
		quit(2)
		return
	handle.store_string(JSON.stringify(results, "\t") + "\n")
	handle.close()
	print("MODEL_AUDIT records=", results.size())
	quit(1 if failing else 0)

func _measure(id: String, domain: String, path: String, stated: Array, out: String, export_glb: bool) -> void:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("could not load " + path)
		failing = true
		return
	var model: Node3D = scene.instantiate() as Node3D
	if model == null:
		push_error("not a Node3D " + path)
		failing = true
		return
	root.add_child(model)
	await process_frame
	var origin_inv: Transform3D = model.global_transform.affine_inverse()
	var mins: Vector3 = Vector3(INF, INF, INF)
	var maxs: Vector3 = Vector3(-INF, -INF, -INF)
	var hull_min: Vector3 = Vector3(INF, INF, INF)
	var hull_max: Vector3 = Vector3(-INF, -INF, -INF)
	var plane_min: Vector2 = Vector2(INF, INF)
	var plane_max: Vector2 = Vector2(-INF, -INF)
	var min_paths: Array[String] = ["", "", ""]
	var max_paths: Array[String] = ["", "", ""]
	var visual_root: Node3D = Node3D.new() if export_glb else null
	var n: int = 0
	var meshes: int = 0
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = child as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var tr: Transform3D = origin_inv * m.global_transform
		var local_path: String = str(model.get_path_to(m))
		var hull: bool = domain == "ship" and _hull_surface(id, local_path)
		var vertices: PackedVector3Array = m.mesh.get_faces()
		if vertices.is_empty():
			continue
		if visual_root != null:
			var view_mesh: MeshInstance3D = MeshInstance3D.new()
			view_mesh.mesh = m.mesh
			view_mesh.transform = tr
			visual_root.add_child(view_mesh)
			view_mesh.owner = visual_root
			for surface: int in range(m.mesh.get_surface_count()):
				view_mesh.set_surface_override_material(surface, m.get_active_material(surface))
		meshes += 1
		n += vertices.size()
		if hull:
			for j: int in range(0, vertices.size() - 2, 3):
				var tri: Array[Vector3] = [tr * vertices[j], tr * vertices[j+1], tr * vertices[j+2]]
				for k: int in range(3):
					var a: Vector3 = tri[k]
					var b: Vector3 = tri[(k+1)%3]
					if absf(a.y) <= 0.00001:
						var flat: Vector2 = Vector2(a.x, a.z)
						plane_min = plane_min.min(flat)
						plane_max = plane_max.max(flat)
					elif a.y * b.y < 0.0:
						var at: Vector3 = a.lerp(b, -a.y / (b.y - a.y))
						var flat: Vector2 = Vector2(at.x, at.z)
						plane_min = plane_min.min(flat)
						plane_max = plane_max.max(flat)
		for raw_v: Vector3 in vertices:
			var v: Vector3 = tr * raw_v
			if hull:
				hull_min = hull_min.min(v)
				hull_max = hull_max.max(v)
			for i: int in range(3):
				if v[i] < mins[i]:
					mins[i] = v[i]
					min_paths[i] = local_path
				if v[i] > maxs[i]:
					maxs[i] = v[i]
					max_paths[i] = local_path
	if meshes == 0:
		push_error("no visible triangles in " + path)
		failing = true
		if visual_root != null:
			visual_root.free()
		model.free()
		return
	var size: Vector3 = maxs - mins
	results.append({"id": id, "domain": domain, "scene": path, "stated_m": stated,
		"measured_m": _arr(size), "minimum_m": _arr(mins), "maximum_m": _arr(maxs),
		"hull_m": _arr(hull_max-hull_min) if hull_min.is_finite() else [],
		"hull_y0_m": [plane_max.x-plane_min.x, plane_max.y-plane_min.y] if plane_min.is_finite() else [],
		"min_paths": min_paths, "max_paths": max_paths, "meshes": meshes, "triangle_vertices": n})
	print("MODEL ", id, " size=", size, " meshes=", meshes)
	if export_glb:
		var document: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		var e: Error = document.append_from_scene(visual_root, state)
		if e == OK:
			e = document.write_to_filesystem(state, out.path_join(id + ".glb"))
		if e != OK:
			push_error("failed exporting native geometry for " + id + " code=" + str(e))
			failing = true
		visual_root.free()
	model.free()

func _arr(v: Vector3) -> Array[float]:
	return [v.x, v.y, v.z]

# Report the hull separately: a flight-deck overhang or a visible prop/fixture
# is not part of the navy's hull beam or waterline. These are model paths,
# not assumptions about which parts compare with an external source.
func _hull_surface(id: String, path: String) -> bool:
	if id.begins_with("us_iowa"):
		return path.ends_with("/Hull/Hull")
	if id.begins_with("us_essex"):
		return path.ends_with("/Hull/ContinuousHull")
	if id.begins_with("jp_yamato"):
		return "/Hull/Static_" in path
	if id.begins_with("jp_shokaku"):
		return "/Hull/StaticBatch_" in path
	return path == "Hull/ShellAndSheer" or path == "Hull/UnderwaterHull"
