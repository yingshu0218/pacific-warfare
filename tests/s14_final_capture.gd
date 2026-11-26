extends SceneTree

var game: AllUnitsShowcase
var mode: String = "train_us_axial_roll"
var output: String = "res://docs/showcase/evidence/S14/final/native/default"
var fps: int = 15
var limit_s: float = 65
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var keys: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func draw() -> void:
	await process_frame
	RenderingServer.force_draw(false,0)
func tick(count: int) -> void:
	game.session.world.step_ticks(count)
	var batch: Array[BattleEvent] = game.session.consume_world()
	for event: BattleEvent in batch: events.append(event.snapshot())
	game.apply_presentation(batch)
	game._update_guide(float(count)/60)
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	game._refresh_guide_ui()
func picture(name: String) -> void:
	await draw()
	var err: Error = root.get_texture().get_image().save_png(output.path_join(name+".png"))
	if err != OK: push_error("S14 PNG save failed "+name)

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	AudioServer.set_bus_mute(0,true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode=arg.get_slice("=",1)
		if arg.begins_with("--output="): output=arg.get_slice("=",1)
		if arg.begins_with("--fps="): fps=int(arg.get_slice("=",1))
		if arg.begins_with("--limit="): limit_s=float(arg.get_slice("=",1))
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game=(load("res://showcase/all_units.tscn") as PackedScene).instantiate() as AllUnitsShowcase
	root.add_child(game)
	game.set_process(false)
	if not game.running: push_error("S14 scene did not start"); quit(1); return
	if mode=="inventory":
		await inventory()
		quit(0)
		return
	var index: int = AllUnitsShowcase.MODES.find(mode)
	if index<0: push_error("Unknown S14 exercise "+mode);quit(1);return
	game.choose_exercise(index)
	var stop_s: float = INF
	var frames: int = 0
	var final: Dictionary = {}
	for frame: int in int(limit_s*fps):
		tick(60/fps)
		var training: Dictionary = game.training_view() if not game.missions.training_order_id.is_empty() else {}
		var phase: String = str(training.get("phase",game.missions.cycle_status))
		var projections: Dictionary = {}
		for id: String in game.guide_state.get("ids",[]):
			var point: Vector2 = game.camera.unproject_position(game.session.units[id].position_m)
			projections[id] = [point.x,point.y]
		var units: Dictionary = {}
		for id: String in game.session.units:
			var unit: Dictionary = game.session.units[id]
			if not unit.module_data.has("aircraft_motion"): continue
			units[id] = {"active":unit.active,"position_m":unit.position_m,"velocity_mps":unit.velocity_mps,"rotation_rad":unit.rotation_rad,"task":unit.task.duplicate(true),"flight":unit.module_data.aircraft_motion.duplicate(true),"training":unit.module_data.get("aircraft_training",{}).duplicate(true),"formation":unit.module_data.get("air_formation",{}).duplicate(true),"damage":unit.module_data.get("damage",{}).duplicate(true)}
		samples.append({"time_s":game.session.world.time_s(),"units":units,"guide":game.guide_state.duplicate(true),"training":training,"mission":game.missions.snapshot_state(),"orders":game.session.orders.duplicate(true) if frame%fps==0 else [],"camera":{"position_m":game.camera.position,"focus_m":game.camera.focus,"projected_subjects":projections},"label":game.guide_status.text})
		await picture("frame_%04d"%frame)
		frames+=1
		if not keys.has(phase):
			keys[phase] = {"frame":frame,"time_s":game.session.world.time_s()}
			root.get_texture().get_image().save_png(output.path_join("phase_"+phase+".png"))
		if training.get("status","") == "completed" and is_inf(stop_s): stop_s=game.session.world.time_s()+3
		if game.missions.cycle_completed_s>=0 and is_inf(stop_s): stop_s=game.session.world.time_s()+8
		if training.get("status","") in ["failed","aborted"]: final=training;break
		if game.session.world.time_s()>=stop_s: break
	final = game.training_view() if not game.missions.training_order_id.is_empty() else game.missions.snapshot_state()
	var passed: bool = final.get("status","")=="completed" if not game.missions.training_order_id.is_empty() else game.missions.cycle_completed_s>=0
	var audit: Dictionary = {"mode":mode,"resolution":[1280,720],"fps":fps,"frames":frames,"scope":"Actual AllUnitsShowcase, 19 units, production fixed ticks and public BattleOrders. Recording cadence is not performance.","source_manifest":JSON.parse_string(FileAccess.get_file_as_string("res://freeze_manifest.json")),"harness_sha256":FileAccess.get_sha256("res://tests/s14_final_capture.gd"),"samples":samples,"events":events,"final":final,"phase_keys":keys,"passed":passed}
	var file: FileAccess = FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(json_data(audit),"\t"))
	if not passed: push_error("S14 native cycle incomplete "+mode+" "+str(final))
	game.queue_free();await process_frame
	print("S14 native ",mode," frames=",frames," passed=",passed)
	quit(0 if passed else 1)

func inventory() -> void:
	tick(120)
	await picture("normal_ui")
	for id: String in ["jp_bb","us_bb","jp_dd","us_dd","us_pair_demo_1","jp_air_1","us_sb2c_1","us_coast_01","us_aa_01"]:
		game._action("follow",id)
		game.hud._selected_unit=id
		tick(1)
		game.camera.update_view(0,game.session.world.time_s(),game.session.units,true)
		await picture(id)
	for index: int in game.gallery.entries.size():
		game.inspect_weapon(index)
		await picture("weapon_%d"%index)
	game.hud.cinema=false;game.hud.expanded=true;game.hud._layout()
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	game._refresh_guide_ui()
	await picture("real_orders")
	var file: FileAccess=FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(json_data({"mode":"inventory","models":game.models.keys(),"gallery":game.gallery.entries,"orders":game.session.world.orders_snapshot(),"source_manifest":JSON.parse_string(FileAccess.get_file_as_string("res://freeze_manifest.json")),"resolution":[1280,720]}),"\t"))
	game.queue_free();await process_frame

static func json_data(value: Variant) -> Variant:
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Vector2: return [value.x,value.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)]=json_data(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value: result.append(json_data(item))
		return result
	return value
