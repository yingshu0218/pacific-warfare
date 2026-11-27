extends SceneTree

const VIEWER: PackedScene = preload("res://aircraft/b6n2/b6n2_viewer.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewer := VIEWER.instantiate() as Node3D
	root.add_child(viewer)
	var model := viewer.get_node("B6N2") as Node3D
	var camera: Camera3D = root.get_camera_3d()
	var valid: bool = camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	if valid:
		viewer.call("_set_view", 2)
		valid = camera.position.x > 0.0
		viewer.call("_set_view", 3)
		valid = valid and camera.position.y > 0.0 and camera.basis.y.is_equal_approx(Vector3.FORWARD)
	var mins := Vector3(INF, INF, INF)
	var maxs := Vector3(-INF, -INF, -INF)
	var blade_count: int = 0
	var triangle_total: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if str(part.name).begins_with("Propeller blade"):
			blade_count += 1
		var points: PackedVector3Array = part.mesh.get_faces()
		for vertex: Vector3 in points:
			var p: Vector3 = part.global_transform * vertex
			valid = valid and p.is_finite()
			mins = mins.min(p)
			maxs = maxs.max(p)
		triangle_total += points.size() / 3
	var span: float = maxs.x - mins.x
	var length: float = maxs.z - mins.z
	var height: float = maxs.y - mins.y
	valid = valid and absf(span - 14.90) < 0.005 and absf(length - 10.865) < 0.005
	valid = valid and absf(maxs.x + mins.x) < 0.005 and height > 3.5 and height < 4.05
	valid = valid and blade_count == 4 and triangle_total > 0 and triangle_total < 9000
	for required: String in ["Fuselage", "Wing L", "Wing R", "Canopy glazing", "Vertical fin", "Spinner"]:
		valid = valid and model.has_node(NodePath(required))
	print("B6N2 airframe: %.3f m span, %.3f m length, %.3f m displayed height, %d blades, %d triangles" % [
		span, length, height, blade_count, triangle_total])
	if not valid:
		printerr("B6N2 visual geometry/camera validation failed")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var result: Error = doc.append_from_scene(model, state)
		if result == OK:
			result = doc.write_to_filesystem(state, args[0])
		if result != OK:
			printerr("B6N2 visual export error: ", result)
			quit(2)
			return
	quit(0)
