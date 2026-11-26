extends SceneTree

const TRAIN: Script = preload("res://tests/fixtures/aircraft_training_fixture.gd")
var definition_id: String = "us_f6f5_1944"
var maneuver: String = "axial_roll"
var direction: int = 1
var output: String = "res://.local/s04-training-frames/default"
const FPS: int = 15

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	AudioServer.set_bus_mute(0,true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--definition="): definition_id = arg.get_slice("=",1)
		if arg.begins_with("--maneuver="): maneuver = arg.get_slice("=",1)
		if arg.begins_with("--direction="): direction = int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output = arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1100,700)
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1100,700)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage: Node3D = Node3D.new()
	view.add_child(stage)
	var environment: CloudSeaEnvironment = CloudSeaEnvironment.new()
	stage.add_child(environment)
	var camera: Camera3D = Camera3D.new()
	camera.current = true
	camera.fov = 44
	camera.far = 70000
	stage.add_child(camera)
	var world: SimulationWorld = TRAIN.world(definition_id)
	var submission: Dictionary = TRAIN.order(world,maneuver,direction)
	if not submission.receipt.accepted:
		push_error("Training capture order rejected")
		quit(1);return
	var packed: PackedScene = load(world.unit_definition(definition_id).model_scene)
	var model: AircraftAdapter = packed.instantiate() as AircraftAdapter
	stage.add_child(model)
	var label: Label = Label.new()
	label.position = Vector2(16,16)
	label.add_theme_font_size_override("font_size",17)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	view.add_child(label)
	var samples: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var stop_s: float = INF
	var frames: int = 0
	for frame: int in 65*FPS:
		for i: int in 60/FPS:
			world.step_ticks(1)
			for event: BattleEvent in world.drain_events(): events.append(event.snapshot())
		var unit: UnitState = world.get_unit("pilot")
		var record: Dictionary = TRAIN.record(world)
		var training: Dictionary = unit.module_data.get("aircraft_training",{})
		var flight: Dictionary = unit.module_data.aircraft_motion
		model.apply_state(unit.snapshot())
		camera.position = unit.position_m+Vector3(-16,9,28)
		camera.look_at(unit.position_m,Vector3.UP)
		environment.advance(world.time_s())
		environment.update_observer(camera.position)
		label.text = "S04 REAL BATTLEORDER TRAINING | %s | %s\n%.2f s | %s / %s | roll measured %.1f deg (peak %.1f)\nALT %.0fm AGL %.0fm | SPEED %.1fm/s | PITCH %.1f BANK %.1f | LOAD %.2fg\n%s | fixed world-up camera; no scripted aircraft transforms" % [definition_id,maneuver,world.time_s(),record.status,training.get("phase","rejected"),rad_to_deg(float(training.get("roll_accum_rad",0))),rad_to_deg(float(training.get("peak_roll_rad",0))),unit.position_m.y,flight.height_agl_m,unit.velocity_mps.length(),rad_to_deg(float(flight.path_pitch_rad)),rad_to_deg(float(flight.bank_rad)),flight.load_factor,record.reason]
		if frame%3 == 0: samples.append({"time_s":world.time_s(),"unit":unit.snapshot(),"order":record,"camera_position_m":camera.position})
		if record.status in BattleOrder.TERMINAL and is_inf(stop_s): stop_s = world.time_s()+3.0
		await process_frame
		RenderingServer.force_draw(false,0)
		var saved: Error = view.get_texture().get_image().save_png(output.path_join("frame_%04d.png"%frame))
		if saved != OK: push_error("Training PNG save failed");quit(1);return
		frames += 1
		if world.time_s() >= stop_s: break
	var final: Dictionary = TRAIN.record(world)
	var file: FileAccess = FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(AircraftDamageFixture.json_data({"scope":"Real high-level BattleOrder, production aircraft task/controller/force integration, fixed world-up camera; recording cadence is not performance.","definition_id":definition_id,"maneuver":maneuver,"direction":direction,"fps":FPS,"frames":frames,"resolution":[1100,700],"request":submission.request.request_data(),"final":final,"samples":samples,"events":events}),"\t"))
	if final.status != "completed": push_error("Training capture did not complete: "+str(final));quit(1);return
	print("S04 training native PASS ",definition_id," ",maneuver," frames=",frames)
	quit(0)
