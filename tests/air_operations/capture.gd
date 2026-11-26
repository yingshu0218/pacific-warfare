extends SceneTree

const INSPECTOR: Script = preload("res://tests/air_operations/inspection.gd")
const FIX: Script = preload("res://tests/air_operations/fixture.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	AudioServer.set_bus_mute(0,true)
	var output: String = "res://.local/ops01-native"
	var count: int = 1
	var fps: int = 3
	var segment: String = "overview"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.get_slice("=",1)
		if arg == "--two": count = 2
		if arg.begins_with("--fps="): fps = int(arg.get_slice("=",1))
		if arg.begins_with("--segment="): segment = arg.get_slice("=",1)
	if fps not in [3,15,30] or segment not in ["overview","launch","recovery","waveoff","hard_contact"]:
		push_error("OPS01 capture invalid cadence/segment"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view: SubViewport = SubViewport.new(); view.size = Vector2i(960,640); view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var scene: Node3D = INSPECTOR.new(); scene.set("auto_run",false); scene.set("aircraft_count",count); view.add_child(scene)
	var world: SimulationWorld = scene.get("world")
	var ops: CarrierOperations = scene.get("operations")
	var frames: int = 0
	var events: Array[Dictionary] = []
	var samples: Array[Dictionary] = []
	var seen: Dictionary = {}
	var done: bool = false
	# Short segments still run every fixed tick from the original parked state.
	# Fast-forwarding the unrecorded context does not set any unit pose or phase.
	if segment != "overview":
		var reached: bool = false
		for i: int in 900*60:
			world.step_ticks(1); world.drain_events()
			var s: Dictionary = ops.roster.hellcat_1
			if (segment == "launch" and s.phase == "takeoff_roll") or (segment in ["recovery","waveoff","hard_contact"] and s.phase == "approach" and (s.local_m as Vector3).z < (450.0 if segment == "hard_contact" else 550.0)):
				reached = true; break
		if not reached: push_error("OPS01 segment never reached by simulation"); quit(1); return
	if segment == "waveoff": ops.external_block = true
	if segment == "hard_contact": ops.roster.hellcat_1["configuration_pitch_command_deg"] = -2.0
	var start_s: float = world.time_s()
	var duration_s: float = {"overview":900.0,"launch":22.0,"recovery":24.0,"waveoff":12.0,"hard_contact":20.0}[segment]
	for frame: int in roundi(duration_s*fps):
		for j: int in 60/fps:
			world.step_ticks(1)
			for event: BattleEvent in world.drain_events():
				if event.kind.begins_with("carrier_") or event.kind.begins_with("order_"): events.append(event.snapshot())
		if count == 2:
			scene.set("observed_id","hellcat_2" if world.time_s() > 30.0 else "hellcat_1")
		scene.call("refresh")
		await process_frame
		RenderingServer.force_draw(false,0)
		var screenshot: Image = view.get_texture().get_image()
		if screenshot.save_png(output.path_join("frame_%05d.png"%frame)) != OK: push_error("OPS01 frame save failed"); quit(1); return
		for id: String in ops.roster:
			var phase: String = ops.roster[id].phase
			if not seen.has(id+phase):
				seen[id+phase] = frame
				screenshot.save_png("res://docs/showcase/evidence/OPS01/"+id+"-"+phase+".png")
		if segment != "overview" or frame%3 == 0: samples.append({"frame":frame,"time_s":world.time_s(),"units":world.snapshot().units,"operations":ops.snapshot_state(),"geometry_diagnostics":scene.call("geometry_diagnostics")})
		frames += 1
		done = true
		for id: String in ops.roster:
			if int(ops.roster[id].recoveries) != 1 or str(ops.roster[id].phase) != "standby": done = false
		if done or (segment == "launch" and world.time_s()-start_s >= 22.0) or (segment == "recovery" and world.time_s()-start_s >= 24.0): break
	if segment != "overview":
		done = int(ops.roster.hellcat_1.sorties) == 1
		if segment == "recovery":
			var stopped: bool = false
			for row: Dictionary in ops.history:
				if row.reason == "arrest_complete_clear_landing_area": stopped = true
			done = done and stopped and ops.roster.hellcat_1.has("wire_id")
		elif segment == "waveoff": done = done and int(ops.roster.hellcat_1.go_arounds) > 0
		elif segment == "hard_contact": done = done and not world.get_unit("hellcat_1").active and ops.roster.hellcat_1.touchdown_count == 0 and bool(world.get_unit("hellcat_1").module_data.get("carrier_deck_contact",{}).get("settling_stable",false))
	var file: FileAccess = FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(FIX.json_data({"complete":done,"fps":fps,"frames":frames,"segment":segment,"start_s":start_s,"aircraft_count":count,"scope":"Accepted S04 r10 actual model; original force/fleet integration; fixed-tick 15fps segment, no interpolated frames or Chrome performance claim","samples":samples,"events":events,"phase_first_frames":seen,"final":world.snapshot()}),"\t")); file.close()
	print("OPS01_NATIVE complete=",done," frames=",frames," t=",world.time_s())
	quit(0 if done else 1)
