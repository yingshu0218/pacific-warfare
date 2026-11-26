extends SceneTree
const FIX: Script = preload("res://tests/air_operations/fixture.gd")
func _initialize() -> void:
	var f: Dictionary = FIX.build(2)
	var w: SimulationWorld = f.world
	FIX.sortie(w,["hellcat_1","hellcat_2"])
	var rows: Array[Dictionary] = []
	for i: int in 60*1000:
		w.step_ticks(1); w.drain_events()
		var u: UnitState = w.get_unit("hellcat_2")
		if i%30 == 0 and f.operations.roster.hellcat_2.phase in ["approach","go_around"]:
			rows.append({"t":w.time_s(),"ops":f.operations.roster.hellcat_2.duplicate(true),"position":u.position_m,"velocity":u.velocity_mps,"flight":u.module_data.aircraft_motion.duplicate(true),"control":u.module_data.get("aircraft_control",{}).duplicate(true)})
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/OPS01/second-trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(FIX.json_data(rows),"\t")); file.close()
	quit()
