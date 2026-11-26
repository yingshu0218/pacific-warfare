extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var session: FirstPlayableSession=FirstPlayableSession.new()
	var errors: PackedStringArray=session.load_battle("res://data/scenarios/s14_expansion_carrier_pair.json")
	if not errors.is_empty():printerr(errors);quit(1);return
	var manager: SimulationModule=load("res://scripts/showcase/expansion/expansion_missions.gd").new("carrier_pair")
	session.world.register_module(manager);session.world.step_ticks(60)
	var wave_order: String=manager.get("wave_orders")[0]
	var command: BattleCommand=BattleCommand.new()
	command.command_id="ownership_cancel";command.issuer_id="test_human";command.source="human";command.faction_id="us";command.kind=BattleCommand.CANCEL_ORDER;command.payload={"order_id":wave_order,"reason":"human_cancelled"}
	var receipt: Dictionary=session.world.submit_command(command)
	session.world.step_ticks(120);session.consume_world()
	var checks: Array=[]
	checks.append({"passed":bool(receipt.accepted),"label":"actual cancellation goes through shared command validation"})
	checks.append({"passed":session.orders.any(func(o: Dictionary)->bool:return o.order_id==wave_order and o.status=="cancelled"),"label":"actual wave order reaches cancelled terminal status"})
	for id: String in ["us_cv","us_deck_1","us_deck_2"]:
		checks.append({"passed":session.world.get_unit(id).module_data.command_assignment.phase=="released","label":id+" actual cancelled operation releases manager assignment"})
	checks.append({"passed":manager.get("goal_phase")=="cancelled" and manager.get("wave")==1,"label":"cancellation does not fake a completed second wave"})
	var failed: int=checks.filter(func(c: Dictionary)->bool:return not c.passed).size()
	var output: String="res://command_ownership.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"manager":manager.snapshot_state(),"receipt":receipt},"\t"))
	print("OWNERSHIP checks=",checks.size()," failed=",failed)
	quit(0 if failed==0 else 1)
