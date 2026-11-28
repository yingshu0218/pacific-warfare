extends Node3D

const MAP_PATH := "res://data/maps/qj02_geography.json"
const MAP_VIEW := preload("res://scripts/qingjia/geography_view.gd")
const UI_FONT := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
var chart: Dictionary
var map_view: IslandHarborView
var camera: Camera3D
var stage: CloudSeaEnvironment
var overlay: CanvasLayer
var selector: OptionButton
var selected := -1
var yaw := 0.0
var pitch := 0.0
var travel_speed := 430.0
var elapsed := 0.0

func _ready() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	if not source is Dictionary:
		push_error("Cannot load Qingjia geography chart")
		set_process(false)
		return
	chart = TerrainQueries.compile(source)
	stage = CloudSeaEnvironment.new()
	add_child(stage)
	stage.set_terrain(chart)
	map_view = MAP_VIEW.new()
	add_child(map_view)
	map_view.build(chart)
	camera = Camera3D.new()
	camera.name = "LandSeaAirObserver"
	camera.far = 70000.0
	camera.current = true
	add_child(camera)
	_create_hud()
	select_view(0)

func _process(delta: float) -> void:
	elapsed += delta
	stage.advance(elapsed)
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var motion := forward * (float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))) + right * (float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)))
	motion.y = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if motion.length_squared() > 0.0:
		var multiplier := 3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
		var p := camera.position + motion.normalized() * travel_speed * multiplier * delta
		var min_height := TerrainQueries.height_data(chart, p, true) + 3.0
		p.x = clampf(p.x, -26000.0, 26000.0)
		p.z = clampf(p.z, -26000.0, 26000.0)
		p.y = clampf(p.y, min_height, 25500.0)
		camera.position = p
	stage.update_observer(camera.position)

func select_view(index: int) -> void:
	if index < 0 or index >= 7:
		return
	var view: Dictionary = chart.source.viewpoints[index]
	var focus := SimData.vec3(view.focus_m)
	var distance: float = view.distance_m
	yaw = float(view.yaw_rad)
	pitch = -float(view.pitch_rad)
	var offset := Vector3(sin(yaw)*cos(pitch), -sin(pitch), cos(yaw)*cos(pitch))*distance
	var eye := focus + offset
	eye.y = maxf(eye.y, TerrainQueries.height_data(chart,eye,true) + 6.5)
	focus.y = maxf(focus.y, TerrainQueries.height_data(chart,focus,false) + 2.6)
	camera.position = eye
	camera.look_at(focus)
	pitch = camera.rotation.x
	yaw = camera.rotation.y
	camera.near = maxf(.8, distance*.006)
	camera.fov = [42.0,47.0,44.0,47.0,49.0,49.0,45.0][index]
	stage.world_environment.environment.fog_depth_begin = 18000.0 if index == 0 else 5000.0
	stage.world_environment.environment.fog_depth_end = 69000.0 if index == 0 else 45000.0
	travel_speed = clampf(distance*.26, 28.0, 1400.0)
	selected = index
	selector.select(index)

func _create_hud() -> void:
	overlay = CanvasLayer.new()
	add_child(overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(25,24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("122832ee")
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	var theme := Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 17
	panel.theme = theme
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "青岬群岛  /  海陆空地图"
	title.add_theme_font_size_override("font_size", 23)
	rows.add_child(title)
	selector = OptionButton.new()
	for i: int in 7:
		var view: Dictionary = chart.source.viewpoints[i]
		selector.add_item("%02d   %s" % [i+1, view.label])
	selector.item_selected.connect(select_view)
	rows.add_child(selector)
	var help := Label.new()
	help.text = "1–7 跳转   右键拖动视角\nWASD 移动   Q/E 升降   H 隐藏"
	help.modulate = Color("bdcbd2")
	rows.add_child(help)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_H:
			overlay.visible = not overlay.visible
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_7:
			select_view(event.physical_keycode - KEY_1)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		yaw -= event.relative.x*.004
		pitch = clampf(pitch - event.relative.y*.004, -1.53, 1.53)
		camera.rotation = Vector3(pitch, yaw, 0.0)
