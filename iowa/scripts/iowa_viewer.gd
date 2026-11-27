extends Node3D

const WATER_SHADER: Shader = preload("../shaders/iowa_water.gdshader")
const SHIP_SCENE: PackedScene = preload("../scenes/iowa_bb61.tscn")

var ship: IowaShip
var ship_simulation: IowaSimulation
var camera: Camera3D
var hud_label: Label
var status_label: Label
var orbit_target: Vector3 = Vector3(0.0, 13.0, 0.0)
var orbit_yaw: float = -0.62
var orbit_pitch: float = 0.28
var orbit_distance: float = 315.0
var drag_button: MouseButton = MOUSE_BUTTON_NONE
var selected_mount_index: int = 0
var selected_mount: IowaWeaponMount
var selected_gun_index: int = 0
var hud_visible: bool = true
var hide_hud_on_capture: bool = false
var view_name: String = "overview"
var capture_path: String = ""
var refresh_timer: float = 0.0
var mount_summary: String = ""
var mount_total: int = 0

func _ready() -> void:
	_build_environment()
	_build_water()
	ship = SHIP_SCENE.instantiate() as IowaShip
	ship.name = "USS_Iowa_BB61_1944_12_28"
	add_child(ship)
	ship_simulation = ship.simulation
	var counts: Dictionary = ship.get_weapon_counts()
	mount_summary = "%d × 16-inch turrets   ·   %d × twin 5-inch mounts\n%d × quad 40 mm   ·   %d × single 20 mm" % [
		counts["main_16in"], counts["secondary_5in"], counts["bofors_40mm"], counts["oerlikon_20mm"]
	]
	mount_total = ship.get_weapon_mounts().size()
	_build_camera()
	_build_hud()
	_parse_user_arguments()
	if not capture_path.is_empty() and is_instance_valid(ship_simulation):
		ship_simulation.set_paused(true)
	if hide_hud_on_capture:
		hud_visible = false
		get_node("InspectionHUD/InfoPanel").visible = false
		status_label.visible = false
	_select_mount(0)
	_update_camera()
	_update_hud()
	if not capture_path.is_empty():
		call_deferred("_capture_after_frame", capture_path)

func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "NeutralInspectionEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("17252d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c1c7c9")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "NeutralKeyLight"
	sun.rotation_degrees = Vector3(-46.0, -28.0, 0.0)
	sun.light_color = Color("fff4df")
	sun.light_energy = 0.82
	add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "CoolFillLight"
	fill.rotation_degrees = Vector3(-22.0, 130.0, 0.0)
	fill.light_color = Color("cbd9e2")
	fill.light_energy = 0.22
	add_child(fill)

func _build_water() -> void:
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "SeaSurface"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(1200.0, 1200.0)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	water.mesh = plane
	var water_material: ShaderMaterial = ShaderMaterial.new()
	water_material.shader = WATER_SHADER
	water.material_override = water_material
	water.position.y = -0.72
	add_child(water)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FreeInspectionCamera"
	camera.current = true
	camera.fov = 42.0
	camera.near = 0.1
	camera.far = 1800.0
	add_child(camera)

func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "InspectionHUD"
	add_child(canvas)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "InfoPanel"
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(500.0, 280.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.09, 0.91)
	style.border_color = Color(0.59, 0.68, 0.72, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 13.0
	style.content_margin_bottom = 13.0
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	hud_label = Label.new()
	hud_label.name = "ModelStatus"
	hud_label.add_theme_color_override("font_color", Color("e6ecee"))
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(hud_label)
	status_label = Label.new()
	status_label.name = "ControlHints"
	status_label.anchor_left = 0.0
	status_label.anchor_top = 1.0
	status_label.anchor_right = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_left = 24.0
	status_label.offset_top = -70.0
	status_label.offset_right = -24.0
	status_label.offset_bottom = -18.0
	status_label.add_theme_color_override("font_color", Color("e6ecee"))
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(status_label)
	status_label.text = "Drag: orbit / pan   Wheel: zoom   Tab: select mount   Q/E: select gun\nA/D: train   W/S: elevate selected gun   Space: pause   1–9: views   H: hide HUD"

func _parse_user_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index] == "--view" and index + 1 < args.size():
			view_name = args[index + 1]
		elif args[index] == "--capture" and index + 1 < args.size():
			capture_path = args[index + 1]
		elif args[index].begins_with("--view="):
			view_name = args[index].get_slice("=", 1)
		elif args[index].begins_with("--capture="):
			capture_path = args[index].get_slice("=", 1)
		elif args[index] == "--hide-ui":
			hide_hud_on_capture = true
	_set_view_preset(view_name)

func _process(delta: float) -> void:
	refresh_timer += delta
	if refresh_timer >= 0.2:
		refresh_timer = 0.0
		_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			orbit_distance = maxf(65.0, orbit_distance * 0.89)
			_update_camera()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			orbit_distance = minf(760.0, orbit_distance * 1.12)
			_update_camera()
		elif mouse_button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			drag_button = mouse_button.button_index if mouse_button.pressed else MOUSE_BUTTON_NONE
	elif event is InputEventMouseMotion and drag_button != MOUSE_BUTTON_NONE:
		var motion: InputEventMouseMotion = event
		if drag_button == MOUSE_BUTTON_LEFT:
			orbit_yaw -= motion.relative.x * 0.006
			orbit_pitch = clampf(orbit_pitch + motion.relative.y * 0.0045, -0.12, 1.48)
			_update_camera()
		else:
			var pan_scale: float = orbit_distance * 0.0013
			orbit_target -= camera.global_basis.x * motion.relative.x * pan_scale
			orbit_target += camera.global_basis.y * motion.relative.y * pan_scale
			_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)

func _handle_key(key: Key) -> void:
	match key:
		KEY_TAB:
			var mounts: Array[IowaWeaponMount] = ship.get_weapon_mounts()
			_select_mount((selected_mount_index + 1) % mounts.size())
		KEY_SPACE:
			ship_simulation.toggle_paused()
		KEY_H:
			hud_visible = not hud_visible
			get_node("InspectionHUD/InfoPanel").visible = hud_visible
			status_label.visible = hud_visible
		KEY_1: _set_view_preset("overview")
		KEY_2: _set_view_preset("top")
		KEY_3: _set_view_preset("side")
		KEY_4: _set_view_preset("bridge")
		KEY_5: _set_view_preset("turret")
		KEY_6: _set_view_preset("secondary")
		KEY_7: _set_view_preset("aircraft")
		KEY_8: _set_view_preset("catapult")
		KEY_9: _set_view_preset("crane")
		KEY_R:
			orbit_target = Vector3(0.0, 13.0, 0.0)
			_set_view_preset("overview")
		KEY_A: _command_selected_train(-10.0)
		KEY_D: _command_selected_train(10.0)
		KEY_W: _command_selected_gun_elevation(8.0)
		KEY_S: _command_selected_gun_elevation(-8.0)
		KEY_Q: _select_gun(-1)
		KEY_E: _select_gun(1)

func _set_view_preset(preset: String) -> void:
	view_name = preset
	match preset:
		"top":
			orbit_target = Vector3(0.0, 13.0, 0.0)
			orbit_yaw = 0.0
			orbit_pitch = 1.46
			orbit_distance = 370.0
		"side":
			orbit_target = Vector3(0.0, 13.0, 0.0)
			orbit_yaw = PI * 0.5
			orbit_pitch = 0.07
			orbit_distance = 290.0
		"bridge":
			orbit_target = Vector3(0.0, 20.0, -24.0)
			orbit_yaw = PI * 0.5
			orbit_pitch = 0.23
			orbit_distance = 78.0
		"bridge_front":
			orbit_target = Vector3(0.0, 10.55, -44.9)
			orbit_yaw = 3.9
			orbit_pitch = 0.65
			orbit_distance = 18.0
		"turret":
			orbit_target = Vector3(0.0, 8.8, -91.0)
			orbit_yaw = 2.3
			orbit_pitch = 0.34
			orbit_distance = 28.0
		"secondary":
			orbit_target = Vector3(-9.4, 8.2, -47.0)
			orbit_yaw = -PI * 0.5
			orbit_pitch = 0.12
			orbit_distance = 18.0
		"aircraft":
			orbit_target = Vector3(0.0, 8.5, 112.0)
			orbit_yaw = 0.92
			orbit_pitch = 0.22
			orbit_distance = 34.0
		"catapult":
			orbit_target = Vector3(12.0, 7.5, 121.0)
			orbit_yaw = 1.24
			orbit_pitch = 0.26
			orbit_distance = 24.0
		"crane":
			orbit_target = Vector3(0.0, 10.5, 120.0)
			orbit_yaw = 0.92
			orbit_pitch = 0.40
			orbit_distance = 22.0
		"bow":
			orbit_target = Vector3(0.0, 11.0, -115.0)
			orbit_yaw = 0.0
			orbit_pitch = 0.07
			orbit_distance = 100.0
		"stern":
			orbit_target = Vector3(0.0, 10.0, 86.0)
			orbit_yaw = 0.0
			orbit_pitch = 0.3
			orbit_distance = 118.0
		_:
			orbit_target = Vector3(0.0, 13.0, 0.0)
			orbit_yaw = -0.62
			orbit_pitch = 0.28
			orbit_distance = 250.0
	_update_camera()

func _update_camera() -> void:
	var horizontal_distance: float = orbit_distance * cos(orbit_pitch)
	var camera_offset: Vector3 = Vector3(sin(orbit_yaw) * horizontal_distance, sin(orbit_pitch) * orbit_distance, cos(orbit_yaw) * horizontal_distance)
	camera.position = orbit_target + camera_offset
	var up_axis: Vector3 = Vector3.BACK if orbit_pitch > 1.34 else Vector3.UP
	camera.look_at(orbit_target, up_axis)

func _select_mount(index: int) -> void:
	var mounts: Array[IowaWeaponMount] = ship.get_weapon_mounts()
	if mounts.is_empty():
		return
	selected_mount_index = clampi(index, 0, mounts.size() - 1)
	selected_mount = mounts[selected_mount_index]
	selected_gun_index = 0

func _select_gun(change: int) -> void:
	if not is_instance_valid(selected_mount) or selected_mount.elevation_axes.is_empty():
		return
	selected_gun_index = posmod(selected_gun_index + change, selected_mount.elevation_axes.size())

func _command_selected_train(train_change: float) -> void:
	if not is_instance_valid(selected_mount):
		return
	var current: Vector2 = selected_mount.get_angle_state()
	selected_mount.aim_at_train_angle(current.x + train_change)

func _command_selected_gun_elevation(elevation_change: float) -> void:
	if not is_instance_valid(selected_mount):
		return
	var elevations: PackedFloat64Array = selected_mount.get_gun_elevation_states()
	if selected_gun_index < 0 or selected_gun_index >= elevations.size():
		return
	selected_mount.aim_at_gun_elevation(selected_gun_index, float(elevations[selected_gun_index]) + elevation_change)

func _update_hud() -> void:
	if not is_instance_valid(ship) or not is_instance_valid(hud_label):
		return
	var heading_text: String = view_name.to_upper()
	var selected_text: String = "None"
	if is_instance_valid(selected_mount):
		var angles: Vector2 = selected_mount.get_angle_state()
		var elevations: PackedFloat64Array = selected_mount.get_gun_elevation_states()
		var gun_elevation: float = float(elevations[selected_gun_index]) if selected_gun_index < elevations.size() else angles.y
		selected_text = "%s   |   train %+.1f°   |   gun %d/%d %+.1f°" % [selected_mount.display_name, angles.x, selected_gun_index + 1, elevations.size(), gun_elevation]
	var fps: int = int(roundf(Performance.get_monitor(Performance.TIME_FPS)))
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	hud_label.text = "USS IOWA · BB-61\nConfiguration: 28 December 1944   |   View: %s\n\n270.4 m overall   ·   33.0 m beam   ·   11.3 m max draft\nDigital model mounts:\n%s\n\nIndependent weapon mounts: %d\nSelected: %s\nRender: %d FPS · %d draw calls\nWeapon placement and display rates are estimates where noted in data and docs." % [heading_text, mount_summary, mount_total, selected_text, fps, draw_calls]
	status_label.text = "Drag: orbit / pan   Wheel: zoom   Tab: select mount   Q/E: select gun\nA/D: train   W/S: elevate selected gun   Space: pause   1–9: views   H: hide HUD"

func _capture_after_frame(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var result: Error = image.save_png(path)
	if result != OK:
		push_error("Could not save screenshot at %s" % path)
	get_tree().quit()

