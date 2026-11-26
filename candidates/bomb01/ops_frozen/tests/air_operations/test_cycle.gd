extends SceneTree

const FIXTURE: Script = preload("res://tests/air_operations/fixture.gd")

func _initialize() -> void:
	var fixture: Dictionary = FIXTURE.build(1)
	var world: SimulationWorld = fixture.world
	var ops: CarrierOperations = fixture.operations
	assert(FIXTURE.sortie(world,["hellcat_1"]).accepted)
	var trace: Array[Dictionary] = []
	var previous: Vector3 = world.get_unit("hellcat_1").position_m
	var max_step: float = 0.0
	var events: Array[Dictionary] = []
	for i: int in range(60*900):
		world.step_ticks(1)
		var unit: UnitState = world.get_unit("hellcat_1")
		max_step = maxf(max_step,unit.position_m.distance_to(previous))
		previous = unit.position_m
		if i%60 == 0:
			trace.append({"t":world.time_s(),"position":unit.position_m,"velocity":unit.velocity_mps,"phase":ops.roster.hellcat_1.phase,"local":ops.roster.hellcat_1.local_m,"flight":unit.module_data.aircraft_motion.duplicate(true),"control":unit.module_data.get("aircraft_control",{}).duplicate(true)})
		for event: BattleEvent in world.drain_events():
			if event.kind.begins_with("carrier_") or event.kind in ["unit_surface_contact","unit_impact"]: events.append(event.snapshot())
		if int(ops.roster.hellcat_1.recoveries) == 1 and ops.roster.hellcat_1.phase == "standby": break
		if ops.roster.hellcat_1.phase == "lost": break
	var result: Dictionary = {"finished":int(ops.roster.hellcat_1.recoveries)==1 and ops.roster.hellcat_1.phase=="standby","max_tick_displacement_m":max_step,"time_s":world.time_s(),"history":ops.history,"trace":trace,"events":events,"state":ops.snapshot_state(),"orders":world.orders_snapshot()}
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/OPS01/cycle.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(FIXTURE.json_data(result),"\t")); file.close()
	print("OPS01_CYCLE ",result.finished," t=",world.time_s()," max_step=",max_step," phase=",ops.roster.hellcat_1.phase)
	quit(0 if result.finished else 1)
