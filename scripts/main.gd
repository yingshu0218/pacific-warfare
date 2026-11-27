extends "res://scripts/ship_geometry.gd"

const NavalMountStudy = preload("res://scripts/naval_mount_study.gd")
const ArchiveFinish = preload("res://scripts/presentation/models/archive_finish.gd")

var elapsed: float = 0.0
var interface_layer: CanvasLayer
var auto_orbit: bool = false
var ocean_surface: MeshInstance3D
var ship: Node3D
var naval_study: Node3D
var naval_study_mode: bool = false
var title_label: Label
var floating: bool = true
var selected_weapon: int = -1
var mount_markers: Array[Label3D] = []
var show_mount_ids: bool = false
var show_hypothesis: bool = false
var performance_label: Label
var weapon_label: Label
var cinematic: bool = false
var world_environment: Environment
var sky_palette: ProceduralSkyMaterial
var camera: Camera3D
var sun: DirectionalLight3D
var yaw: float = -1.1
var pitch: float = 0.22
var distance: float = 230.0
var target: Vector3 = Vector3(0, 10, 0)
var saved_target: Vector3 = Vector3.ZERO
var saved_yaw: float = -1.1
var saved_pitch: float = 0.22
var saved_distance: float = 230.0
var saved_projection: int = Camera3D.PROJECTION_PERSPECTIVE
var saved_camera_size: float = 1.0
var saved_background_mode: int = Environment.BG_SKY
var saved_background_color: Color = Color.BLACK


func _ready() -> void:
	ship = build_ship()
	ArchiveFinish.apply(ship, "ship")
	naval_study = NavalMountStudy.new()
	naval_study.visible = false
	add_child(naval_study)
	for entry: Dictionary in weapons:
		var weapon: WeaponMount = entry.pivot
		var marker: Label3D = Label3D.new()
		marker.text = weapon.name
		if str(weapon.get_meta("placement_status","")).begins_with("UNRESOLVED"):
			marker.text += " 未定位"
			marker.modulate = Color("ff9b65")
			weapon.set_geometry_visible(false)
		marker.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
		marker.font_size = 40
		marker.pixel_size = 0.035
		marker.outline_size = 10
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = true
		marker.position = Vector3(0,7,0)
		marker.visible = false
		weapon.add_child(marker)
		mount_markers.append(marker)
	var ocean: PlaneMesh = PlaneMesh.new()
	ocean.size = Vector2(10000,10000)
	ocean.subdivide_width = 256
	ocean.subdivide_depth = 256
	var water: ShaderMaterial = ShaderMaterial.new()
	water.shader = load("res://assets/ocean.gdshader")
	ocean_surface = mesh_part(ocean,Vector3.ZERO,water)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	world_environment = environment.environment
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_palette = sky_material
	sky_material.sky_top_color = Color("507fa5")
	sky_material.sky_horizon_color = Color("c1d2da")
	sky_material.ground_horizon_color = Color("c1d2da")
	sky_material.ground_bottom_color = Color("365362")
	sky_material.sky_curve = 0.18
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment.environment.sky = sky
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b5c7d5")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-32,0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600
	add_child(sun)
	apply_lighting()
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 7000
	camera.near = 0.15
	add_child(camera)
	var layer: CanvasLayer = CanvasLayer.new()
	interface_layer = layer
	add_child(layer)
	title_label = Label.new()
	var ui_font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	title_label.add_theme_font_override("font",ui_font)
	title_label.text = "大和 YAMATO  /  1944.04 改装后 · 造型复原中\n拖动环绕 · 滚轮缩放 · 右键平移 · L 切换光照 · 1/2/3 近景 · 4侧视/5俯视 · M舰载武器样件\n263 m × 38.9 m  |  程序几何 / 非测绘复原"
	title_label.position = Vector2(26,24)
	title_label.add_theme_font_size_override("font_size",20)
	layer.add_child(title_label)
	weapon_label = Label.new()
	weapon_label.add_theme_font_override("font",ui_font)
	weapon_label.position = Vector2(26,125)
	weapon_label.add_theme_font_size_override("font_size",17)
	layer.add_child(weapon_label)
	performance_label = Label.new()
	performance_label.add_theme_font_override("font",ui_font)
	performance_label.position = Vector2(26,240)
	performance_label.add_theme_font_size_override("font_size",17)
	performance_label.visible = false
	layer.add_child(performance_label)
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--weapon="): continue
		var identifier: String = argument.trim_prefix("--weapon=")
		for index: int in range(weapons.size()):
			var mount: WeaponMount = weapons[index].pivot
			if str(mount.name) != identifier: continue
			selected_weapon = index
			target = mount.global_position+Vector3.UP*2
			distance = 38 if index < 5 else 14
	if "--naval-study" in OS.get_cmdline_user_args(): set_naval_study_mode(true)
	if "--capture" in OS.get_cmdline_user_args():
		if "--clean" in OS.get_cmdline_user_args(): interface_layer.visible = false
		if "--close" in OS.get_cmdline_user_args():
			target = Vector3(0,12,-48)
			distance = 70
			yaw = -2.3
			pitch = 0.38
		if "--main-turret" in OS.get_cmdline_user_args():
			target = Vector3(0,13,-50)
			distance = 38
			yaw = -2.1
			pitch = 0.24
		if "--secondary-turret" in OS.get_cmdline_user_args():
			target = Vector3(0,12,-9.5)
			distance = 22
			yaw = -2.1
			pitch = 0.24
		if "--elevated" in OS.get_cmdline_user_args():
			target = Vector3(0,14,-50)
			distance = 46
			yaw = -2.6
			pitch = 0.3
			for entry: Dictionary in weapons:
				var mount: WeaponMount = entry.pivot
				mount.moving = false
				mount.rotation.y = mount.base_heading
				mount.elevation_axis.rotation.x = deg_to_rad(mount.elevation_limits.y)
		if "--under" in OS.get_cmdline_user_args():
			target = Vector3(0,-5,108)
			distance = 70
			yaw = -0.8
			pitch = -0.24
			ocean_surface.visible = false
			floating = false
		if "--stern" in OS.get_cmdline_user_args():
			target = Vector3(0,10,106)
			distance = 60
			yaw = -0.9
			pitch = 0.65
		if "--bridge" in OS.get_cmdline_user_args():
			target = Vector3(0,26,2)
			distance = 65
			yaw = -1.0
			pitch = 0.25
		if "--bridge-detail" in OS.get_cmdline_user_args():
			target = Vector3(5,26,2)
			distance = 22
			yaw = -1.0
			pitch = 0.28
		if "--bridge-lower" in OS.get_cmdline_user_args():
			target = Vector3(-4.45,15.8,-1.85)
			distance = 13
			yaw = -1.1
			pitch = 0.32
		if "--bridge-lower-alt" in OS.get_cmdline_user_args():
			target = Vector3(4.45,15.8,-1.85)
			distance = 13
			yaw = 1.1
			pitch = 0.32
		if "--secondary" in OS.get_cmdline_user_args():
			target = Vector3(0,10,20)
			distance = 68
			yaw = -1.1
			pitch = 0.28
		if "--aft-bridge" in OS.get_cmdline_user_args():
			target = Vector3(0,18,39)
			distance = 25
			yaw = -1.3
			pitch = 0.14
		if "--funnel" in OS.get_cmdline_user_args():
			target = Vector3(0,20.5,22)
			distance = 32
			yaw = -1.1
			pitch = 0.46
		if "--aa" in OS.get_cmdline_user_args():
			target = Vector3(8,14,20)
			distance = 32
			yaw = 1.2
			pitch = 0.5
		if "--side" in OS.get_cmdline_user_args(): set_inspection_view(false)
		if "--top" in OS.get_cmdline_user_args(): set_inspection_view(true)
		if "--perf" in OS.get_cmdline_user_args():
			performance_label.visible = true
			for frame: int in range(120): await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output: String = "inspection" if selected_weapon >= 0 else "preview"
		for view: String in ["close", "main-turret", "secondary-turret", "side", "top", "clean", "perf", "aa", "under", "bridge", "bridge-detail", "bridge-lower", "bridge-lower-alt", "aft-bridge", "funnel", "secondary", "elevated", "stern", "naval-study"]:
			if "--"+view in OS.get_cmdline_user_args(): output = view
		if "--naval-study" in OS.get_cmdline_user_args(): output = "naval-weapon-study"
		get_viewport().get_texture().get_image().save_png("res://docs/"+output+".png")
		get_tree().quit()

func _process(_delta: float) -> void:
	elapsed += _delta
	if performance_label.visible:
		performance_label.text = "FPS %d | Draw calls %d | Objects %d" % [Engine.get_frames_per_second(),int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))]
	if auto_orbit: yaw += _delta*0.035
	if floating:
		ship.position.y = sin(elapsed*0.55)*0.22
		ship.rotation.z = sin(elapsed*0.43)*deg_to_rad(0.45)
		ship.rotation.x = sin(elapsed*0.31)*deg_to_rad(0.12)
	else:
		ship.position = Vector3.ZERO
		ship.rotation = Vector3.ZERO
	if naval_study_mode:
		weapon_label.text = "左：九六式双联 25 毫米舰载炮\n右：维克斯 7.7 毫米机枪 + Model F 三脚架\n标称口径比 3.25 : 1 · 甲板仅作尺度样件\n按 M 返回大和号 1944 画面"
	else:
		weapon_label.text = "Tab / Shift+Tab 逐座选择武器 · 方向键手动转动 · R 恢复自动 · F 静态/漂浮 · H 隐藏界面 · O 环绕 · N 炮位编号 · W 海面 · U 未定位假设"
	if selected_weapon >= 0 and not naval_study_mode:
		var weapon: WeaponMount = weapons[selected_weapon].pivot
		var horizontal: float = float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
		var vertical: float = float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN))
		if horizontal != 0 or vertical != 0:
			weapon.moving = false
			weapon.manual_move(horizontal,vertical,_delta)
		weapon_label.text += "\n" + weapon.name + "  [" + str(weapon.get_meta("placement_status","待核对")) + "]" + "\n武器 %d / %d  水平 %.1f°  俯仰 %.1f°\n水平范围 %.0f…%.0f° / %.1f°每秒  俯仰范围 %.0f…%.0f° / %.1f°每秒" % [selected_weapon+1,weapons.size(),rad_to_deg(weapon.rotation.y-weapon.base_heading),rad_to_deg(weapon.elevation_axis.rotation.x),weapon.train_limits.x,weapon.train_limits.y,weapon.train_speed,weapon.elevation_limits.x,weapon.elevation_limits.y,weapon.elevation_speed]
		var state: String = "自动展示" if weapon.automatic_demo else "目标角度控制"
		if not weapon.moving: state = "手动保持"
		if weapon.obstructed: state += " · 几何受阻，安全轴仍可移动"
		weapon_label.text += "\n"+state
	camera.position = target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			auto_orbit = false
			yaw -= event.relative.x*0.005
			pitch = clampf(pitch+event.relative.y*0.004,-1.4,1.5)
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			target += camera.global_basis.x * -event.relative.x*distance*0.001+Vector3.UP*event.relative.y*distance*0.001
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(8,distance*0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(1000,distance*1.1)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			set_naval_study_mode(not naval_study_mode)
			return
		if naval_study_mode: return
		if event.keycode == KEY_U:
			show_hypothesis = not show_hypothesis
			for entry: Dictionary in weapons:
				var weapon: WeaponMount = entry.pivot
				if str(weapon.get_meta("placement_status","")).begins_with("UNRESOLVED"):
					weapon.set_geometry_visible(show_hypothesis)
		if event.keycode == KEY_W: ocean_surface.visible = not ocean_surface.visible
		if event.keycode == KEY_N:
			show_mount_ids = not show_mount_ids
			for marker: Label3D in mount_markers: marker.visible = show_mount_ids
		if event.keycode == KEY_F8: performance_label.visible = not performance_label.visible
		if event.keycode == KEY_H: interface_layer.visible = not interface_layer.visible
		if event.keycode == KEY_O:
			auto_orbit = not auto_orbit
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			ocean_surface.visible = true
		if event.keycode == KEY_F: floating = not floating
		if event.keycode == KEY_TAB:
			selected_weapon = posmod((weapons.size() if selected_weapon < 0 and event.shift_pressed else selected_weapon)+(-1 if event.shift_pressed else 1),weapons.size())
			var selected: WeaponMount = weapons[selected_weapon].pivot
			target = selected.global_position+Vector3.UP*2
			distance = 38 if selected_weapon < 5 else 14
		if event.keycode == KEY_R:
			for entry: Dictionary in weapons:
				(entry.pivot as WeaponMount).resume_demo()
		if event.keycode == KEY_SPACE:
			for entry: Dictionary in weapons:
				var weapon: WeaponMount = entry.pivot
				weapon.moving = not weapon.moving
		if event.keycode == KEY_L:
			cinematic = not cinematic
			apply_lighting()
		if event.keycode == KEY_4: set_inspection_view(false)
		if event.keycode == KEY_5: set_inspection_view(true)
		if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_TAB]:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			ocean_surface.visible = true
		if event.keycode == KEY_1: target = Vector3(0,10,0); distance = 320
		if event.keycode == KEY_2: target = Vector3(0,24,-15); distance = 65
		if event.keycode == KEY_3: target = Vector3(0,10,-48); distance = 75


func set_naval_study_mode(enabled: bool) -> void:
	if naval_study_mode == enabled: return
	naval_study_mode = enabled
	if enabled:
		saved_target = target
		saved_yaw = yaw
		saved_pitch = pitch
		saved_distance = distance
		saved_projection = camera.projection
		saved_camera_size = camera.size
		saved_background_mode = world_environment.background_mode
		saved_background_color = world_environment.background_color
		ship.visible = false
		ocean_surface.visible = false
		naval_study.visible = true
		selected_weapon = -1
		auto_orbit = false
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 5.6
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color("58636b")
		target = Vector3(0.0, 1.05, 0.0)
		distance = 14.0
		yaw = 2.3
		pitch = 0.42
		title_label.text = "日本海军舰载武器型式校核\n甲板样件 · 非大和号1944年炮位复原"
	else:
		naval_study.visible = false
		ship.visible = true
		ocean_surface.visible = true
		target = saved_target
		yaw = saved_yaw
		pitch = saved_pitch
		distance = saved_distance
		camera.projection = saved_projection
		camera.size = saved_camera_size
		world_environment.background_mode = saved_background_mode
		world_environment.background_color = saved_background_color
		title_label.text = "大和 YAMATO  /  1944.04 改装后 · 造型复原中\n拖动环绕 · 滚轮缩放 · 右键平移 · L 切换光照 · 1/2/3 近景 · 4侧视/5俯视 · M舰载武器样件\n263 m × 38.9 m  |  程序几何 / 非测绘复原"

func set_inspection_view(top: bool) -> void:
	floating = false
	selected_weapon = -1
	for entry: Dictionary in weapons:
		var weapon: WeaponMount = entry.pivot
		weapon.moving = false
		weapon.rotation.y = weapon.base_heading
		weapon.elevation_axis.rotation.x = deg_to_rad(3)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 175
	ocean_surface.visible = false
	target = Vector3(0,16,0)
	distance = 300
	yaw = PI/2
	pitch = PI/2-0.001 if top else 0.0

func apply_lighting() -> void:
	sun.rotation_degrees = Vector3(-13,-65,0) if cinematic else Vector3(-35,-32,0)
	sun.light_color = Color("ffd0a0") if cinematic else Color.WHITE
	sun.light_energy = 1.65 if cinematic else 1.4
	world_environment.ambient_light_color = Color("8398b1") if cinematic else Color("b5c7d5")
	world_environment.ambient_light_energy = 0.38 if cinematic else 0.65
	sky_palette.sky_top_color = Color("395e83") if cinematic else Color("507fa5")
	sky_palette.sky_horizon_color = Color("d4b6a0") if cinematic else Color("c1d2da")
	sky_palette.ground_horizon_color = sky_palette.sky_horizon_color
	world_environment.fog_enabled = cinematic
	world_environment.fog_light_color = Color("a1a9b3")
	world_environment.fog_density = 0.00012
