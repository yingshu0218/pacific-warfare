extends "res://scripts/air_operations/task_bridge.gd"

## Install THIS bridge alone for OPS composition. Parent bombing_delegate stays
## null; only OPS mission_delegate owns supports/reset/accept/step/released.
func supported_order_types() -> PackedStringArray:
	var result: PackedStringArray = super.supported_order_types()
	if mission_delegate != null and mission_delegate.supports("bombing"): result.append("bombing")
	return result

func accept_order(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String]) -> Dictionary:
	if bombing_delegate != null: return {"accepted":false,"reason":"duplicate_mission_delegate_configuration"}
	return super.accept_order(world_ref,order,unit_ids)
