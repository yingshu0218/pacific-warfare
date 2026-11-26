class_name ShowcaseMissions
extends SimulationModule

## External exercise orders only. AircraftTasks and the force integrator own
## every attitude, shot and hit. A receipt is never an execution result.
var exercise: String = "guided"
var stage: int = 0
var serial: int = 0
var receipts: Array[Dictionary] = []
var history: Array[Dictionary] = []
var training_subject: String = ""
var training_order_id: String = ""
var regroup_orders: Array[String] = []
var escort_order_id: String = ""
var guard_since_s: float = -1
var cycle_status: String = "forming"
var cycle_completed_s: float = -1

func _init(mode: String = "guided") -> void:
	module_id = "s14_missions"
	priority = 205
	exercise = mode

func reset(world_ref: RefCounted) -> void:
	stage = 0
	serial = 0
	receipts.clear()
	history.clear()
	regroup_orders.clear()
	training_order_id = ""
	escort_order_id = ""
	guard_since_s = -1
	cycle_completed_s = -1
	cycle_status = "forming"
	var world: SimulationWorld = world_ref as SimulationWorld
	training_subject = ("us_pair_demo_1" if exercise.get_slice("_",1)=="us" else "jp_air_1") if exercise.begins_with("train_") else ""
	_order(world,"us",["us_cruise_pair"],"patrol","",_route([[-1500,1600,3100],[-3400,1900,1400],[-1000,1250,-1200],[1500,1600,2000]]))
	_order(world,"us",["us_strike"],"patrol","",_route([[1300,1100,800],[3400,1350,-500],[4500,1100,2300],[1300,1100,3800]]))
	_order(world,"us",["us_air"],"patrol","",_route([[0,1500,900],[-1900,1950,-900],[1000,1300,-2600],[1800,1500,1400]]))
	_order(world,"jp",["jp_air"],"patrol","",_route([[0,1500,1800],[-1400,1900,3200],[1800,1500,4300],[2000,1500,100]]))
	if not training_subject.is_empty():
		_submit_training(world)
	elif exercise == "maneuver":
		_order(world,"us",["us_cruise_pair"],"engage","jp_air_1")
		_order(world,"jp",["jp_pair_1"],"engage","us_pair_demo_1")
	elif exercise == "escort":
		escort_order_id = _order(world,"us",["us_air"],"escort","us_sb2c_1",[],[1300,1400,8500],2500)
		_mark(world,"guarding")

func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	var now: float = world.time_s()
	if not training_subject.is_empty(): return
	if exercise == "escort":
		_escort_cycle(world)
		return
	if exercise in ["guided","four","fire"]:
		if stage == 0 and now >= (12.0 if exercise == "four" else 88.0):
			_order(world,"us",["us_air"],"engage","jp_air_1")
			_order(world,"jp",["jp_air"],"engage","us_air_1")
			stage = 1
			_mark(world,"engaging")
		elif stage == 1 and now >= (52.0 if exercise == "four" else 120.0):
			regroup_orders.append(_order(world,"us",["us_air"],"regroup","",[],[1300,1700,8500],800))
			regroup_orders.append(_order(world,"jp",["jp_air"],"regroup","",[],[-1400,1700,7000],800))
			stage = 2
			_mark(world,"regrouping")
		elif stage == 2:
			var done: bool = true
			for id: String in regroup_orders:
				var record: Dictionary = _record(world,id)
				if record.is_empty() or record.status != "completed": done = false
			if done:
				stage = 3
				cycle_completed_s = now
				_mark(world,"regrouped")
		if exercise == "guided" and stage == 3 and now >= 160:
			escort_order_id = _order(world,"us",["us_air"],"escort","us_sb2c_1",[],[1300,1400,8500],2500)
			stage = 4

func _escort_cycle(world: SimulationWorld) -> void:
	var now: float = world.time_s()
	if stage == 0 and now >= 12:
		_order(world,"jp",["jp_pair_1"],"engage","us_sb2c_1")
		stage = 1
		_mark(world,"threat_approaching")
	elif stage == 1:
		var responding: bool = false
		for id: String in ["us_air_1","us_air_2","us_air_3","us_air_4"]:
			var task: Dictionary = world.get_unit(id).task.get("aircraft",{})
			if task.get("phase","") in ["approach","aim","burst","evade","extend"]: responding = true
		if responding and cycle_status != "intercepting": _mark(world,"intercepting")
		if now >= 58:
			_order(world,"jp",["jp_pair_1"],"retreat","",[],[6500,1600,10000],700)
			stage = 2
			_mark(world,"threat_withdrawing")
	elif stage == 2:
		var ward: UnitState = world.get_unit("us_sb2c_1")
		if not ward.active:
			_mark(world,"protected_unit_lost")
			stage = 4
			return
		var guarding: int = 0
		var survivors: int = 0
		for id: String in ["us_air_1","us_air_2","us_air_3","us_air_4"]:
			var unit: UnitState = world.get_unit(id)
			if not unit.active: continue
			survivors += 1
			var task: Dictionary = unit.task.get("aircraft",{})
			if unit.active_order_id == escort_order_id and task.get("phase","") in ["guard","formation","support"] and unit.position_m.distance_to(ward.position_m) < 2500:
				guarding += 1
		if survivors > 0 and guarding == survivors:
			if guard_since_s < 0: guard_since_s = now
			if now-guard_since_s >= 3:
				stage = 3
				cycle_completed_s = now
				_mark(world,"guard_restored")
		else: guard_since_s = -1

func _submit_training(world: SimulationWorld) -> void:
	var faction: String = world.get_unit(training_subject).faction_id
	var order: BattleOrder = _base_order(faction,[training_subject],"aircraft_training")
	order.training = {"maneuver":exercise.trim_prefix("train_"+faction+"_"),"direction":1}
	training_order_id = order.order_id
	_submit(world,order)

func _route(route: Array) -> Array:
	var result: Array = route.duplicate(true)
	if exercise.begins_with("train_"):
		# Other aircraft remain well away from the training envelope.
		var us: bool = float(result[0][0]) >= -1500
		for point: Array in result:
			point[0] += 6500 if us else -6500
			point[2] += 10000
	elif exercise != "fire":
		for point: Array in result: point[2] += 6500
	return result

func _order(world: SimulationWorld, faction: String, recipients: Array[String], type: String, target: String = "", route: Array = [], center: Array = [], radius: float = 1800.0) -> String:
	var ids: Array[String] = []
	for recipient: String in recipients:
		for id: String in world.recipient_unit_ids(recipient):
			if id != training_subject: ids.append(id)
	if ids.is_empty(): return ""
	var order: BattleOrder = _base_order(faction,ids,type)
	order.target_id = target
	order.waypoints_m = route.duplicate(true)
	order.area = {"center_m":center if not center.is_empty() else [0,1600,8000],"radius_m":radius}
	_submit(world,order)
	return order.order_id

func _base_order(faction: String, ids: Array[String], kind: String) -> BattleOrder:
	serial += 1
	var order: BattleOrder = BattleOrder.new()
	order.order_id = "s14:%s:%03d" % [faction,serial]
	order.issuer_id = "s14_exercise_director"
	order.source = "human"
	order.faction_id = faction
	order.recipient_ids = ids
	order.order_type = kind
	order.intent = "showcase_exercise_"+exercise
	return order

func _submit(world: SimulationWorld, order: BattleOrder) -> void:
	var receipt: Dictionary = world.submit_order(order)
	receipts.append({"request":order.request_data(),"receipt":receipt,"time_s":world.time_s()})

func _record(world: SimulationWorld, id: String) -> Dictionary:
	for record: Dictionary in world.orders_snapshot():
		if record.order_id == id: return record
	return {}

func _mark(world: SimulationWorld, value: String) -> void:
	cycle_status = value
	history.append({"time_s":world.time_s(),"phase":value,"regroup_orders":regroup_orders.duplicate(),"escort_order_id":escort_order_id})

func snapshot_state() -> Dictionary:
	return {"exercise":exercise,"stage":stage,"serial":serial,"receipts":receipts.duplicate(true),"history":history.duplicate(true),"training_subject":training_subject,"training_order_id":training_order_id,"cycle_status":cycle_status,"cycle_completed_s":cycle_completed_s,"regroup_orders":regroup_orders.duplicate(),"escort_order_id":escort_order_id}
