extends ShowcaseMissions

## High-level orders only. OPS owns actual motion, resources and completion.
var wave: int = 0
var wave_orders: Array[String] = []
var deck_ids: Array[String] = []
var operation_mode: String = "harbor"

func _init(mode: String = "harbor") -> void:
	super._init(mode)
	operation_mode = mode

func reset(world_ref: RefCounted) -> void:
	super.reset(world_ref)
	var world: SimulationWorld = world_ref as SimulationWorld
	wave = 0; wave_orders.clear(); deck_ids.clear()
	for id: String in world.unit_ids():
		if world.get_unit(id).module_data.get("carrier_initial",{}).get("carrier_id","") == "us_cv": deck_ids.append(id)
	if world.get_unit("us_cv") == null: return
	for pair: Array in [["us","us_cv"],["jp","jp_cv"]]:
		var unit: UnitState = world.get_unit(pair[1])
		var target: String = ("jp_cv" if pair[0] == "us" else "us_cv") if operation_mode == "carrier_gunnery" else ""
		var destination: Vector3 = unit.position_m-unit.world_transform().basis.z*1000000
		if pair[1] == "us_cv" and operation_mode in ["carrier_single","carrier_pair","carrier_partial"]:
			var heading_order: BattleOrder = _base_order("us",["us_cv"],"patrol")
			heading_order.source = "human"; heading_order.issuer_id = "carrier_course_command"
			heading_order.waypoints_m = [SimData.array3(destination)]; heading_order.intent = "flight_operations_course"
			_submit(world,heading_order)
		else:
			_order(world,pair[0],[pair[1]],"engage" if not target.is_empty() else "patrol",target,[] if not target.is_empty() else [SimData.array3(destination)],SimData.array3(unit.position_m),700)
	if operation_mode in ["carrier_single","carrier_pair","carrier_partial"]: _sortie(world)

func fixed_update(world_ref: RefCounted, dt: float) -> void:
	super.fixed_update(world_ref,dt)
	var world: SimulationWorld = world_ref as SimulationWorld
	if operation_mode not in ["carrier_single","carrier_pair"] or wave != 1: return
	var carrier: UnitState = world.get_unit("us_cv")
	if carrier == null or not carrier.active or str(carrier.module_data.get("damage",{}).get("phase","operational")) != "operational": return
	var ready: bool = true
	for id: String in deck_ids:
		var unit: UnitState = world.get_unit(id)
		var state: Dictionary = unit.module_data.get("carrier_ops",{})
		if not unit.active or not bool(state.get("service_done",false)) or int(state.get("recoveries",0)) < wave or str(state.get("phase","")) != "standby" or float(unit.module_data.get("aircraft_motion",{}).get("fuel_kg",0)) < 140.0: ready = false
	if ready: _sortie(world)

func _sortie(world: SimulationWorld) -> void:
	wave += 1
	var ids: Array[String] = deck_ids.duplicate()
	if operation_mode == "carrier_partial": ids = [deck_ids[0]]
	var center: Vector3 = world.get_unit("us_cv").world_transform()*Vector3(-1000,700,-3500)
	var order: BattleOrder = _base_order("us",ids,"patrol")
	order.source = "human"; order.issuer_id = "carrier_patrol_command"; order.target_id = "us_cv"
	order.area = {"center_m":SimData.array3(center),"radius_m":1200.0,"on_station_duration_s":110.0}
	order.intent = "carrier_patrol_with_visible_duration"
	_submit(world,order); wave_orders.append(order.order_id)

func snapshot_state() -> Dictionary:
	var result: Dictionary = super.snapshot_state()
	result.merge({"wave":wave,"wave_orders":wave_orders.duplicate(),"deck_ids":deck_ids.duplicate(),"operation_mode":operation_mode})
	return result
