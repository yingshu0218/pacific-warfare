extends SceneTree
const FIX: Script=preload("res://tests/bombing/fixture.gd")
var failures: int=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var records: Array=[]
	for intercepted: bool in [false,true]:
		var spawns: Array=[FIX.spawn("bomber","jp",Vector3(0,1800,5500),"jp_g4m1_1942_07",Vector3(0,0,-87)),FIX.spawn("wing","jp",Vector3(220,1800,5580),"jp_g4m1_1942_07",Vector3(0,0,-87))]
		if intercepted:spawns.append(FIX.spawn("fighter","us",Vector3(220,1800,6180),"us_f6f5_1944",Vector3(0,0,-105)))
		var a: Dictionary=FIX.arena(spawns,true,true,null,false,true)
		var world: SimulationWorld=a.world
		var goals: Array=[{"id":"attack","order_type":"bombing","faction_id":"jp","unit_ids":["bomber","wing"],"mode":"level","area_id":"charted_water_range","area":{"center_m":[0.,0.,0.],"radius_m":400.}}]
		if intercepted:goals.append({"id":"intercept","order_type":"intercept","faction_id":"us","unit_ids":["fighter"]})
		var commander: SimulationModule=load("res://scripts/bombing/commander.gd").new(goals)
		assert(world.register_module(commander).accepted)
		var events: Array=[]
		for tick: int in 110*60:
			world.step_ticks(1)
			for event: BattleEvent in world.drain_events():
				if event.kind in ["fired","hit","damaged","disabled","bombing_phase","bomb_released","bomb_contact","order_issued","order_received","order_status"]:events.append(event.snapshot())
		var bomb_count: int=events.filter(func(e: Dictionary) -> bool:return e.kind=="bomb_released").size()
		var fire_count: int=events.filter(func(e: Dictionary) -> bool:return e.kind=="fired").size()
		var impacts: Array=events.filter(func(e: Dictionary) -> bool:return e.kind=="damaged" and e.target_id in ["bomber","wing"])
		var actual_reaction: bool=false
		for id: String in ["bomber","wing"]:
			var unit: UnitState=world.get_unit(id)
			if not unit.active or not str(unit.module_data.get("bombing",{}).get("abort_reason","")).is_empty():actual_reaction=true
		var passed: bool=(bomb_count==24) if not intercepted else (fire_count>0 and not impacts.is_empty() and actual_reaction and bomb_count<24)
		if not passed:failures+=1
		print("BOMB01_INTERCEPT ",intercepted," pass=",passed," bombs=",bomb_count," fired=",fire_count," damage=",impacts.size()," reaction=",actual_reaction)
		records.append({"intercepted":intercepted,"passed":passed,"bombs":bomb_count,"fired":fire_count,"events":events,"final":world.snapshot(),"goals":goals})
		FIX.dispose(a)
	var f: FileAccess=FileAccess.open("res://.local/interception.json",FileAccess.WRITE);f.store_string(JSON.stringify(FIX.json_data(records)));f.close()
	call_deferred("_exit_test",0 if failures==0 else 1)
func _exit_test(code: int) -> void:quit(code)
