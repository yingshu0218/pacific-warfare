extends AircraftTasks

## Reuses the entire existing task executor. Only the OPS-managed phases defer
## the pilot; patrol/combat is still super._update_unit and normal BattleOrder.
var operations: CarrierOperations

func accept_order(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String]) -> Dictionary:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in unit_ids:
		if not operations.roster.has(id): continue
		if not order.target_id.is_empty() and order.order_type in ["patrol","retreat"] and order.target_id != operations.carrier_id:
			return {"accepted":false,"reason":"carrier_base_mismatch"}
		if operations.roster[id].on_deck and order.order_type not in ["patrol","retreat"]:
			return {"accepted":false,"reason":"deck_aircraft_requires_sortie_or_recall"}
	return super.accept_order(world_ref,order,unit_ids)

func _update_unit(world: SimulationWorld, unit: UnitState, order: Dictionary, owned: Array[String], formation: Dictionary) -> void:
	if operations.roster.has(unit.id) and str(operations.roster[unit.id].phase) != "mission": return
	super._update_unit(world,unit,order,owned,formation)

func on_order_units_released(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String], reason: String) -> void:
	super.on_order_units_released(world_ref,order,unit_ids,reason)
	for id: String in unit_ids: operations.order_released(world_ref as SimulationWorld,(world_ref as SimulationWorld).get_unit(id),reason)
