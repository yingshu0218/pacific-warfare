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
	if operation_mode in ["carrier_single","carrier_pair","carrier_partial"]:
		# A live deck-training area is ordered quiet at the high-level command
		# boundary. All weapons/damage remain installed; normal combat modes keep
		# their original rules and the separate carrier gunnery mode is live fire.
		for pair: Array in [["us","us_bb"],["us","us_dd"],["jp","jp_bb"],["jp","jp_dd"]]:
			var ship: UnitState = world.get_unit(pair[1])
			_order(world,pair[0],[pair[1]],"patrol","",[[ship.position_m.x,0,-1000000]],SimData.array3(ship.position_m),700)
	for pair: Array in [["us","us_cv"],["jp","jp_cv"]]:
		var unit: UnitState = world.get_unit(pair[1])
		var target: String = ("jp_cv" if pair[0] == "us" else "us_cv") if operation_mode == "carrier_gunnery" else ""
		var destination: Vector3 = unit.position_m-unit.world_transform().basis.z*1000000
		_order(world,pair[0],[pair[1]],"engage" if not target.is_empty() else "patrol",target,[] if not target.is_empty() else [SimData.array3(destination)],SimData.array3(unit.position_m),700)
	if operation_mode in ["carrier_single","carrier_pair","carrier_partial"]: _sortie(world)

func fixed_update(world_ref: RefCounted, dt: float) -> void:
	super.fixed_update(world_ref,dt)
	var world: SimulationWorld = world_ref as SimulationWorld
	if operation_mode not in ["carrier_single","carrier_pair"] or wave != 1: return
	var ready: bool = true
	for id: String in deck_ids:
		var unit: UnitState = world.get_unit(id)
		var state: Dictionary = unit.module_data.get("carrier_ops",{})
		if not unit.active or not bool(state.get("service_done",false)) or int(state.get("recoveries",0)) < wave or str(state.get("phase","")) != "standby": ready = false
	if ready: _sortie(world)

func _sortie(world: SimulationWorld) -> void:
	wave += 1
	var ids: Array[String] = deck_ids.duplicate()
	if operation_mode == "carrier_partial": ids = [deck_ids[0]]
	var center: Vector3 = world.get_unit("us_cv").world_transform()*Vector3(-1000,700,-3500)
	var id: String = _order(world,"us",ids,"patrol","us_cv",[],SimData.array3(center),1200)
	wave_orders.append(id)

func snapshot_state() -> Dictionary:
	var result: Dictionary = super.snapshot_state()
	result.merge({"wave":wave,"wave_orders":wave_orders.duplicate(),"deck_ids":deck_ids.duplicate(),"operation_mode":operation_mode})
	return result
