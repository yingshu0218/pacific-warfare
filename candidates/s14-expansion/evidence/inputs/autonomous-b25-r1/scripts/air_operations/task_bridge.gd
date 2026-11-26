extends AircraftTasks

## Reuses the entire existing task executor. Only the OPS-managed phases defer
## the pilot; patrol/combat is still super._update_unit and normal BattleOrder.
var operations: CarrierOperations
var mission_delegate: CarrierMissionDelegate = null

func reset(world_ref: RefCounted) -> void:
	super.reset(world_ref)
	if mission_delegate != null: mission_delegate.reset(world_ref as SimulationWorld)

func accept_order(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String]) -> Dictionary:
	var world: SimulationWorld = world_ref as SimulationWorld
	var delegated: bool = mission_delegate != null and mission_delegate.supports(order.order_type)
	for id: String in unit_ids:
		if not operations.roster.has(id): continue
		if not order.target_id.is_empty() and order.order_type in ["patrol","retreat"] and order.target_id != operations.carrier_id:
			return {"accepted":false,"reason":"carrier_base_mismatch"}
		if operations.roster[id].on_deck and order.order_type not in ["patrol","retreat"] and not delegated:
			return {"accepted":false,"reason":"deck_aircraft_requires_sortie_or_recall"}
	if delegated: return mission_delegate.accept(world,order,unit_ids)
	return super.accept_order(world_ref,order,unit_ids)

func _update_unit(world: SimulationWorld, unit: UnitState, order: Dictionary, owned: Array[String], formation: Dictionary) -> void:
	if operations.roster.has(unit.id) and str(operations.roster[unit.id].phase) != "mission": return
	if mission_delegate != null and mission_delegate.supports(str(order.order_type)):
		if not unit.module_data.has("carrier_delegated_mission"):
			unit.module_data["carrier_delegated_mission"] = {"active":true,"return_requested":false,"return_reason":""}
		mission_delegate.step(world,unit,order,owned,formation)
		return
	unit.module_data.erase("carrier_delegated_mission")
	super._update_unit(world,unit,order,owned,formation)

func on_order_units_released(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String], reason: String) -> void:
	super.on_order_units_released(world_ref,order,unit_ids,reason)
	if mission_delegate != null and mission_delegate.supports(order.order_type): mission_delegate.released(world_ref as SimulationWorld,order,unit_ids,reason)
	for id: String in unit_ids:
		(world_ref as SimulationWorld).get_unit(id).module_data.erase("carrier_delegated_mission")
		operations.order_released(world_ref as SimulationWorld,(world_ref as SimulationWorld).get_unit(id),reason)
