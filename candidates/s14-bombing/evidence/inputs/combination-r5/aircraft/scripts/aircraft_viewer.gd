extends Node3D

const A6M5_SCENE: PackedScene = preload("res://aircraft/scenes/a6m5_52ko.tscn")
const F6F_SCENE: PackedScene = preload("res://aircraft/scenes/f6f5.tscn")

var camera: Camera3D
var models_root: Node3D
var active_models: Array[PacificAircraftBuilder] = []
var info_label: Label
var mode_label: Label
var control_label: Label
var spin_button: Button
var flap_button: Button
var gear_button: Button
var interface_layer: CanvasLayer

var mode: String = "pair"
var camera_yaw: float = PI - 0.58
var camera_pitch: float = 0.38
var camera_focus: Vector3 = Vector3(0.0, 1.55, 0.0)
var camera_size: float = 16.6
var mouse_action: int = MOUSE_MODE_NONE
var mouse_position: Vector2 = Vector2.ZERO
var propeller_spinning: bool = false
var flaps_down: bool = false
var gear_retracted: bool = false
var controls_deflected: bool = false
var screenshot_path: String = ""
var capture_started: bool = false

const MOUSE_MODE_NONE: int = 0
const MOUSE_MODE_ORBIT: int = 1
const MOUSE_MODE_PAN: int = 2


func _ready() -> void:
	_build_stage()
	_build_camera()
	_build_interface()
	_set_mode("pair")
	_update_camera()
	_parse_capture_argument()


func _process(delta: float) -> void:
	if propeller_spinning:
		for model in active_models:
			if is_instance_valid(model.propeller):
				model.propeller.rotation.z += delta * 24.0
	if not screenshot_path.is_empty() and not capture_started:
		capture_started = true
		_capture_after_delay()


func _capture_after_delay() -> void:
	await get_tree().create_timer(2.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(screenshot_path)
	print("Aircraft viewer capture: %s (%s)" % [screenshot_path, error_string(error)])
	screenshot_path = ""
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			mouse_action = MOUSE_MODE_ORBIT if button_event.pressed else MOUSE_MODE_NONE
			mouse_position = button_event.position
		elif button_event.button_index == MOUSE_BUTTON_RIGHT or button_event.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_action = MOUSE_MODE_PAN if button_event.pressed else MOUSE_MODE_NONE
			mouse_position = button_event.position
		elif button_event.pressed and button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_size = maxf(5.0, camera_size * 0.88)
			_update_camera()
		elif button_event.pressed and button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_size = minf(42.0, camera_size / 0.88)
			_update_camera()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if mouse_action == MOUSE_MODE_ORBIT:
			camera_yaw -= motion.relative.x * 0.006
			camera_pitch = clampf(camera_pitch + motion.relative.y * 0.005, -0.1, 1.34)
			_update_camera()
		elif mouse_action == MOUSE_MODE_PAN:
			var pan_scale: float = camera_size / get_viewport().get_visible_rect().size.y
			camera_focus -= camera.global_basis.x * motion.relative.x * pan_scale
			camera_focus += camera.global_basis.y * motion.relative.y * pan_scale
			_update_camera()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_1:
				_set_mode("a6m5")
			KEY_2:
				_set_mode("f6f")
			KEY_3:
				_set_mode("pair")
			KEY_0:
				_reset_view()
			KEY_SPACE:
				_toggle_propeller()
			KEY_F:
				_toggle_flaps()
			KEY_G:
				_toggle_gear()
			KEY_C:
				_toggle_controls()
			KEY_H:
				interface_layer.visible = not interface_layer.visible
			KEY_ESCAPE:
				mouse_action = MOUSE_MODE_NONE


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("2b343d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aeb9c2")
	environment.ambient_light_energy = 0.54
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	var world := WorldEnvironment.new()
	world.name = "Neutral studio environment"
	world.environment = environment
	add_child(world)

	var key_light := DirectionalLight3D.new()
	key_light.name = "Large soft key"
	key_light.rotation_degrees = Vector3(-46.0, 155.0, 0.0)
	key_light.light_energy = 0.92
	key_light.light_color = Color("fff3dc")
	key_light.shadow_enabled = false
	key_light.directional_shadow_max_distance = 50.0
	add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.name = "Cool fill"
	fill_light.position = Vector3(3.0, 12.0, 8.0)
	fill_light.light_energy = 0.48
	fill_light.omni_range = 48.0
	fill_light.light_color = Color("b3c8e2")
	add_child(fill_light)
	var rim_light := OmniLight3D.new()
	rim_light.name = "Warm rim"
	rim_light.position = Vector3(-10.0, 9.0, -8.0)
	rim_light.light_energy = 0.28
	rim_light.omni_range = 40.0
	rim_light.light_color = Color("ffdfbf")
	add_child(rim_light)

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("333c44")
	ground_material.roughness = 0.84
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(500.0, 500.0)
	var ground := MeshInstance3D.new()
	ground.name = "Neutral grey ground"
	ground.mesh = ground_mesh
	ground.material_override = ground_material
	ground.position.y = -0.065
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	_add_ground_grid()

	models_root = Node3D.new()
	models_root.name = "Aircraft comparison display"
	add_child(models_root)


func _add_ground_grid() -> void:
	var grid_material := StandardMaterial3D.new()
	grid_material.albedo_color = Color("58636b")
	grid_material.roughness = 0.88
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.albedo_color.a = 0.07
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	for index in range(-30, 31):
		var offset: float = float(index)
		surface.add_vertex(Vector3(offset, -0.052, -30.0))
		surface.add_vertex(Vector3(offset, -0.052, 30.0))
		surface.add_vertex(Vector3(-30.0, -0.052, offset))
		surface.add_vertex(Vector3(30.0, -0.052, offset))
	var grid := MeshInstance3D.new()
	grid.name = "One metre floor grid"
	grid.mesh = surface.commit()
	grid.material_override = grid_material
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grid)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Inspection camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 300.0
	camera.current = true
	add_child(camera)


func _build_interface() -> void:
	var font: Font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Color("e8edf0"))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_color", "Button", Color("e8edf0"))
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_stylebox("normal", "Button", _button_style(Color("2e3c49"), Color("6e8190")))
	theme.set_stylebox("hover", "Button", _button_style(Color("43596a"), Color("91a7b5")))
	theme.set_stylebox("pressed", "Button", _button_style(Color("506c7b"), Color("bfd0d8")))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	interface_layer = CanvasLayer.new()
	interface_layer.name = "Aircraft viewer interface"
	interface_layer.layer = 3
	add_child(interface_layer)

	var panel := PanelContainer.new()
	panel.name = "Aircraft information card"
	panel.position = Vector2(20.0, 20.0)
	panel.custom_minimum_size = Vector2(350.0, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("18232ccc"), Color("83919d")))
	panel.theme = theme
	interface_layer.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	content.add_theme_constant_override("margin_left", 18)
	content.add_theme_constant_override("margin_right", 18)
	content.add_theme_constant_override("margin_top", 16)
	content.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(content)

	var kicker := Label.new()
	kicker.text = "PACIFIC AIRCRAFT • 3D INSPECTION"
	kicker.add_theme_font_size_override("font_size", 12)
	kicker.add_theme_color_override("font_color", Color("93a9b8"))
	content.add_child(kicker)
	var title := Label.new()
	title.text = "舰载战斗机 · 1944"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f3f4ec"))
	content.add_child(title)
	var divider := ColorRect.new()
	divider.color = Color("536577")
	divider.custom_minimum_size.y = 1.0
	content.add_child(divider)
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 16)
	mode_label.add_theme_color_override("font_color", Color("e3ecf0"))
	content.add_child(mode_label)
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", Color("bac7ce"))
	content.add_child(info_label)
	var model_buttons := HBoxContainer.new()
	model_buttons.add_theme_constant_override("separation", 7)
	content.add_child(model_buttons)
	var zero_button := _button("A6M5a 五二甲", "a6m5")
	var hellcat_button := _button("F6F-5", "f6f")
	var compare_button := _button("并排对照", "pair")
	model_buttons.add_child(zero_button)
	model_buttons.add_child(hellcat_button)
	model_buttons.add_child(compare_button)

	var views := HBoxContainer.new()
	views.add_theme_constant_override("separation", 7)
	content.add_child(views)
	views.add_child(_action_button("正视", _set_front_view))
	views.add_child(_action_button("侧视", _set_side_view))
	views.add_child(_action_button("俯视", _set_top_view))
	views.add_child(_action_button("复位", _reset_view))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	content.add_child(actions)
	spin_button = _action_button("螺旋桨 · 停", _toggle_propeller)
	flap_button = _action_button("襟翼 · 收", _toggle_flaps)
	gear_button = _action_button("起落架 · 放", _toggle_gear)
	actions.add_child(spin_button)
	actions.add_child(flap_button)
	actions.add_child(gear_button)
	var notes := Label.new()
	notes.text = "左键旋转 · 右键平移 · 滚轮缩放\n空格 螺旋桨 · F 襟翼 · G 起落架 · C 操纵面 · H 隐藏界面"
	notes.add_theme_font_size_override("font_size", 12)
	notes.add_theme_color_override("font_color", Color("90a1ad"))
	content.add_child(notes)
	control_label = notes

	var footer := PanelContainer.new()
	footer.name = "Scale note"
	footer.anchor_left = 1.0
	footer.anchor_right = 1.0
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = -288.0
	footer.offset_right = -20.0
	footer.offset_top = -68.0
	footer.offset_bottom = -20.0
	footer.add_theme_stylebox_override("panel", _panel_style(Color("18232ccc"), Color("536577")))
	footer.theme = theme
	interface_layer.add_child(footer)
	var footer_label := Label.new()
	footer_label.text = "比例尺按真实米制 · 中性展示灯光\n部件分组：机体 / 机翼 / 座舱 / 发动机 / 起落架"
	footer_label.add_theme_font_size_override("font_size", 11)
	footer_label.add_theme_color_override("font_color", Color("a9b7bf"))
	footer.add_child(footer_label)


func _button(text_value: String, target_mode: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 36.0
	button.pressed.connect(func() -> void: _set_mode(target_mode))
	return button


func _action_button(text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 34.0
	button.pressed.connect(action)
	return button


func _panel_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 10
	style.content_margin_left = 0.0
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


func _button_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _set_mode(new_mode: String) -> void:
	if mode == new_mode and not active_models.is_empty():
		return
	mode = new_mode
	for child in models_root.get_children():
		child.queue_free()
	active_models.clear()
	if mode == "pair":
		var zero := A6M5_SCENE.instantiate() as PacificAircraftBuilder
		var hellcat := F6F_SCENE.instantiate() as PacificAircraftBuilder
		models_root.add_child(zero)
		models_root.add_child(hellcat)
		zero.position.x = -6.3
		hellcat.position.x = 6.3
		active_models.append(zero)
		active_models.append(hellcat)
		camera_focus = Vector3(0.0, 1.65, 0.0)
		camera_size = 16.6
		mode_label.text = "A6M5a Model 52 Ko     /     F6F-5"
		info_label.text = "A6M5a 五二甲型：11.000 × 9.121 × 3.509 m\nF6F-5：13.056 × 10.236 × 3.990 m\n真实米制并列；轮距、翼展和外形比例可直接比较。"
	else:
		var scene: PackedScene = A6M5_SCENE if mode == "a6m5" else F6F_SCENE
		var model := scene.instantiate() as PacificAircraftBuilder
		models_root.add_child(model)
		active_models.append(model)
		model.position = Vector3.ZERO
		camera_focus = Vector3(0.0, float(model.spec.get("height_m", 3.8)) * 0.44, 0.0)
		camera_size = 10.0 if mode == "a6m5" else 11.2
		mode_label.text = model.spec.get("name", "")
		info_label.text = "服役配置：%s\n尺寸：翼展 %.3f m · 机长 %.3f m · 机高 %.3f m\n%s\n%s\n%s" % [model.spec.get("service_year", ""), model.spec.get("span_m", 0.0), model.spec.get("length_m", 0.0), model.spec.get("height_m", 0.0), model.spec.get("engine", ""), model.spec.get("armament", ""), model.spec.get("profile_note", "")]
	camera_yaw = PI - 0.58
	camera_pitch = 0.38
	_update_camera()
	_update_action_labels()


func _update_camera() -> void:
	if camera == null:
		return
	var horizontal: float = cos(camera_pitch) * camera_size * 2.4
	var direction := Vector3(sin(camera_yaw) * cos(camera_pitch), sin(camera_pitch), cos(camera_yaw) * cos(camera_pitch))
	camera.position = camera_focus + direction * horizontal
	camera.look_at(camera_focus, Vector3.UP)
	camera.size = camera_size


func _reset_view() -> void:
	camera_yaw = PI - 0.58
	camera_pitch = 0.38
	if mode == "pair":
		camera_focus = Vector3(0.0, 1.65, 0.0)
		camera_size = 16.6
	else:
		camera_focus = Vector3(0.0, 1.65, 0.0)
		camera_size = 10.0 if mode == "a6m5" else 11.2
	_update_camera()


func _set_front_view() -> void:
	camera_yaw = PI
	camera_pitch = 0.0
	_update_camera()


func _set_side_view() -> void:
	camera_yaw = PI * 0.5
	camera_pitch = 0.0
	_update_camera()


func _set_top_view() -> void:
	camera_pitch = 1.50
	_update_camera()


func _toggle_propeller() -> void:
	propeller_spinning = not propeller_spinning
	_update_action_labels()


func _toggle_flaps() -> void:
	flaps_down = not flaps_down
	for model in active_models:
		for child in model.control_surfaces.get_children():
			if String(child.name).contains("flap"):
				var target: float = 0.42 if flaps_down else 0.0
				create_tween().tween_property(child, "rotation:x", target, 0.35)
	_update_action_labels()


func _toggle_gear() -> void:
	gear_retracted = not gear_retracted
	for model in active_models:
		for gear_part in model.landing_gear.get_children():
			var target: float = -1.14 if gear_retracted and String(gear_part.name).begins_with("Main") else (1.15 if gear_retracted else 0.0)
			create_tween().tween_property(gear_part, "rotation:x", target, 0.45)
	_update_action_labels()


func _toggle_controls() -> void:
	controls_deflected = not controls_deflected
	for model in active_models:
		for surface in model.control_surfaces.get_children():
			var name: String = String(surface.name).to_lower()
			var target: float = 0.0
			if controls_deflected:
				if name.contains("aileron"):
					target = -0.16 if name.contains("port") else 0.16
				elif name.contains("elevator"):
					target = 0.12
				elif name.contains("rudder"):
					target = 0.12
			create_tween().tween_property(surface, "rotation:x" if not name.contains("rudder") else "rotation:y", target, 0.3)
	_update_action_labels()


func _update_action_labels() -> void:
	if spin_button != null:
		spin_button.text = "螺旋桨 · 转" if propeller_spinning else "螺旋桨 · 停"
	if flap_button != null:
		flap_button.text = "襟翼 · 放" if flaps_down else "襟翼 · 收"
	if gear_button != null:
		gear_button.text = "起落架 · 收" if gear_retracted else "起落架 · 放"


func _parse_capture_argument() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index in range(args.size()):
		if args[index] == "--model" and index + 1 < args.size():
			if args[index + 1] in ["a6m5", "f6f", "pair"]:
				_set_mode(args[index + 1])
		elif args[index] == "--view" and index + 1 < args.size():
			match args[index + 1]:
				"front":
					_set_front_view()
				"side":
					_set_side_view()
				"top":
					_set_top_view()
		elif args[index] == "--capture" and index + 1 < args.size():
			screenshot_path = args[index + 1]
		elif args[index] == "--hide-ui":
			interface_layer.visible = false
