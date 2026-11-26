extends SceneTree

func _initialize() -> void:
	var kind: String = "standard"
	var baseline: bool = false
	var seconds: int = 120
	var checkpoint: int = 0
	var output: String = "res://docs/showcase/evidence/S04-spatial/standard.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): kind = arg.get_slice("=",1)
		if arg == "--baseline": baseline = true
		if arg.begins_with("--seconds="): seconds = int(arg.get_slice("=",1))
		if arg.begins_with("--checkpoint="): checkpoint = int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output = arg.get_slice("=",1)
	var world: SimulationWorld = AircraftSpatialFixture.build(kind,baseline)
	var trace: AircraftSpatialRecorder = AircraftSpatialRecorder.new()
	trace.setup(world)
	for tick: int in range(seconds*60):
		world.step_ticks(1)
		trace.collect(world,world.drain_events(),tick%15 == 0)
		if checkpoint > 0 and world.tick == checkpoint*60:
			_save(trace.result(world),kind,baseline,output.get_basename()+"-%ds.json" % checkpoint)
	var result: Dictionary = trace.result(world)
	_save(result,kind,baseline,output)
	print("S04 spatial trace ",kind," baseline=",baseline," seconds=",seconds," air_fired=",result.summary.air_fired," hits=",result.summary.air_hits," min_friend=",result.summary.min_friend_m)
	quit(0)

func _save(result: Dictionary, kind: String, baseline: bool, output: String) -> void:
	result["case"] = kind
	result["baseline"] = baseline
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
