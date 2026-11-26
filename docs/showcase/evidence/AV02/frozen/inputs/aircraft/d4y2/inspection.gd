extends Node3D
## Bounded native evidence generator. A stage only, never a production aircraft driver.
const MODEL: PackedScene = preload("res://aircraft/d4y2/d4y2.tscn")
const SHIP: PackedScene = preload("res://naval/shokaku_1941_08_23/shokaku.tscn")
const G: Script = preload("res://aircraft/d4y2/geometry.gd")
var aircraft: Node3D
var carrier: Node3D
var camera: Camera3D
var floor_mesh: MeshInstance3D
var label: Label
var selected: String = "quarter"
var output: String = ""
var batch: String = ""

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		match args[i]:
			"--view": selected = args[i + 1]
			"--capture": output = args[i + 1]
			"--batch": batch = args[i + 1]
	_stage()
	aircraft = MODEL.instantiate() as Node3D
	add_child(aircraft)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.far = 600.0
	add_child(camera); camera.current = true
	if not batch.is_empty():
		_batch_capture()
	else:
		_view(selected)
		if not output.is_empty(): _capture(output)

func _stage() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("c8cfd2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e4e5e3"); env.ambient_light_energy = 0.70
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new(); world.environment = env; add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -30.0, 0.0); sun.light_energy = 0.90; add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(25.0, 145.0, 0.0); fill.light_energy = 0.33; add_child(fill)
	floor_mesh = G.box(self, "NeutralGround", Vector3(40.0, 0.08, 40.0), Vector3(0.0, -0.04, 0.0), G.material(Color("aeb9bd")))
	var layer: CanvasLayer = CanvasLayer.new(); add_child(layer)
	label = Label.new(); label.position = Vector2(24.0, 20.0); label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color("233b45")); layer.add_child(label)

func _view(id: String) -> void:
	selected = id
	aircraft.transform = Transform3D.IDENTITY
	aircraft.apply_damage_state({"center": true, "engine": true, "left_wing": true, "right_wing": true, "tail": true})
	aircraft.apply_visual_state({"gear": 1.0, "hook": 0.0, "flap": 0.0, "brake": 0.0, "bay": 0.0, "crutch": 0.0,
		"bomb_visible": true, "rear_gun": false, "propeller_rad": 0.0, "aileron_left_wing_rad": 0.0, "aileron_right_wing_rad": 0.0,
		"elevator_left_rad": 0.0, "elevator_right_rad": 0.0, "rudder_rad": 0.0})
	floor_mesh.visible = true
	if carrier != null: carrier.visible = false
	var target: Vector3 = Vector3(0.0, 1.55, 0.0)
	var offset: Vector3 = Vector3(13.0, 7.0, -16.0)
	var size: float = 9.6
	var parked: bool = not id.ends_with("flight")
	if parked: aircraft.transform = aircraft.get_parked_transform()
	else: aircraft.set_flight_configuration(); floor_mesh.visible = false; target.y = 0.15
	match id:
		"side", "side_flight": offset = Vector3(22.0, 0.0, 0.0); size = 8.2
		"front", "front_flight": offset = Vector3(0.0, 0.0, -24.0); size = 8.8
		"top_flight": offset = Vector3(0.0, 25.0, 0.001); size = 12.2
		"high_front": offset = Vector3(12.0, 17.0, -18.0); size = 10.2
		"high_rear": offset = Vector3(-12.0, 16.0, 20.0); size = 10.2
		"rear": offset = Vector3(0.0, 2.0, 24.0); size = 13.5
		"underside_flight": offset = Vector3(10.0, -16.0, -14.0); size = 14.0
		"gear": target = aircraft.transform * Vector3(0.0, -0.6, -1.4); offset = Vector3(9.0, 0.1, -12.0); size = 6.3
		"tailgear": target = aircraft.transform * Vector3(0.0, -0.12, 3.55); offset = Vector3(12.0, 0.5, -1.0); size = 4.2
		"canopy": target = aircraft.transform * Vector3(0.0, 0.75, -0.3); offset = Vector3(7.0, 3.0, -9.0); size = 5.4
		"rear_gun":
			aircraft.apply_visual_state({"rear_gun": true})
			target = aircraft.transform * Vector3(0.0, 0.75, 0.55); offset = Vector3(6.0, 4.0, 9.0); size = 4.8
		"bay":
			aircraft.transform = Transform3D.IDENTITY; aircraft.set_flight_configuration()
			aircraft.apply_visual_state({"bay": 1.0, "crutch": 1.0}); floor_mesh.visible = false
			target = Vector3(0.0, -0.5, 0.3); offset = Vector3(7.0, -6.0, -5.0); size = 5.5
		"brake":
			aircraft.transform = Transform3D.IDENTITY; aircraft.set_flight_configuration()
			aircraft.apply_visual_state({"brake": 1.0}); floor_mesh.visible = false
			target = Vector3(0.0, -0.1, -0.4); offset = Vector3(8.0, -9.0, 13.0); size = 13.0
		"landing":
			aircraft.apply_visual_state({"flap": 1.0, "hook": 1.0}); offset = Vector3(-13.0, 3.0, 15.0)
		"damage":
			aircraft.transform = Transform3D.IDENTITY; aircraft.set_flight_configuration()
			aircraft.apply_damage_state({"left_wing": false, "engine": false})
			floor_mesh.visible = false; target.y = 0.0
	if id.begins_with("deck_"):
		if carrier == null:
			carrier = SHIP.instantiate() as Node3D; add_child(carrier)
		carrier.visible = true; floor_mesh.visible = false
		var z: float = -80.0
		match id:
			"deck_forward": z = -43.5
			"deck_middle": z = 29.0
			"deck_aft": z = 84.5
		var at: Vector3 = Vector3(0.0, 14.15, z)
		aircraft.transform = Transform3D(Basis.IDENTITY, at) * aircraft.get_parked_transform()
		target = at + Vector3(0.0, 1.5, 0.0); offset = Vector3(12.0, 11.0, -14.0); size = 21.0
		if id == "deck_parking": size = 24.0
	camera.size = size
	camera.position = target + offset
	camera.look_at(target)
	label.text = "D4Y2 Model 12  |  1944-10  |  " + id.replace("_", " ") + "\n1:1 m  |  static model inspection"
	if id.begins_with("deck_"): label.text += "\nShokaku 1941-08-23 + D4Y2 1944: hypothetical cross-era fit"

func _save_capture(path: String) -> void:
	for i: int in range(5): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(path)
	if err != OK:
		push_error("AV02 capture failed: " + path); get_tree().quit(1); return
	var sidecar: Dictionary = {"view": selected, "size_px": [img.get_width(), img.get_height()], "native": true,
		"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"model_state": aircraft.state.duplicate(true), "camera_position_m": _vec(camera.position), "camera_basis": [_vec(camera.basis.x), _vec(camera.basis.y), _vec(camera.basis.z)],
		"camera_size_m": camera.size, "model_origin_m": _vec(aircraft.position), "model_rotation_rad": _vec(aircraft.rotation),
		"model_scale": _vec(aircraft.scale), "source_hashes": {}}
	for source: String in ["aircraft/d4y2/d4y2.gd", "aircraft/d4y2/geometry.gd", "aircraft/d4y2/inspection.gd",
		"naval/shokaku_1941_08_23/shokaku.gd", "naval/shokaku_1941_08_23/data/deck.json"]:
		sidecar.source_hashes[source] = FileAccess.get_sha256("res://" + source)
	var file: FileAccess = FileAccess.open(path + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(sidecar, "\t") + "\n"); file.close()
	print("AV02 captured ", path)

func _capture(path: String) -> void:
	await _save_capture(path)
	get_tree().quit()

func _batch_capture() -> void:
	var views: PackedStringArray = PackedStringArray(["side", "side_flight", "front", "top_flight", "high_front", "high_rear", "gear", "tailgear", "canopy", "rear_gun", "bay", "brake", "landing", "damage"])
	if batch == "deck": views = PackedStringArray(["deck_forward", "deck_middle", "deck_aft", "deck_parking"])
	if batch == "final": views = PackedStringArray(["canopy", "high_front", "side", "top_flight"])
	for id: String in views:
		_view(id)
		await _save_capture(output.path_join(id + ".png"))
	get_tree().quit()

func _vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: get_tree().quit()
