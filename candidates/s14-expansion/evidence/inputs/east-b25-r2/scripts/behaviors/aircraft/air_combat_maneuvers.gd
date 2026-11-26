class_name AirCombatManeuvers
extends RefCounted

## Geometry-driven F6F defensive maneuvers. No world or hidden enemy access.
## A plane normal is fixed at entry; forces, not an animation, bend the path.
static func decide(unit: UnitState, p: Dictionary, memory: Dictionary, contact: Dictionary, threat: Dictionary, now: float) -> Dictionary:
	if unit.definition_id != "us_f6f5_1944": return {}
	var flight: Dictionary = unit.module_data.aircraft_motion
	var forward: Vector3 = unit.velocity_mps.normalized()
	var speed: float = unit.velocity_mps.length()
	var clearance: float = flight.height_agl_m
	var safety: String = flight.safety_state
	var pose: Basis = Basis.from_euler(unit.rotation_rad)
	var active: Dictionary = memory.get("attitude",{})
	var blocked_until: float = float(unit.module_data.get("aircraft_maneuver",{}).get("blocked_until_s",0))
	if active.is_empty() and now >= maxf(float(memory.get("cooldown_until_s",0)),blocked_until) and safety == "normal" and speed > float(p.stall_mps)*1.65 and pose.y.dot(AircraftFlightMath.level_up(forward,pose.y)) > 0.1:
		var offset: Vector3 = (contact.position_m as Vector3)-unit.position_m
		var heading_error: float = wrapf(AircraftFlightMath.heading(offset)-AircraftFlightMath.heading(forward),-PI,PI)
		var side: float = -signf(heading_error)
		if absf(side) < 0.5: side = 1.0
		var selected: String = ""
		var reason: String = ""
		var split: Dictionary = split_s_envelope(unit,p)
		if not threat.is_empty():
			selected = "split_s" if bool(split.allowed) else "break_turn"
			reason = "tail_contact_split_s_envelope" if selected == "split_s" else "tail_contact_roll_and_pull"
			var lateral: float = pose.x.dot((threat.position_m as Vector3)-unit.position_m)
			if absf(lateral) > 20: side = -signf(lateral)
		elif absf(float(flight.bank_rad)) > deg_to_rad(40) and float(flight.bank_rad)*side < 0 and offset.length() < 950 and absf(heading_error) > deg_to_rad(30) and clearance > 450:
			selected = "roll_reversal"
			reason = "contact_crossed_current_turn"
		if not selected.is_empty() and clearance > 350:
			var entry_up: Vector3 = AircraftFlightMath.level_up(forward,pose.y)
			var roll_angle: float = PI*side if selected == "split_s" else deg_to_rad(80)*side
			var target_up: Vector3 = entry_up.rotated(forward,roll_angle)
			active = {"mode":selected,"stage":"roll","started_s":now,"entry_forward":forward,
				"plane_normal":forward.cross(target_up).normalized(),"side":side,"reason":reason,
				"pull_started_s":-1.0,"entry_height_m":unit.position_m.y,"entry_speed_mps":speed}
			memory["attitude"] = active
	if active.is_empty(): return {}
	var mode: String = active.mode
	var elapsed: float = now-float(active.started_s)
	var stalled: bool = safety == "stall_recovery" or speed < float(p.stall_mps)*1.3
	var abort: bool = stalled or safety in ["terrain_recovery","overspeed_recovery","glide"]
	# A committed descending half-loop keeps pulling through instead of rolling
	# 180 degrees at the vertical. The motion safety controller can increase load.
	if safety == "low_altitude_recovery" and not (mode == "split_s" and active.stage == "pull"):
		abort = true
	var target_up: Vector3 = AircraftFlightMath.frame(forward,(active.plane_normal as Vector3).cross(forward)).y
	var roll_error: float = absf(AircraftFlightMath.signed_roll(pose.y,target_up,forward))
	if active.stage == "roll" and roll_error < deg_to_rad(8) and absf(float(flight.body_roll_rate_radps)) < deg_to_rad(18):
		active.stage = "pull"
		active.pull_started_s = now
	var bend: float = (active.entry_forward as Vector3).angle_to(forward)
	var finished: bool = active.stage == "pull" and (bend > deg_to_rad(65) if mode != "split_s" else (bend > deg_to_rad(145) and forward.y > -0.14))
	if abort or finished or elapsed > (18.0 if mode == "split_s" else 12.0):
		memory.erase("attitude")
		memory.mode = "track"
		memory.last_exit = "safety_abort" if abort else ("maneuver_geometry_complete" if finished else "maneuver_timeout")
		memory.cooldown_until_s = now+(10.0 if mode == "split_s" else 6.0)
		unit.module_data["aircraft_maneuver"] = {"blocked_until_s":memory.cooldown_until_s,"last_exit":memory.last_exit}
		return {}
	var stall_speed: float = float(p.stall_mps)*exp(unit.position_m.y/(2*float(p.spatial.density_scale_m)))
	var available: float = minf(float(p.spatial.operating_load_g),pow(speed/(stall_speed*float(p.spatial.stall_control_margin)),2))
	var requested: float = 0.65 if active.stage == "roll" else minf(4.8,available)
	return {"direction":forward,"speed_mps":p.combat_mps,"max_bank_rad":PI,"turn_side":active.side,
		"mode":mode+"_"+str(active.stage),"reason":active.reason,"phase":"evade","permit_fire":false,
		"last_exit":memory.get("last_exit",""),"attitude":{"lift_plane_normal":active.plane_normal,
			"load_factor_g":requested,"pull_through":mode == "split_s" and active.stage == "pull","throttle":0.0 if mode == "split_s" else 1.0},
		"maneuver_roll_error_rad":roll_error,"maneuver_bend_rad":bend}

static func split_s_envelope(unit: UnitState, p: Dictionary) -> Dictionary:
	var flight: Dictionary = unit.module_data.aircraft_motion
	var speed: float = unit.velocity_mps.length()
	var stall_speed: float = float(p.stall_mps)*exp(unit.position_m.y/(2*float(p.spatial.density_scale_m)))
	var load: float = minf(4.8,pow(speed/(stall_speed*float(p.spatial.stall_control_margin)),2))
	if load < 2.5: return {"allowed":false}
	# Conservative no-drag, unpowered constant-load vertical half-loop energy:
	# V_out/V_in=(n+1)/(n-1). Drag lowers the exit speed and altitude loss.
	var exit_speed: float = speed*(load+1)/(load-1)
	var roll_time: float = 180.0/float(p.roll_rate_degps)+0.5
	var loss: float = (exit_speed*exit_speed-speed*speed)/19.6133+4.903325*roll_time*roll_time
	var local_max: float = lerpf(float(p.sea_level_max_mps),float(p.max_level_mps),clampf(unit.position_m.y/float(p.optimum_altitude_m),0,1))
	var allowed: bool = flight.height_agl_m > loss+float(p.spatial.recovery_floor_m)+250 and exit_speed < local_max*float(p.spatial.dive_speed_factor)*0.96 and absf(AircraftFlightMath.pitch(unit.velocity_mps)) < deg_to_rad(20)
	return {"allowed":allowed,"estimated_loss_m":loss,"estimated_exit_speed_mps":exit_speed,"load_g":load}
