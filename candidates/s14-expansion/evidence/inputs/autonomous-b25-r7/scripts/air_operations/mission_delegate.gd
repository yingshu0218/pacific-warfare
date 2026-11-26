class_name CarrierMissionDelegate
extends RefCounted

## Optional BOMB/S14 composition point on the one AircraftTasks executor.
## It may set intent/control and consume its own combat inventory through the
## existing simulation contracts. It must not integrate movement or deck state.
func supports(_order_type: String) -> bool:
	return false

func reset(_world: SimulationWorld) -> void:
	pass

func accept(_world: SimulationWorld, _order: BattleOrder, _unit_ids: Array[String]) -> Dictionary:
	return {"accepted":false,"reason":"mission_delegate_not_implemented"}

func step(_world: SimulationWorld, _unit: UnitState, _order: Dictionary, _owned: Array[String], _formation: Dictionary) -> void:
	pass

func released(_world: SimulationWorld, _order: BattleOrder, _unit_ids: Array[String], _reason: String) -> void:
	pass
