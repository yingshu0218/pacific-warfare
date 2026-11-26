extends SceneTree

var output: String = ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,720)
	var game: AllUnitsShowcase=(load("res://showcase/carrier_harbor.tscn") as PackedScene).instantiate() as AllUnitsShowcase
	root.add_child(game);await process_frame;game.set_process(false)
	game.choose_exercise(27);game.guide.active=false;game.camera.follow("bomber")
	var samples: Array=[]
	for i: int in 432:
		game._process(1.0/144.0)
		var model: Node3D=game.models.bomber
		var screen: Vector2=game.camera.unproject_position(model.global_position)
		samples.append({"wall_s":float(i+1)/144.0,"tick":game.session.world.tick,"actual_position":SimData.array3(game.session.units.bomber.position_m),"model_position":SimData.array3(model.global_position),"focus":SimData.array3(game.camera.focus),"camera_position":SimData.array3(game.camera.position),"screen":[screen.x,screen.y]})
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"scope":"Actual normal B25 adapter/camera pipeline at144Hz render scheduling and60Hz simulation","samples":samples},"\t"))
	game.free();await process_frame;quit()
