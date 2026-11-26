extends SceneTree

var checks: Array[Dictionary] = []
var samples: Dictionary = {}
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok: failures += 1; push_error("S14: "+label)

func build(mode: String) -> FirstPlayableSession:
	var result: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = result.load_battle("res://data/scenarios/s14_"+mode+".json")
	check(errors.is_empty(),mode+" assembles: "+str(errors))
	if not errors.is_empty(): return result
	var missions: ShowcaseMissions = ShowcaseMissions.new(mode)
	check(result.world.register_module(missions).accepted,mode+" installs high-level missions")
	return result

func run() -> void:
	var modes: Array[String] = ["guided","pair","four","maneuver","escort","fire"]
	var duration: int = 4
	var suffix: String = "assembly"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): modes.assign([arg.get_slice("=",1)]); suffix = modes[0]
		if arg.begins_with("--seconds="): duration = int(arg.get_slice("=",1))
	for mode: String in modes:
		var session: FirstPlayableSession = build(mode)
		if session.world == null: continue
		check(session.world.unit_ids().size()==19,mode+" has all 19 units")
		var counts: Dictionary = {}
		var phases: Dictionary = {}
		var min_speed: float = INF
		var max_roll: float = 0
		var max_pitch: float = 0
		var minimum_pair_distance: float = INF
		var initial_sb2c: Vector3 = session.world.get_unit("us_sb2c_1").position_m
		var max_rejoin: float = 0
		var stages: Array[String] = []
		var seconds: int = duration
		for tick: int in seconds*60:
			session.world.step_ticks(1)
			var events: Array[BattleEvent] = session.consume_world()
			for event: BattleEvent in events:
				counts[event.kind] = int(counts.get(event.kind,0))+1
				if event.kind == "command_rejected": stages.append(str(event.data))
			if tick%6 != 0: continue
			for id: String in session.world.unit_ids():
				var unit: UnitState = session.world.get_unit(id)
				if not unit.active or not unit.module_data.has("aircraft_motion"): continue
				var flight: Dictionary = unit.module_data.aircraft_motion
				min_speed = minf(min_speed,unit.velocity_mps.length())
				max_roll = maxf(max_roll,absf(float(flight.bank_rad)))
				max_pitch = maxf(max_pitch,absf(float(flight.path_pitch_rad)))
				var task: Dictionary = unit.task.get("aircraft",{})
				phases[id+":"+str(task.get("phase",""))+":"+str(task.get("maneuver_phase",""))] = true
			var a: UnitState = session.world.get_unit("us_pair_demo_1")
			var b: UnitState = session.world.get_unit("us_pair_demo_2")
			if a.active and b.active: minimum_pair_distance = minf(minimum_pair_distance,a.position_m.distance_to(b.position_m))
			max_rejoin = maxf(max_rejoin,float(b.task.get("aircraft",{}).get("distance_m",0)))
		check(session.world.get_unit("us_sb2c_1").position_m.distance_to(initial_sb2c)>minf(200,seconds*20),mode+" SB2C really integrates flight")
		check(session.world.get_unit("us_sb2c_1").task.get("aircraft",{}).get("phase","")!="withdraw",mode+" unarmed ward does not withdraw for no ammunition")
		check(min_speed>35,mode+" active aircraft speed bounded")
		check(int(counts.get("command_rejected",0))==0,mode+" no command rejections "+str(stages))
		samples[mode] = {"seconds":seconds,"counts":counts,"phases":phases.keys(),"min_speed_mps":min_speed,"max_bank_deg":rad_to_deg(max_roll),"max_path_pitch_deg":rad_to_deg(max_pitch),"minimum_pair_distance_m":minimum_pair_distance,"max_wingman_goal_distance_m":max_rejoin}
		var previous: int = session.world.generation
		check(session.restart() and session.world.generation==previous+1,mode+" normal reset/generation")
	var replay: FirstPlayableSession = build("pair")
	replay.world.step_ticks(1800)
	var expected: Dictionary = replay.world.snapshot()
	replay.restart()
	replay.world.step_ticks(1800)
	var actual: Dictionary = replay.world.snapshot()
	expected.erase("generation");actual.erase("generation")
	check(expected==actual,"same orders reset deterministically")
	var out: FileAccess = FileAccess.open("res://docs/showcase/evidence/S14/mechanisms_"+suffix+".json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks,"samples":samples,"failures":failures},"\t"))
	print("S14 checks ",checks.size()," failures ",failures)
	quit(1 if failures>0 else 0)
