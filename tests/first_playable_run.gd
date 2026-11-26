extends SceneTree

## Runs the actual S07 scenario and all three formal suites. No fixtures or injected orders.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var seconds: int = 600
	var output: String = "res://.local/s07_probe.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds = int(arg.get_slice("=", 1))
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle()
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	var started_ms: int = Time.get_ticks_msec()
	var camera: ObserverCamera = ObserverCamera.new()
	root.add_child(camera)
	var camera_definitions: Dictionary = {}
	for id: String in session.units:
		var definition: UnitDefinition = session.catalog.unit(session.units[id].definition_id)
		camera_definitions[id] = ObserverCamera.describe_unit(definition)
	camera.reset_view(session.world.generation, camera_definitions)
	camera.views = session.units
	camera.followed_id = "jp_bb"
	camera.fit_unit("jp_bb")
	camera.shot_label = "舰队跟随"
	camera.hold_s = 10.0
	var shots: Array[Dictionary] = []
	var visible_events: Array[Dictionary] = []
	var shot_key: String = ""
	for index: int in range(seconds * 60):
		session.world.step_ticks(1)
		var events: Array[BattleEvent] = session.consume_world()
		camera.consume(events)
		camera.update_view(1.0 / 60.0, session.world.time_s(), session.units, session.world.paused)
		for event: BattleEvent in events:
			if event.kind == "fired" and camera.followed_id == event.entity_id and camera.is_position_in_frustum(event.position_m):
				if camera_definitions[event.entity_id].domain == "aircraft" or float(event.data.get("caliber_m", 0.0)) >= 0.3:
					visible_events.append({"kind":event.kind, "entity_id":event.entity_id, "sequence":event.sequence, "time_s":event.time_s, "caliber_m":event.data.caliber_m, "shot_serial":camera.shot_serial, "label":camera.shot_label})
		var key: String = str(camera.shot_serial)
		if key != shot_key:
			shot_key = key
			shots.append({"time_s":session.world.time_s(), "label":camera.shot_label, "followed_id":camera.followed_id, "position_m":camera.position, "focus_m":camera.focus, "trigger":camera.shot_event.duplicate(true)})
			if camera.shot_event.get("kind", "") in ["airburst", "surface_impact"]:
				visible_events.append({"kind":camera.shot_event.kind, "sequence":camera.shot_event.get("sequence", 0), "time_s":camera.shot_event.time_s, "observed_time_s":session.world.time_s(), "age_s":session.world.time_s() - float(camera.shot_event.time_s), "shot_serial":camera.shot_serial, "label":camera.shot_label})
		if (index + 1) % 3600 == 0:
			print("S07 actual scenario ", (index + 1) / 60, "s; events ", session.counts)
		if not session.ended_reason.is_empty(): break
	session.refresh_view(true)
	var result: Dictionary = {"scenario":session.scenario.id, "seed":session.world.seed_value, "time_s":session.world.time_s(), "wall_s":float(Time.get_ticks_msec() - started_ms) / 1000.0, "ended_reason":session.ended_reason, "counts":session.counts, "phases":session.phases.keys(), "event_samples":session.event_samples, "report":session.report(), "outcomes":session.outcomes, "orders":session.orders, "units":session.units, "journal":session.journal, "last_sequence":session.last_sequence, "pending_events":session.world.drain_events().size(), "automatic_camera_shots":shots, "automatic_camera_visible_events":visible_events}
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("S07 cannot write audit")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("S07 actual scenario audit: ", output)
	quit(0)
