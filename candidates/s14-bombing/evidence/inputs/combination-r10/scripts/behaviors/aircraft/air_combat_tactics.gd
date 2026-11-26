class_name AirCombatTactics
extends RefCounted

## Pure pilot decisions: only own state and copied, faction-visible contacts enter.
## No world/enemy lookup, random motion, model access, damage or projectile writer.
static func decide(unit: UnitState, p: Dictionary, memory: Dictionary, contact: Dictionary, contacts: Array, aim: Vector3, now: float) -> Dictionary:
	var forward: Vector3 = -Basis.from_euler(unit.rotation_rad).z
	var point: Vector3 = contact.position_m + (contact.velocity_mps as Vector3)*maxf(0,now-float(contact.observed_time_s))
	var offset: Vector3 = point-unit.position_m
	var distance: float = offset.length()
	var speed: float = unit.velocity_mps.length()
	var target_speed: float = (contact.velocity_mps as Vector3).length()
	var closure: float = (unit.velocity_mps-(contact.velocity_mps as Vector3)).dot(offset.normalized())
	var height_advantage: float = unit.position_m.y-point.y
	var safe_speed: float = maxf(float(p.stall_mps)*1.75,float(p.cruise_mps)*0.80)
	var kinetic_margin: float = maxf(0,(speed*speed-safe_speed*safe_speed)/19.6133)
	var pursuit: bool = forward.dot((contact.velocity_mps as Vector3).normalized()) > 0.4
	var angle: float = forward.angle_to(offset)
	if not memory.has("mode"):
		memory.merge({"mode":"track","entered_s":now,"entry_position_m":unit.position_m,"entry_speed_mps":speed,
			"entry_forward":forward,"last_setup_s":-1000.0,"cooldown_until_s":0.0,"last_exit":"","target_id":contact.entity_id})
	if str(memory.target_id) != str(contact.entity_id):
		memory.mode = "track"
		memory.target_id = contact.entity_id
	var attitude: Dictionary = AirCombatManeuvers.decide(unit,p,memory,contact,_tail_threat(unit,contacts,forward),now)
	if not attitude.is_empty():
		attitude.merge({"relative_height_m":height_advantage,"closing_mps":closure,"energy_margin_m":kinetic_margin})
		return attitude
	var mode: String = memory.mode
	var elapsed: float = now-float(memory.entered_s)
	var changed_height: float = unit.position_m.y-(memory.entry_position_m as Vector3).y
	var finish: String = ""
	if mode == "climb_setup" and (changed_height > 190 or speed < safe_speed or distance < 950):
		finish = "position_or_energy_reached"
	elif mode == "high_yoyo" and (changed_height > 180 or closure < 12 or speed < safe_speed):
		finish = "closure_reduced"
	elif mode == "low_yoyo" and (changed_height < -160 or speed > target_speed+5 or speed > float(p.sea_level_max_mps)*0.98):
		finish = "speed_recovered"
	elif mode == "dive_attack" and (distance < 230 or height_advantage < 45):
		finish = "attack_pass_finished"
	elif mode in ["zoom_climb","diving_break","oblique_extend"] and elapsed > 2.0 and (absf(changed_height) > 210 or distance > 1200):
		finish = "separation_reached"
	if mode != "track" and elapsed > (8.0 if mode == "dive_attack" else 6.0):
		finish = "maneuver_timeout"
	var flight: Dictionary = unit.module_data.get("aircraft_motion",{})
	var clearance: float = float(flight.get("height_agl_m",unit.position_m.y))
	var unsafe: bool = str(flight.get("safety_state","normal")) in ["stall_recovery","low_altitude_recovery","overspeed_recovery","energy_recovery","terrain_recovery"] or speed < float(p.stall_mps)*1.32
	if unsafe and not bool(memory.get("recovery_active",false)):
		memory["recovery_active"] = true
		memory["recovery_until_s"] = now+1.5
		memory["recovery_reason"] = str(flight.get("safety_state","energy_margin"))
		if memory.recovery_reason == "normal": memory.recovery_reason = "low_energy"
	if bool(memory.get("recovery_active",false)):
		var recovered: bool = not unsafe and now >= float(memory.recovery_until_s) and speed > float(p.stall_mps)*1.50 and absf(AircraftFlightMath.pitch(forward)) < deg_to_rad(18.0)
		if recovered:
			memory.recovery_active = false
			memory.cooldown_until_s = now+3.0
			memory.last_exit = "recovery_complete"
		else:
			unsafe = true
	if unsafe:
		finish = "safety_abort"
	if not finish.is_empty():
		memory.last_exit = finish
		memory.mode = "track"
		memory.cooldown_until_s = now+3.0
		mode = "track"
	var threat: Dictionary = _tail_threat(unit,contacts,forward)
	var reason: String = "lead_solution"
	if mode == "track" and now >= float(memory.cooldown_until_s) and not unsafe:
		var selected: String = "track"
		if not threat.is_empty():
			selected = "zoom_climb" if kinetic_margin > 220 and speed > float(p.cruise_mps)*0.95 else ("diving_break" if clearance > float(p.spatial.recovery_floor_m)+350 else "oblique_extend")
			reason = "tail_contact_energy" if selected == "zoom_climb" else "tail_contact_clearance"
		elif distance < 170 or (angle > 1.65 and distance < 650):
			selected = "zoom_climb" if kinetic_margin > 200 else "oblique_extend"
			reason = "pass_separation"
		elif pursuit and distance < 1100 and distance > 280 and closure > 35 and speed > target_speed+18 and kinetic_margin > 130:
			selected = "high_yoyo"
			reason = "excess_closure"
		elif pursuit and closure < -6 and distance < 2600 and angle < 1.0 and speed < float(p.sea_level_max_mps)*0.94 and clearance > float(p.spatial.recovery_floor_m)+350:
			selected = "low_yoyo"
			reason = "target_pulling_away"
		elif height_advantage > 180 and distance > 350 and distance < 3000:
			selected = "dive_attack"
			reason = "height_advantage"
		elif distance > 1700 and height_advantage < 120 and kinetic_margin > 150 and now-float(memory.last_setup_s) > 24:
			selected = "climb_setup"
			reason = "convert_speed_to_highside"
			memory.last_setup_s = now
		if selected != "track":
			memory.mode = selected
			memory.entered_s = now
			memory.entry_position_m = unit.position_m
			memory.entry_speed_mps = speed
			memory.entry_forward = forward
			memory["reason"] = reason
			# Geometry picks the outside of the observed target; slot breaks exact symmetry.
			var side: float = signf((Basis.from_euler(unit.rotation_rad).x).dot(offset))
			if absf(side) < 0.1:
				side = -1.0 if int(unit.module_data.get("air_formation",{}).get("slot",0)) % 2 == 0 else 1.0
			memory["side"] = side
			mode = selected
	var desired: Vector3 = aim.normalized()
	var broad_phase: String = "aim" if distance < 850 else "approach"
	var permit_fire: bool = true
	var entry_forward: Vector3 = memory.entry_forward
	var side: float = float(memory.get("side",1.0))
	var right: Vector3 = AircraftFlightMath.frame(forward,Vector3.UP).x
	var bank_limit: float = deg_to_rad(float(p.spatial.combat_bank_deg))
	if mode == "climb_setup":
		desired = AircraftFlightMath.elevated(offset,deg_to_rad(30.0 if unit.module_data.get("air_formation",{}).get("role","") == "wingman" else 25.0),forward)
		permit_fire = false
	elif mode == "high_yoyo":
		desired = AircraftFlightMath.elevated(offset-right*side*220,deg_to_rad(38.0),forward)
		permit_fire = false
	elif mode == "low_yoyo":
		desired = AircraftFlightMath.elevated(offset+right*side*130,deg_to_rad(-28.0),forward)
		permit_fire = false
	elif mode in ["zoom_climb","diving_break","oblique_extend"]:
		var diagonal: Vector3 = entry_forward+right*side*0.65
		var elevation: float = 42.0 if mode == "zoom_climb" else (-34.0 if mode == "diving_break" else 12.0)
		desired = AircraftFlightMath.elevated(diagonal,deg_to_rad(elevation),forward)
		broad_phase = "evade" if str(memory.get("reason","" )).begins_with("tail_contact") else "extend"
		permit_fire = false
	elif mode == "dive_attack":
		desired = aim.normalized()
	if unsafe:
		mode = "recover"
		reason = str(memory.get("recovery_reason",flight.get("safety_state","energy_margin")))
		var recover_pitch: float = 0.25 if reason in ["low_altitude_recovery","terrain_recovery"] and speed > float(p.stall_mps)*1.35 else -0.12
		desired = AircraftFlightMath.elevated(forward,recover_pitch,forward)
		bank_limit = deg_to_rad(20.0)
		permit_fire = false
		broad_phase = "extend"
	elif mode != "track":
		reason = str(memory.get("reason",reason))
	return {"direction":desired,"speed_mps":p.combat_mps,"max_bank_rad":bank_limit,
		"turn_side":side,"mode":mode,"reason":reason,"phase":broad_phase,"permit_fire":permit_fire,
		"relative_height_m":height_advantage,"closing_mps":closure,"energy_margin_m":kinetic_margin,
		"last_exit":memory.last_exit}

static func _tail_threat(unit: UnitState, contacts: Array, forward: Vector3) -> Dictionary:
	for contact: Dictionary in contacts:
		if contact.domain != "aircraft" or not bool(contact.fresh) or not bool(contact.valid):
			continue
		var to_self: Vector3 = unit.position_m-(contact.position_m as Vector3)
		if to_self.length() < 750 and forward.dot(-to_self.normalized()) < -0.35 and (contact.velocity_mps as Vector3).normalized().dot(to_self.normalized()) > 0.78:
			return contact
	return {}
