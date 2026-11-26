extends SceneTree

var checks: int = 0
var failures: int = 0
var evidence: Dictionary = {}

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	_behind()
	_circle()
	_half_roll()
	_tactics()
	evidence["checks"] = checks
	evidence["failures"] = failures
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-spatial/f6f-coordination.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	print("S04 F6F coordinated flight ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func _world(height: float = 2200, speed: float = 120) -> SimulationWorld:
	return AircraftFixture.world([AircraftFixture.spawn("f6f","us",Vector3(0,height,0),"us_f6f5_1944",0,speed)])

func _row(world: SimulationWorld) -> Dictionary:
	var unit: UnitState = world.get_unit("f6f")
	var f: Dictionary = unit.module_data.aircraft_motion
	return {"time_s":world.time_s(),"position_m":SimData.array3(unit.position_m),"velocity_mps":SimData.array3(unit.velocity_mps),"rotation_rad":SimData.array3(unit.rotation_rad),
		"pitch_deg":rad_to_deg(AircraftFlightMath.pitch(unit.velocity_mps)),"bank_deg":rad_to_deg(f.bank_rad),"speed_mps":unit.velocity_mps.length(),
		"load_g":f.load_factor,"roll_rate_degps":rad_to_deg(f.body_roll_rate_radps),"heading_rate_degps":rad_to_deg(f.heading_rate_radps),"safety":f.safety_state}

func _behind() -> void:
	var world: SimulationWorld = _world()
	var unit: UnitState = world.get_unit("f6f")
	unit.module_data["aircraft_control"] = {"flight_direction":Vector3.BACK,"speed_mps":125.0}
	var max_pitch: float = 0
	var max_step: float = 0
	var previous: Quaternion = Basis.from_euler(unit.rotation_rad).get_rotation_quaternion()
	var rows: Array = []
	for tick: int in range(1500):
		world.step_ticks(1); world.drain_events()
		max_pitch = maxf(max_pitch,absf(rad_to_deg(AircraftFlightMath.pitch(unit.velocity_mps))))
		var q: Quaternion = Basis.from_euler(unit.rotation_rad).get_rotation_quaternion()
		max_step = maxf(max_step,previous.angle_to(q)); previous = q
		if tick%15 == 0: rows.append(_row(world))
	check(max_pitch < 12,"behind target produces a banked heading reversal, not a spurious vertical loop: "+str(max_pitch))
	check(unit.velocity_mps.normalized().dot(Vector3.BACK) > 0.8,"behind target actually reached by continuous turn")
	check(max_step < deg_to_rad(1.2),"no body attitude jump during the large heading change")
	evidence.behind_target = {"max_abs_pitch_deg":max_pitch,"max_body_step_deg":rad_to_deg(max_step),"states":rows}

func _circle() -> void:
	var world: SimulationWorld = _world(1000,110)
	var unit: UnitState = world.get_unit("f6f")
	var bank: float = deg_to_rad(65)
	unit.rotation_rad = AircraftFlightMath.frame(Vector3.FORWARD,Vector3.UP.rotated(Vector3.FORWARD,bank)).get_euler()
	unit.module_data.aircraft_motion.load_factor = 1/cos(bank)
	var error: float = 0
	var radius_min: float = INF
	var radius_max: float = 0
	var rows: Array = []
	for tick: int in range(900):
		var forward: Vector3 = unit.velocity_mps.normalized()
		var up: Vector3 = AircraftFlightMath.level_up(forward,Vector3.UP).rotated(forward,bank)
		unit.module_data["aircraft_control"] = {"lift_plane_normal":forward.cross(up),"load_factor_g":1/cos(bank),"speed_mps":110.0}
		world.step_ticks(1); world.drain_events()
		var speed: float = unit.velocity_mps.length()
		var measured: float = absf(float(unit.module_data.aircraft_motion.heading_rate_radps))
		var analytical: float = 9.80665*tan(bank)/speed
		error = maxf(error,absf(measured-analytical)/analytical)
		var radius: float = speed/maxf(measured,0.0001)
		radius_min = minf(radius_min,radius); radius_max = maxf(radius_max,radius)
		if tick%15 == 0: rows.append(_row(world))
	check(error < 0.03,"65 degree coordinated turn matches g*tan(bank)/V within3%: "+str(error))
	check(absf(unit.position_m.y-1000) < 8,"lift supports weight in a steady positive-load banked turn")
	check(radius_min > 300 and radius_max < 900,"F6F turn radius stays in the physical speed/load range")
	evidence.coordinated_turn = {"relative_rate_error_max":error,"radius_min_m":radius_min,"radius_max_m":radius_max,"states":rows}

func _half_roll() -> void:
	var world: SimulationWorld = _world(3000,110)
	var unit: UnitState = world.get_unit("f6f")
	var pulling: bool = false
	var finished: bool = false
	var inverted: bool = false
	var loaded_inverted_elevator: bool = false
	var minimum_pitch: float = 0
	var minimum_height: float = 3000
	var max_roll_rate: float = 0
	var minimum_speed: float = 110
	var maximum_speed: float = 110
	var max_step: float = 0
	var rows: Array = []
	var previous: Quaternion = Basis.from_euler(unit.rotation_rad).get_rotation_quaternion()
	for tick: int in range(1440):
		var forward: Vector3 = unit.velocity_mps.normalized()
		var pose: Basis = Basis.from_euler(unit.rotation_rad)
		var target_up: Vector3 = AircraftFlightMath.frame(forward,Vector3.LEFT.cross(forward)).y
		var roll_error: float = absf(AircraftFlightMath.signed_roll(pose.y,target_up,forward))
		if roll_error < deg_to_rad(8) and absf(float(unit.module_data.aircraft_motion.body_roll_rate_radps)) < deg_to_rad(18): pulling = true
		unit.module_data["aircraft_control"] = {"lift_plane_normal":Vector3.LEFT,"load_factor_g":4.5 if pulling else 0.65,"pull_through":pulling,"turn_side":1.0,"throttle":0.0}
		world.step_ticks(1); world.drain_events()
		var f: Dictionary = unit.module_data.aircraft_motion
		forward = unit.velocity_mps.normalized()
		inverted = inverted or (Basis.from_euler(unit.rotation_rad).y.dot(Vector3.UP) < -0.8)
		if Basis.from_euler(unit.rotation_rad).y.dot(Vector3.UP) < -0.6 and float(f.load_factor) > 2:
			loaded_inverted_elevator = loaded_inverted_elevator or float(f.elevator_rad) > 0.025
		minimum_pitch = minf(minimum_pitch,rad_to_deg(AircraftFlightMath.pitch(forward)))
		minimum_height = minf(minimum_height,unit.position_m.y)
		minimum_speed = minf(minimum_speed,unit.velocity_mps.length())
		maximum_speed = maxf(maximum_speed,unit.velocity_mps.length())
		max_roll_rate = maxf(max_roll_rate,absf(rad_to_deg(f.body_roll_rate_radps)))
		var q: Quaternion = Basis.from_euler(unit.rotation_rad).get_rotation_quaternion()
		max_step = maxf(max_step,previous.angle_to(q)); previous = q
		if tick%15 == 0: rows.append(_row(world))
		if pulling and forward.dot(Vector3.FORWARD) < -0.9 and forward.y > -0.12:
			finished = true
			break
	check(inverted and pulling and minimum_pitch < -75,"actual inverted roll followed by positive-load descending half-loop")
	check(loaded_inverted_elevator,"positive pull keeps the same elevator direction while inverted, without an Euler-pitch sign flip")
	check(finished and unit.position_m.y < 2600 and minimum_height > 250,"half-loop reverses flight direction, returns toward level, and preserves ground clearance")
	check(max_roll_rate <= 60.01 and max_step < deg_to_rad(1.3),"finite real roll rate and continuous body attitude through vertical")
	check(maximum_speed > minimum_speed+8,"gravity accelerates the descending segment while loaded drag dissipates energy")
	evidence.split_s_motion = {"finished":finished,"time_s":world.time_s(),"minimum_pitch_deg":minimum_pitch,"minimum_height_m":minimum_height,"minimum_speed_mps":minimum_speed,"maximum_speed_mps":maximum_speed,"max_roll_rate_degps":max_roll_rate,"max_body_step_deg":rad_to_deg(max_step),"states":rows}

func _tactics() -> void:
	var world: SimulationWorld = _world(2600,125)
	var unit: UnitState = world.get_unit("f6f")
	var p: Dictionary = AircraftPerformance.new().profile(unit.definition_id)
	var tail: Dictionary = AircraftFixture.contact("known",unit.position_m+Vector3(40,0,450),Vector3(0,0,-140))
	var memory: Dictionary = {}
	var result: Dictionary = AirCombatTactics.decide(unit,p,memory,tail,[tail],Vector3.BACK,0)
	check(result.mode == "split_s_roll" and not result.permit_fire,"known tail threat with real clearance triggers roll entry, not immediate pull")
	unit.position_m.y = 200
	unit.module_data.aircraft_motion.height_agl_m = 200
	unit.module_data.aircraft_motion.safety_state = "low_altitude_recovery"
	result = AirCombatTactics.decide(unit,p,memory,tail,[tail],Vector3.BACK,1)
	check(not memory.has("attitude") and not result.permit_fire,"low-altitude abort removes the roll program and firing permission")
	memory = {}
	unit.position_m.y = 2600
	unit.module_data.aircraft_motion.height_agl_m = 2600
	unit.module_data.aircraft_motion.safety_state = "normal"
	result = AirCombatTactics.decide(unit,p,memory,tail,[tail],Vector3.BACK,2)
	check(not str(result.mode).begins_with("split_s"),"clearing task/contact memory cannot bypass the physical aircraft maneuver cooldown")
	unit.position_m.y = 200
	unit.module_data.aircraft_motion.height_agl_m = 200
	result = AirCombatTactics.decide(unit,p,memory,tail,[tail],Vector3.BACK,0)
	check(not AirCombatManeuvers.split_s_envelope(unit,p).allowed and not str(result.mode).begins_with("split_s"),"insufficient actual AGL forbids the descending half-loop")
	check(world.reset(),"reset clears per-aircraft maneuver state")
	unit = world.get_unit("f6f")
	unit.position_m.y = 1500
	unit.module_data.aircraft_motion.height_agl_m = 1500
	unit.module_data.aircraft_motion.bank_rad = deg_to_rad(65)
	unit.rotation_rad = AircraftFlightMath.frame(Vector3.FORWARD,Vector3.UP.rotated(Vector3.FORWARD,deg_to_rad(65))).get_euler()
	var crossing: Dictionary = AircraftFixture.contact("known",unit.position_m+Vector3(-500,0,-550),Vector3(0,0,-110))
	memory = {}
	result = AirCombatTactics.decide(unit,p,memory,crossing,[crossing],Vector3(-1,0,-1),0)
	check(result.mode == "roll_reversal_roll","contact crossing the current bank triggers an actual reversal stage")
