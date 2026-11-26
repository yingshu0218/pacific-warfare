extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output: String = "res://.local/s08-20261111/replay.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var results: Array = []
	for scenario: Dictionary in [{"mode":"guided","seconds":120},{"mode":"four","seconds":160},{"mode":"train_us_axial_roll","seconds":18},{"mode":"fire","seconds":80}]:
		var session: FirstPlayableSession = FirstPlayableSession.new()
		var errors: PackedStringArray = session.load_battle("res://data/scenarios/s14_"+scenario.mode+".json")
		if not errors.is_empty(): push_error(str(errors)); quit(1); return
		var missions: ShowcaseMissions = ShowcaseMissions.new(scenario.mode)
		if not session.world.register_module(missions).accepted: push_error("missions install"); quit(1); return
		session.world.profile_enabled = true
		var hash: HashingContext = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		var checkpoints: Array = []
		for index: int in int(scenario.seconds)*60:
			session.world.step_ticks(1)
			var events: Array[BattleEvent] = session.consume_world()
			for event: BattleEvent in events: hash.update(JSON.stringify(event.snapshot()).to_utf8_buffer())
			if (index+1)%600==0:
				var state: String = JSON.stringify(session.world.snapshot())
				checkpoints.append({"tick":session.world.tick,"state_sha256":state.sha256_text(),"rng_state":session.world.rng.state})
		results.append({"scenario":scenario.mode,"checkpoints":checkpoints,"events_sha256":hash.finish().hex_encode(),"counts":session.counts,"report":session.report(),"profile_us":session.world.profile_us,"profile_calls":session.world.profile_calls})
		print("S08 replay ",scenario.mode," complete")
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	quit(0)
