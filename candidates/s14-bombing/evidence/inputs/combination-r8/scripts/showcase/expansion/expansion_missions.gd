extends ShowcaseMissions

## High-level orders only. OPS owns actual motion, resources and completion.
var wave: int = 0
var wave_orders: Array[String] = []
var deck_ids: Array[String] = []
var operation_mode: String = "harbor"
var goal_phase: String = "active"
var recovery_order_id: String = ""
var management_next_s: float = 0

func _init(mode: String = "harbor") -> void:
	super._init(mode)
	operation_mode = mode

func reset(world_ref: RefCounted) -> void:
	super.reset(world_ref)
	var world: SimulationWorld = world_ref as SimulationWorld
	wave = 0; wave_orders.clear(); deck_ids.clear();goal_phase="active";recovery_order_id="";management_next_s=0
	for id: String in world.unit_ids():
		if world.get_unit(id).module_data.get("carrier_initial",{}).get("carrier_id","") == "us_cv": deck_ids.append(id)
	if world.get_unit("us_cv") == null: return
	for pair: Array in [["us","us_cv"],["jp","jp_cv"]]:
		var unit: UnitState = world.get_unit(pair[1])
		var target: String = ("jp_cv" if pair[0] == "us" else "us_cv") if operation_mode == "carrier_gunnery" else ""
		var destination: Vector3 = unit.position_m-unit.world_transform().basis.z*1000000
		if pair[1] == "us_cv" and operation_mode in ["carrier_single","carrier_pair","carrier_partial"]:
			var heading_order: BattleOrder = _base_order("us",["us_cv"],"patrol")
			heading_order.source = "ai"; heading_order.issuer_id = "carrier_course_command"
			heading_order.waypoints_m = [SimData.array3(destination)]; heading_order.intent = "flight_operations_course"
			_submit(world,heading_order)
		else:
			_order(world,pair[0],[pair[1]],"engage" if not target.is_empty() else "patrol",target,[] if not target.is_empty() else [SimData.array3(destination)],SimData.array3(unit.position_m),700)
	if operation_mode in ["carrier_single","carrier_pair","carrier_partial"]:
		var managed: Array[String] = deck_ids.duplicate();managed.append("us_cv")
		_assign_manager(world,managed,"carrier_patrol_two_sorties","active")
		_sortie(world)

func fixed_update(world_ref: RefCounted, dt: float) -> void:
	super.fixed_update(world_ref,dt)
	var world: SimulationWorld = world_ref as SimulationWorld
	if operation_mode not in ["carrier_single","carrier_pair","carrier_partial"]: return
	if world.time_s() < management_next_s: return
	management_next_s = world.time_s()+.5
	if not _continue_operation(world): return
	if wave != 1 or operation_mode == "carrier_partial": return
	var ready: bool = true
	for id: String in deck_ids:
		var unit: UnitState = world.get_unit(id)
		var state: Dictionary = unit.module_data.get("carrier_ops",{})
		if not unit.active or not bool(state.get("service_done",false)) or int(state.get("recoveries",0)) < wave or str(state.get("phase","")) != "standby" or float(unit.module_data.get("aircraft_motion",{}).get("fuel_kg",0)) < 140.0: ready = false
	if ready: _sortie(world)

func _continue_operation(world: SimulationWorld) -> bool:
	var all_ids: Array[String] = deck_ids.duplicate();all_ids.append("us_cv")
	if goal_phase in ["completed","cancelled","base_unavailable"]: return false
	var mother: UnitState = world.get_unit("us_cv")
	var damage: Dictionary = mother.module_data.get("damage",{}) if mother != null else {}
	if mother == null or not mother.active or str(damage.get("phase","operational")) != "operational" or float(damage.get("propulsion_factor",1)) < .4 or float(damage.get("control_factor",1)) < .5:
		goal_phase="base_unavailable";_assign_manager(world,all_ids,"carrier_patrol_two_sorties","released");return false
	var survivors: Array[String] = []
	var interrupted: bool = goal_phase=="recover_survivors"
	var complete: bool = wave>=2
	for id: String in deck_ids:
		var unit: UnitState = world.get_unit(id)
		var state: Dictionary = unit.module_data.get("carrier_ops",{})
		var unusable: bool = not unit.active or str(state.get("phase","")) in ["lost","diverted"] or (str(state.get("phase",""))=="deck_hold" and bool(state.get("cancelled",false)))
		if unusable:
			_assign_manager(world,[id],"carrier_patrol_two_sorties","released");interrupted=true;complete=false
		else:
			survivors.append(id)
			if int(state.get("recoveries",0))<2 or state.get("phase","")!="standby" or not bool(state.get("service_done",false)): complete=false
	for order: Dictionary in world.orders_snapshot():
		if order.order_id in wave_orders and order.status in ["cancelled","superseded","failed"]: interrupted=true
	if complete:
		goal_phase="completed";_assign_manager(world,all_ids,"carrier_patrol_two_sorties","released");return false
	if not interrupted: return true
	goal_phase="recover_survivors"
	var safe: bool = survivors.all(func(id: String)->bool:
		var state: Dictionary = world.get_unit(id).module_data.carrier_ops
		return bool(state.on_deck) and str(state.phase) in ["standby","deck_hold"])
	if safe:
		goal_phase="cancelled";_assign_manager(world,all_ids,"carrier_patrol_two_sorties","released");return false
	if recovery_order_id.is_empty() and not survivors.is_empty():
		var order: BattleOrder = _base_order("us",survivors,"retreat")
		order.issuer_id="carrier_recovery_command";order.target_id="us_cv";order.intent="recover_survivors_after_interruption"
		var receipt: Dictionary = world.submit_order(order)
		if receipt.accepted: recovery_order_id=order.order_id
	return false

func _sortie(world: SimulationWorld) -> void:
	wave += 1
	var ids: Array[String] = deck_ids.duplicate()
	if operation_mode == "carrier_partial": ids = [deck_ids[0]]
	var center: Vector3 = world.get_unit("us_cv").world_transform()*Vector3(-1000,700,-3500)
	var order: BattleOrder = _base_order("us",ids,"patrol")
	order.source = "ai"; order.issuer_id = "carrier_patrol_command"; order.target_id = "us_cv"
	order.area = {"center_m":SimData.array3(center),"radius_m":1200.0,"on_station_duration_s":110.0}
	order.intent = "carrier_patrol_with_visible_duration"
	_submit(world,order); wave_orders.append(order.order_id)

func snapshot_state() -> Dictionary:
	var result: Dictionary = super.snapshot_state()
	result.merge({"wave":wave,"wave_orders":wave_orders.duplicate(),"deck_ids":deck_ids.duplicate(),"operation_mode":operation_mode,"goal_phase":goal_phase,"recovery_order_id":recovery_order_id})
	return result
