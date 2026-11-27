extends Node3D
## Read-only inspection of the newly added standalone exterior models.
const CATALOG := "res://data/visual_catalogs/us_expansion.json"
const ORIGINAL_FINISH: StringName = &"pacific_archive_compare_original"

@export_file("*.json") var catalog_path: String = CATALOG
@export var full_archive: bool = false
const VIEWS: Array[Vector3] = [
	Vector3(1.02, 0.61, -1.25), Vector3(-1.03, 0.58, 0.97),
	Vector3(0.0, 1.9, -0.014), Vector3(1.25, 0.08, -0.03)
]
const VIEW_LABELS: Array[String] = ["艏／机头斜视", "艉／机尾斜视", "俯视", "侧视"]

@onready var camera: Camera3D = $Camera
@onready var water: MeshInstance3D = $Water
@onready var caption: Label = $UI/Caption
var catalog: Array = []
var model: Node3D
var selected: int = -1
var view: int = 0
var bounds: AABB
var visual_triangles: int = 0
var picker: OptionButton
var show_original: bool = false

func _ready() -> void:
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if not entries is Array or entries.is_empty():
		push_error("Missing US visual model catalog")
		return
	catalog = entries
	if full_archive:
		picker = OptionButton.new()
		picker.position = Vector2(22, 82)
		picker.custom_minimum_size = Vector2(270, 36)
		$UI.add_child(picker)
		for entry: Dictionary in catalog:
			picker.add_item(str(entry["label"]))
		picker.get_popup().max_size = Vector2i(0, 560)
		picker.item_selected.connect(select_model)
	select_model(0)
	get_viewport().size_changed.connect(frame_model)

func select_model(index: int) -> bool:
	if index < 0 or index >= catalog.size():
		return false
	var entry: Dictionary = catalog[index]
	var resource: PackedScene = load(str(entry["scene"])) as PackedScene
	if resource == null or not resource.can_instantiate():
		push_error("Could not load gallery scene: " + str(entry["scene"]))
		return false
	var next_model: Node3D = resource.instantiate() as Node3D
	if next_model == null:
		return false
	if is_instance_valid(model):
		model.free()
	model = next_model
	if show_original:
		model.set_meta(ORIGINAL_FINISH, true)
	add_child(model)
	if picker != null:
		picker.select(index)
	selected = index
	bounds = AABB()
	visual_triangles = 0
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var visual: MeshInstance3D = child as MeshInstance3D
		if visual.mesh == null or not visual.is_visible_in_tree():
			continue
		var faces: PackedVector3Array = visual.mesh.get_faces()
		if faces.is_empty():
			continue
		# Use real transformed vertices, not the inflated bounds of rotated boxes.
		for point: Vector3 in faces:
			var world_point: Vector3 = visual.global_transform * point
			bounds = AABB(world_point, Vector3.ZERO) if visual_triangles == 0 else bounds.expand(world_point)
			visual_triangles += 1
	visual_triangles = int(float(visual_triangles) / 3.0)
	water.visible = str(entry["kind"]) == "ship"
	frame_model()
	return visual_triangles > 0

func frame_model() -> void:
	if selected < 0 or visual_triangles == 0:
		return
	var entry: Dictionary = catalog[selected]
	var focus: Vector3 = bounds.get_center()
	var direction: Vector3 = VIEWS[view]
	if float(entry.get("nose_z_sign", -1.0)) > 0.0:
		direction.z *= -1.0
	var size: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	camera.position = focus + direction * size * 1.7
	camera.look_at(focus, Vector3.UP)
	if view == 2 and water.visible:
		camera.rotate_object_local(Vector3.BACK, PI * 0.5)
	var min_screen := Vector2(INF, INF)
	var max_screen := Vector2(-INF, -INF)
	for corner: int in range(8):
		var offset: Vector3 = camera.global_transform.basis.inverse() * (bounds.get_endpoint(corner) - focus)
		var screen := Vector2(offset.x, offset.y)
		min_screen = min_screen.min(screen)
		max_screen = max_screen.max(screen)
	var extent: Vector2 = max_screen - min_screen
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = screen_size.x / maxf(screen_size.y, 1.0)
	camera.size = maxf(extent.y / 0.72, extent.x / (0.9 * aspect))
	caption.text = "%s  |  %s  |  %s" % [entry["label"], entry["date"], VIEW_LABELS[view]]
	if full_archive:
		caption.text += "\n%s  ·  C 原版/统一   V 视角   PageUp/PageDown 上一款/下一款" % (
			"原版材质" if show_original else "统一材质"
		)
	else:
		caption.text += "\n1–8 选择模型  /  V 切换视角  ·  静态外观"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_8:
		select_model(event.keycode - KEY_1)
	elif full_archive and event.keycode == KEY_C:
		show_original = not show_original
		select_model(selected)
	elif full_archive and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var offset: int = -1 if event.keycode == KEY_PAGEUP else 1
		select_model(posmod(selected + offset, catalog.size()))
	elif event.keycode == KEY_V:
		view = (view + 1) % VIEWS.size()
		frame_model()
