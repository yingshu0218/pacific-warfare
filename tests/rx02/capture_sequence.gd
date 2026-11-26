extends SceneTree

var game: AllUnitsShowcase
var output: String=""
var mode: String="fire"
var frames: int=180
var rows: Array=[]

func _initialize() -> void:
	root.content_scale_size=Vector2i(1280,720)
	root.size=Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--case="):mode=arg.trim_prefix("--case=")
		if arg.begins_with("--frames="):frames=int(arg.trim_prefix("--frames="))
	call_deferred("run")

func save_frame(index: int) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("frame_%04d.png"%index))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://showcase/carrier_harbor.tscn").instantiate() as AllUnitsShowcase
	root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
	var ready: bool=false
	if mode=="follow":
		game.choose_exercise(27);game._action("follow","bomber");ready=true
	else:
		for i: int in 60*45:
			game._process(1.0/60.0)
			if game.presentation_events.any(func(e: BattleEvent)->bool:return e.kind=="fired" and e.entity_id=="us_bb" and e.data.get("mount_role","")=="main"):
				ready=true;break
	if not ready:push_error("actual main-gun release not reached");game.free();quit(1);return
	for frame: int in frames:
		game._process(1.0/144.0 if mode=="follow" else 1.0/30.0)
		rows.append({"frame":frame,"time_s":game.session.world.time_s(),"presentation_time_s":game.session.presentation_time_s,"anchor":game.observer_frame(),"label":game.camera.shot_label,"events":game.presentation_events.map(func(e: BattleEvent)->Dictionary:return {"kind":e.kind,"entity_id":e.entity_id,"time_s":e.time_s}),"effects":game.effects.statistics()})
		await save_frame(frame)
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"case":mode,"frames":frames,"fps":30,"simulation_step_s":1.0/144.0 if mode=="follow" else 1.0/30.0,"not_performance":true,"rows":rows},"\t"))
	game.free();await process_frame;quit()
