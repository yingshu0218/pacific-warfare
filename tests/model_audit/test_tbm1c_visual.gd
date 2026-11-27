extends SceneTree

const SCENE: PackedScene = preload("res://aircraft/tbm1c/tbm1c_visual.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model := SCENE.instantiate() as Node3D
	root.add_child(model)
	var views: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var valid: bool = views.size() >= 15
	for required: String in ["Fuselage", "Wing L", "Wing R", "Vertical fin", "Canopy glazing", "Rear glazed blister"]:
		valid = valid and model.has_node(NodePath(required))
	var count: int = 0
	var tris: int = 0
	for node: Node in views:
		var mesh_node := node as MeshInstance3D
		var faces: PackedVector3Array = mesh_node.mesh.get_faces()
		var transform: Transform3D = mesh_node.global_transform
		valid = valid and not faces.is_empty()
		for point: Vector3 in faces:
			var p: Vector3 = transform * point
			valid = valid and p.is_finite()
			lo = lo.min(p)
			hi = hi.max(p)
			count += 1
		tris += faces.size() / 3
	var bounds: Vector3 = hi - lo
	valid = valid and absf(bounds.x - 16.51) < 0.025 and absf(bounds.z - 12.50) < 0.035
	valid = valid and absf(hi.x + lo.x) < 0.01 and count > 0 and tris < 9000
	print("TBM1C airframe: %.3f m span, %.3f m length, %.3f m displayed height; %d meshes, %d triangles" % [
		bounds.x, bounds.z, bounds.y, views.size(), tris])
	if not valid:
		printerr("TBM1C geometry validation failed")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error: Error = doc.append_from_scene(model, state)
		if error == OK:
			error = doc.write_to_filesystem(state, args[0])
		if error != OK:
			printerr("GLB export error: ", error)
			quit(2)
			return
	quit(0)
