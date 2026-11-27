extends SceneTree
## Verify the gallery with the same entry point and model switches a player uses.
const GALLERY := "res://showcase/us_model_gallery/viewer.tscn"
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load(GALLERY) as PackedScene
	var gallery: Node3D = scene.instantiate() as Node3D
	root.add_child(gallery)
	await process_frame
	_check(gallery.catalog.size() == 8, "expected 6 ships and 2 aircraft")
	var ids: Dictionary = {}
	var counts := {"ship": 0, "aircraft": 0}
	for index: int in range(gallery.catalog.size()):
		var entry: Dictionary = gallery.catalog[index]
		var label: String = str(entry.get("label", index))
		var id: String = str(entry.get("id", ""))
		_check(not id.is_empty() and not ids.has(id), label + " missing or duplicate identity")
		ids[id] = true
		if counts.has(entry["kind"]):
			counts[entry["kind"]] += 1
		else:
			_check(false, label + " invalid kind")
		var selection_event := InputEventKey.new()
		selection_event.pressed = true
		selection_event.keycode = (KEY_1 + index) as Key
		gallery._unhandled_key_input(selection_event)
		if not _check(gallery.selected == index and gallery.visual_triangles > 600, label + " did not switch to the expected nontrivial model"):
			continue
		var model: Node3D = gallery.model
		_check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), label + " must stay visual-only")
		_check(gallery.water.visible == (entry["kind"] == "ship"), label + " wrong environment")
		var bounds: AABB = gallery.bounds
		_check(bounds.position.is_finite() and bounds.size.is_finite(), label + " nonfinite bounds")
		if entry.has("expected_length_m"):
			var expected: float = float(entry["expected_length_m"])
			_check(absf(bounds.size.z - expected) <= expected * 0.055, label + " longitudinal scope")
		if entry.has("expected_width_m") and entry["kind"] == "aircraft":
			var expected: float = float(entry["expected_width_m"])
			_check(absf(bounds.size.x - expected) <= expected * 0.045, label + " wingspan scope")
		var views_seen := {}
		for pass_index: int in range(4):
			var view_event := InputEventKey.new()
			view_event.pressed = true
			view_event.keycode = KEY_V
			gallery._unhandled_key_input(view_event)
			views_seen[gallery.view] = true
			_check(gallery.camera.position.is_finite() and is_finite(gallery.camera.size) and gallery.camera.size > 0.0, label + " camera frame")
			_check(gallery.caption.text.contains(label), label + " missing caption")
			for corner: int in range(8):
				var pixel: Vector2 = gallery.camera.unproject_position(bounds.get_endpoint(corner))
				_check(root.get_visible_rect().grow(1.5).has_point(pixel), label + " outside frame")
		_check(views_seen.size() == 4, label + " repeated views")
		print("US_GALLERY ", id, " bounds=", bounds.size, " triangles=", gallery.visual_triangles)
	_check(counts["ship"] == 6 and counts["aircraft"] == 2, "wrong exhibit totals")
	_check(not gallery.select_model(-1) and not gallery.select_model(8), "invalid catalog index accepted")
	print("US_GALLERY_RESULT failures=", failures)
	gallery.free()
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures += 1
		push_error(label)
	return condition
