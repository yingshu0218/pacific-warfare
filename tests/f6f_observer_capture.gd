extends SceneTree

## Exact public scene, HUD and default follow distance. Only camera selection and
## fixed-tick stepping are controlled; aircraft/commands/weapons remain untouched.
var game: FirstPlayableGame

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var follow: String = "us_air_2"
	var start_s: float = 66.0
	var duration_s: float = 30.0
	var directory: String = "res://.local/S04-f6f-observer-frames"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--follow="): follow = arg.get_slice("=",1)
		if arg.begins_with("--start="): start_s = float(arg.get_slice("=",1))
		if arg.begins_with("--duration="): duration_s = float(arg.get_slice("=",1))
		if arg.begins_with("--output="): directory = arg.get_slice("=",1)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size = Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	game = (load("res://showcase/first_playable.tscn") as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	if not game.running:
		push_error("F6F public observer scene failed to initialize")
		quit(1)
		return
	while game.session.world.tick < int(start_s*60):
		_tick(mini(60,int(start_s*60)-game.session.world.tick))
	game.camera.follow(follow)
	game.hud._selected_unit = follow
	var samples: Array = []
	for frame: int in range(int(duration_s*15)):
		_tick(4)
		game.camera.update_view(1.0/15,game.session.world.time_s(),game.session.units,false)
		game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
		if frame%15 == 0:
			var unit: UnitState = game.session.world.get_unit(follow)
			samples.append({"time_s":game.session.world.time_s(),"id":follow,"position_m":SimData.array3(unit.position_m),"velocity_mps":SimData.array3(unit.velocity_mps),"rotation_rad":SimData.array3(unit.rotation_rad),"task":unit.task.duplicate(true),"flight":unit.module_data.aircraft_motion.duplicate(true),"camera_m":SimData.array3(game.camera.position),"distance_m":game.camera.distance_m})
		await process_frame
		RenderingServer.force_draw(false,0.0)
		var error: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(directory.path_join("frame_%04d.png" % frame)))
		if error != OK:
			push_error("F6F observer PNG failed")
			quit(1)
			return
	var file: FileAccess = FileAccess.open(directory.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"case":"current","follow":follow,"fps":15,"camera_view":"actual public observer follow, default distance42m","samples":samples},"\t"))
	print("S04 actual F6F observer capture PASS frames=",int(duration_s*15))
	quit(0)

func _tick(count: int) -> void:
	game.session.world.step_ticks(count)
	var events: Array[BattleEvent] = game.session.consume_world()
	game.apply_presentation(events)
