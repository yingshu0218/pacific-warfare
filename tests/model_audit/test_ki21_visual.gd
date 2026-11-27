extends SceneTree

const VIEWER: PackedScene = preload("res://aircraft/ki21_iia/ki21_viewer.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewer := VIEWER.instantiate() as Node3D
	root.add_child(viewer)
	var model := viewer.get_node("Ki21IIa") as Node3D
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
	var low_panes: int = 0
	var longitudinal_frames: int = 0
	var blade_sides: Array[int] = [0,0]
	var triangle_total: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if str(part.name).begins_with("Propeller blade"):
			blade_count += 1
			blade_sides[0 if part.position.x < 0.0 else 1] += 1
		if str(part.name).begins_with("Low nose pane") and not str(part.name).ends_with("trim"):
			low_panes += 1
		if "longitudinal" in str(part.name):
			longitudinal_frames += 1
		var points: PackedVector3Array = part.mesh.get_faces()
		valid = valid and points.size() > 0 and part.material_override != null
		for vertex: Vector3 in points:
			var p: Vector3 = part.global_transform * vertex
			valid = valid and p.is_finite()
			mins = mins.min(p)
			maxs = maxs.max(p)
		triangle_total += points.size() / 3
	var span: float = maxs.x - mins.x
	var length: float = maxs.z - mins.z
	var height: float = maxs.y - mins.y
	valid = valid and absf(span - 22.50) < 0.005 and absf(length - 16.02) < 0.005
	valid = valid and absf(maxs.x + mins.x) < 0.005 and height > 4.0 and height < 5.5
	valid = valid and blade_count == 6 and blade_sides == [3,3] and low_panes == 12 and longitudinal_frames > 40 and triangle_total > 12000 and triangle_total < 24000
	for required: String in ["Fuselage", "Wing L", "Wing R", "Round glazed nose", "Stepped cockpit", "Low continuous dorsal greenhouse", "Single fin", "Rolled inlet L", "Rolled inlet R", "Closed wheel fairing L", "Closed wheel fairing R", "Low nose pane L00", "Low nose pane R21"]:
		valid = valid and model.has_node(NodePath(required))
	if camera != null:
		for view: int in [1,2,3]:
			viewer.call("_set_view",view)
			for p: Vector3 in [Vector3(mins.x,0,-2.05),Vector3(maxs.x,0,-2.05),Vector3(0,0,mins.z),Vector3(0,0,maxs.z),Vector3(0,maxs.y,7.0)]:
				valid = valid and not camera.is_position_behind(p)
				valid = valid and root.get_visible_rect().has_point(camera.unproject_position(p))
	print("Ki21IIa airframe: %.3f m span, %.3f m length, %.3f m displayed height, %d blades, %d triangles" % [
		span, length, height, blade_count, triangle_total])
	if not valid:
		printerr("Ki21IIa visual geometry/camera validation failed")
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
			printerr("Ki21IIa visual export error: ", result)
			quit(2)
			return
	quit(0)
