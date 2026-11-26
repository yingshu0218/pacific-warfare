extends SceneTree
var checks: int = 0
var failures: int = 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)
		quit(1)
		assert(ok,reason)

func _initialize() -> void:
	var cases: Array = [
		["climb_setup",130.0,1500.0,Vector3(0,1500,-2600),Vector3(0,0,110)],
		["dive_attack",130.0,2100.0,Vector3(300,1500,-1500),Vector3(0,0,100)],
		["high_yoyo",150.0,1500.0,Vector3(0,1500,-650),Vector3(0,0,-80)],
		["low_yoyo",90.0,1500.0,Vector3(0,1500,-1400),Vector3(0,0,-145)],
		["zoom_climb",130.0,1500.0,Vector3(0,1500,300),Vector3(0,0,-145)],
		["diving_break",75.0,1500.0,Vector3(0,1500,300),Vector3(0,0,-130)],
		["oblique_extend",75.0,150.0,Vector3(0,150,300),Vector3(0,0,-130)]]
	for record: Array in cases:
		var world: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("pilot","jp",Vector3(0,record[2],0),"jp_a6m5a_1944",0,record[1])])
		var unit: UnitState = world.get_unit("pilot")
		var p: Dictionary = AircraftPerformance.new().profile(unit.definition_id)
		var contact: Dictionary = AircraftFixture.contact("observed",record[3],record[4])
		var memory: Dictionary = {}
		var result: Dictionary = AirCombatTactics.decide(unit,p,memory,contact,[contact],((record[3] as Vector3)-unit.position_m).normalized(),0)
		check(result.mode == record[0],str(record[0])+" from actual relative geometry, got "+str(result.mode))
		check((result.direction as Vector3).is_finite(),"finite direction")
		if result.mode in ["climb_setup","high_yoyo","zoom_climb"]: check((result.direction as Vector3).y > 0.35,"upward spatial command")
		if result.mode in ["low_yoyo","diving_break"]: check((result.direction as Vector3).y < -0.35,"downward spatial command")
		var later: Dictionary = AirCombatTactics.decide(unit,p,memory,contact,[contact],((record[3] as Vector3)-unit.position_m).normalized(),9)
		check(later.last_exit == "maneuver_timeout" or later.last_exit == "attack_pass_finished","bounded maneuver completion/timeout")
		unit.module_data.aircraft_motion.safety_state = "low_altitude_recovery"
		var abort: Dictionary = AirCombatTactics.decide(unit,p,memory,contact,[contact],Vector3.FORWARD,10)
		check(abort.mode == "recover" and not abort.permit_fire and abort.last_exit == "safety_abort","safety abort clears attack permission")
	print("S04 spatial tactics ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
