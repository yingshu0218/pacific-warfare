extends Node3D
## The observer uses the same chart for mesh, shore, and elevation/collision queries.
const CHART := "res://data/maps/qj03_archipelago.json"
const VIEW := preload("res://scripts/qingjia/qj03/archipelago_view.gd")
const CLOUD := preload("res://scripts/qingjia/cloud_layer.gd")
const FONT := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
var terrain: Dictionary
var camera: Camera3D
var atmosphere: CloudSeaEnvironment
var cloud_layer: MeshInstance3D
var island_view: Node3D
var overlay: CanvasLayer
var picker: OptionButton
var selection: int = 0
var clock_s: float = 0.0
var speed_mps: float = 265.0

func _ready() -> void:
	var chart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHART))
	terrain = TerrainQueries.compile(chart)
	atmosphere = CloudSeaEnvironment.new()
	add_child(atmosphere)
	atmosphere.set_terrain(terrain)
	var env: Environment = atmosphere.world_environment.environment
	env.ambient_light_color = Color("b7c7d6")
	env.ambient_light_energy = .63
	env.fog_depth_begin = 2000.
	env.fog_depth_end = 45000.
	cloud_layer = CLOUD.new()
	cloud_layer.base_m = 850.
	cloud_layer.top_m = 2050.
	cloud_layer.footprint_scale = .85
	cloud_layer.cloud_reach_m = 18000.
	atmosphere.add_child(cloud_layer)
	island_view = VIEW.new()
	add_child(island_view)
	island_view.build(terrain)
	camera = Camera3D.new()
	camera.far = 67000
	camera.current = true
	add_child(camera)
	_hud()
	show_view(0)

func _hud() -> void:
	overlay = CanvasLayer.new()
	add_child(overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(26,25)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("152a36e9")
	panel_style.set_corner_radius_all(7)
	panel_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel",panel_style)
	overlay.add_child(panel)
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 17
	panel.theme = theme
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation",8)
	panel.add_child(list)
	var label := Label.new()
	label.text = "青岬群岛   /   QJ03"
	label.add_theme_font_size_override("font_size",23)
	list.add_child(label)
	picker = OptionButton.new()
	for row: Dictionary in terrain.source.viewpoints:
		picker.add_item(str(row.label))
	picker.item_selected.connect(show_view)
	list.add_child(picker)
	var hint := Label.new()
	hint.text = "1–9、0 快速切换 / 下拉查看全部\nWASD 移动   Q/E 升降   H 隐藏"
	hint.modulate = Color("c6d0d6")
	list.add_child(hint)

func show_view(index: int) -> void:
	if index < 0 or index >= terrain.source.viewpoints.size():
		return
	var row: Dictionary = terrain.source.viewpoints[index]
	var eye := SimData.vec3(row.eye_m)
	var focus := SimData.vec3(row.focus_m)
	camera.position = eye
	camera.look_at(focus)
	camera.fov = 53.0 if row.id in ["overview","above_clouds"] else 55.0
	camera.near = maxf(.4,minf(18,eye.distance_to(focus)*.004))
	speed_mps = clampf(eye.distance_to(focus)*.23,29,1000)
	atmosphere.update_observer(camera.position)
	selection = index
	picker.select(index)

func _process(delta: float) -> void:
	clock_s += delta
	atmosphere.advance(clock_s)
	cloud_layer.advance(clock_s)
	island_view.advance(clock_s)
	var forward := -camera.basis.z
	forward.y = 0
	forward = forward.normalized()
	var side := camera.basis.x
	side.y = 0
	side = side.normalized()
	var move := forward*(float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S)))
	move += side*(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)))
	move.y = float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
	if move.length_squared() > 0:
		var at := camera.position+move.normalized()*speed_mps*delta
		at.y = maxf(at.y,TerrainQueries.height_data(terrain,at,true)+2.5)
		camera.position = at
	atmosphere.update_observer(camera.position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_H:
			overlay.visible = not overlay.visible
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			show_view(event.physical_keycode-KEY_1)
		elif event.physical_keycode == KEY_0:
			show_view(9)
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		camera.rotation.y -= event.relative.x*.004
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*.004,-1.49,1.49)
