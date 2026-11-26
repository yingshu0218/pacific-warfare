extends SceneTree

var stage: Node3D
var camera: Camera3D
var output_dir: String = "res://docs/showcase/evidence/S04"
var metrics: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,800)
	stage = Node3D.new()
	root.add_child(stage)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("d9e1e5")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d1dce4")
	environment.ambient_light_energy = 0.65
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-30,0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	stage.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.far = 20000
	stage.add_child(camera)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	for id: String in ["jp_a6m5a_1944", "us_f6f5_1944"]:
		var model: AircraftAdapter = AircraftAdapter.new()
		model.model_id = id
		stage.add_child(model)
		model.apply_state({"module_data":{"aircraft_motion":{"propeller_phase_rad":0.35}}})
		var views: Dictionary = {"side":Vector3(-25,1,0),"front":Vector3(0,1,-25),"top":Vector3(0,25,0.01),"quarter":Vector3(-16,10,-18),"underside":Vector3(12,-12,-15)}
		for view: String in views:
			camera.position = views[view]
			camera.size = 12 if view == "top" else (9 if view == "front" else 10)
			camera.look_at(Vector3.ZERO)
			await _save(id+"_"+view)
		var triangle_count: int = 0
		var meshes: int = 0
		for part: Node in model.find_children("*","MeshInstance3D",true,false):
			var mesh: Mesh = (part as MeshInstance3D).mesh
			if mesh != null:
				triangle_count += mesh.get_faces().size() / 3
				meshes += 1
		metrics[id] = {"triangles":triangle_count,"mesh_instances":meshes,"sockets":model.mount_sockets(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		model.free()
	# Independent fixed-tick flight with a visible, continuously changing bank.
	var world: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("lead","jp",Vector3(0,1500,0)),AircraftFixture.spawn("wing","jp",Vector3(90,1545,150))])
	AircraftFixture.order(world,"capture_patrol",["lead","wing"],"patrol","",Vector3(-1800,1800,-2200),1800)
	var models: Dictionary = {}
	for id: String in world.unit_ids():
		var model: AircraftAdapter = AircraftAdapter.new()
		stage.add_child(model)
		models[id] = model
	var frames: Array = []
	for frame: int in range(7):
		if frame > 0:
			for tick: int in range(240):
				world.step_ticks(1)
				world.drain_events()
		for id: String in models:
			(models[id] as AircraftAdapter).apply_state(world.get_unit(id).snapshot())
		var lead: UnitState = world.get_unit("lead")
		camera.position = lead.position_m + Vector3(-16,9,-18)
		camera.size = 11
		camera.look_at(lead.position_m)
		await _save("motion_%02d" % frame)
		frames.append({"time_s":world.time_s(),"lead":lead.snapshot(),"wing":world.get_unit("wing").snapshot()})
	metrics["motion_frames"] = frames
	var file: FileAccess = FileAccess.open(output_dir.path_join("capture-metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	print("S04 native capture PASS 10 model views + 7 real flight keyframes; auto exit")
	quit(0)

func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output_dir.path_join(name + ".png")))
	if error != OK:
		push_error("S04 capture save failed: " + name)
		quit(1)
