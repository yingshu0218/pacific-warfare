extends SceneTree

var checks: Array[Dictionary] = []
var failed: int = 0
var output: String = "res://autonomy.json"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"passed":ok,"label":label})
	if not ok: failed += 1; printerr("CHECK FAILED ",label)

func scenario(name: String, seconds: int) -> Dictionary:
	var s: FirstPlayableSession = FirstPlayableSession.new()
	check(s.load_battle("res://tests/s14_expansion/fixtures/"+name+".json").is_empty(),name+" actual two-aircraft registration")
	var missions: ShowcaseMissions = ShowcaseMissions.new("guided")
	check(s.world.register_module(missions).accepted,name+" initial legal mission module")
	var first_contact: float = -1
	var first_intercept: float = -1
	var observations: Array = []
	for tick: int in range(60*seconds):
		s.world.step_ticks(1)
		if tick%30 != 0: continue
		s.consume_world()
		var view: Dictionary = s.world.commander_snapshot("us")
		if first_contact < 0 and not view.contacts.is_empty(): first_contact = s.world.time_s()
		for order: Dictionary in view.orders:
			if order.order_type == "intercept" and order.status != "failed" and first_intercept < 0:
				first_intercept = float(order.issued_tick)/60.0
		if tick%600 == 0: observations.append({"time_s":s.world.time_s(),"contacts":view.contacts,"orders":view.orders})
	var orders: Array[Dictionary] = s.world.orders_snapshot()
	check(missions.serial==2,name+" no new director order after initial objectives")
	check(not orders.any(func(o: Dictionary) -> bool: return str(o.intent).begins_with("showcase_")),name+" no legacy choreography intent")
	if name == "no_contact":
		check(first_contact < 0,"no enemy observation over180 seconds")
		check(not orders.any(func(o: Dictionary) -> bool: return o.order_type in ["engage","intercept","regroup","retreat"]),"old12/52/88/120/160 gates do not force combat/transitions")
	elif name == "low_fuel":
		check(orders.any(func(o: Dictionary) -> bool: return o.faction_id=="us" and o.order_type=="retreat" and o.intent=="low_fuel"),"actual initial low fuel changes commander mission")
	else:
		check(first_contact >= 0 and first_intercept >= first_contact-.5,"interception follows own contact "+name)
	return {"name":name,"first_contact_s":first_contact,"first_intercept_s":first_intercept,"orders":orders,"observations":observations}

func run() -> void:
	var runs: Array = []
	for row: Array in [["no_contact",181],["near_contact",30],["delayed_contact",181],["low_fuel",3]]:
		runs.append(scenario(row[0],row[1]))
	check(float(runs[2].first_intercept_s)>float(runs[1].first_intercept_s)+6,"different initial approach delays actual contact/interception, not a shared show second")
	var roles: FirstPlayableSession = FirstPlayableSession.new()
	check(roles.load_battle("res://tests/s14_expansion/fixtures/role_contact.json").is_empty(),"fighter and strike aircraft share actual role fixture")
	roles.world.step_ticks(400);roles.consume_world()
	check(roles.orders.any(func(o: Dictionary) -> bool: return o.order_type=="intercept" and o.assigned_unit_ids.has("us_air_1")),"explicit fighter receives own-contact interception")
	check(not roles.orders.any(func(o: Dictionary) -> bool: return o.order_type in ["intercept","engage","escort"] and o.recipient_ids.has("us_sb2c_1")),"fleet commander never conscripts strike aircraft into fighter combat")
	var s: FirstPlayableSession = FirstPlayableSession.new()
	check(s.load_battle("res://data/scenarios/s14_expansion_harbor.json").is_empty(),"production expanded registration")
	s.world.register_module(load("res://scripts/showcase/expansion/expansion_missions.gd").new("harbor"))
	s.world.step_ticks(40);s.consume_world()
	check(not s.orders.any(func(o: Dictionary) -> bool: return o.reason=="deck_aircraft_requires_sortie_or_recall"),"commander excludes parked inventory from airborne mixed orders")
	check(s.orders.any(func(o: Dictionary) -> bool: return o.faction_id=="us" and o.order_id.begins_with("fleet_ai:") and o.assigned_unit_ids.has("us_air_1")),"airborne aircraft still receive actual commander orders beside parked inventory")
	var validations: Array = []
	for row: Array in [["patrol",0],["patrol",86401],["escort",10],["patrol",110]]:
		var o: BattleOrder = BattleOrder.new()
		o.order_id = "duration_test_"+str(validations.size());o.issuer_id="human_test";o.faction_id="us";o.source="human"
		o.recipient_ids=["us_air_1"];o.order_type=row[0];o.area={"center_m":[0,1500,8000],"radius_m":1200,"on_station_duration_s":row[1]}
		if o.order_type=="escort":o.target_id="us_bb"
		var receipt: Dictionary = s.world.submit_order(o)
		validations.append(receipt)
		check(bool(receipt.accepted)==(row[0]=="patrol" and row[1]==110),"shared validation of explicit patrol duration "+str(row))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(clean({"checks":checks,"failed":failed,"runs":runs,"role_orders":roles.orders,"duration_validation":validations}),"\t"))
	print("S14_AUTONOMY checks=",checks.size()," failed=",failed)
	quit(0 if failed==0 else 1)

static func clean(value: Variant) -> Variant:
	if value is Vector3: return SimData.array3(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value: result[key]=clean(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:result.append(clean(item))
		return result
	return value
