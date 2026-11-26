extends SceneTree

const LABELS: Script = preload("res://scripts/showcase/training_labels.gd")
var checks: Array[Dictionary] = []
var results: Dictionary = {}
var failed: int = 0
var mode: String = "train_us_axial_roll"
var limit_s: float = 240
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"passed":ok,"label":label})
	if not ok: failed += 1; push_error("S14 integration: "+label)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.get_slice("=",1)
		if arg.begins_with("--limit="): limit_s = float(arg.get_slice("=",1))
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle("res://data/scenarios/s14_"+mode+".json")
	check(errors.is_empty(),"admitted scene assembly: "+str(errors))
	if not errors.is_empty(): quit(1); return
	var missions: ShowcaseMissions = ShowcaseMissions.new(mode)
	check(session.world.register_module(missions).accepted,"single existing aircraft executor accepts director")
	check(session.world.unit_ids().size()==19,"19 baseline units")
	var min_friend: float = INF
	var finished_s: float = -1
	while session.world.time_s() < limit_s:
		session.world.step_ticks(1)
		for event: BattleEvent in session.consume_world(): events.append(event.snapshot())
		if session.world.tick%12==0:
			var planes: Dictionary = {}
			for id: String in session.units:
				var unit: Dictionary = session.units[id]
				if not unit.module_data.has("aircraft_motion"): continue
				planes[id] = {"active":unit.active,"position_m":SimData.array3(unit.position_m),"velocity_mps":SimData.array3(unit.velocity_mps),"task":unit.task.duplicate(true),"training":unit.module_data.get("aircraft_training",{}).duplicate(true),"formation":unit.module_data.get("air_formation",{}).duplicate(true),"shots":unit.module_data.get("combat_runtime",{}).get("shots_fired",0)}
				if not missions.training_subject.is_empty() and id!=missions.training_subject and unit.active and unit.faction_id==session.units[missions.training_subject].faction_id:
					min_friend = minf(min_friend,(unit.position_m as Vector3).distance_to(session.units[missions.training_subject].position_m))
			samples.append({"time_s":session.world.time_s(),"units":planes,"mission":missions.snapshot_state()})
		if not missions.training_order_id.is_empty():
			var view: Dictionary = LABELS.view(session.units,session.world.orders_snapshot(),missions.training_subject,missions.training_order_id)
			if view.status=="completed" and finished_s<0: finished_s=session.world.time_s()
			if view.status in ["failed","aborted"]: break
		else:
			if missions.cycle_completed_s >= 0 and finished_s<0: finished_s=session.world.time_s()
		if finished_s>=0 and session.world.time_s()>finished_s+4: break
	var orders: Array[Dictionary] = session.world.orders_snapshot()
	if not missions.training_order_id.is_empty():
		var view: Dictionary = LABELS.view(session.units,orders,missions.training_subject,missions.training_order_id)
		check(view.status=="completed","matched per-unit order/training actually completed: "+str(view))
		check(min_friend>110,"training friendly clearance >110m")
		if mode.ends_with("axial_roll"): check(float(view.training.get("peak_roll_rad",0))>=TAU,"actual roll crosses a full circle")
		results["training"] = view
	else:
		check(missions.cycle_completed_s>=0,"real complete cycle: "+str(missions.snapshot_state()))
		if mode=="four":
			for id: String in missions.regroup_orders:
				var found: bool = false
				for order: Dictionary in orders:
					if order.order_id==id: found=order.status=="completed"
				check(found,"actual regroup order completed "+id)
		elif mode=="escort":
			check(session.units.us_sb2c_1.active,"protected SB2C remains in flight")
			check(missions.history.any(func(h: Dictionary) -> bool: return h.phase=="intercepting"),"actual escort responds to threat")
	results.merge({"mode":mode,"time_s":session.world.time_s(),"orders":orders,"mission":missions.snapshot_state(),"min_training_friend_m":min_friend if is_finite(min_friend) else -1,"checks":checks,"failed":failed,"samples":samples,"events":events})
	var out_dir: String = "res://docs/showcase/evidence/S14/final/integration"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var file: FileAccess = FileAccess.open(out_dir.path_join(mode+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	print("S14 ",mode," ",session.world.time_s(),"s checks=",checks.size()," failed=",failed)
	quit(1 if failed>0 else 0)
