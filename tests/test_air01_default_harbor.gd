extends SceneTree

const SCENE: PackedScene = preload("res://showcase/carrier_harbor.tscn")
const OUTPUT: String = "res://.local/repairs/20261119_showcase_command/air01"
const SAMPLE_DT: float = 1.0 / 30.0

var game: AllUnitsShowcase
var failures: PackedStringArray = []
var gunfire: Dictionary = {}
var releases: Dictionary = {}
var contacts: Dictionary = {}
var explosions: Dictionary = {}
var aircraft_lock_rejections: Array[Dictionary] = []
var maneuver: Dictionary = {}
var cuts: Array[Dictionary] = []
var covered: Dictionary = {}
var capture: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	capture = DisplayServer.get_name() != "headless"
	if capture:
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
		push_error("AIR01 default scene could not load")
		quit(1)
		return
	_check(game.exercise == "harbor" and not game.guide.active, "normal scene starts on actual combat")
	for id: String in ["us_b25_1", "jp_g4m_1", "us_sb2c_1"]:
		var unit: UnitState = game.session.world.get_unit(id)
		_check(unit.active and unit.position_m.y > 300.0 and int(unit.module_data.bomb_rack.remaining) > 0 and game.models.has(id), "loaded airborne " + id)
	var last_cut: int = -1
	for frame: int in 2700:
		game._process(SAMPLE_DT)
		for event: BattleEvent in game.presentation_events:
			_record_event(event)
		if frame % 6 == 0: _record_maneuvers()
		if game.camera.shot_serial == last_cut: continue
		last_cut = game.camera.shot_serial
		await _record_cut()
	_check(gunfire.has("jp_surface") and gunfire.has("us_surface"), "both ships fire at opposing ships")
	_check(gunfire.has("fighter_bomber"), "fighter ammunition actually launches toward a bomber")
	_check(gunfire.has("fighter_fighter"), "fighter ammunition actually launches toward a fighter")
	var landed: int = 0
	for id: String in releases:
		if contacts.has(id) and explosions.has(id): landed += 1
	_check(landed > 0, "at least one released bomb generates matching physical contact and explosion")
	for faction: String in ["jp", "us"]:
		var flow: Dictionary = maneuver.get(faction, {})
		_check(flow.get("phases", {}).size() >= 2 and float(flow.get("bank_rad", 0.0)) > .12 and float(flow.get("pitch_rad", 0.0)) > .08 and float(flow.get("vertical_mps", 0.0)) > 10.0 and float(flow.get("turn_rad", 0.0)) > .1, "opposing fighter engagement has actual spatial motion " + faction)
	for kind: String in ["surface_gunnery", "bombing_run", "bomber_intercept", "fighter_dogfight", "bomber_intercept_fire", "fighter_dogfight_fire", "bomb_released", "bomb_explosion"]:
		_check(covered.has(kind), "automatic cut with observable " + kind)
	_check_air_button()
	_check_restart()
	var mode: String = "native" if capture else "headless"
	var audit: FileAccess = FileAccess.open(OUTPUT.path_join(mode + ".json"), FileAccess.WRITE)
	audit.store_string(JSON.stringify({"exercise":"harbor", "gunfire":gunfire, "bomb_releases":releases, "bomb_contacts":contacts,
		"bomb_explosions":explosions, "matching_bomb_contacts":landed, "maneuvers":maneuver,
		"cuts":cuts, "covered":covered, "aircraft_lock_rejections":aircraft_lock_rejections, "failures":failures}, "\t") + "\n")
	audit.close()
	game.queue_free()
	await process_frame
	print("AIR01 %s %s, %d matching bomb chains, %s" % [mode, "PASS" if failures.is_empty() else "FAIL", landed, gunfire])
	quit(0 if failures.is_empty() else 1)

func _record_event(event: BattleEvent) -> void:
	if event.kind == "command_rejected" and event.data.get("issuer_id") == "aircraft_tasks" and event.data.get("kind") == BattleCommand.SET_TARGET:
		var request: Dictionary = event.data.request
		aircraft_lock_rejections.append({"s":event.time_s, "unit_id":request.entity_id, "target_id":request.payload.target_id, "reason":event.data.reason})
	if event.kind in ["bomb_released", "bomb_contact", "bomb_explosion"]:
		var book: Dictionary = releases if event.kind == "bomb_released" else (contacts if event.kind == "bomb_contact" else explosions)
		book[event.data.projectile_id] = {"s":event.time_s, "id":event.entity_id, "target":event.target_id, "surface":event.data.get("surface", "")}
	if event.kind != "fired": return
	var source: Dictionary = game.metadata.get(event.entity_id, {})
	var target: Dictionary = game.metadata.get(event.target_id, {})
	var bucket: String = ""
	if event.data.get("mount_role") == "main" and source.get("domain") == "ship" and target.get("domain") == "ship":
		bucket = str(game.session.units[event.entity_id].faction_id) + "_surface"
	elif event.data.get("mount_role") == "aircraft_fixed" and _fighter(event.entity_id) and target.get("domain") == "aircraft":
		bucket = "fighter_fighter" if _fighter(event.target_id) else ("fighter_bomber" if game.session.units[event.target_id].module_data.has("bomb_rack") else "")
	if bucket.is_empty(): return
	if not gunfire.has(bucket): gunfire[bucket] = {"count":0, "first_s":event.time_s, "pairs":{}}
	var row: Dictionary = gunfire[bucket]
	row.count += 1
	var pair: String = event.entity_id + ">" + event.target_id
	row.pairs[pair] = int(row.pairs.get(pair, 0)) + 1

func _record_maneuvers() -> void:
	for id: String in game.session.units:
		if not _fighter(id): continue
		var unit: Dictionary = game.session.units[id]
		var state: Dictionary = unit.task.get("aircraft", {})
		if not unit.active or not _fighter(str(state.get("target_id", ""))) or state.get("phase", "") not in ["approach", "aim", "burst", "evade", "extend"]:
			continue
		var faction: String = unit.faction_id
		var motion: Dictionary = unit.module_data.aircraft_motion
		if not maneuver.has(faction): maneuver[faction] = {"phases":{}, "bank_rad":0.0, "pitch_rad":0.0, "vertical_mps":0.0, "turn_rad":0.0}
		var row: Dictionary = maneuver[faction]
		row.phases[str(state.maneuver_phase)] = true
		var pose: Vector3 = unit.rotation_rad
		row.bank_rad = maxf(float(row.bank_rad), absf(pose.z))
		row.pitch_rad = maxf(float(row.pitch_rad), absf(pose.x))
		row.vertical_mps = maxf(float(row.vertical_mps), absf(unit.velocity_mps.y))
		row.turn_rad = maxf(float(row.turn_rad), absf(float(motion.get("heading_rate_radps", 0.0))))

func _record_cut() -> void:
	var camera: ObserverCamera = game.camera
	var cue: Dictionary = camera.shot_event
	var kind: String = str(cue.get("kind", ""))
	var subject: String = camera.followed_id
	var surface: bool = kind in ["salvo", "gunnery_ready"] or cue.get("mount_role", "") == "main"
	if surface and subject in ["jp_bb", "us_bb"]: kind = "surface_gunnery"
	var visible: bool = _in_frame(subject)
	var source: String = str(cue.get("id", ""))
	var target: String = str(cue.get("target_id", ""))
	var opponent: String = source if subject == target else target
	var sequence: int = int(cue.get("sequence", 0))
	var shot: Dictionary = {"s":game.session.presentation_time_s, "kind":kind, "label":camera.shot_label, "subject":subject,
		"source":source, "target":target, "sequence":sequence, "visible_subject":visible, "visible_opponent":_in_frame(opponent)}
	cuts.append(shot)
	if not (kind in ObserverCamera.AIR_SHOTS or kind == "surface_gunnery"): return
	if kind != "bomb_explosion" and not visible: return
	if kind == "bomb_explosion" and not camera.is_position_in_frustum(cue.position_m): return
	var key: String = kind + "_fire" if kind in ["bomber_intercept", "fighter_dogfight"] and sequence > 0 else kind
	if covered.has(key): return
	covered[key] = shot
	if capture:
		game.hud.refresh(game.session, camera.mode, camera.shot_label)
		game._refresh_guide_ui()
		await process_frame
		RenderingServer.force_draw(false, 0)
		var error: Error = root.get_texture().get_image().save_png(OUTPUT.path_join(key + ".png"))
		_check(error == OK, "native screenshot " + key)

func _in_frame(id: String) -> bool:
	return game.models.has(id) and game.camera.is_position_in_frustum((game.models[id] as Node3D).global_position)

func _check_air_button() -> void:
	var before: Dictionary = game.session.world.snapshot()
	var button: Button = game.get("air_combat_button") as Button
	_check(button.is_visible_in_tree(), "air-only button available")
	button.pressed.emit()
	_check(game.camera.air_focus and game.camera.mode == "auto" and before == game.session.world.snapshot(), "air-only changes presentation in the same battle")
	for frame: int in 120:
		game._process(SAMPLE_DT)
		_check(game.camera.followed_id.is_empty() or game.metadata[game.camera.followed_id].domain == "aircraft", "air-only follows only aircraft")
	_check(game.session.world.time_s() > float(before.time_s), "air-only continues the battle")

func _check_restart() -> void:
	var generation: int = game.session.world.generation
	game._action("restart", null)
	_check(game.session.world.generation > generation and game.session.world.tick == 0 and not game.camera.air_focus and not game.guide.active, "restart resets both battle and camera")

func _fighter(id: String) -> bool:
	return game.metadata.get(id, {}).get("definition_id", "") in ["jp_a6m5a_1944", "us_f6f5_1944"]

func _check(ok: bool, message: String) -> void:
	if ok or failures.has(message): return
	failures.append(message)
	push_error("AIR01: " + message)
