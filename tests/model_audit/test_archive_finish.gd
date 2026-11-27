extends SceneTree
const FINISH = preload("res://scripts/presentation/models/archive_finish.gd")
const CATALOG := "res://data/visual_catalogs/all_exteriors.json"

var errors: int = 0
var counts := {"ship": 0, "aircraft": 0}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var seen: Dictionary = {}
	for item: Dictionary in items:
		var kind: String = str(item.kind)
		_check(counts.has(kind), "Unknown category " + kind)
		counts[kind] += 1
		_check(not seen.has(item.id), "Duplicate model " + str(item.id))
		seen[item.id] = true
		await _audit(item)
	_check(counts.ship == 24 and counts.aircraft == 13, "Expected all 37 models")
	print("ARCHIVE_FINISH_RESULT ", counts, " failures=", errors)
	quit(0 if errors == 0 else 1)

func _audit(item: Dictionary) -> void:
	var scene: PackedScene = load(str(item.scene)) as PackedScene
	if scene == null:
		_check(false, "No model scene: " + str(item.scene))
		return
	var model: Node3D = scene.instantiate() as Node3D
	root.add_child(model)
	# Model builders run _ready immediately. The scene hook runs after builders and batching.
	var comparisons: Array[Dictionary] = []
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for surface: int in range(mesh_node.mesh.get_surface_count()):
			var material: Material = mesh_node.get_active_material(surface)
			comparisons.append({
				"part": mesh_node, "mesh": mesh_node.mesh, "surface": surface, "material": material,
				"albedo": material.albedo_color if material is StandardMaterial3D else Color.WHITE,
				"texture": material.albedo_texture if material is StandardMaterial3D else null,
				"roughness": material.roughness if material is StandardMaterial3D else -1.0,
			})
	await process_frame
	var styled: int = 0
	var preserved: int = 0
	for row: Dictionary in comparisons:
		var part: MeshInstance3D = row.part
		if not is_instance_valid(part):
			_check(false, str(item.id) + " lost mesh node")
			continue
		_check(part.mesh == row.mesh, str(item.id) + " mesh changed")
		var source: Material = row.material
		var result: Material = part.get_active_material(int(row.surface))
		if not FINISH.can_style(source, str(part.name)):
			_check(source == result, str(item.id) + " special material changed")
			preserved += 1
			continue
		_check(result != source and result.has_meta(FINISH.STYLED_META), str(item.id) + " paint not normalized")
		if result is StandardMaterial3D:
			_check(result.albedo_color == row.albedo and result.albedo_texture == row.texture, str(item.id) + " original livery changed")
			_check(source.roughness == row.roughness, str(item.id) + " modified shared source material")
		styled += 1
	_check(styled > 0, str(item.id) + " no paint surfaces styled")
	_check(FINISH.apply(model, str(item.kind)) == 0, str(item.id) + " non-idempotent archive finish")
	print("ARCHIVE ", item.id, " styled=", styled, " special=", preserved)
	model.free()

func _check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)
