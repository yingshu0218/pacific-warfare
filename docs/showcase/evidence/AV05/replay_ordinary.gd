extends SceneTree

const HARBOR: PackedScene = preload("res://showcase/carrier_harbor.tscn")
const POSES: Dictionary = {
	"front": Vector3(.78,.34,-.91), "side": Vector3(1.32,.08,-.02),
	"rear": Vector3(-.84,.28,1.02), "follow": Vector3(-1.15,.55,1.62),
}

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var directory: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(directory)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	var game: Node = HARBOR.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_process_input(false)
	await process_frame
	var detail: Array[Dictionary] = []
	for mode: String in ["attack_g4m","attack_d4y"]:
		game.choose_exercise(game.MODES.size()+game.NEW_MODES.find(mode))
		if not game.running or not game.models.has("bomber"):
			push_error("Normal exercise failed "+mode)
			quit(2)
			return
		for frame: int in 12:
			game._process(1./30.)
		game.hud.hide()
		var plane: Node3D = game.models.bomber
		var definition: UnitDefinition = game.session.catalog.unit(game.session.units.bomber.definition_id)
		var span: float = definition.dimensions_m.x
		var camera: Camera3D = game.camera
		var node_count: int = plane.find_children("*","MeshInstance3D",true,false).size()
		for name_key: String in POSES:
			var focus: Vector3 = plane.global_transform * Vector3(0,.025*span,0)
			var offset: Vector3 = POSES[name_key] * span
			camera.global_position = focus + plane.global_basis.orthonormalized()*offset
			camera.look_at(focus,Vector3.UP)
			camera.fov = 46.
			camera.near = .4
			camera.make_current()
			camera.force_update_transform()
			game.environment_view.update_observer(camera.global_position)
			await process_frame
			RenderingServer.force_draw(false,0.)
			var path: String = directory.path_join(mode+"-"+name_key+".png")
			var error: Error = root.get_texture().get_image().save_png(path)
			if error != OK:
				push_error("Cannot save "+path)
				quit(3)
				return
			detail.append({"scene":game.session.scenario.id,"subject":plane.name,"definition":game.metadata.bomber.definition_id,"pose":name_key,"span":span,"mesh_nodes":node_count,"simulation_time_s":game.session.world.time_s(),"camera_m":SimData.array3(camera.global_position),"focus_m":SimData.array3(focus),"size":[960,540]})
	var f: FileAccess = FileAccess.open(directory.path_join("viewpoints.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(detail,"\t")+"\n")
	game.queue_free()
	await process_frame
	print("Ordinary aircraft exercises photographed at eight viewpoints")
	quit()
