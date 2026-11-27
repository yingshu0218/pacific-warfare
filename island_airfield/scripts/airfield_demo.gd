extends Node3D

const ENVIRONMENT_SCRIPT = preload("res://scripts/woleai_environment.gd")
const SORTIE_SCRIPT = preload("res://scripts/sortie_controller.gd")
const UI_FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

var sortie: AirfieldSortieController
var camera: Camera3D
var sun: DirectionalLight3D
var world_environment: Environment
var sky_material: ProceduralSkyMaterial
var hud_layer: CanvasLayer
var phase_label: Label
var telemetry_label: Label
var mode_label: Label
var performance_label: Label
var airfield_geometry: Node3D
var _camera_mode: String = "overview"
var _camera_target: Vector3 = Vector3(0.0, 50.0, 0.0)
var _camera_distance: float = 2860.0
var _camera_yaw: float = -0.72
var _camera_pitch: float = 0.56
var _cinematic_light: bool = true
var _show_hud: bool = true
var _show_performance: bool = false
var _orbit_drag: bool = false
var _pan_drag: bool = false
var _last_logged_phase: String = ""


func _ready() -> void:
	_build_environment()
	_build_world()
	_build_camera()
	_build_hud()
	sortie = SORTIE_SCRIPT.new() as AirfieldSortieController
	sortie.name = "A6M5a ground and flight demonstration"
	add_child(sortie)
	sortie.telemetry_updated.connect(_on_telemetry_updated)
	sortie.sortie_completed.connect(_on_sortie_completed)
	_apply_lighting()
	_update_camera(0.0, true)
	_handle_capture_arguments()


func _process(delta: float) -> void:
	_update_camera(delta)
	if _show_performance and performance_label != null:
		var fps: int = Engine.get_frames_per_second()
		var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var objects: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		performance_label.text = "FPS %d   Draw %d   Objects %d" % [fps, draw_calls, objects]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_orbit_drag = mouse.pressed
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			_pan_drag = mouse.pressed
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(24.0, _camera_distance * 0.88)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(7600.0, _camera_distance / 0.88)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _orbit_drag:
			_camera_mode = "free"
			_camera_yaw -= motion.relative.x * 0.0045
			_camera_pitch = clampf(_camera_pitch + motion.relative.y * 0.0038, -0.08, 1.48)
		elif _pan_drag:
			_camera_mode = "free"
			_camera_target -= camera.global_basis.x * motion.relative.x * _camera_distance * 0.0012
			_camera_target += camera.global_basis.y * motion.relative.y * _camera_distance * 0.0012
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_1:
				_set_camera_mode("overview")
			KEY_2:
				_set_camera_mode("runway")
			KEY_3:
				_set_camera_mode("aircraft")
			KEY_4:
				_set_camera_mode("antiaircraft")
			KEY_5:
				_set_camera_mode("machinegun")
			KEY_6:
				_set_camera_mode("comparison")
			KEY_L:
				_cinematic_light = not _cinematic_light
				_apply_lighting()
			KEY_SPACE:
				if sortie != null:
					sortie.toggle_pause()
					_update_mode_label()
			KEY_R:
				if sortie != null:
					sortie.restart()
			KEY_T:
				if sortie != null:
					sortie.cycle_playback_rate()
					_update_telemetry(sortie.phase, sortie.speed_mps, sortie.aircraft.global_position.y, sortie.elapsed_seconds)
			KEY_H:
				_show_hud = not _show_hud
				hud_layer.visible = _show_hud
			KEY_F8:
				_show_performance = not _show_performance
				performance_label.visible = _show_performance


func _build_world() -> void:
	airfield_geometry = Node3D.new()
	airfield_geometry.name = "Woleai 1944 airfield geometry"
	airfield_geometry.set_script(ENVIRONMENT_SCRIPT)
	add_child(airfield_geometry)


func _build_environment() -> void:
	var world_node := WorldEnvironment.new()
	world_node.name = "Tropical Pacific atmosphere"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("aabcb7")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.91
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.08
	env.fog_enabled = true
	env.fog_light_color = Color("92a7aa")
	env.fog_density = 0.000025
	env.fog_sun_scatter = 0.16
	env.fog_aerial_perspective = 0.32
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("345c78")
	sky_material.sky_horizon_color = Color("c6d1c8")
	sky_material.ground_bottom_color = Color("263f43")
	sky_material.ground_horizon_color = Color("aabbb7")
	sky_material.sky_curve = 0.3
	sky_material.ground_curve = 0.25
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	world_environment = env
	world_node.environment = env
	add_child(world_node)

	sun = DirectionalLight3D.new()
	sun.name = "Tropical sun"
	sun.rotation_degrees = Vector3(-34.0, -38.0, 0.0)
	sun.light_energy = 1.15
	# Compatibility renderer shadow cascades at this island scale produced block artifacts
	# over the dense palm MultiMeshes, so use direct tropical light without dynamic shadows.
	sun.shadow_enabled = false
	add_child(sun)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Orbit, runway and aircraft-follow camera"
	camera.fov = 48.0
	camera.near = 0.12
	camera.far = 16000.0
	camera.current = true
	add_child(camera)


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "Airfield and flight HUD"
	add_child(hud_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)

	var info_panel := PanelContainer.new()
	info_panel.position = Vector2(24.0, 22.0)
	info_panel.custom_minimum_size = Vector2(610.0, 226.0)
	info_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.058, 0.061, 0.86)))
	root.add_child(info_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	info_panel.add_child(column)
	var title := _make_label("沃莱艾环礁 · 法拉拉普岛", 25, Color("f0eadb"))
	column.add_child(title)
	column.add_child(_make_label("1944 年机场 · 概略布局  /  海拔约 3.5 m", 15, Color("c7cfbf")))
	column.add_child(_make_label("跑道 1,000 × 100 m 清障带  ·  滑行道 625 m  ·  1:1 米制", 15, Color("c7cfbf")))
	var divider := HSeparator.new()
	column.add_child(divider)
	phase_label = _make_label("阶段：停机准备", 20, Color("e4c592"))
	column.add_child(phase_label)
	telemetry_label = _make_label("A6M5a 五二甲型  ·  准备滑行", 15, Color("e3e2d8"))
	column.add_child(telemetry_label)
	mode_label = _make_label("镜头：全岛俯视  ·  光照：电影感  ·  播放：3×", 14, Color("bdc8bf"))
	column.add_child(mode_label)

	var controls_panel := PanelContainer.new()
	controls_panel.position = Vector2(24.0, 842.0)
	controls_panel.custom_minimum_size = Vector2(1140.0, 74.0)
	controls_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.058, 0.061, 0.78)))
	root.add_child(controls_panel)
	var controls := _make_label("左键拖动 环绕   ·   滚轮 缩放   ·   右键拖动 平移     1 全岛   2 跑道   3 飞机跟随   4 高射炮特写   5 重机枪特写   6 尺寸对照     Space 暂停   R 重飞   T 播放速度   L 光照   H 隐藏界面   F8 性能", 15, Color("e3e2d8"))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_panel.add_child(controls)

	performance_label = _make_label("", 15, Color("f0eadb"))
	performance_label.position = Vector2(1260.0, 28.0)
	performance_label.visible = false
	root.add_child(performance_label)

	var attribution := _make_label("模型：程序几何 / 装备与场景依据见 island_airfield/docs", 13, Color(0.88, 0.89, 0.81, 0.76))
	attribution.position = Vector2(1250.0, 946.0)
	attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(attribution)


func _make_label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _panel_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.81, 0.78, 0.66, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 12.0
	return style


func _set_camera_mode(mode: String) -> void:
	_camera_mode = mode
	match mode:
		"overview":
			_camera_target = Vector3(0.0, 50.0, 0.0)
			_camera_distance = 2860.0
			_camera_yaw = -0.72
			_camera_pitch = 0.56
		"runway":
			_camera_target = Vector3(-25.0, 25.0, 0.0)
			_camera_distance = 650.0
			_camera_yaw = -0.72
			_camera_pitch = 0.54
		"aircraft":
			_camera_distance = 190.0
			_camera_yaw = -0.72
			_camera_pitch = 0.3
		"antiaircraft":
			var gun_y: float = float(airfield_geometry.call("_terrain_height", -485.0, -690.0))
			_camera_target = Vector3(-485.0, gun_y + 3.2, -690.0)
			_camera_distance = 9.8
			_camera_yaw = 1.55
			_camera_pitch = 0.24
		"machinegun":
			var hmg_y: float = float(airfield_geometry.call("_terrain_height", -552.0, 325.0))
			_camera_target = Vector3(-552.0, hmg_y + 1.42, 325.0)
			_camera_distance = 4.4
			_camera_yaw = -2.03
			_camera_pitch = 0.19
		"comparison":
			var comparison_y: float = float(airfield_geometry.call("_terrain_height", 0.0, 1350.0))
			_camera_target = Vector3(0.0, comparison_y + 2.0, 1350.0)
			_camera_distance = 11.8
			_camera_yaw = -2.45
			_camera_pitch = 0.28
	_update_mode_label()
	_update_camera(0.0, true)


func _update_camera(delta: float, snap: bool = false) -> void:
	if camera == null:
		return
	if _camera_mode == "aircraft" and sortie != null and sortie.aircraft != null:
		var aircraft_target: Vector3 = sortie.aircraft.global_position + Vector3.UP * 4.0
		var backward: Vector3 = sortie.aircraft.global_basis.z.normalized()
		var desired_position: Vector3 = aircraft_target + backward * _camera_distance * cos(_camera_pitch) + Vector3.UP * _camera_distance * sin(_camera_pitch)
		if snap or delta <= 0.0:
			camera.global_position = desired_position
		else:
			var ease: float = 1.0 - exp(-delta * 4.0)
			camera.global_position = camera.global_position.lerp(desired_position, ease)
		camera.look_at(aircraft_target + sortie.aircraft.global_basis.z * -28.0, Vector3.UP)
		camera.near = 0.12
		return

	var direction := Vector3(sin(_camera_yaw) * cos(_camera_pitch), sin(_camera_pitch), cos(_camera_yaw) * cos(_camera_pitch))
	var desired := _camera_target + direction * _camera_distance
	camera.global_position = desired
	camera.look_at(_camera_target, Vector3.UP)
	# Compatibility depth is sensitive to a 12 cm near plane at island scale.
	# Keep it for close views and zoom/pan near the ground; recover depth
	# precision only when the overview/runway camera has vertical clearance.
	camera.near = 0.12
	if _camera_mode == "overview" or _camera_mode == "runway":
		camera.near = clampf(minf(_camera_distance * 0.025, (desired.y - 60.0) * 0.25), 0.12, 40.0)


func _on_telemetry_updated(phase_name: String, speed: float, altitude: float, elapsed: float) -> void:
	_update_telemetry(phase_name, speed, altitude, elapsed)
	_update_mode_label()
	if "--auto-verify" in OS.get_cmdline_user_args() and phase_name != _last_logged_phase:
		_last_logged_phase = phase_name
		print("SORTIE_PHASE | %s | %.1f m/s | altitude %.1f m | sim %.1f s" % [phase_name, speed, altitude, elapsed])


func _update_telemetry(phase_name: String, speed: float, altitude: float, elapsed: float) -> void:
	if phase_label == null or telemetry_label == null:
		return
	phase_label.text = "飞行阶段：%s" % phase_name
	var speed_kmh: float = speed * 3.6
	telemetry_label.text = "三菱 A6M5a 五二甲型  ·  %.1f m/s  /  %.0f km/h  ·  海拔 %.0f m  ·  演示计时 %.0f s" % [speed, speed_kmh, altitude, elapsed]


func _on_sortie_completed() -> void:
	_update_mode_label()
	if "--auto-verify" in OS.get_cmdline_user_args():
		var report := FileAccess.open("res://docs/flight-cycle-verification.txt", FileAccess.WRITE)
		if report != null:
			report.store_line("Godot 4.7.2 Compatibility renderer; M5 16 GB.")
			report.store_line("Full A6M5a route completed from parking through taxi-out, takeoff, airborne circuit, approach, landing roll and return taxi.")
			report.store_line("Automation playback: 10x for this verification run; route geometry remains 1:1 metres.")
		print("SORTIE_COMPLETE | %.1f simulated seconds | FPS %d | draws %d | objects %d" % [sortie.elapsed_seconds, Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
		get_tree().quit()


func _update_mode_label() -> void:
	if mode_label == null:
		return
	var mode_text: String = "全岛俯视"
	if _camera_mode == "runway":
		mode_text = "跑道检查"
	elif _camera_mode == "aircraft":
		mode_text = "飞机跟随"
	elif _camera_mode == "antiaircraft":
		mode_text = "九六式双联高射炮"
	elif _camera_mode == "machinegun":
		mode_text = "九二式重机枪"
	elif _camera_mode == "comparison":
		mode_text = "左九六式双联炮 · 右九二式重机枪"
	elif _camera_mode == "free":
		mode_text = "自由环绕"
	var light_text: String = "电影感" if _cinematic_light else "中性"
	var pause_text: String = " · 已暂停" if sortie != null and sortie.paused else ""
	var rate_text: String = "%.0f×" % sortie.playback_rate if sortie != null else "1×"
	mode_label.text = "镜头：%s  ·  光照：%s  ·  播放：%s%s" % [mode_text, light_text, rate_text, pause_text]


func _apply_lighting() -> void:
	if sun == null or world_environment == null or sky_material == null:
		return
	if _cinematic_light:
		sun.rotation_degrees = Vector3(-22.0, -42.0, 0.0)
		sun.light_color = Color("ffe0b5")
		sun.light_energy = 1.48
		world_environment.ambient_light_color = Color("9aa9ad")
		world_environment.ambient_light_energy = 0.58
		world_environment.fog_light_color = Color("a5aba4")
		sky_material.sky_top_color = Color("294a64")
		sky_material.sky_horizon_color = Color("d0b89b")
		sky_material.ground_horizon_color = Color("b8a990")
	else:
		sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
		sun.light_color = Color.WHITE
		sun.light_energy = 1.25
		world_environment.ambient_light_color = Color("aec0c1")
		world_environment.ambient_light_energy = 0.78
		world_environment.fog_light_color = Color("9cb4bd")
		sky_material.sky_top_color = Color("456e8a")
		sky_material.sky_horizon_color = Color("d2ddd9")
		sky_material.ground_horizon_color = Color("bdc9c0")
	_update_mode_label()


func _handle_capture_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--fast-demo" in args:
		sortie.playback_rate = 10.0
	if "--capture-airborne" in args:
		sortie.seek_to_airborne_capture()
		_set_camera_mode("aircraft")
	elif "--capture-takeoff" in args:
		sortie.seek_to_takeoff_capture()
		_set_camera_mode("aircraft")
	elif "--capture-runway" in args:
		_set_camera_mode("runway")
	elif "--capture-follow" in args:
		_set_camera_mode("aircraft")
	elif "--capture-machinegun" in args:
		_set_camera_mode("machinegun")
	elif "--capture-comparison" in args:
		_set_camera_mode("comparison")
	if "--neutral" in args:
		_cinematic_light = false
		_apply_lighting()
	if "--performance" in args:
		_show_performance = true
		performance_label.visible = true
	if "--capture" in args or "--capture-airborne" in args or "--capture-takeoff" in args or "--capture-runway" in args or "--capture-follow" in args or "--capture-machinegun" in args or "--capture-comparison" in args:
		await get_tree().create_timer(2.2).timeout
		await RenderingServer.frame_post_draw
		var capture_name: String = "overview"
		if "--capture-airborne" in args:
			capture_name = "airborne_follow"
		elif "--capture-takeoff" in args:
			capture_name = "takeoff_follow"
		elif "--capture-runway" in args:
			capture_name = "runway"
		elif "--capture-follow" in args:
			capture_name = "aircraft_follow"
		elif "--capture-machinegun" in args:
			capture_name = "type92_hmg_closeup"
		elif "--capture-comparison" in args:
			capture_name = "type92_vs_type96_scale"
		if "--neutral" in args:
			capture_name += "_neutral"
		if "--performance" in args:
			capture_name += "_performance"
		get_viewport().get_texture().get_image().save_png("res://screenshots/%s.png" % capture_name)
		get_tree().quit()

