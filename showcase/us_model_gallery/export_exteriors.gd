extends SceneTree
## Export the rendered Godot meshes for an offline visual QA sheet, not for gameplay.
const GALLERY := "res://showcase/us_model_gallery/viewer.tscn"
const ARCHIVE_GALLERY := "res://showcase/archive_gallery/viewer.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].is_absolute_path():
		printerr("Usage: -- <absolute-output-directory> [archive] [model ids...]")
		quit(2)
		return
	var out: String = args[0]
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(2)
		return
	var gallery_path: String = ARCHIVE_GALLERY if "archive" in args else GALLERY
	var gallery: Node3D = (load(gallery_path) as PackedScene).instantiate() as Node3D
	var requested: PackedStringArray = []
	for index: int in range(1, args.size()):
		if args[index] != "archive":
			requested.append(args[index])
	root.add_child(gallery)
	await process_frame
	var failures: int = 0
	var exported: int = 0
	for index: int in range(gallery.catalog.size()):
		var id: String = str(gallery.catalog[index]["id"])
		if not requested.is_empty() and id not in requested:
			continue
		if not gallery.select_model(index):
			failures += 1
			continue
		await process_frame
		var mesh_root := Node3D.new()
		mesh_root.name = "VisualMeshExport"
		for child: Node in gallery.model.find_children("*", "MeshInstance3D", true, false):
			var source: MeshInstance3D = child as MeshInstance3D
			if source.mesh == null or not source.is_visible_in_tree():
				continue
			var copy := MeshInstance3D.new()
			copy.name = str(source.name).validate_node_name()
			copy.mesh = source.mesh
			copy.transform = source.global_transform
			mesh_root.add_child(copy, true)
			copy.owner = mesh_root
			for surface: int in range(source.mesh.get_surface_count()):
				copy.set_surface_override_material(surface, source.get_active_material(surface))
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var status: Error = document.append_from_scene(mesh_root, state)
		if status == OK:
			status = document.write_to_filesystem(state, out.path_join(id + ".glb"))
		if status != OK:
			failures += 1
			printerr(id + " visual export failed: " + str(status))
		else:
			exported += 1
		mesh_root.free()
	if not requested.is_empty() and exported != requested.size():
		failures += 1
		printerr("Missing archive selection: expected %d, exported %d" % [requested.size(), exported])
	gallery.free()
	quit(0 if failures == 0 else 1)
