extends SceneTree
const FIX: Script = preload("res://tests/bombing/fixture.gd")
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	print("BOMB01_CHECK ",ok," ",label)
	if not ok: failures += 1
func run() -> void:
	var records: Array = []
	for type: String in ["us_sb2c4_1944","jp_g4m1_1942_07","jp_d4y2_model12_1944_10"]:
		var p: Dictionary = FIX.parameters().aircraft[type]
		var a: Dictionary = FIX.arena([FIX.spawn("bomber","us",Vector3(0,float(p.entry_altitude_m),5500),type,Vector3(0,0,-float(p.attack_mps)))])
		var world: SimulationWorld = a.world
		var area: Dictionary = {"center_m":[0.,0.,0.],"radius_m":300.}
		expect(FIX.order(world,["bomber"],str(p.mode),"",area).accepted,type+" unified order accepted")
		var events: Array = []
		var samples: Array = []
		for tick: int in 150*60:
			world.step_ticks(1)
			for event: BattleEvent in world.drain_events():
				if event.kind in ["bomb_released","bomb_contact","bomb_explosion","bombing_phase","unit_surface_contact"]: events.append(event.snapshot())
			if tick%30 == 0:
				var u: UnitState = world.get_unit("bomber")
				samples.append({"t":world.time_s(),"position_m":u.position_m,"velocity_mps":u.velocity_mps,"flight":u.module_data.aircraft_motion.duplicate(true),"task":u.module_data.get("bombing",{}).duplicate(true),"rack":u.module_data.bomb_rack.duplicate(true)})
		var released: int = world.get_unit("bomber").module_data.bomb_rack.released
		expect(released==p.slots_m.size(),type+" finite load naturally released: "+str(released))
		expect(world.get_unit("bomber").active,type+" survives continuous pullout/return")
		var phases: Array = events.filter(func(e: Dictionary) -> bool: return e.kind=="bombing_phase")
		print(type," PHASES ",phases.map(func(e: Dictionary) -> Variant: return [e.time_s,e.data.phase,e.data.reason]))
		records.append({"type":type,"released":released,"events":events,"samples":samples,"final":world.snapshot()})
	var out: String = "res://.local/attacks.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out=arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var f: FileAccess=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(FIX.json_data(records)));f.close()
	quit(0 if failures==0 else 1)
