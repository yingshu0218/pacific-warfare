extends SceneTree

## A fixed world-up follow view: no camera orbit/roll and no scripted aircraft path.
## Every frame follows a live, unmodified fixed-tick world with real CombatSuite.
var stage: Node3D
var camera: Camera3D
var world: SimulationWorld
var models: Dictionary = {}
var label: Label
var follow_id: String = "jp_air_1"
var folder: String = "res://.local/S04-spatial-frames"
var case_name: String = "standard"
var start_s: float = 8
var duration_s: float = 24
var fps: int = 15
var offsets: Vector3 = Vector3(-55,24,48)
var trail_points: PackedVector3Array = PackedVector3Array()
var trail: MeshInstance3D
var evidence: Array = []
var effects: CombatEffects
var capture_view: SubViewport
var camera_view: String = "world"
var camera_heading: float = 0.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): case_name = arg.get_slice("=",1)
		if arg.begins_with("--follow="): follow_id = arg.get_slice("=",1)
		if arg.begins_with("--start="): start_s = float(arg.get_slice("=",1))
		if arg.begins_with("--duration="): duration_s = float(arg.get_slice("=",1))
		if arg.begins_with("--output="): folder = arg.get_slice("=",1)
		if arg.begins_with("--view="): camera_view = arg.get_slice("=",1)
	root.size = Vector2i(1100,700)
	capture_view = SubViewport.new()
	capture_view.size = Vector2i(1100,700)
	capture_view.own_world_3d = true
	capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_view)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	world = AircraftSpatialFixture.build(case_name)
	if world.get_unit(follow_id) == null:
		follow_id = "jp_0"
	stage = Node3D.new()
	capture_view.add_child(stage)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b9cfdf")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6e1e8")
	environment.ambient_light_energy = 0.7
	var settings: WorldEnvironment = WorldEnvironment.new()
	settings.environment = environment
	stage.add_child(settings)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-30,0)
	sun.light_energy = 1.0
	stage.add_child(sun)
	camera = Camera3D.new()
	camera.current = true
	camera.far = 40000
	camera.fov = 45
	stage.add_child(camera)
	var sea: MeshInstance3D = MeshInstance3D.new()
	var sea_mesh: PlaneMesh = PlaneMesh.new()
	sea_mesh.size = Vector2(50000,50000)
	sea.mesh = sea_mesh
	var sea_material: StandardMaterial3D = StandardMaterial3D.new()
	sea_material.albedo_color = Color("42677a")
	sea_material.roughness = 1.0
	sea.material_override = sea_material
	stage.add_child(sea)
	if world.shared_state.has("terrain"):
		var terrain_view: IslandHarborView = IslandHarborView.new()
		stage.add_child(terrain_view)
		terrain_view.build(world.shared_state.terrain)
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		var definition: UnitDefinition = world.unit_definition(unit.definition_id)
		if definition.domain != "aircraft": continue
		var packed: PackedScene = load(definition.model_scene)
		var model: Node3D = packed.instantiate() as Node3D
		stage.add_child(model)
		models[id] = model
	label = Label.new()
	label.position = Vector2(20,18)
	label.add_theme_font_size_override("font_size",17)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	capture_view.add_child(label)
	trail = MeshInstance3D.new()
	var trail_material: StandardMaterial3D = StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.albedo_color = Color("dceca9")
	trail.material_override = trail_material
	stage.add_child(trail)
	effects = CombatEffects.new()
	effects.sound_enabled = false
	stage.add_child(effects)
	for tick: int in range(int(start_s*60)):
		world.step_ticks(1)
		world.drain_events()
	camera_heading = AircraftFlightMath.heading(world.get_unit(follow_id).velocity_mps)
	for frame: int in range(int(duration_s*fps)):
		var events: Array[BattleEvent] = []
		for step: int in range(60/fps):
			world.step_ticks(1)
			events.append_array(world.drain_events())
		effects.consume(events,world.generation)
		effects.advance(1.0/fps)
		for id: String in models:
			(models[id] as AircraftAdapter).apply_state(world.get_unit(id).snapshot())
		var unit: UnitState = world.get_unit(follow_id)
		var flight: Dictionary = unit.module_data.aircraft_motion
		var task: Dictionary = unit.task.get("aircraft",{})
		var actual_offset: Vector3 = offsets
		if camera_view in ["rear","side"]:
			var flat: Vector3 = Vector3(unit.velocity_mps.x,0,unit.velocity_mps.z)
			if flat.length() > unit.velocity_mps.length()*0.25:
				var heading_error: float = wrapf(AircraftFlightMath.heading(flat)-camera_heading,-PI,PI)
				camera_heading += clampf(heading_error,-deg_to_rad(60.0)/fps,deg_to_rad(60.0)/fps)
			actual_offset = Basis(Vector3.UP,camera_heading)*Vector3(48,12,10) if camera_view == "side" else Basis(Vector3.UP,camera_heading)*Vector3(-14,12,44)
		camera.position = unit.position_m+actual_offset
		camera.look_at(unit.position_m,Vector3.UP)
		trail_points.append(unit.position_m)
		if trail_points.size() > fps*6: trail_points.remove_at(0)
		var line: ImmediateMesh = ImmediateMesh.new()
		if trail_points.size() > 1:
			line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for point: Vector3 in trail_points: line.surface_add_vertex(point)
			line.surface_end()
		trail.mesh = line
		label.text = "%s | %.2f s | %s / %s\nALT %.0f m  SPEED %.1f m/s  PITCH %.1f deg  BANK %.1f deg  LOAD %.2f g\nROLL %.1f deg/s  PATH CURVATURE %.1f deg/s | %s | %s view; world up" % [follow_id,world.time_s(),task.get("phase","inactive"),task.get("maneuver_phase","idle"),unit.position_m.y,unit.velocity_mps.length(),rad_to_deg(AircraftFlightMath.pitch(unit.velocity_mps)),rad_to_deg(float(flight.bank_rad)),flight.load_factor,rad_to_deg(float(flight.get("body_roll_rate_radps",0))),rad_to_deg(float(flight.get("path_turn_rate_radps",0))),flight.safety_state,camera_view]
		if frame%fps == 0:
			evidence.append({"time_s":world.time_s(),"id":follow_id,"position_m":SimData.array3(unit.position_m),"velocity_mps":SimData.array3(unit.velocity_mps),"rotation_rad":SimData.array3(unit.rotation_rad),"task":task.duplicate(true),"flight":flight.duplicate(true)})
		await process_frame
		# A minimized macOS window suspends the automatic draw loop. Explicitly
		# draw the same live viewport without restoring/focusing the window.
		RenderingServer.force_draw(false,0.0)
		var error: Error = capture_view.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join("frame_%04d.png" % frame)))
		if error != OK:
			push_error("spatial PNG save failed")
			quit(1)
			return
	var file: FileAccess = FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"case":case_name,"follow":follow_id,"fps":fps,"camera_view":camera_view,"camera_offset_m":SimData.array3(offsets),"samples":evidence},"\t"))
	print("S04 spatial native capture PASS frames=",int(duration_s*fps))
	quit(0)
