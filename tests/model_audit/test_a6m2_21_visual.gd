extends SceneTree

const STUDY := preload("res://aircraft/a6m2_21/viewer.tscn")
const BASELINE := preload("res://aircraft/scenes/a6m5_52ko.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, note: String) -> void:
	if not ok:
		failures.append(note)


func _run() -> void:
	var viewer := STUDY.instantiate() as Node3D
	root.add_child(viewer)
	var model := viewer.get_node("A6M2") as Node3D
	var camera := root.get_camera_3d()
	_check(camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "camera projection")
	viewer.call("_set_view", 2)
	_check(camera.position.x > 10, "side camera")
	viewer.call("_set_view", 3)
	_check(camera.position.y > 10, "plan camera")
	var low := Vector3(INF, INF, INF)
	var high := -low
	var tris := 0
	var decals := 0
	for entry in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := entry as MeshInstance3D
		if mesh_node.material_override == model.get("materials")["insignia_red"]:
			decals += 1
		if not mesh_node.visible:
			continue
		var points := mesh_node.mesh.get_faces()
		_check(not points.is_empty(), "empty mesh " + str(mesh_node.name))
		for vertex in points:
			var p := mesh_node.global_transform * vertex
			_check(p.is_finite(), "non-finite vertex")
			low = low.min(p)
			high = high.max(p)
		tris += int(float(points.size()) / 3.0)
	var dims := high - low
	_check(absf(dims.x - 12.0) < .004 and absf(high.x + low.x) < .004, "symmetric 12 m span")
	_check(absf(dims.z - 9.06) < .024 and absf(dims.y - 3.51) < .025, "length/height envelope")
	_check(decals == 6, "six red roundels")
	_check(model.get_node("Propeller").get_child_count() == 5, "spinner, shaft and three blades")
	_check(tris > 10000 and tris < 100000, "triangle budget")
	_check(not (model.get_node("PreviewEffect/PreviewFlash") as Node3D).visible, "flash off when loaded")
	viewer.call("_unhandled_key_input", _fire_key())
	_check((model.get_node("PreviewEffect/PreviewFlash") as Node3D).visible, "F input triggers preview")
	await create_timer(.18).timeout
	_check(not (model.get_node("PreviewEffect/PreviewFlash") as Node3D).visible, "flash clears")
	viewer.call("preview_fire")
	_check((model.get_node("PreviewEffect/PreviewFlash") as Node3D).visible, "preview is repeatable")
	await create_timer(.18).timeout
	_check(not (model.get_node("PreviewEffect/PreviewFlash") as Node3D).visible, "repeated flash clears")
	print("A6M2: span %.3f, height %.3f, length %.3f m; %d triangles; %d decals; %d failures" % [dims.x, dims.y, dims.z, tris, decals, failures.size()])
	if not failures.is_empty():
		printerr(failures)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() == 2:
		var late := BASELINE.instantiate() as Node3D
		root.add_child(late)
		var effect := model.get_node("PreviewEffect")
		model.remove_child(effect)
		effect.queue_free()
		if _export(model, args[0]) != OK or _export(late, args[1]) != OK:
			quit(2)
			return
	quit()


func _fire_key() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	return key


func _export(model: Node3D, dest: String) -> Error:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var status := doc.append_from_scene(model, state)
	if status == OK:
		status = doc.write_to_filesystem(state, dest)
	if status != OK:
		printerr("GLB export failed: ", error_string(status))
	return status
