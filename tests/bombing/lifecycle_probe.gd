extends BombingMissionDelegate
var calls: Dictionary={"reset":0,"accept":0,"step":0,"released":0}
func reset(world: SimulationWorld) -> void:
	calls.reset+=1
	super.reset(world)
func accept(world: SimulationWorld, order: BattleOrder, ids: Array[String]) -> Dictionary:
	calls.accept+=1
	return super.accept(world,order,ids)
func step(world: SimulationWorld, unit: UnitState, order: Dictionary, owned: Array[String], formation: Dictionary) -> void:
	calls.step+=1
	super.step(world,unit,order,owned,formation)
func released(world: SimulationWorld, order: BattleOrder, ids: Array[String], reason: String) -> void:
	calls.released+=1
	super.released(world,order,ids,reason)
