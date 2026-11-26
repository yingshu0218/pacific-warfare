class_name SB2CShowcaseTasks
extends AircraftTasks

## Reuse the production navigation/formation executor. This admission is an
## unarmed flight/escort ward; do not let the commander turn it into a fighter.
func accept_order(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String]) -> Dictionary:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in unit_ids:
		if world.get_unit(id).definition_id == "us_sb2c4_1944" and order.order_type not in ["patrol", "regroup", "retreat"]:
			return {"accepted":false, "reason":"sb2c_showcase_navigation_only"}
	return super.accept_order(world_ref, order, unit_ids)

func _exit_reason(unit: UnitState, p: Dictionary) -> String:
	var reason: String = super._exit_reason(unit, p)
	# No working weapons are admitted for this ward. Fuel and actual damage still
	# trigger withdrawal, and the ordinary fighter ammunition rule is unchanged.
	if unit.definition_id == "us_sb2c4_1944" and reason == "no_ammunition": return ""
	return reason
