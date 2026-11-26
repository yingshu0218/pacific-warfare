extends SceneTree
const FIX: Script=preload("res://tests/bombing/fixture.gd")
var failures: int=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/bombing/data/scenarios.json"))
	var selected: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):selected=arg.get_slice("=",1)
	var records: Array=[]
	for key: String in data.cases:
		if not selected.is_empty() and key!=selected:continue
		var c: Dictionary=data.cases[key]
		var a: Dictionary=FIX.arena(c.spawns,true,true,null,false,true)
		var world: SimulationWorld=a.world
		assert(world.register_module(load("res://scripts/bombing/commander.gd").new(c.goals)).accepted)
		var events: Array=[]
		for i: int in 120*60:
			world.step_ticks(1)
			for event: BattleEvent in world.drain_events():
				if event.kind in ["fired","hit","damaged","disabled","bombing_phase","bomb_released","bomb_contact","unit_surface_contact","aircraft_part_detached"]:events.append(event.snapshot())
		var bombs: int=events.filter(func(e: Dictionary) -> bool:return e.kind=="bomb_released").size()
		var fire: int=events.filter(func(e: Dictionary) -> bool:return e.kind=="fired").size()
		var impacts: Array=events.filter(func(e: Dictionary) -> bool:return e.kind=="damaged" and e.target_id in ["bomber","wing"])
		var target_damage: int=events.filter(func(e: Dictionary) -> bool:return e.kind=="damaged" and e.target_id=="target").size()
		var complete: int=0
		for spawn: Dictionary in c.spawns:
			if spawn.id in ["bomber","wing"]:complete+=FIX.parameters().aircraft[spawn.unit_definition_id].slots_m.size()
		var passed: bool=bombs==complete and target_damage>0 if key.begins_with("bombing_") else fire>0 and impacts.size()>0 and bombs<complete
		if not passed:failures+=1
		print("BOMB01_SCENARIO ",key," pass=",passed," bombs=",bombs," fire=",fire," bomber_damage=",impacts.size()," target_damage=",target_damage)
		records.append({"id":key,"passed":passed,"events":events,"final":world.snapshot(),"input":c})
		FIX.dispose(a)
	var f: FileAccess=FileAccess.open("res://.local/scenarios"+("_"+selected if not selected.is_empty() else "")+".json",FileAccess.WRITE);f.store_string(JSON.stringify(FIX.json_data(records)));f.close()
	call_deferred("_exit",0 if failures==0 else 1)
func _exit(code: int) -> void:quit(code)
