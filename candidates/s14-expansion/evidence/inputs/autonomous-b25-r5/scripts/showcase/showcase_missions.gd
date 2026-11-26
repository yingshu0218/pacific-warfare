class_name ShowcaseMissions
extends SimulationModule

## Initial legal mission objectives only. FleetCommander uses its own friendly
## intelligence; AircraftTasks handles actual tactics/resources/withdrawal.
## There is no elapsed-time combat choreography in this module.
var exercise: String = "guided"
var stage: int = 0
var serial: int = 0
var receipts: Array[Dictionary] = []
var history: Array[Dictionary] = []
var training_subject: String = ""
var training_order_id: String = ""
var regroup_orders: Array[String] = []
var escort_order_id: String = ""
var cycle_status: String = "forming"
var cycle_completed_s: float = -1
var next_observer_s: float = 0

func _init(mode: String = "guided") -> void:
	module_id = "s14_missions"
	priority = 205
	exercise = mode

func reset(world_ref: RefCounted) -> void:
	stage = 0; serial = 0; receipts.clear(); history.clear(); regroup_orders.clear()
	training_order_id = ""; escort_order_id = ""; cycle_status = "forming"; cycle_completed_s = -1; next_observer_s = 0
	var world: SimulationWorld = world_ref as SimulationWorld
	training_subject = ("us_pair_demo_1" if exercise.get_slice("_",1)=="us" else "jp_air_1") if exercise.begins_with("train_") else ""
	_order(world,"us",["us_cruise_pair"],"patrol","",_route([[-1500,1600,3100],[-3400,1900,1400],[-1000,1250,-1200],[1500,1600,2000]]))
	_order(world,"us",["us_strike"],"patrol","",_route([[1300,1100,800],[3400,1350,-500],[4500,1100,2300],[1300,1100,3800]]))
	_order(world,"us",["us_air"],"patrol","",_route([[0,1500,900],[-1900,1950,-900],[1000,1300,-2600],[1800,1500,1400]]))
	_order(world,"jp",["jp_air"],"patrol","",_route([[0,1500,1800],[-1400,1900,3200],[1800,1500,4300],[2000,1500,100]]))
	if not training_subject.is_empty(): _submit_training(world)
	elif exercise == "escort": escort_order_id = _order(world,"us",["us_air"],"escort","us_sb2c_1",[],[1300,1400,8500],2500)

func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	# Observe actual owned tasks only; never issue a timed combat transition.
	var world: SimulationWorld = world_ref as SimulationWorld
	if world.time_s() < next_observer_s: return
	next_observer_s = world.time_s()+.5
	var counts: Dictionary = {}
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not unit.active: continue
		for task: Dictionary in unit.task.values():
			var phase: String = str(task.get("phase",""))
			counts[phase] = int(counts.get(phase,0))+1
	cycle_status = "engaging" if counts.has("burst") or counts.has("aim") or counts.has("evade") or counts.has("approach") else ("regrouping" if counts.has("regroup") else ("guarding" if counts.has("guard") else "forming"))

func _submit_training(world: SimulationWorld) -> void:
	var faction: String = world.get_unit(training_subject).faction_id
	var order: BattleOrder = _base_order(faction,[training_subject],"aircraft_training")
	order.source = "human"
	order.issuer_id = "training_command"
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
	# Explicit navigation/escort mission objectives stay assigned; fighter
	# patrols are AI-owned and may be reassigned by FleetPlanner using own contacts.
	if ids.all(func(id: String) -> bool: return world.get_unit(id).definition_id == "us_sb2c4_1944") or type == "escort": order.source = "human"
	order.target_id = target
	order.waypoints_m = route.duplicate(true)
	order.area = {"center_m":center if not center.is_empty() else [0,1600,8000],"radius_m":radius}
	_submit(world,order)
	return order.order_id

func _base_order(faction: String, ids: Array[String], kind: String) -> BattleOrder:
	serial += 1
	var order: BattleOrder = BattleOrder.new()
	order.order_id = "s14:%s:%03d" % [faction,serial]
	order.issuer_id = "scenario_"+faction+"_command"
	order.source = "ai"
	order.faction_id = faction
	order.recipient_ids = ids
	order.order_type = kind
	order.intent = "scenario_initial_"+exercise
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
