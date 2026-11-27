extends SceneTree
## Export the rendered Godot meshes for an offline visual QA sheet, not for gameplay.
const GALLERY := "res://showcase/us_model_gallery/viewer.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		printerr("Usage: -- <absolute-output-directory>")
		quit(2)
		return
	var out: String = args[0]
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(2)
		return
	var gallery: Node3D = (load(GALLERY) as PackedScene).instantiate() as Node3D
	root.add_child(gallery)
	await process_frame
	var failures: int = 0
	for index: int in range(gallery.catalog.size()):
		var id: String = str(gallery.catalog[index]["id"])
		if not gallery.select_model(index):
			failures += 1
			continue
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
		mesh_root.free()
	gallery.free()
	quit(0 if failures == 0 else 1)
