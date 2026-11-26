extends SceneTree

## Native captures from the unmodified automatic camera in the actual S07 scene.
## This runner never calls follow/locate or writes camera pose, focus, yaw or distance.
var game: FirstPlayableGame
var views: Array[Dictionary] = []
var captured: Dictionary = {}
var recent: Dictionary = {}
var recent_ids: Array[int] = []
const DIRECTORY: String = "res://docs/showcase/evidence/S07"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.content_scale_size = Vector2i(1280, 720)
	game = (load("res://showcase/first_playable.tscn") as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	if not game.running: quit(1); return
	game.hud.cinema_button.pressed.emit()
	for index: int in range(180 * 60):
		var events: Array[BattleEvent] = tick()
		for event: BattleEvent in events:
			if event.kind != "fired" or game.camera.followed_id != event.entity_id or not game.camera.is_position_in_frustum(event.position_m): continue
			var label_value: String = ""
			if game.metadata[event.entity_id].domain == "aircraft": label_value = "auto_air_combat"
			elif float(event.data.get("caliber_m", 0.0)) >= 0.3: label_value = "auto_bb_gunnery"
			if label_value.is_empty() or captured.has(label_value): continue
			captured[label_value] = true
			var source: Dictionary = event.snapshot()
			# Advance real ticks so the tracer has length while the short flash is alive.
			tick()
			tick()
			await save_view(label_value, source)
			break
		var cue: Dictionary = game.camera.shot_event
		if cue.get("kind", "") == "airburst" and not captured.has("auto_airburst") and game.session.world.time_s() - float(cue.time_s) < 0.8 and recent.has(int(cue.sequence)):
			captured["auto_airburst"] = true
			await save_view("auto_airburst", recent[int(cue.sequence)])
		if captured.size() == 3: break
		if not game.session.ended_reason.is_empty(): break
		if index % 60 == 0: await process_frame
	var hashes: Dictionary = {}
	for path: String in ["res://scripts/game/first_playable.gd", "res://scripts/game/first_playable_session.gd", "res://scripts/presentation/cameras/observer_camera.gd", "res://scripts/presentation/effects/combat_effects.gd", "res://data/scenarios/first_playable.json", "res://data/combat/showcase.json", "res://tests/first_playable_auto_capture.gd"]:
		hashes[path] = FileAccess.get_file_as_string(path).sha256_text()
	var output: FileAccess = FileAccess.open(DIRECTORY.path_join("auto_capture_audit.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"scope":"Actual first_playable.tscn and automatic camera; only normal cinema UI is collapsed", "manual_camera_calls":false, "views":views, "source_sha256":hashes, "counts":game.session.counts, "time_s":game.session.world.time_s()}, "\t"))
	output.close()
	if captured.size() != 3:
		push_error("S07 automatic native capture missing categories: " + str(captured))
		quit(1)
		return
	print("S07 actual automatic camera native captures: PASS (3)")
	quit(0)

func tick() -> Array[BattleEvent]:
	game.session.world.step_ticks(1)
	var events: Array[BattleEvent] = game.session.consume_world()
	game.apply_presentation(events)
	game.camera.update_view(1.0 / 60.0, game.session.world.time_s(), game.session.units, game.session.world.paused)
	for event: BattleEvent in events:
		if event.kind not in ["fired", "airburst", "surface_impact"]: continue
		recent[event.sequence] = event.snapshot()
		recent_ids.append(event.sequence)
	while recent_ids.size() > 1024: recent.erase(recent_ids.pop_front())
	return events

func save_view(label_value: String, source: Dictionary) -> void:
	if game.camera.mode != "auto": push_error("S07 capture lost automatic mode"); quit(1); return
	game.hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(ProjectSettings.globalize_path(DIRECTORY.path_join(label_value + ".png"))) != OK:
		push_error("S07 auto screenshot write failed")
		quit(1)
		return
	views.append({"view":label_value, "time_s":game.session.world.time_s(), "source_event":source, "source_age_s":game.session.world.time_s() - float(source.time_s), "camera_mode":game.camera.mode, "camera_label":game.camera.shot_label, "followed_id":game.camera.followed_id, "shot_serial":game.camera.shot_serial, "shot_trigger":game.camera.shot_event.duplicate(true), "camera_position_m":game.camera.position, "camera_focus_m":game.camera.focus, "effects":game.effects.statistics()})
