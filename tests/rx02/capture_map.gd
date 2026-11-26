extends SceneTree

var output: String = ""
var frames: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func capture(label: String, camera: Camera3D, water: MeshInstance3D) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	frames.append({"image":path,"camera_position":SimData.array3(camera.position),"near":camera.near,"far":camera.far,"water":water.visible})

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var session: FirstPlayableSession = FirstPlayableSession.new()
	if not session.load_battle("res://data/scenarios/s14_expansion_harbor.json").is_empty(): quit(1);return
	var environment: CloudSeaEnvironment = CloudSeaEnvironment.new()
	root.add_child(environment)
	if environment.has_method("set_terrain"):environment.set_terrain(session.world.shared_state.terrain)
	var map_view: IslandHarborView = load("res://scripts/map02/expanded_map_view.gd").new()
	root.add_child(map_view);map_view.build(session.world.shared_state.terrain)
	var camera: ObserverCamera = ObserverCamera.new()
	root.add_child(camera)
	camera.far = 70000
	for view: Dictionary in [{"id":"far","at":Vector3(2000,2400,18000),"focus":Vector3(0,0,-3600)},{"id":"overview","at":Vector3(3000,19000,5000),"focus":Vector3(800,0,-700)},{"id":"port","at":Vector3(-3200,120,-1800),"focus":Vector3(-4850,20,-3330)}]:
		camera.position = view.at;camera.look_at(view.focus,Vector3.UP);environment.update_observer(camera.position)
		for near_plane: float in [.06,.8,4.0,16.0]:
			camera.near = near_plane;environment.water.visible = true
			await capture(view.id+"_near_"+str(near_plane),camera,environment.water)
		environment.water.visible = false
		await capture(view.id+"_no_sea",camera,environment.water)
		if view.id == "far":
			environment.water.visible = true;camera.near = .8
			for i: int in 16:
				camera.position.x = float(view.at.x)+i*.2;camera.look_at(view.focus,Vector3.UP);environment.update_observer(camera.position)
				await capture("moving_%02d"%i,camera,environment.water)
	var mesh_bounds: AABB = (map_view.get_node("IslandTerrain") as MeshInstance3D).get_aabb()
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"frames":frames,"terrain_bounds_position":SimData.array3(mesh_bounds.position),"terrain_bounds_size":SimData.array3(mesh_bounds.size),"scope":"Paused actual CloudSea/expanded-map renderer, no terrain or combat edits"},"\t"))
	environment.free();map_view.free();camera.free();await process_frame;quit()
