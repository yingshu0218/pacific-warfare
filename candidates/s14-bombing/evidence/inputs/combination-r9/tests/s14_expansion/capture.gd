extends SceneTree

const MAIN: PackedScene = preload("res://showcase/carrier_harbor.tscn")
var game: AllUnitsShowcase
var segment: String = "inventory"
var output: String = ""
var samples: Array = []
var events: Array = []
var source_manifest: Dictionary = {}
var static_installations: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	game = MAIN.instantiate() as AllUnitsShowcase
	root.add_child(game)
	await process_frame
	game.set_process(false)
	if not game.running: quit(1); return
	if FileAccess.file_exists("res://source-manifest.json"): source_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://source-manifest.json"))
	DirAccess.make_dir_recursive_absolute(output)
	if segment == "inventory":
		await inventory()
	else:
		await record_segment()
	game.free()
	await process_frame
	quit()

func advance(ticks: int, present: bool = true) -> void:
	game.session.world.step_ticks(ticks)
	var drained: Array[BattleEvent] = game.session.consume_world()
	for event: BattleEvent in drained:
		if event.kind.begins_with("carrier_") or event.kind in ["order_issued","order_status_changed","command_rejected","hit","damaged","damage_phase"]: events.append(event.snapshot())
	if present:
		game.apply_presentation(drained)
		game._update_guide(float(ticks)/60.0)
		game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
		game._refresh_guide_ui()

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func inventory() -> void:
	advance(60)
	await shot("normal_harbor")
	var map: Dictionary = game.session.world.shared_state.terrain
	game.guide.active = false
	for point: Dictionary in map.source.viewpoints:
		if not point.id in ["map02_civil_low","map02_naval_low","map02_airfield","map02_ridge"]: continue
		game.camera.locate_map(point); game.camera.update_view(0,game.session.world.time_s(),game.session.units,true)
		game._refresh_guide_ui(); await shot(str(point.id))
	for id: String in ["us_cv","jp_cv"]:
		game._action("follow",id)
		game.camera.update_view(0,game.session.world.time_s(),game.session.units,true)
		await shot(id)
	for index: int in [21,22,23]:
		game.choose_exercise(index); advance(60)
		static_installations.append(check_static({21:"d4y2",22:"g4m1",23:"b25j"}[index]))
		await shot({21:"d4y2",22:"g4m1",23:"b25j"}[index])
	game.choose_exercise(20); advance(60); await shot("partial_wave_rejected")
	game.hud.cinema_button.pressed.emit()
	for value: Node in game.hud.root.find_children("*","Button",true,false):
		if (value as Button).text == "指挥态势": (value as Button).pressed.emit()
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label);game._refresh_guide_ui()
	await shot("real_carrier_commands")
	var transitions: Array = []
	for index: int in range(16):
		game.choose_exercise(index); advance(4)
		transitions.append({"mode":game.exercise,"models":game.models.size(),"units":game.session.units.size(),"generation":game.session.world.generation})
	game.choose_exercise(16);advance(4);transitions.append({"mode":game.exercise,"models":game.models.size(),"units":game.session.units.size(),"generation":game.session.world.generation})
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(json_data({"segment":segment,"transitions":transitions,"events":events,"models":game.models.keys(),"static_models":(game.get("static_models") as Dictionary).keys(),"static_installations":static_installations,"resolution":[1280,720],"source_manifest":source_manifest}),"\t"))

func check_static(id: String) -> Dictionary:
	var models: Dictionary = game.get("static_models")
	var model: Node3D = models[id]
	var c: Dictionary = (model.get_script() as Script).get_script_constant_map()
	var rows: Array = []
	for side: float in [-1.0,1.0]: rows.append({"point":(c.MAIN_WHEEL_CENTER_M as Vector3)*Vector3(side,1,1),"radius":c.MAIN_WHEEL_RADIUS_M})
	rows.append({"point":c.NOSE_WHEEL_CENTER_M if id == "b25j" else c.TAIL_WHEEL_CENTER_M,"radius":c.NOSE_WHEEL_RADIUS_M if id == "b25j" else c.TAIL_WHEEL_RADIUS_M})
	var contacts: Array = []
	var max_error: float = 0
	for row: Dictionary in rows:
		var center: Vector3 = model.global_transform*(row.point as Vector3)
		var axis: Vector3 = model.global_basis.x.normalized()
		var foot: Vector3 = center-(Vector3.UP-axis*axis.dot(Vector3.UP)).normalized()*float(row.radius)
		var height: float = TerrainQueries.height_data(game.session.world.shared_state.terrain,foot,true)
		if id == "d4y2":
			var carrier: Node3D = game.models.jp_cv
			var local: Vector3 = carrier.to_local(foot)
			height = float(carrier.visual.deck_surface_at(Vector2(local.x,local.z)).height_m)+carrier.global_position.y
		max_error = maxf(max_error,absf(foot.y-height))
		contacts.append({"foot_m":foot,"actual_surface_height_m":height})
	if max_error>.006: push_error("Static wheel installation "+id+" error="+str(max_error))
	return {"model":id,"position_m":model.global_position,"rotation_rad":model.global_rotation,"scale":model.global_basis.get_scale(),"wheel_contacts":contacts,"max_error_m":max_error,"simulation_unit":false,"flight_bombing_ops_damage_admitted":false}

func record_segment() -> void:
	game.choose_exercise(18)
	if not game.hud.cinema: game.hud.cinema_button.pressed.emit()
	var found: bool = false
	for second: int in range(2600*2):
		advance(30,false)
		var s: Dictionary = game.session.world.get_unit("us_deck_1").module_data.carrier_ops
		if segment == "launch" and s.phase == "takeoff_roll" and float(s.local_m.z)<-50: found = true
		elif segment == "recovery" and s.phase == "approach" and float(s.local_m.z)<220: found = true
		elif segment == "second_launch" and s.phase == "takeoff_roll" and int(s.sorties)>=1: found = true
		elif segment == "service" and s.phase == "servicing": found = true
		if found: break
		if second%120 == 0: print("CAPTURE_PREROLL ",segment," ",game.session.world.time_s()," ",s.phase)
	if not found: push_error("Capture phase not reached: "+segment); return
	var frames: int = {"launch":120,"recovery":180,"second_launch":120,"service":480}[segment]
	for frame: int in range(frames):
		advance(4)
		var u: UnitState = game.session.world.get_unit("us_deck_1")
		samples.append({"time_s":game.session.world.time_s(),"position_m":u.position_m,"rotation_rad":u.rotation_rad,"velocity_mps":u.velocity_mps,"carrier":game.session.world.get_unit("us_cv").snapshot(),"ops":u.module_data.carrier_ops.duplicate(true),"aircraft_motion":u.module_data.aircraft_motion.duplicate(true),"label":game.guide_status.text,"operation_text":(game.get("operation_text") as Label).text,"camera":{"position":game.camera.position,"focus":game.camera.focus}})
		await shot("frame_%04d"%frame)
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(json_data({"segment":segment,"fps":15,"frames":frames,"resolution":[1280,720],"samples":samples,"events":events,"pre_roll_simulated_all_ticks":true,"sampling_is_not_performance":true,"source_manifest":source_manifest}),"\t"))

static func json_data(value: Variant) -> Variant:
	if value is Vector3: return SimData.array3(value)
	if value is Dictionary:
		var out: Dictionary = {}
		for key: String in value: out[key] = json_data(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value: out.append(json_data(item))
		return out
	return value
