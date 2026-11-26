extends SceneTree
const OPS_FIX: Script = preload("res://tests/air_operations/fixture.gd")
func _initialize() -> void:
	var f: Dictionary = OPS_FIX.build(2)
	var w: SimulationWorld = f.world
	OPS_FIX.sortie(w,["hellcat_1","hellcat_2"])
	var second: bool = false
	for i: int in 60*1000:
		w.step_ticks(1); w.drain_events()
		if not second and f.operations.roster.hellcat_1.recoveries == 1 and f.operations.roster.hellcat_2.recoveries == 1 and f.operations.roster.hellcat_1.phase == "standby" and f.operations.roster.hellcat_2.phase == "standby":
			OPS_FIX.sortie(w,["hellcat_1","hellcat_2"],"repeat"); second = true
		if second and f.operations.roster.hellcat_2.phase in ["diverted","lost"]:
			print("RESDEBUG ",OPS_FIX.json_data(f.operations.roster.hellcat_2)); break
	quit()
