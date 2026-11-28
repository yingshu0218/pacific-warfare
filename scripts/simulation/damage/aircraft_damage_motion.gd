class_name AircraftDamageMotion
extends RefCounted

## DM01: deterministic coarse post-failure dynamics, never used by healthy flight.
const G: float = 9.80665
const FRAGMENT_LIMIT: int = 3
const FRAGMENT_LIFETIME_S: float = 12.0
const MAX_ANGULAR_SPEED_RADPS: float = 1.8

static func initialize(unit: UnitState) -> void:
	var damage: Dictionary = unit.module_data.damage
	damage.parts["wing_left"] = 1.0
	damage.parts["wing_right"] = 1.0
	damage.parts["tail"] = 1.0
	damage["aircraft"] = {"detached_parts": [], "fragments": [], "breakup": false,
		"angular_velocity_body_radps": Vector3.ZERO, "contact_surface": "", "terminal_started": false}
	damage["effect_emitters"] = []

static func begin_terminal(unit: UnitState) -> void:
	var aircraft: Dictionary = unit.module_data.damage.get("aircraft",unit.module_data.damage.get("coarse_airframe",{}))
	if bool(aircraft.terminal_started): return
	aircraft.terminal_started = true
	aircraft.angular_velocity_body_radps = inherited_angular_velocity(unit)
	var flight: Dictionary = unit.module_data.get("aircraft_motion", {})
	aircraft["transition_load_g"] = clampf(float(flight.get("load_factor", 1.0)), 0.0, 4.0)

static func inherited_angular_velocity(unit: UnitState) -> Vector3:
	var flight: Dictionary = unit.module_data.get("aircraft_motion", {})
	return flight.get("body_angular_velocity_radps",Vector3.ZERO)

static func detach(world: SimulationWorld, unit: UnitState, part_id: String, profile: Dictionary, frame: CombatFrame, reason: String, projectile_id: String = "") -> void:
	var damage: Dictionary = unit.module_data.damage
	var aircraft: Dictionary = damage.aircraft
	if part_id in aircraft.detached_parts or aircraft.detached_parts.size() >= FRAGMENT_LIMIT: return
	var anchor: Vector3 = SimData.vec3(profile.aircraft_damage.anchors_m[part_id])
	var pose: Transform3D = unit.world_transform()
	var omega: Vector3 = aircraft.angular_velocity_body_radps if bool(aircraft.terminal_started) else inherited_angular_velocity(unit)
	var velocity: Vector3 = unit.velocity_mps + (pose.basis * omega).cross(pose.basis * anchor)
	var fragment: Dictionary = {"part_id": part_id, "position_m": pose * anchor, "rotation_rad": unit.rotation_rad,
		"velocity_mps": velocity, "angular_velocity_body_radps": omega, "born_tick": world.tick,
		"born_time_s": world.time_s(), "age_s": 0.0, "lifetime_s": FRAGMENT_LIFETIME_S, "surface": ""}
	# The anchor may already be below the entry plane when the fuselage
	# contacts sea. Such debris starts submerged instead of crossing a second time.
	if aircraft.contact_surface == "sea" and (fragment.position_m as Vector3).y <= unit.position_m.y:
		fragment.surface = "sea"
		fragment.velocity_mps = Vector3(velocity.x, minf(-1.1, velocity.y), velocity.z) * 0.12
	damage.parts[part_id] = 0.0
	aircraft.detached_parts.append(part_id)
	aircraft.fragments.append(fragment)
	frame.remove_aircraft_part(unit.id, part_id)
	for mount_id: String in unit.weapons:
		if (part_id == "wing_left" and mount_id.begins_with("wing_port_")) or (part_id == "wing_right" and mount_id.begins_with("wing_starboard_")):
			(unit.weapons[mount_id] as WeaponState).enabled = false
			if mount_id not in damage.disabled_mounts: damage.disabled_mounts.append(mount_id)
	var event_data: Dictionary = fragment.duplicate(true)
	event_data.merge({"local_anchor_m": anchor, "reason": reason, "projectile_id": projectile_id})
	event_data["velocity_mps"] = velocity
	world.emit_event("aircraft_part_detached", unit.id, "", fragment.position_m, event_data)

static func breakup(world: SimulationWorld, unit: UnitState, profile: Dictionary, frame: CombatFrame, reason: String, projectile_id: String = "") -> void:
	var aircraft: Dictionary = unit.module_data.damage.aircraft
	if bool(aircraft.breakup): return
	aircraft.breakup = true
	for part_id: String in ["wing_left", "wing_right", "tail"]:
		detach(world, unit, part_id, profile, frame, reason, projectile_id)
	world.emit_event("aircraft_breakup", unit.id, "", unit.position_m, {"reason": reason, "projectile_id": projectile_id, "fragment_count": aircraft.detached_parts.size()})

static func advance_terminal(world: SimulationWorld, unit: UnitState, dt: float) -> Dictionary:
	var damage: Dictionary = unit.module_data.damage
	var aircraft: Dictionary = damage.get("aircraft",damage.get("coarse_airframe",{}))
	var basis: Basis = Basis.from_euler(unit.rotation_rad)
	var velocity: Vector3 = unit.velocity_mps
	var speed: float = maxf(velocity.length(), 0.1)
	var direction: Vector3 = velocity / speed
	var left: float = 0.0 if "wing_left" in aircraft.detached_parts else 1.0
	var right: float = 0.0 if "wing_right" in aircraft.detached_parts else 1.0
	var tail: float = 0.0 if "tail" in aircraft.detached_parts else lerpf(0.28, 1.0, float(damage.parts.get("tail", 1.0)))
	var asymmetry: float = right - left
	var alignment: Vector3 = basis.inverse() * (-basis.z).cross(direction)
	var omega: Vector3 = aircraft.angular_velocity_body_radps
	var torque: Vector3 = alignment * (0.6 * tail + 0.12) + Vector3(-0.16 - 0.10 * (2.0-left-right), asymmetry * 0.25, asymmetry * 1.5) - omega * 0.85
	omega = (omega + torque.limit_length(3.0) * dt).limit_length(MAX_ANGULAR_SPEED_RADPS)
	basis = _rotate(basis, omega, dt)
	var lift_direction: Vector3 = (basis.y - direction * basis.y.dot(direction)).normalized()
	var incidence: float = clampf((-basis.z).dot(direction), 0, 1)
	var passive_load: float = minf(2.0, pow(speed / 90.0, 2)) * incidence * incidence
	var load: float = lerpf(float(aircraft.get("transition_load_g", passive_load)), passive_load,
		clampf(float(damage.phase_time_s) / 0.65, 0.0, 1.0))
	var lift: Vector3 = lift_direction * G * load * (left + right) * 0.5
	var drag: Vector3 = -direction * speed*speed * (0.00013 + 0.00016 * (2.0-left-right) + 0.0003 * (1.0-incidence))
	var acceleration: Vector3 = Vector3.DOWN * G + lift + drag
	var previous: Vector3 = unit.position_m
	var next: Vector3 = previous + velocity * dt + acceleration * (0.5 * dt * dt)
	unit.velocity_mps = velocity + acceleration * dt
	unit.rotation_rad = basis.get_euler()
	aircraft.angular_velocity_body_radps = omega
	var flight: Dictionary = unit.module_data.get("aircraft_motion", {})
	flight["speed_mps"] = unit.velocity_mps.length()
	flight["forward_m"] = unit.velocity_mps.normalized()
	flight["body_forward_m"] = -basis.z
	flight["body_angular_velocity_radps"] = omega
	flight["vertical_speed_mps"] = unit.velocity_mps.y
	flight["lift_up_m"] = basis.y
	flight["safety_state"] = "uncontrolled_damage"
	flight["body_roll_rate_radps"] = -omega.z
	_coast_propeller(flight, unit.velocity_mps.length() * 0.12, dt)
	var contact: Dictionary = TerrainQueries.segment_hit(world, previous, next, true) if world.shared_state.has("terrain") else {}
	unit.position_m = next
	return contact

static func advance_fragments(world: SimulationWorld, unit: UnitState, dt: float, environment: Dictionary) -> void:
	var fragments: Array = unit.module_data.damage.aircraft.fragments
	for index: int in range(fragments.size()-1, -1, -1):
		var piece: Dictionary = fragments[index]
		if int(piece.born_tick) == world.tick: continue
		piece.age_s += dt
		if float(piece.age_s) >= float(piece.lifetime_s):
			fragments.remove_at(index)
			continue
		if str(piece.surface) != "":
			if piece.surface == "sea":
				var water_velocity: Vector3 = piece.velocity_mps
				var sink_velocity: Vector3 = Vector3.DOWN * 1.1
				var damped: Vector3 = sink_velocity + (water_velocity - sink_velocity) * exp(-12.0 * dt)
				piece.position_m += (water_velocity + damped) * (0.5 * dt)
				piece.velocity_mps = damped
			continue
		var velocity: Vector3 = piece.velocity_mps
		var acceleration: Vector3 = Vector3.DOWN*G - velocity * velocity.length() * 0.0015
		var previous: Vector3 = piece.position_m
		var next: Vector3 = previous + velocity*dt + acceleration*(0.5*dt*dt)
		piece.velocity_mps = velocity + acceleration*dt
		var sign_side: float = -1.0 if piece.part_id == "wing_left" else 1.0
		var omega: Vector3 = piece.angular_velocity_body_radps
		omega = (omega + (Vector3(0.32, 0.18*sign_side, 0.45*sign_side)-omega*0.3)*dt).limit_length(MAX_ANGULAR_SPEED_RADPS)
		piece.angular_velocity_body_radps = omega
		piece.rotation_rad = _rotate(Basis.from_euler(piece.rotation_rad), omega, dt).get_euler()
		var contact: Dictionary = _fragment_contact(world, previous, next, environment)
		piece.position_m = next if contact.is_empty() else contact.position_m
		if not contact.is_empty():
			piece.surface = contact.surface
			var fraction: float = clampf(previous.distance_to(piece.position_m) / maxf(0.000001, previous.distance_to(next)), 0.0, 1.0)
			var at_contact: Vector3 = velocity + acceleration * (fraction * dt)
			piece.velocity_mps = Vector3(at_contact.x, minf(-1.1, at_contact.y), at_contact.z) * 0.12 if contact.surface == "sea" else Vector3.ZERO

static func _fragment_contact(world: SimulationWorld, a: Vector3, b: Vector3, environment: Dictionary) -> Dictionary:
	if world.shared_state.has("terrain"): return TerrainQueries.segment_hit(world,a,b,true)
	var nearest: float = INF
	var result: Dictionary = {}
	for solid: Dictionary in environment.get("solids",[]):
		var fraction: float = CombatGeometry.segment_box(a,b,SimData.vec3(solid.center_m),SimData.vec3(solid.half_extents_m))
		if fraction < nearest:
			nearest = fraction
			result = {"surface":solid.surface,"position_m":a.lerp(b,fraction)}
	var sea: float = float(environment.get("sea_level_m",0))
	if a.y >= sea and b.y <= sea and a.y > b.y:
		var fraction: float = (a.y-sea)/(a.y-b.y)
		if fraction < nearest: result = {"surface":"sea","position_m":a.lerp(b,fraction)}
	return result

static func update_emitters(unit: UnitState, profile: Dictionary) -> void:
	var damage: Dictionary = unit.module_data.damage
	var aircraft: Dictionary = damage.aircraft
	var emitters: Array[Dictionary] = []
	if not CombatPresence.is_present(unit.module_data) or str(aircraft.contact_surface) != "":
		damage.effect_emitters = emitters
		return
	var engine_loss: float = 1.0-float(damage.parts.engine)
	var fire: float = float(damage.fire)
	var anchors: Dictionary = profile.damage_effects
	if damage.parts.has("engine_left"):
		for box: Dictionary in profile.boxes:
			var part_id: String = str(box.part)
			if part_id not in ["engine_left", "engine_right"]: continue
			var loss: float = 1.0 - float(damage.parts[part_id])
			if loss <= 0.02: continue
			var anchor: Vector3 = SimData.vec3(box.center_m) + Vector3.UP * 0.55
			emitters.append({"id":part_id+"_smoke", "part_id":part_id, "kind":"smoke", "anchor_m":anchor, "intensity":clampf(loss*0.9+fire*0.2,0,1), "size_m":2.4, "enabled":true})
			if fire > 0.02:
				emitters.append({"id":part_id+"_fire", "part_id":part_id, "kind":"fire", "anchor_m":anchor, "intensity":fire, "size_m":1.3, "enabled":true})
	elif engine_loss > 0.02:
		emitters.append({"id":"engine_smoke", "part_id":"engine", "kind":"smoke", "anchor_m":SimData.vec3(anchors.smoke_anchor_m), "intensity":clampf(engine_loss*0.9+fire*0.2,0,1), "size_m":2.4, "enabled":true})
		if fire > 0.02:
			emitters.append({"id":"engine_fire", "part_id":"engine", "kind":"fire", "anchor_m":SimData.vec3(anchors.fire_anchor_m), "intensity":fire, "size_m":1.3, "enabled":true})
	if damage.phase == "crashing" or (fire > 0.02 and engine_loss <= 0.02):
		emitters.append({"id":"structure_smoke", "part_id":"structure", "kind":"smoke", "anchor_m":Vector3(0,0.2,0.5), "intensity":clampf(0.35+fire*0.6,0,1), "size_m":3.5, "enabled":true})
		if fire > 0.02:
			emitters.append({"id":"structure_fire", "part_id":"structure", "kind":"fire", "anchor_m":Vector3(0,0.1,0.5), "intensity":fire, "size_m":1.5, "enabled":true})
	damage.effect_emitters = emitters

static func _rotate(basis: Basis, omega: Vector3, dt: float) -> Basis:
	var speed: float = omega.length()
	return (basis * Basis(omega/speed, speed*dt)).orthonormalized() if speed > 0.000001 else basis

static func _coast_propeller(flight: Dictionary, target_radps: float, dt: float) -> void:
	var rate: float = move_toward(float(flight.get("propeller_speed_radps", 0)), clampf(target_radps,0,24), 18.0*dt)
	flight["propeller_speed_radps"] = rate
	flight["propeller_phase_rad"] = fmod(float(flight.get("propeller_phase_rad",0))+rate*dt, TAU)
