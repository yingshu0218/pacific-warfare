extends SceneTree

var output: String = "res://combination.json"
var selected: String = "all"
var duration: int = 360
var checks: Array = []
var failures: int = 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--case="): selected=arg.trim_prefix("--case=")
		if arg.begins_with("--seconds="): duration=int(arg.trim_prefix("--seconds="))
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks.append({"passed":value,"label":label})
	if not value: failures+=1;printerr("CHECK FAILED ",label)

func run() -> void:
	var results: Array = []
	for mode: String in ["attack_sb2c","attack_d4y","attack_g4m","attack_b25","intercept_g4m","intercept_b25"]:
		if selected!="all" and selected!=mode:continue
		results.append(simulate(mode))
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(clean({"checks":checks,"failed":failures,"cases":results}),"\t"))
	print("S14_BOMB checks=",checks.size()," failed=",failures)
	quit(0 if failures==0 else 1)

func simulate(mode: String) -> Dictionary:
	var s: FirstPlayableSession=FirstPlayableSession.new()
	var errors: PackedStringArray=s.load_battle("res://data/scenarios/s14_"+mode+".json")
	check(errors.is_empty(),mode+" production registration "+str(errors))
	if not errors.is_empty():return {"mode":mode,"errors":errors}
	s.world.register_module(ShowcaseMissions.new(mode))
	var modules: Dictionary={}
	for module: SimulationModule in s.world._modules:modules[module.module_id]=int(modules.get(module.module_id,0))+1
	check(modules.get("aircraft_tasks",0)==1 and modules.get("aircraft_motion",0)==1 and modules.get("combat_projectiles",0)==1 and modules.get("combat_damage",0)==1 and modules.get("bomb_stores",0)==1,mode+" unique task/flight/projectiles/damage/stores")
	check((s.bombing_delegate as RefCounted)!=null,mode+" uses admitted mission delegate")
	var events: Array=[];var trace: Array=[];var first_contact: float=-1;var first_order: float=-1
	var start: Vector3=s.world.get_unit("target").position_m
	for tick: int in range(60*duration):
		s.world.step_ticks(1)
		if tick%30==0:
			for event: BattleEvent in s.consume_world():
				if event.kind in ["bomb_released","bomb_source_cleared","bomb_contact","bomb_explosion","bombing_phase","fired","damaged","damage_phase","unit_impact","unit_surface_contact","order_issued","order_status_changed"]:events.append(event.snapshot())
			var view: Dictionary=s.world.commander_snapshot(str(s.scenario.bombing_goals[0].faction_id))
			if first_contact<0 and not CombatContacts.find(s.world,view.faction_id,"target").is_empty(): first_contact=s.world.time_s()
			if first_order<0:
				for order: Dictionary in s.orders:
					if order.order_type=="bombing":first_order=float(order.issued_tick)/60.0
		if tick%120==0:
			var units: Dictionary={}
			for id: String in s.world.unit_ids():
				var u: UnitState=s.world.get_unit(id)
				units[id]={"active":u.active,"position_m":u.position_m,"velocity_mps":u.velocity_mps,"bombing":u.module_data.get("bombing",{}).duplicate(true),"rack":u.module_data.get("bomb_rack",{}).duplicate(true),"damage":u.module_data.damage.duplicate(true),"task":u.task.duplicate(true)}
			trace.append({"time_s":s.world.time_s(),"units":units})
		if tick%7200==0:print("BOMB_PROGRESS ",mode," ",s.world.time_s())
	for event: BattleEvent in s.consume_world():
		if event.kind.begins_with("bomb") or event.kind in ["damaged","unit_impact"]:events.append(event.snapshot())
	var released: int=events.filter(func(e: Dictionary)->bool:return e.kind=="bomb_released").size()
	var contacts: int=events.filter(func(e: Dictionary)->bool:return e.kind=="bomb_contact").size()
	var aa: int=events.filter(func(e: Dictionary)->bool:return e.kind=="fired" and e.entity_id=="target").size()
	var intercept: int=events.filter(func(e: Dictionary)->bool:return e.kind=="fired" and e.entity_id=="fighter").size()
	check(first_contact>=0 and first_order>=first_contact-.5,mode+" bomb task follows actual own contact")
	check(not s.orders.any(func(o: Dictionary)->bool:return o.source=="human"),mode+" no automatic mission pretends human source")
	if mode.begins_with("attack_"):
		if mode=="attack_sb2c" and released==0:
			var actual_abort: bool=events.any(func(e: Dictionary)->bool:return e.kind=="bombing_phase" and e.data.get("phase","")=="pullout" and e.data.get("reason","") in ["too_low","damage_abort","combat_damage_abort","missed_release_window","target_passed"])
			var actual_egress: bool=events.any(func(e: Dictionary)->bool:return e.kind=="bombing_phase" and e.data.get("phase","")=="egress")
			check(actual_abort and actual_egress,mode+" actual safety/combat abort followed by autonomous pullout and egress")
			check(s.world.get_unit("bomber").module_data.bomb_rack.remaining==1 and s.world.get_unit("wing").module_data.bomb_rack.remaining==1,mode+" abort keeps finite unreleased inventory; no successful bombing claim")
			check(events.any(func(e: Dictionary)->bool:return e.kind=="unit_impact" and e.entity_id in ["bomber","wing"]),mode+" real later terminal damage reaches physical surface impact")
		else:
			check(released>0,mode+" actual finite release under live defense")
			check(contacts>0,mode+" actual first external contact")
	if mode in ["attack_sb2c","attack_b25","intercept_b25"]:check(s.world.get_unit("target").position_m.distance_to(start)>50,mode+" target really moves through ShipMotion")
	check(aa>0,mode+" target AA actually fires, no passive override")
	if mode.begins_with("intercept_"):
		check(intercept>0,mode+" fighter actually fires")
		check(s.orders.filter(func(o: Dictionary)->bool:return o.recipient_ids.has("fighter")).all(func(o: Dictionary)->bool:return str(o.issuer_id).ends_with("_commander") and o.order_id.begins_with("fleet_ai:")),mode+" only FleetPlanner allocates the fighter")
	check(not s.orders.any(func(o: Dictionary)->bool:return o.order_type in ["intercept","engage","escort","aircraft_training"] and o.recipient_ids.has("bomber")),mode+" bomber role never becomes a fighter")
	print("BOMB_RESULT ",mode," released=",released," contacts=",contacts," aa=",aa," fighter=",intercept)
	return {"mode":mode,"duration_s":s.world.time_s(),"released":released,"contacts":contacts,"target_AA_shots":aa,"fighter_shots":intercept,"first_own_contact_s":first_contact,"first_bomb_order_s":first_order,"modules":modules,"orders":s.world.orders_snapshot(),"events":events,"trace":trace}

static func clean(value: Variant) -> Variant:
	if value is Vector3:return SimData.array3(value)
	if value is Dictionary:
		var result: Dictionary={}
		for key: String in value:result[key]=clean(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value:result.append(clean(item))
		return result
	return value
