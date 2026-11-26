extends SceneTree

const DEMO: Script=preload("res://tests/fixtures/fx01_demo.gd")
var game: FirstPlayableGame
var demo: Node3D
var directory: String="res://docs/showcase/evidence/FX01/native"
var baseline: bool=false
var audit: Dictionary={"scope":"Controlled real projectile witness in frozen S10/S13 environment; not natural AI battle","views":[],"frames":[]}

func _initialize() -> void:
	baseline="--baseline" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):directory=arg.trim_prefix("--evidence-dir=")
	call_deferred("run")

func draw() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false,0.)

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-1800,0))
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	game=(load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	game.session.world.set_paused(true)
	game.hud.hide()
	game.effects.hide()
	game.camera.mode="free"
	game.camera.followed_id=""
	demo=DEMO.new()
	root.add_child(demo)
	demo.configure(baseline)
	for label_value: String in ["water","flak","tracer","smoke"]:
		demo.start(label_value)
		var count: int=55 if label_value=="water" else 75 if label_value=="flak" else 34 if label_value=="tracer" else 60
		if not baseline:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory.path_join(label_value)))
		for frame: int in count:
			demo.step_ticks(6)
			demo.camera_pose(game.camera)
			game.environment_view.advance(float(demo.arena.world.time_s()))
			game.environment_view.update_observer(game.camera.position)
			if not baseline or frame in [3,10,20]:
				await draw()
				var relative: String=label_value+"/frame_%03d.png"%frame
				if baseline:relative=label_value+"_%02d.png"%frame
				root.get_texture().get_image().save_png(directory.path_join(relative))
				audit.frames.append({"file":relative,"case":label_value,"age_s":demo.age_s,"effects":demo.effects.statistics(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
			if frame==10:
				audit.views.append(demo.snapshot())
				if not baseline:
					demo.camera_pose(game.camera,true)
					game.environment_view.update_observer(game.camera.position)
					await draw()
					root.get_texture().get_image().save_png(directory.path_join(label_value+"_observer.png"))
			if label_value=="smoke" and frame==30 and not baseline:
				var point: Vector3=demo.arena.world.get_unit("plane").position_m
				game.camera.position=point+Vector3(18,9,-23)
				game.camera.look_at(point+Vector3(0,.5,-1.5))
				await draw()
				root.get_texture().get_image().save_png(directory.path_join("smoke_engine.png"))
			if label_value=="water" and frame==15 and not baseline:
				game.camera.position=Vector3(27,30,55)
				game.camera.look_at(Vector3(-18,14,0))
				await draw()
				root.get_texture().get_image().save_png(directory.path_join("water_close.png"))
		var file: FileAccess=FileAccess.open(directory.path_join(label_value+"_events.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(demo.event_log,"\t"));file.close()
	var file: FileAccess=FileAccess.open(directory.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(audit,"\t"));file.close()
	demo.free();game.free()
	print("FX01 native controlled capture saved; baseline=",baseline)
	quit(0)
