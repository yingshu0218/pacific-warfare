class_name AircraftTraining
extends RefCounted

## Explicit high-level drills. No transform writes, camera, enemy reads or RNG.
const KINDS: PackedStringArray = ["bank_turn","climb_dive","axial_roll","roll_reversal","split_s"]
const DURATIONS: Dictionary = {"bank_turn":45.0,"climb_dive":55.0,"axial_roll":25.0,"roll_reversal":45.0,"split_s":30.0}
const START_AGL: Dictionary = {"bank_turn":600.0,"climb_dive":800.0,"axial_roll":1000.0,"roll_reversal":1000.0,"split_s":1000.0}
const KEYS: PackedStringArray = ["maneuver","direction","turn_angle_deg","climb_height_m","bank_angle_deg","min_start_agl_m","max_duration_s"]

static func validate(unit: UnitState, p: Dictionary, request: Dictionary) -> String:
	if unit.definition_id not in ["us_f6f5_1944","jp_a6m5a_1944"]: return "training_fighter_only"
	if str(request.get("maneuver","")) not in KINDS: return "training_unknown_maneuver"
	for key: Variant in request:
		if str(key) not in KEYS: return "training_unknown_parameter:"+str(key)
	var kind: String = request.maneuver
	for key: String in ["direction","turn_angle_deg","climb_height_m","bank_angle_deg","min_start_agl_m","max_duration_s"]:
		if request.has(key) and not SimData.finite_number(request[key]): return "training_invalid_number:"+key
	if absf(float(request.get("direction",1))) != 1: return "training_direction_must_be_plus_or_minus_one"
	if request.has("turn_angle_deg") and kind != "bank_turn": return "training_turn_angle_not_applicable"
	if request.has("climb_height_m") and kind != "climb_dive": return "training_climb_height_not_applicable"
	if request.has("bank_angle_deg") and kind not in ["bank_turn","roll_reversal"]: return "training_bank_angle_not_applicable"
	if float(request.get("turn_angle_deg",90)) < 45 or float(request.get("turn_angle_deg",90)) > 180: return "training_turn_angle_out_of_range"
	if float(request.get("climb_height_m",100)) < 60 or float(request.get("climb_height_m",100)) > 250: return "training_climb_height_out_of_range"
	if float(request.get("bank_angle_deg",65)) < 45 or float(request.get("bank_angle_deg",65)) > minf(65,float(p.max_bank_deg)): return "training_bank_angle_out_of_range"
	if float(request.get("max_duration_s",DURATIONS[kind])) < 5 or float(request.get("max_duration_s",DURATIONS[kind])) > 60: return "training_duration_out_of_range"
	if float(request.get("min_start_agl_m",0)) < 0: return "training_invalid_minimum_agl"
	var flight: Dictionary = unit.module_data.get("aircraft_motion",{})
	if flight.is_empty(): return "training_flight_state_missing"
	var unsafe: String = safety_reason(unit,p)
	if not unsafe.is_empty(): return unsafe
	if float(flight.height_agl_m) < maxf(float(START_AGL[kind]),float(request.get("min_start_agl_m",0))): return "training_insufficient_start_agl"
	var forward: Vector3 = unit.velocity_mps.normalized()
	var basis: Basis = unit.world_transform().basis
	if absf(AircraftFlightMath.pitch(forward)) > deg_to_rad(20) or basis.y.dot(AircraftFlightMath.level_up(forward,basis.y)) < cos(deg_to_rad(20)) or absf(float(flight.body_roll_rate_radps)) > deg_to_rad(12): return "training_requires_level_entry"
	if kind == "split_s" and not bool(AirCombatManeuvers.split_s_envelope(unit,p).allowed): return "training_split_s_envelope"
	return ""

static func safety_reason(unit: UnitState, p: Dictionary) -> String:
	var flight: Dictionary = unit.module_data.get("aircraft_motion",{})
	var damage: Dictionary = unit.module_data.get("damage",{})
	if not unit.active or bool(flight.get("exited",false)): return "training_recipient_inactive"
	if float(damage.get("propulsion_factor",1)) < .99: return "training_power_lost"
	if float(damage.get("control_factor",1)) < .99: return "training_control_lost"
	if damage.get("phase","operational") != "operational" or float(damage.get("structure",1)) < float(damage.get("structure_max",1))-.0001 or float(damage.get("fire",0)) > 0: return "training_damage"
	if float(flight.get("fuel_kg",0)) <= float(p.cruise_burn_kgps)*float(p.reserve_s): return "training_low_fuel"
	var stall: float = float(p.stall_mps)*exp(unit.position_m.y/(2*float(p.spatial.density_scale_m)))
	if bool(flight.get("stalled",false)) or unit.velocity_mps.length() < stall*1.5: return "training_stall_margin"
	if float(flight.get("height_agl_m",0)) < float(p.spatial.recovery_floor_m)+150: return "training_low_altitude"
	var state: String = str(flight.get("safety_state","normal"))
	if state != "normal": return "training_safety:"+state
	var local_max: float = lerpf(float(p.sea_level_max_mps),float(p.max_level_mps),clampf(unit.position_m.y/float(p.optimum_altitude_m),0,1))
	local_max *= maxf(.4,1.0-maxf(0,unit.position_m.y-float(p.optimum_altitude_m))/float(p.ceiling_m))
	if unit.velocity_mps.length() > local_max*float(p.spatial.dive_speed_factor)*.99: return "training_overspeed"
	return ""

static func begin(unit: UnitState, request: Dictionary, now: float, order_id: String) -> Dictionary:
	var forward: Vector3 = unit.velocity_mps.normalized()
	var up: Vector3 = unit.world_transform().basis.y
	var kind: String = request.maneuver
	return {"order_id":order_id,"maneuver":kind,"direction":float(request.get("direction",1)),"phase":"climb" if kind == "climb_dive" else ("roll" if kind in ["axial_roll","split_s"] else "roll_in"),"status":"executing","reason":"training_received","started_s":now,"elapsed_s":0.0,"entry_position_m":unit.position_m,"entry_forward":forward,"entry_heading_rad":AircraftFlightMath.heading(forward),"entry_up":AircraftFlightMath.level_up(forward,up),"last_forward":forward,"last_up":up,"last_heading_rad":AircraftFlightMath.heading(forward),"roll_accum_rad":0.0,"peak_roll_rad":0.0,"heading_change_rad":0.0,"height_change_m":0.0,"peak_height_m":unit.position_m.y,"min_agl_m":unit.module_data.aircraft_motion.height_agl_m,"bend_rad":0.0,"recover_heading_rad":AircraftFlightMath.heading(forward),"target_turn_rad":deg_to_rad(float(request.get("turn_angle_deg",90))),"target_climb_m":float(request.get("climb_height_m",100)),"bank_rad":deg_to_rad(float(request.get("bank_angle_deg",65))),"plane_normal":forward.cross(-AircraftFlightMath.level_up(forward,up)).normalized(),"max_duration_s":float(request.get("max_duration_s",DURATIONS[kind])),"phase_history":[]}

static func measure(unit: UnitState, state: Dictionary, now: float) -> void:
	var forward: Vector3 = unit.velocity_mps.normalized()
	var up: Vector3 = unit.world_transform().basis.y
	var previous_forward: Vector3 = state.last_forward
	var previous_up: Vector3 = state.last_up
	var axis: Vector3 = previous_forward.cross(forward)
	if axis.length_squared() > .000000001: previous_up = previous_up.rotated(axis.normalized(),previous_forward.angle_to(forward))
	previous_up = AircraftFlightMath.frame(forward,previous_up).y
	state.roll_accum_rad += AircraftFlightMath.signed_roll(previous_up,up,forward)
	state.peak_roll_rad = maxf(float(state.peak_roll_rad),absf(float(state.roll_accum_rad)))
	var heading: float = AircraftFlightMath.heading(forward,float(state.last_heading_rad))
	state.heading_change_rad += wrapf(heading-float(state.last_heading_rad),-PI,PI)
	state.last_forward = forward
	state.last_up = up
	state.last_heading_rad = heading
	state.elapsed_s = now-float(state.started_s)
	state.height_change_m = unit.position_m.y-(state.entry_position_m as Vector3).y
	state.peak_height_m = maxf(float(state.peak_height_m),unit.position_m.y)
	state.min_agl_m = minf(float(state.min_agl_m),float(unit.module_data.aircraft_motion.height_agl_m))
	state.bend_rad = (state.entry_forward as Vector3).angle_to(forward)

static func change_phase(state: Dictionary, phase: String) -> void:
	if str(state.phase) == phase: return
	state.phase_history.append({"phase":state.phase,"until_s":state.elapsed_s,"roll_accum_rad":state.roll_accum_rad,"heading_change_rad":state.heading_change_rad,"height_change_m":state.height_change_m})
	state.phase = phase

static func abort(state: Dictionary, reason: String) -> void:
	state.status = "aborted"
	state.reason = reason
	change_phase(state,"aborted")

static func roll_control(unit: UnitState, p: Dictionary, up: Vector3, load_g: float, side: float, throttle: float = 1.0) -> Dictionary:
	var forward: Vector3 = unit.velocity_mps.normalized()
	return {"flight_direction":forward,"speed_mps":p.combat_mps,"max_bank_rad":PI,"turn_side":side,"lift_plane_normal":forward.cross(up),"load_factor_g":load_g,"throttle":throttle}

static func recovery_control(state: Dictionary, p: Dictionary) -> Dictionary:
	return {"flight_direction":AircraftFlightMath.direction(float(state.recover_heading_rad),0),"speed_mps":p.combat_mps,"max_bank_rad":deg_to_rad(35)}

static func public_state(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["order_id","maneuver","direction","phase","status","reason","elapsed_s","roll_accum_rad","peak_roll_rad","heading_change_rad","height_change_m","peak_height_m","min_agl_m","bend_rad","target_turn_rad","target_climb_m","phase_history"]: result[key] = state[key]
	return result.duplicate(true)

static func step(unit: UnitState, p: Dictionary, state: Dictionary, now: float) -> Dictionary:
	measure(unit,state,now)
	var unsafe: String = safety_reason(unit,p)
	if not unsafe.is_empty(): abort(state,unsafe); return {}
	if float(state.elapsed_s) > float(state.max_duration_s): abort(state,"training_timeout"); return {}
	var forward: Vector3 = unit.velocity_mps.normalized()
	var pose: Basis = unit.world_transform().basis
	var level: Vector3 = AircraftFlightMath.level_up(forward,pose.y)
	var side: float = state.direction
	var flight: Dictionary = unit.module_data.aircraft_motion
	if state.phase == "recover":
		var heading_error: float = absf(wrapf(float(state.recover_heading_rad)-AircraftFlightMath.heading(forward),-PI,PI))
		if pose.y.dot(level) > cos(deg_to_rad(7)) and absf(AircraftFlightMath.pitch(forward)) < deg_to_rad(5) and absf(float(flight.body_roll_rate_radps)) < deg_to_rad(8) and heading_error < deg_to_rad(10):
			state.status = "completed"
			state.reason = "training_geometry_complete"
			change_phase(state,"completed")
			return {}
		return recovery_control(state,p)
	var kind: String = state.maneuver
	if kind == "climb_dive":
		if state.phase == "climb" and float(state.height_change_m) >= float(state.target_climb_m): change_phase(state,"dive")
		if state.phase == "dive" and float(state.height_change_m) <= 45 and AircraftFlightMath.pitch(forward) < deg_to_rad(-5):
			change_phase(state,"recover")
			return recovery_control(state,p)
		return {"flight_direction":AircraftFlightMath.direction(float(state.entry_heading_rad),deg_to_rad(12 if state.phase == "climb" else -12)),"speed_mps":p.combat_mps,"throttle":1.0 if state.phase == "climb" else 0.0,"max_bank_rad":deg_to_rad(30)}
	if kind == "axial_roll":
		# A small arrest allowance lets the measured rotation actually cross 2PI;
		# the pilot then settles upright using the existing finite roll acceleration.
		var remaining: float = TAU+deg_to_rad(2)-side*float(state.roll_accum_rad)
		if side*float(state.roll_accum_rad) >= TAU and absf(float(flight.body_roll_rate_radps)) < deg_to_rad(8):
			change_phase(state,"recover")
			return recovery_control(state,p)
		var lookahead: float = clampf(remaining,deg_to_rad(-25),deg_to_rad(75))
		return roll_control(unit,p,pose.y.rotated(forward,side*lookahead),.35,side)
	if kind == "split_s":
		var up: Vector3 = AircraftFlightMath.frame(forward,(state.plane_normal as Vector3).cross(forward)).y
		var roll_error: float = absf(AircraftFlightMath.signed_roll(pose.y,up,forward))
		if state.phase == "roll" and roll_error < deg_to_rad(7) and pose.y.dot(level) < -.95 and absf(float(flight.body_roll_rate_radps)) < deg_to_rad(15): change_phase(state,"pull")
		if state.phase == "pull" and float(state.bend_rad) > deg_to_rad(155) and forward.y > -sin(deg_to_rad(20)):
			state.recover_heading_rad = wrapf(float(state.entry_heading_rad)+PI,-PI,PI)
			change_phase(state,"recover")
			return recovery_control(state,p)
		var stall: float = float(p.stall_mps)*exp(unit.position_m.y/(2*float(p.spatial.density_scale_m)))
		var available: float = minf(float(p.spatial.operating_load_g),pow(unit.velocity_mps.length()/(stall*float(p.spatial.stall_control_margin)),2))
		var control: Dictionary = roll_control(unit,p,up,.55 if state.phase == "roll" else minf(4.5,available*.95),side,0)
		control["pull_through"] = state.phase == "pull"
		return control
	# Coordinated bank turn and two-stage bank reversal, measured by real heading.
	var bank_side: float = -side if state.phase in ["roll_reverse","pull_reverse"] else side
	var target_up: Vector3 = level.rotated(forward,bank_side*float(state.bank_rad))
	var error: float = absf(AircraftFlightMath.signed_roll(pose.y,target_up,forward))
	if state.phase in ["roll_in","roll_reverse"] and error < deg_to_rad(7) and absf(float(flight.body_roll_rate_radps)) < deg_to_rad(15):
		if state.phase == "roll_reverse":
			state["reverse_heading_start_rad"] = state.heading_change_rad
			change_phase(state,"pull_reverse")
		else: change_phase(state,"pull_turn")
	if kind == "bank_turn" and state.phase == "pull_turn" and -side*float(state.heading_change_rad) >= float(state.target_turn_rad):
		state.recover_heading_rad = wrapf(float(state.entry_heading_rad)-side*float(state.target_turn_rad),-PI,PI)
		change_phase(state,"recover")
		return recovery_control(state,p)
	if kind == "roll_reversal":
		if state.phase == "pull_turn" and -side*float(state.heading_change_rad) >= deg_to_rad(35): change_phase(state,"roll_reverse")
		if state.phase == "pull_reverse" and side*(float(state.heading_change_rad)-float(state.reverse_heading_start_rad)) >= deg_to_rad(45):
			state.recover_heading_rad = AircraftFlightMath.heading(forward)
			change_phase(state,"recover")
			return recovery_control(state,p)
	var pulling: bool = state.phase in ["pull_turn","pull_reverse"]
	return roll_control(unit,p,target_up,1.0/cos(float(state.bank_rad)) if pulling else .55,bank_side)
