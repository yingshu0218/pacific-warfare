extends "res://scripts/air_operations/task_bridge.gd"

## The accepted bridge remains the sole aircraft task executor. This adds the
## production admission boundary and preserves the existing SB2C navigation.
func accept_order(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String]) -> Dictionary:
	var world: SimulationWorld = world_ref as SimulationWorld
	var starts_parked: bool = false
	for id: String in unit_ids:
		var unit: UnitState = world.get_unit(id)
		if unit.definition_id == "us_sb2c4_1944" and order.order_type not in ["patrol","regroup","retreat"]:
			return {"accepted":false,"reason":"sb2c_showcase_navigation_only"}
		if operations.roster.has(id) and operations.roster[id].on_deck: starts_parked = true
	if starts_parked and order.order_type == "patrol":
		for id: String in operations.roster:
			if world.get_unit(id).active and operations.roster[id].on_deck and not unit_ids.has(id):
				return {"accepted":false,"reason":"carrier_complete_wave_required"}
	return super.accept_order(world_ref,order,unit_ids)

func _exit_reason(unit: UnitState, p: Dictionary) -> String:
	var reason: String = super._exit_reason(unit,p)
	return "" if unit.definition_id == "us_sb2c4_1944" and reason == "no_ammunition" else reason
