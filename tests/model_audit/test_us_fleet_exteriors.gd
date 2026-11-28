extends SceneTree

const CATALOG := "res://data/visual_catalogs/all_exteriors.json"
const IDS: Array[String] = [
	"yorktown", "lexington", "wasp", "north_carolina", "west_virginia",
	"san_francisco", "honolulu", "sims", "sumner",
]

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var audited: Array[String] = []
	var seen_scenes: Dictionary = {}
	for item: Dictionary in entries:
		var id: String = str(item.get("id", ""))
		if not id.begins_with("usfleet_"):
			continue
		_check(id.trim_prefix("usfleet_") in IDS and not id in audited, "Unexpected or duplicate ID: " + id)
		_check(item.get("kind") == "ship", "Wrong catalog category: " + id)
		_check(not seen_scenes.has(item.scene), "Duplicate model scene: " + id)
		audited.append(id)
		seen_scenes[item.scene] = true
		await _audit_ship(item)
	_check(audited.size() == IDS.size(), "Not all nine exteriors were tested")
	print("US_FLEET_EXTERIORS tested=", audited.size(), " failures=", failures)
	quit(0 if failures == 0 else 1)

func _audit_ship(item: Dictionary) -> void:
	var id: String = item.id
	var scene := load(str(item.scene)) as PackedScene
	if scene == null:
		_check(false, "Missing scene: " + id)
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		_check(false, "Model does not instantiate as Node3D: " + id)
		return
	root.add_child(model)
	await process_frame
	var bounds := AABB()
	var n: int = 0
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null or not part.is_visible_in_tree():
			continue
		var box: AABB = part.global_transform * part.get_aabb()
		bounds = box if n == 0 else bounds.merge(box)
		n += 1
	var expected_length_m: float = float(item.get("expected_length_m", 0.0))
	_check(expected_length_m > 0 and absf(bounds.size.z - expected_length_m) <= expected_length_m*.045,
		"%s incorrect fore/aft envelope %s (target %s m)" % [id, bounds.size, expected_length_m])
	_check(n >= 15 and bounds.size.x > 5 and bounds.size.y > 5, "Incomplete geometry: " + id)
	for type_name: String in ["PhysicsBody3D", "CollisionObject3D", "NavigationAgent3D"]:
		_check(model.find_children("*", type_name, true, false).is_empty(), "Nonvisual gameplay node in " + id)
	print("US_FLEET_MODEL ", id, " ", bounds.size, " meshes=", n)
	model.free()

func _check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
