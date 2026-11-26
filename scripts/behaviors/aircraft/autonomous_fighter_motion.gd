extends RefCounted

## Optional flight shapes during an assigned fighter engagement. Inputs here are
## the existing task's direction request and the aircraft's own motion/profile.
const ARC: String = "rising_arc"
const REVERSAL: String = "bank_reversal"
const ROLL: String = "axial_roll"
const OBLIQUE: String = "oblique_roll_arc"
const G: float = 9.80665
const ARC_GAIN_M: float = 235.0
const ARC_TURN_RAD: float = deg_to_rad(95.0)

static func select_shape(unit: UnitState, profile: Dictionary, direction: Vector3, terrain_top_m: float) -> String:
	var flight: Dictionary = unit.module_data.aircraft_motion
	if not _abort_reason(unit, profile).is_empty() or absf(float(flight.path_pitch_rad)) > deg_to_rad(28.0):
		return ""
	var speed: float = unit.velocity_mps.length()
	var reserve: float = (speed * speed - pow(_stall_speed(unit, profile) * 1.65, 2.0)) / (2.0 * G)
	var bank: float = flight.bank_rad
	var heading_error: float = _heading_error(unit, direction)
	var target_pitch: float = AircraftFlightMath.pitch(direction)
	var roll_time: float = 440.0 / float(profile.roll_rate_degps)
	var roll_loss: float = 0.5 * G * roll_time * roll_time + maxf(0.0, -unit.velocity_mps.y) * roll_time
	var roll_floor: float = terrain_top_m + float(profile.spatial.recovery_floor_m) + roll_loss + 230.0
	var can_roll: bool = reserve > 150.0 and absf(bank) < deg_to_rad(74.0) and unit.position_m.y > roll_floor
	var turn_requested: bool = absf(heading_error) > deg_to_rad(22.0) or (absf(bank) > deg_to_rad(32.0) and bank * heading_error < 0.0)
	var climbing_turn: bool = target_pitch > deg_to_rad(17.0) and turn_requested
	if climbing_turn and reserve > 190.0:
		var room_for_oblique: bool = can_roll and reserve > 270.0 and unit.position_m.y > roll_floor + 160.0
		# A steeper combined request can use the rolling variation while both
		# the recovery space and the existing turn direction support it.
		if room_for_oblique and target_pitch > deg_to_rad(24.0) and absf(heading_error) > deg_to_rad(23.0) and bank * heading_error <= 0.0:
			return OBLIQUE
		return ARC
	if absf(bank) > deg_to_rad(29.0) and bank * heading_error > 0.0 and absf(heading_error) > deg_to_rad(36.0):
		return REVERSAL
	var level_request: bool = absf(heading_error) < deg_to_rad(18.0) and absf(target_pitch) < deg_to_rad(11.0)
	if level_request and can_roll and absf(bank) >= deg_to_rad(43.0) and absf(float(flight.path_pitch_rad)) < deg_to_rad(14.0):
		return ROLL
	return ""

static func start(unit: UnitState, profile: Dictionary, task: Dictionary, now: float, terrain_top_m: float, direction: Vector3) -> void:
	var flight: Dictionary = unit.module_data.aircraft_motion
	var prior: Dictionary = flight.get("autonomous_maneuver", {})
	var distance: float = flight.distance_m
	if distance < float(prior.get("next_entry_distance_m", 0.0)):
		return
	var kind: String = select_shape(unit, profile, direction, terrain_top_m)
	if kind.is_empty():
		task.erase("motion_intent")
		return
	var heading: float = AircraftFlightMath.heading(unit.velocity_mps)
	var side: float = signf(float(flight.bank_rad)) if kind in [REVERSAL, ROLL] else -signf(_heading_error(unit, direction))
	var intent: Array = [kind, side]
	if task.get("motion_intent", []) != intent:
		task["motion_intent"] = intent
		task["motion_intent_since_s"] = now
		return
	# An opposing bank request already demonstrates a change from the current
	# turn. Its shorter confirmation allows a timely roll into the new arc.
	var confirm_s: float = 0.18 if kind == REVERSAL else 0.4
	if now - float(task.motion_intent_since_s) < confirm_s:
		return
	task.erase("motion_intent")
	var entry_right: Vector3 = AircraftFlightMath.direction(heading, 0.0).cross(Vector3.UP)
	task["autonomous_motion"] = {"kind":kind, "phase":"enter", "sequence":int(prior.get("sequence", 0)) + 1,
		"started_s":now, "entry_position_m":unit.position_m, "heading_rad":heading, "last_heading_rad":heading,
		"heading_change_rad":0.0, "stage_heading_rad":0.0, "roll_rad":0.0, "side":side,
		"arc_turn_rad":0.0, "initial_turn_rad":0.0, "opposite_turn_rad":0.0, "peak_roll_rad":0.0,
		"entry_distance_m":distance, "last_sample_s":now, "peak_gain_m":0.0, "lowest_offset_m":0.0,
		"entry_right_m":entry_right, "peak_lateral_offset_m":0.0}

static func step(unit: UnitState, profile: Dictionary, task: Dictionary, now: float) -> Dictionary:
	var state: Dictionary = task.autonomous_motion
	var flight: Dictionary = unit.module_data.aircraft_motion
	var forward: Vector3 = unit.velocity_mps.normalized()
	var heading: float = AircraftFlightMath.heading(forward)
	var turn_step: float = wrapf(heading - float(state.last_heading_rad), -PI, PI)
	state.heading_change_rad += turn_step
	state.stage_heading_rad += turn_step
	state.roll_rad += float(flight.body_roll_rate_radps) * (now - float(state.last_sample_s))
	state.last_heading_rad = heading
	state.last_sample_s = now
	var displacement: Vector3 = unit.position_m - (state.entry_position_m as Vector3)
	state.peak_gain_m = maxf(float(state.peak_gain_m), displacement.y)
	state.lowest_offset_m = minf(float(state.lowest_offset_m), displacement.y)
	state.peak_lateral_offset_m = maxf(float(state.peak_lateral_offset_m), absf(displacement.dot(state.entry_right_m)))
	var unsafe: String = _abort_reason(unit, profile, 1.48 if state.phase == "recover" else 1.66)
	if not unsafe.is_empty():
		finish(unit, task, now, unsafe)
		return {}
	if now - float(state.started_s) > (16.0 if state.kind == ROLL else 24.0):
		finish(unit, task, now, "envelope_timeout")
		return {}

	var bank: float = flight.bank_rad
	var side: float = state.side
	var target_heading: float = state.heading_rad
	var directed_arc_turn: float = float(state.heading_change_rad) * -side
	var pitch: float = 0.0
	var control: Dictionary = {"speed_mps":profile.combat_mps}
	match state.kind:
		ARC:
			state.arc_turn_rad = maxf(float(state.arc_turn_rad), directed_arc_turn)
			if state.phase == "enter" and directed_arc_turn > deg_to_rad(24.0):
				state.phase = "sweep"
			if state.phase == "sweep" and directed_arc_turn >= ARC_TURN_RAD and float(state.peak_gain_m) >= ARC_GAIN_M:
				state.phase = "recover"
			target_heading -= side * deg_to_rad(126.0)
			pitch = deg_to_rad(29.0)
		REVERSAL:
			if state.phase == "enter" and bank * side >= deg_to_rad(42.0) and float(state.stage_heading_rad) * -side > deg_to_rad(29.0):
				state.phase = "reverse"
				state.initial_turn_rad = float(state.stage_heading_rad) * -side
				state.heading_rad = heading
				state.stage_heading_rad = 0.0
			if state.phase == "reverse":
				target_heading = float(state.heading_rad) + side * deg_to_rad(92.0)
				pitch = deg_to_rad(19.0)
				if bank * -side >= deg_to_rad(42.0) and float(state.stage_heading_rad) * side > deg_to_rad(52.0):
					state.opposite_turn_rad = float(state.stage_heading_rad) * side
					state.phase = "recover"
			else:
				target_heading -= side * deg_to_rad(74.0)
				pitch = deg_to_rad(-14.0)
		ROLL, OBLIQUE:
			var oblique: bool = state.kind == OBLIQUE
			if state.phase == "enter":
				target_heading -= side * deg_to_rad(30.0) if oblique else 0.0
				pitch = deg_to_rad(32.0) if oblique else 0.0
				var has_rising_path: bool = float(flight.path_pitch_rad) > deg_to_rad(21.0) and directed_arc_turn > deg_to_rad(14.0) and float(state.peak_gain_m) >= 90.0
				var ready: bool = has_rising_path if oblique else absf(float(flight.path_pitch_rad)) < deg_to_rad(9.0)
				if ready:
					state.phase = "rotate"
					state["roll_started_rad"] = state.roll_rad
			if state.phase == "rotate":
				var roll_progress: float = (float(state.roll_rad) - float(state.roll_started_rad)) * side
				state.peak_roll_rad = maxf(float(state.peak_roll_rad), roll_progress)
				if roll_progress >= deg_to_rad(348.0):
					state.phase = "recover"
				else:
					var up: Vector3 = flight.lift_up_m
					var requested_up: Vector3 = up.rotated(forward, side * deg_to_rad(21.0))
					control["lift_plane_normal"] = forward.cross(requested_up)
					control["load_factor_g"] = 1.7 if oblique else 0.80
					target_heading = heading

	if state.phase == "recover":
		# Let the coordinated controller capture a level attitude through the
		# usual roll, load and energy limits. Test the actual settled flight.
		if not state.has("recovery_heading_rad"):
			state["recovery_heading_rad"] = heading
		target_heading = state.recovery_heading_rad
		pitch = 0.0
		var level: bool = absf(bank) < deg_to_rad(12.0) and absf(float(flight.path_pitch_rad)) < deg_to_rad(9.0)
		if level and absf(float(flight.body_roll_rate_radps)) < deg_to_rad(15.0):
			var measured_span: float = float(state.peak_gain_m) - float(state.lowest_offset_m)
			var oblique_geometry: bool = float(state.peak_lateral_offset_m) >= 130.0 and measured_span >= 160.0
			finish(unit, task, now, "geometry_complete" if state.kind != OBLIQUE or oblique_geometry else "displacement_shortfall")
			return {}
	control["direction"] = AircraftFlightMath.direction(target_heading, pitch)
	publish(unit, state, "executing", "", -1.0)
	return control

static func finish(unit: UnitState, task: Dictionary, now: float, reason: String) -> void:
	if not task.has("autonomous_motion"):
		return
	var state: Dictionary = task.autonomous_motion
	publish(unit, state, "completed" if reason == "geometry_complete" else "aborted", reason, now)
	task.erase("autonomous_motion")
	task.erase("motion_intent")

static func publish(unit: UnitState, state: Dictionary, status: String, reason: String, ended_s: float) -> void:
	var flight: Dictionary = unit.module_data.aircraft_motion
	flight["autonomous_maneuver"] = {"kind":state.kind, "phase":state.phase, "sequence":state.sequence,
		"status":status, "reason":reason, "started_s":state.started_s, "ended_s":ended_s, "entry_position_m":state.entry_position_m,
		"position_m":unit.position_m, "heading_change_rad":state.heading_change_rad, "body_roll_rad":state.roll_rad,
		"height_change_m":unit.position_m.y - (state.entry_position_m as Vector3).y, "peak_gain_m":state.peak_gain_m,
		"height_span_m":float(state.peak_gain_m) - float(state.lowest_offset_m), "peak_lateral_offset_m":state.peak_lateral_offset_m,
		"arc_turn_rad":state.arc_turn_rad, "initial_turn_rad":state.initial_turn_rad, "opposite_turn_rad":state.opposite_turn_rad,
		"peak_roll_rad":state.peak_roll_rad,
		"path_length_m":float(flight.distance_m) - float(state.entry_distance_m),
		"next_entry_distance_m":float(flight.distance_m) + 1250.0}

static func _heading_error(unit: UnitState, direction: Vector3) -> float:
	var heading: float = AircraftFlightMath.heading(unit.velocity_mps)
	return wrapf(AircraftFlightMath.heading(direction, heading) - heading, -PI, PI)

static func _stall_speed(unit: UnitState, profile: Dictionary) -> float:
	return float(profile.stall_mps) * exp(unit.position_m.y / (2.0 * float(profile.spatial.density_scale_m)))

static func _abort_reason(unit: UnitState, profile: Dictionary, stall_ratio: float = 1.73) -> String:
	var flight: Dictionary = unit.module_data.aircraft_motion
	if not unit.active or bool(flight.get("surface_contact", false)) or bool(flight.exited):
		return "flight_unavailable"
	var damage: Dictionary = unit.module_data.get("damage", {})
	if float(damage.get("control_factor", 1.0)) < 0.92 or float(damage.get("propulsion_factor", 1.0)) < 0.92:
		return "flight_damage"
	if flight.safety_state != "normal":
		return str(flight.safety_state)
	if unit.velocity_mps.length() < _stall_speed(unit, profile) * stall_ratio:
		return "low_energy"
	var high_enough: bool = float(flight.height_agl_m) >= float(profile.spatial.recovery_floor_m) + 290.0
	if not high_enough or unit.position_m.y > float(profile.ceiling_m) - 650.0:
		return "altitude_margin"
	return ""
