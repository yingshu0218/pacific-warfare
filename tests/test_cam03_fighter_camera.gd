extends SceneTree

const SCENE: PackedScene = preload("res://showcase/carrier_harbor.tscn")
const OUTPUT: String = "res://.local/repairs/cam03/evidence"
const FRAME_DT: float = 1.0 / 30.0
const SIM_INPUTS: Array[String] = [
	"res://data/scenarios/s14_expansion_harbor.json",
	"res://data/scenarios/s14_maneuver.json",
	"res://scripts/behaviors/aircraft/aircraft_tasks.gd",
	"res://scripts/behaviors/aircraft/autonomous_fighter_motion.gd",
	"res://scripts/simulation/aircraft_motion/aircraft_motion.gd",
]

var game: AllUnitsShowcase
var native_render: bool
var checks: int = 0
var failures: PackedStringArray = []
var result: Dictionary = {}
var captures: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var input_hashes: Dictionary = {}
	for path: String in SIM_INPUTS:
		input_hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	native_render = DisplayServer.get_name() != "headless"
	if native_render:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	game = SCENE.instantiate() as AllUnitsShowcase
	root.add_child(game)
	game.set_process(false)
	if not game.running:
		push_error("CAM03: production Showcase failed to load")
		quit(1)
		return
	await process_frame
	_check(game.exercise == "harbor" and game.camera.mode == "auto", "normal harbor starts with automatic combat")
	var before: Dictionary = game.session.world.snapshot()
	_click(game.fighter_camera_button)
	_check(game.camera.mode == "fighter" and not game.guide.active and game.fighter_camera_button.button_pressed,
		"visible camera button selects the fighter view in the regular harbor")
	_check(before == game.session.world.snapshot(), "fighter view changes no simulation state")
	_check(not game.camera.shot_label.contains("交战"), "before contact the view distinguishes airborne aircraft from combat")
	await _sample("harbor", 90.0)
	await _controls()

	# Use the same menu callback and admitted scenario as the standard Web entry.
	var menu_index: int = AllUnitsShowcase.MODES.find("maneuver")
	game.segment_menu.select(menu_index)
	game.segment_menu.item_selected.emit(menu_index)
	await process_frame
	_check(game.exercise == "maneuver" and game.fighter_camera_button.is_visible_in_tree(),
		"existing autonomous flight menu exposes the fighter view")
	_click(game.fighter_camera_button)
	await _sample("maneuver", 105.0)
	await _validity_check()

	var training_index: int = AllUnitsShowcase.MODES.find("train_us_axial_roll")
	game.segment_menu.select(training_index)
	game.segment_menu.item_selected.emit(training_index)
	_check(game.guide.active and not game.fighter_camera_button.is_visible_in_tree()
		and not game.guide_status.text.contains("自主"), "training keeps its own guide and status")
	var report: FileAccess = FileAccess.open(OUTPUT.path_join("native.json" if native_render else "headless.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks, "failures":failures, "runs":result,
		"captures":captures, "simulation_inputs":input_hashes}, "\t") + "\n")
	report.close()
	game.queue_free()
	await process_frame
	print("CAM03 %d checks, %d failed" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _sample(exercise: String, duration_s: float) -> void:
	var runs: Array[Dictionary] = []
	var events: Dictionary = {}
	var samples: Array[Dictionary] = []
	var current: Dictionary = {}
	var camera: ObserverCamera = game.camera
	var all_centered: bool = true
	var level_horizon: bool = true
	var max_yaw_rate: float = 0.0
	var continuous_engagement_s: float = 0.0
	var previous_yaw: float = camera.yaw
	var former_id: String = camera.followed_id
	var real_transfer: bool = false
	var motion_labels: Dictionary = {}
	var labels_valid: bool = true
	for index: int in int(duration_s / FRAME_DT):
		game._process(FRAME_DT)
		current = camera.fighter_frame()
		var id: String = camera.followed_id
		var now: float = game.session.presentation_time_s
		var before_unit: Dictionary = game.session.presentation_units.get(former_id, {})
		if id != former_id and not former_id.is_empty() and not before_unit.is_empty():
			var damage: String = str(before_unit.module_data.get("damage", {}).get("phase", "operational"))
			if not before_unit.active or damage != "operational":
				real_transfer = not id.is_empty()
				result[exercise + "_transfer"] = {"s":now, "from":former_id, "to":id, "damage":damage}
		if id == former_id:
			max_yaw_rate = maxf(max_yaw_rate, absf(wrapf(camera.yaw - previous_yaw, -PI, PI)) / FRAME_DT)
		former_id = id
		previous_yaw = camera.yaw
		for event: BattleEvent in game.presentation_events:
			var is_fighter: bool = bool(game.metadata.get(event.entity_id, {}).get("fighter", false))
			var targets_fighter: bool = bool(game.metadata.get(event.target_id, {}).get("fighter", false))
			var key: String = event.kind
			if event.kind == "fired" and is_fighter and targets_fighter: key = "fighter_fire"
			if key in ["fighter_fire", "bomb_released", "bomb_contact", "damage_phase"]:
				events[key] = int(events.get(key, 0)) + 1
		if id.is_empty(): continue
		var model: Node3D = game.models[id]
		var in_frame: bool = camera.is_position_in_frustum(model.global_position)
		all_centered = all_centered and in_frame and model.visible
		level_horizon = level_horizon and absf(float(current.camera_roll_rad)) < 0.001
		var engaged: bool = not str(current.opponent_id).is_empty()
		if runs.is_empty() or runs.back().id != id:
			continuous_engagement_s = 0.0
			runs.append({"id":id, "start_s":now, "engagement_s":0.0, "longest_engagement_s":0.0, "peak_bank_deg":0.0,
				"min_climb_mps":INF, "max_climb_mps":-INF, "paired_frames":0, "paired_roles":{},
				"heading_span_deg":0.0, "start_m":SimData.array3(model.position), "min_height_m":model.position.y,
				"max_height_m":model.position.y, "near_frames":0, "bank_left":false, "bank_right":false})
		var row: Dictionary = runs.back()
		row.end_s = now
		row.end_m = SimData.array3(model.position)
		row.min_height_m = minf(row.min_height_m, model.position.y)
		row.max_height_m = maxf(row.max_height_m, model.position.y)
		var bank: float = rad_to_deg(float(current.bank_rad))
		var climb: float = float(current.velocity_mps[1])
		row.peak_bank_deg = maxf(row.peak_bank_deg, absf(bank))
		row.bank_left = row.bank_left or bank > 18.0
		row.bank_right = row.bank_right or bank < -18.0
		row.min_climb_mps = minf(row.min_climb_mps, climb)
		row.max_climb_mps = maxf(row.max_climb_mps, climb)
		var heading: float = AircraftFlightMath.heading(SimData.vec3(current.velocity_mps))
		if not row.has("start_heading"): row.start_heading = heading
		row.heading_span_deg = maxf(row.heading_span_deg, rad_to_deg(absf(wrapf(heading - row.start_heading, -PI, PI))))
		if engaged:
			row.engagement_s += FRAME_DT
			continuous_engagement_s += FRAME_DT
			row.longest_engagement_s = maxf(row.longest_engagement_s, continuous_engagement_s)
		else:
			continuous_engagement_s = 0.0
		if camera.distance_m < 55.0: row.near_frames += 1
		if bool(current.get("secondary_in_frame", false)):
			row.paired_frames += 1
			row.paired_roles[current.relation] = int(row.paired_roles.get(current.relation, 0)) + 1
		var motion: Dictionary = current.get("autonomous_maneuver", {})
		var named: bool = false
		for name_text: String in ["爬升转弯", "反向转弯", "轴向滚转", "斜向滚转弧"]:
			if not camera.shot_label.contains(name_text): continue
			named = true
			motion_labels[name_text] = int(motion_labels.get(name_text, 0)) + 1
			if native_render and camera.distance_m < 65.0:
				await _capture(exercise + "_" + str(motion.get("kind", "unknown")), now)
		labels_valid = labels_valid and named == bool(motion.get("verified_label", false))
		labels_valid = labels_valid and (not named or motion.get("status", "") == "executing")
		if index % 12 == 0:
			current["s"] = now
			current["m"] = SimData.array3(model.position)
			current["distance_m"] = camera.distance_m
			samples.append(current)
		if native_render and bool(current.get("secondary_in_frame", false)):
			await _capture(exercise + "_" + str(current.relation), now)
		if native_render and engaged and camera.distance_m < 55.0 and absf(bank) > 35.0 and absf(climb) > 16.0:
			await _capture(exercise + ("_climb" if climb > 0.0 else "_descent"), now)
	_check(events.get("fighter_fire", 0) > 0, exercise + " produces real fighter fire")
	var substantial: bool = false
	var paired_and_near: bool = false
	for row: Dictionary in runs:
		substantial = substantial or (row.longest_engagement_s >= 5.9 and row.peak_bank_deg > 35.0
			and row.heading_span_deg > 30.0 and row.max_height_m - row.min_height_m > 80.0)
		paired_and_near = paired_and_near or (row.paired_frames > 0 and row.near_frames > 0)
	_check(substantial, exercise + " holds one real engagement through substantial bank, turn and altitude change")
	_check(all_centered and level_horizon and max_yaw_rate < 0.70, exercise + " holds subject and level horizon with bounded camera yaw")
	_check(paired_and_near, exercise + " sees a second aircraft and returns to a legible near view")
	_check(labels_valid and not motion_labels.is_empty(),
		exercise + " only labels measured maneuvers while executing and clears terminal labels")
	print("CAM03 %s at %.1f s: %s" % [exercise, game.session.presentation_time_s, motion_labels])
	result[exercise] = {"cuts":runs, "events":events, "samples":samples, "max_yaw_rate_radps":max_yaw_rate,
		"natural_transfer":real_transfer, "motion_label_frames":motion_labels}

func _controls() -> void:
	var camera: ObserverCamera = game.camera
	var world: SimulationWorld = game.session.world
	var air_button: Button = game.get("air_combat_button") as Button
	_key(KEY_SPACE)
	var pose: Transform3D = camera.transform
	var label: String = camera.shot_label
	var tick: int = world.tick
	for i: int in 12: game._process(FRAME_DT)
	_check(world.paused and world.tick == tick and camera.transform == pose and camera.shot_label == label,
		"Space pauses world, pose, damping and label")
	_key(KEY_SPACE)
	game._process(FRAME_DT)
	_check(not world.paused and world.tick > tick, "Space resumes the same battle")
	_key(KEY_F)
	_check(camera.mode == "free" and camera.manual_free, "F exits fighter view")
	_click(game.fighter_camera_button)
	_key(KEY_W)
	game._process(FRAME_DT)
	_check(camera.mode == "free" and camera.manual_free, "W takes over as free camera")
	_click(game.fighter_camera_button)
	_mouse_button(Vector2(640, 385), MOUSE_BUTTON_RIGHT, true)
	_mouse_button(Vector2(640, 385), MOUSE_BUTTON_RIGHT, false)
	_check(camera.mode == "free" and camera.manual_free, "right mouse takes over in the center viewport")
	_click(game.fighter_camera_button)
	_key(KEY_C)
	_check(camera.mode == "auto" and not camera.air_focus, "C restores mixed automatic cinema")
	_click(game.fighter_camera_button)
	_click(game.fighter_camera_button)
	_check(camera.mode == "auto" and not game.fighter_camera_button.button_pressed, "second button press exits to cinema")
	_click(game.fighter_camera_button)
	_click(air_button)
	_check(camera.mode == "auto" and camera.air_focus, "existing air combat button still selects mixed air events")
	_click(game.fighter_camera_button)
	var follow: Button = _find_button("跟随")
	_check(follow != null, "normal manual follow control is available")
	if follow != null: _click(follow)
	_check(camera.mode == "follow" and not camera.followed_id.is_empty(), "manual unit follow overrides fighter view")
	_click(game.fighter_camera_button)
	var generation: int = world.generation
	_key(KEY_R)
	_check(game.session.world.generation > generation and game.session.world.tick == 0
		and camera.mode == "auto" and not camera.air_focus and not game.fighter_camera_button.button_pressed,
		"R restarts the normal harbor in automatic cinema")
	await process_frame

func _validity_check() -> void:
	# Drive the exact presentation API with a copy of the live entry's views.
	# The simulation is never edited to construct an all-aircraft exhaustion case.
	var camera: ObserverCamera = game.camera
	var combat_snapshot: Dictionary = game.session.world.snapshot()
	var views: Dictionary = game.session.presentation_units.duplicate(true)
	var prior: String = camera.followed_id
	var now: float = game.session.presentation_time_s
	_check(not prior.is_empty(), "autonomous entry has a subject for the validity check")
	if not prior.is_empty():
		views[prior].active = false
		camera.update_view(FRAME_DT, now + FRAME_DT, views, false)
		_check(not camera.followed_id.is_empty() and camera.followed_id != prior,
			"invalid subject hands off immediately to another airborne fighter")
	for id: String in views:
		if game.metadata[id].fighter: views[id].active = false
	var last_pose: Transform3D = camera.transform
	camera.update_view(FRAME_DT, now + FRAME_DT * 2.0, views, false)
	_check(camera.followed_id.is_empty() and camera.transform == last_pose
		and camera.shot_label == "暂无可跟拍的战斗机", "no fighter available retains final pose with accurate status")
	_check(combat_snapshot == game.session.world.snapshot(), "observer validity check is read-only")
	_key(KEY_R)
	_check(camera.mode != "fighter" and not game.fighter_camera_button.button_pressed, "restart also clears fighter camera in autonomous entry")

func _capture(key: String, now: float) -> void:
	if captures.has(key): return
	game.hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
	game._refresh_guide_ui()
	await process_frame
	RenderingServer.force_draw(false, 0)
	var filename: String = key + ".png"
	var error: Error = root.get_texture().get_image().save_png(OUTPUT.path_join(filename))
	_check(error == OK, "native screenshot " + key)
	captures[key] = {"file":filename, "s":now, "id":game.camera.followed_id}

func _find_button(label: String) -> Button:
	for control: Node in game.hud.root.find_children("*", "Button", true, false):
		if (control as Button).text == label and (control as Button).is_visible_in_tree(): return control as Button
	return null

func _click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	_mouse_button(point, MOUSE_BUTTON_LEFT, true)
	_mouse_button(point, MOUSE_BUTTON_LEFT, false)

func _mouse_button(point: Vector2, index: int, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok: return
	failures.append(message)
	push_error("CAM03: " + message)
