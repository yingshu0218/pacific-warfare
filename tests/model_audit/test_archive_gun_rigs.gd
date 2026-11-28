extends SceneTree
const GALLERY := preload("res://showcase/archive_gallery/viewer.tscn")
const EMPTY: Array[String] = ["enterprise","independence","casablanca","akagi","zuiho","taiyo",
	"saratoga","hornet","usfleet_yorktown","usfleet_lexington","usfleet_wasp"]
var errors: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var gallery := GALLERY.instantiate()
	root.add_child(gallery)
	var ready_ships := 0
	var archive_guns := 0
	for index: int in range(gallery.catalog.size()):
		var entry: Dictionary = gallery.catalog[index]
		if entry.kind != "ship":
			continue
		_check(gallery.select_model(index), str(entry.id) + " renders in the gallery")
		var panel: PanelContainer = gallery.gun_controls
		var rows: Array[Dictionary] = panel.rows
		_check(rows.is_empty() == (str(entry.id) in EMPTY), str(entry.id) + " correct gun availability")
		if rows.is_empty():
			continue
		ready_ships += 1
		var ids := {}
		for row: Dictionary in rows:
			_check(not ids.has(row.id) and float(row.reach) > 0.0, str(entry.id) + " independent named profile")
			ids[row.id] = true
			if row.rig == null:
				continue
			archive_guns += 1
			var rig: Node3D = row.rig
			_check(rig.pitch.get_child_count() > 0, str(entry.id) + " no empty rig")
			var original: Transform3D = rig.train.transform
			var barrel := rig.pitch.get_child(0) as Node3D
			var barrel_before: Transform3D = barrel.global_transform
			var peers: Array = rig.get_parent().get_children()
			var other := (peers[1] if peers[0] == rig else peers[0]) as Node3D
			var other_before: Transform3D = other.train.global_transform
			_check(rig.pose(.18,.28) and not rig.train.transform.is_equal_approx(original), "Traverse moves the selected mount")
			_check(not barrel.global_transform.is_equal_approx(barrel_before) and other.train.global_transform.is_equal_approx(other_before), "Pitch moves its barrel without moving neighbors")
			rig.pose(100,100)
			_check(is_equal_approx(rig.pitch.rotation.x,rig.pitch_max_rad), "Excessive pitch is clamped to this station's limit")
			_check(not rig.pose(NAN,0), "Non-finite input is rejected")
			rig.pose(0,0)
			_check(barrel.global_transform.is_equal_approx(barrel_before) and rig.train.transform.is_equal_approx(original), "Neutral geometry is unchanged")
		panel.yaw.value = 7
		panel.pitch.value = 12
		var first_pose: Vector2 = rows[0].pose
		panel._select(1)
		_check(rows[1].pose == Vector2.ZERO and first_pose.length() > .001, "Gallery edit changes one selection")
		panel._select(0)
		_check((rows[0].pose as Vector2).is_equal_approx(first_pose) and is_equal_approx(deg_to_rad(panel.pitch.value),first_pose.y), "Gallery recalls the previous station pose")
	_check(ready_ships == 27 and archive_guns == 183, "All existing gun-bearing models are represented")
	print("ARCHIVE_GUN_RIG checks=",checks," failures=",errors," ships=",ready_ships," newly_rigged_stations=",archive_guns)
	gallery.free()
	await process_frame
	quit(0 if errors == 0 else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		push_error(message)
