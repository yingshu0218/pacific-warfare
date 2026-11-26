extends SceneTree

var game: FirstPlayableGame
var views: Array[Dictionary] = []
var directory: String = "res://docs/showcase/evidence/S07"
var captured: Dictionary = {}
var damage_only: bool = false
var wanted: PackedStringArray = ["gunnery", "air_defence", "water_impact", "air_combat", "damage", "persistent_damage"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.content_scale_size = Vector2i(1280, 720)
	damage_only = "--damage-only" in OS.get_cmdline_user_args()
	if damage_only: wanted = ["persistent_damage"]
	var packed: PackedScene = load("res://showcase/first_playable.tscn") as PackedScene
	game = packed.instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	if not game.running:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for index: int in range(120): tick()
	game.hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
	if not damage_only: await save_view("default_command_cards")
	game.hud.expanded = true
	game.hud._layout()
	game.hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
	if not damage_only: await save_view("command_timeline")
	game.hud.expanded = false
	game.hud._layout()
	if not "--smoke-ui" in OS.get_cmdline_user_args():
		game.hud.cinema = true
		game.hud._layout()
		for index: int in range(600 * 60):
			var events: Array[BattleEvent] = tick()
			for event: BattleEvent in events:
				var shot_name: String = ""
				if event.kind == "salvo" and event.entity_id.ends_with("bb"): shot_name = "gunnery"
				elif event.kind == "airburst": shot_name = "air_defence"
				elif event.kind == "surface_impact" and float(event.data.get("caliber_m", 0.0)) >= 0.3: shot_name = "water_impact"
				elif event.kind == "fired" and game.metadata[event.entity_id].domain == "aircraft": shot_name = "air_combat"
				elif event.kind == "damaged": shot_name = "damage"
				if shot_name.is_empty() or not wanted.has(shot_name) or captured.has(shot_name): continue
				captured[shot_name] = event.snapshot()
				if shot_name in ["air_defence", "water_impact"]:
					game.camera.locate(event.position_m)
					game.camera.distance_m = 70.0 if shot_name == "air_defence" else 140.0
					game.camera.pitch = 0.35
				else:
					var id: String = event.target_id if shot_name == "damage" else event.entity_id
					game.camera.follow(id)
					game.hud._selected_unit = id
					if shot_name == "gunnery": game.camera.distance_m *= 0.7
				game.camera.update_view(0.0, game.session.world.time_s(), game.session.units, true)
				game.hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
				# Give real water columns and gun recoil time to develop, still using real ticks.
				if shot_name in ["water_impact", "damage", "gunnery", "air_defence", "air_combat"]:
					for later: int in range(3 if shot_name in ["gunnery", "air_combat"] else (24 if shot_name == "water_impact" else 8)): tick()
				await save_view(shot_name)
				break
			if not captured.has("persistent_damage"):
				for id: String in game.session.units:
					var view: Dictionary = game.session.units[id]
					var damage: Dictionary = view.module_data.get("damage", {})
					if float(damage.get("fire", 0.0)) < 0.12: continue
					captured["persistent_damage"] = {"time_s":game.session.world.time_s(), "unit_id":id, "damage":damage.duplicate(true), "position_m":view.position_m}
					game.camera.follow(id)
					game.camera.distance_m = 52.0 if game.metadata[id].domain == "aircraft" else 190.0
					game.hud._selected_unit = id
					for later: int in range(120): tick()
					game.hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
					await save_view("persistent_damage")
					break
			if captured.size() >= wanted.size(): break
			if not game.session.ended_reason.is_empty(): break
			if index % 600 == 0: await process_frame
	# Exercise real UI action handlers and ensure resets cannot duplicate model instances.
	var reset_results: Array = []
	for index: int in range(3):
		game._action("restart", null)
		for later: int in range(120): tick()
		reset_results.append({"generation":game.session.world.generation, "units":game.session.units.size(), "models":game.models.size(), "orders":game.session.orders.size(), "events":game.session.last_sequence})
	var file: FileAccess = FileAccess.open(directory.path_join("persistent_damage_audit.json" if damage_only else "capture_audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Actual first_playable.tscn, formal model and simulation modules; native only", "views":views, "captured_events":captured, "restart_runs":reset_results}, "\t"))
	file.close()
	print("S07 native captures: ", views.size())
	var missing: PackedStringArray = []
	if not "--smoke-ui" in OS.get_cmdline_user_args():
		for label_value: String in wanted:
			if not captured.has(label_value): missing.append(label_value)
	if not missing.is_empty(): push_error("S07 missing actual capture states: " + str(missing))
	quit(0 if missing.is_empty() else 1)

func tick() -> Array[BattleEvent]:
	game.session.world.step_ticks(1)
	var events: Array[BattleEvent] = game.session.consume_world()
	game.apply_presentation(events)
	game.camera.update_view(1.0 / 60.0, game.session.world.time_s(), game.session.units, true)
	return events

func save_view(label_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = directory.path_join(label_value + ".png")
	if root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("S07 screenshot save failed")
		quit(1)
		return
	views.append({"view":label_value, "time_s":game.session.world.time_s(), "counts":game.session.counts.duplicate(), "effects":game.effects.statistics(), "camera_mode":game.camera.mode, "followed_id":game.camera.followed_id, "selected_id":game.hud._selected_unit, "selected_damage":game.session.units[game.hud._selected_unit].module_data.get("damage", {}).duplicate(true)})
	var progress: FileAccess = FileAccess.open(directory.path_join("persistent_damage_progress.json" if damage_only else "capture_progress.json"), FileAccess.WRITE)
	progress.store_string(JSON.stringify({"scope":"Partial capture progress; final status is capture_audit.json plus validation report", "views":views}, "\t"))
	progress.close()
