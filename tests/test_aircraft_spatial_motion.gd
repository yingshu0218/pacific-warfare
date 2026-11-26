extends SceneTree
var checks: int = 0
var failures: int = 0
var evidence: Dictionary = {}

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)
		quit(1)
		assert(ok,reason)

func _initialize() -> void:
	for name: String in ["zoom","dive","oblique","stall","low","vertical","glide"]:
		var initial: Dictionary = {"fuel_kg":0.0} if name == "glide" else {}
		var height: float = 200.0 if name == "low" else 2200.0
		var speed: float = 35.0 if name == "stall" else 120.0
		var world: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("pilot","jp",Vector3(0,height,0),"jp_a6m5a_1944",0,speed,initial)])
		var unit: UnitState = world.get_unit("pilot")
		var direction: Vector3 = Vector3.FORWARD
		match name:
			"zoom": direction = AircraftFlightMath.elevated(Vector3.FORWARD,deg_to_rad(38))
			"dive": direction = AircraftFlightMath.elevated(Vector3.FORWARD,deg_to_rad(-38))
			"oblique": direction = Vector3(-0.8,0.6,-1).normalized()
			"stall": direction = Vector3.UP
			"low": direction = Vector3(0.3,-0.8,-1).normalized()
			"vertical":
				direction = Vector3.UP
				unit.velocity_mps = Vector3(0,120,-0.001)
				unit.rotation_rad = AircraftFlightMath.frame(unit.velocity_mps,Vector3.RIGHT).get_euler()
			"glide": direction = Vector3.UP
		unit.module_data["aircraft_control"] = {"flight_direction":direction,"speed_mps":125.0,"max_bank_rad":deg_to_rad(78),"throttle":0.0 if name in ["dive","glide"] else 0.85}
		var initial_energy: float = unit.position_m.y+unit.velocity_mps.length_squared()/19.6133
		var states: Array = []
		var max_pitch: float = -90.0
		var min_pitch: float = 90.0
		var minimum_height: float = height
		var minimum_speed: float = speed
		var maximum_g: float = 0.0
		var max_pose_error: float = 0.0
		var max_attitude_step: float = 0.0
		var safety: Dictionary = {}
		var previous: Quaternion = Basis.from_euler(unit.rotation_rad).get_rotation_quaternion()
		for tick: int in range(1200 if name in ["stall","vertical"] else (720 if name == "dive" else 480)):
			world.step_ticks(1)
			world.drain_events()
			var f: Dictionary = unit.module_data.aircraft_motion
			var basis: Basis = Basis.from_euler(unit.rotation_rad)
			check(unit.position_m.is_finite() and unit.velocity_mps.is_finite() and basis.is_finite(),name+" finite")
			var orientation: Quaternion = basis.get_rotation_quaternion()
			max_attitude_step = maxf(max_attitude_step,previous.angle_to(orientation))
			previous = orientation
			max_pose_error = maxf(max_pose_error,(-basis.z).angle_to(unit.velocity_mps))
			var pitch: float = rad_to_deg(AircraftFlightMath.pitch(unit.velocity_mps))
			max_pitch = maxf(max_pitch,pitch)
			min_pitch = minf(min_pitch,pitch)
			minimum_height = minf(minimum_height,unit.position_m.y)
			minimum_speed = minf(minimum_speed,unit.velocity_mps.length())
			maximum_g = maxf(maximum_g,float(f.load_factor))
			safety[str(f.safety_state)] = true
			if tick%15 == 0:
				states.append({"time_s":world.time_s(),"position_m":SimData.array3(unit.position_m),"velocity_mps":SimData.array3(unit.velocity_mps),"pitch_deg":pitch,"bank_deg":rad_to_deg(float(f.bank_rad)),"speed_mps":f.speed_mps,"energy_height_m":f.energy_height_m,"load_g":f.load_factor,"safety":f.safety_state})
		check(max_pose_error < 0.001,name+" velocity/model same direction")
		check(max_attitude_step < deg_to_rad(2.0),name+" finite orientation steps, including near vertical")
		check(maximum_g <= 5.501,name+" operating load bound")
		if name == "zoom":
			check(max_pitch > 28 and unit.position_m.y > height+180,"zoom exchanges kinetic energy for real height")
			check(unit.velocity_mps.length() < speed-15,"zoom consumes speed")
		if name == "dive":
			check(min_pitch < -25 and unit.position_m.y < height-150,"real steep dive")
			check(unit.velocity_mps.length() > minimum_speed+8,"gravity accelerates after the finite nose-down transition")
			check(float(unit.module_data.aircraft_motion.energy_height_m) < initial_energy+3,"unpowered dive creates no mechanical energy")
		if name == "oblique":
			check(unit.position_m.x < -180 and unit.position_m.y > height+100,"roll/pitch jointly bend actual three-dimensional trajectory")
		if name == "stall":
			check(safety.has("stall_recovery") and unit.velocity_mps.length() > speed+12,"low speed unloads and recovers")
		if name == "low":
			check(safety.has("low_altitude_recovery") and minimum_height > 80,"low altitude refuses unsafe dive before contact")
		if name == "glide":
			check(unit.position_m.y < height-20 and float(unit.module_data.aircraft_motion.fuel_used_kg) == 0,"empty tank cannot sustain climb or hover")
		evidence[name] = {"max_pitch_deg":max_pitch,"min_pitch_deg":min_pitch,"max_g":maximum_g,"max_pose_error_rad":max_pose_error,"max_attitude_step_rad":max_attitude_step,"min_speed_mps":minimum_speed,"min_height_m":minimum_height,"safety":safety,"states":states}
		print("spatial motion ",name," pitch=",min_pitch,"..",max_pitch," speed=",unit.velocity_mps.length()," height=",unit.position_m.y," max_g=",maximum_g)
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-spatial/motion.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	print("S04 spatial motion ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
