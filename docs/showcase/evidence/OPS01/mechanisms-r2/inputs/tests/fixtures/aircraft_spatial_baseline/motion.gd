class_name BaselineAircraftMotion
extends SimulationModule

## Deterministic point-mass flight, bounded bank/roll/pitch, energy and fuel.
## Owns aircraft_motion; reads aircraft_control from the domain task executor.
var performance: AircraftPerformance = AircraftPerformance.new()
var profiles: Dictionary = {}

func _init() -> void:
	module_id = "aircraft_motion"
	priority = 400

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	profiles.clear()
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not performance.supports(unit.definition_id):
			continue
		var p: Dictionary = performance.profile(unit.definition_id)
		profiles[id] = p
		var initial: Dictionary = unit.module_data.get("aircraft_initial", {})
		# Scenario input is remaining fuel, separate from historical capacity.
		var fuel: float = clampf(float(initial.get("fuel_kg", p.fuel_capacity_kg)), 0.0, float(p.fuel_capacity_kg))
		unit.module_data["aircraft_motion"] = {"fuel_kg": fuel, "fuel_capacity_kg": p.fuel_capacity_kg,
			"fuel_used_kg": 0.0, "distance_m": 0.0, "propeller_phase_rad": 0.0, "exited": false,
			"speed_mps": unit.velocity_mps.length(), "throttle": 0.0, "turn_rate_radps": 0.0,
			"aileron_rad": 0.0, "elevator_rad": 0.0, "energy_height_m": unit.position_m.y + unit.velocity_mps.length_squared() / 19.6133}

func fixed_update(world_ref: RefCounted, delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in profiles:
		var unit: UnitState = world.get_unit(id)
		if unit.active and not bool(unit.module_data.aircraft_motion.exited) and not bool(unit.module_data.aircraft_motion.get("surface_contact", false)):
			_fly(world, unit, profiles[id], delta_s)

func _fly(world: SimulationWorld, unit: UnitState, p: Dictionary, dt: float) -> void:
	var flight: Dictionary = unit.module_data.aircraft_motion
	var control: Dictionary = unit.module_data.get("aircraft_control", {})
	var damage: Dictionary = unit.module_data.get("damage", {})
	var propulsion: float = clampf(float(damage.get("propulsion_factor", 1.0)), 0.0, 1.0)
	var authority: float = clampf(float(damage.get("control_factor", 1.0)), 0.0, 1.0)
	var speed: float = maxf(1.0, unit.velocity_mps.length())
	var yaw: float = unit.rotation_rad.y
	var pitch: float = unit.rotation_rad.x
	var roll: float = unit.rotation_rad.z
	var heading: float = float(control.get("heading_rad", yaw))
	var altitude: float = float(control.get("altitude_m", unit.position_m.y))
	var desired_speed: float = float(control.get("speed_mps", p.cruise_mps))
	var altitude_factor: float = clampf(unit.position_m.y / float(p.optimum_altitude_m), 0.0, 1.0)
	var max_speed: float = lerpf(float(p.sea_level_max_mps), float(p.max_level_mps), altitude_factor)
	max_speed *= maxf(0.4, 1.0 - maxf(0.0, unit.position_m.y - float(p.optimum_altitude_m)) / float(p.ceiling_m))
	desired_speed = clampf(desired_speed, float(p.stall_mps) * 1.22, max_speed)
	var heading_error: float = wrapf(heading - yaw, -PI, PI)
	var desired_roll: float = clampf(heading_error * 1.6, -deg_to_rad(float(p.max_bank_deg)), deg_to_rad(float(p.max_bank_deg)))
	if speed < float(p.stall_mps) * 1.2:
		desired_roll *= clampf((speed - float(p.stall_mps) * 0.7) / (float(p.stall_mps) * 0.5), 0.0, 1.0)
	var old_roll: float = roll
	roll = move_toward(roll, desired_roll, deg_to_rad(float(p.roll_rate_degps)) * authority * dt)
	var turn_rate: float = 9.80665 * tan(roll) / maxf(speed, float(p.stall_mps)) * authority
	var climb_limit: float = float(p.climb_mps) * maxf(0.0, 1.0 - pow(maxf(0.0, unit.position_m.y) / float(p.ceiling_m), 2.0)) * propulsion
	var vertical: float = clampf((altitude - unit.position_m.y) * 0.035, -float(p.sink_mps), climb_limit)
	var desired_pitch: float = asin(clampf(vertical / speed, -0.35, 0.28))
	if control.has("pitch_rad"):
		desired_pitch = clampf(float(control.pitch_rad), -asin(minf(0.35, float(p.sink_mps) / speed)), asin(minf(0.28, climb_limit / speed)))
	if speed < float(p.stall_mps) * 1.18:
		desired_pitch = minf(desired_pitch, -0.12) # recover energy, never clamp speed up to stall
	if float(flight.fuel_kg) <= 0.0 or propulsion < 0.05:
		desired_pitch = minf(desired_pitch, -0.09)
	var old_pitch: float = pitch
	pitch = move_toward(pitch, desired_pitch, deg_to_rad(float(p.pitch_rate_degps)) * maxf(0.05, authority) * dt)
	var drag: float = float(p.drag_mps2) * pow(speed / max_speed, 2.0)
	var induced: float = float(p.turn_drag_mps2) * pow(tan(roll), 2.0) * pow(float(p.cruise_mps) / maxf(speed, float(p.stall_mps)), 2.0)
	# Feed-forward level drag only: climbs and sustained turns have a real energy cost.
	var throttle: float = clampf(drag / float(p.acceleration_mps2) + (desired_speed - speed) * 0.09, 0.0, 1.0)
	if control.has("throttle"):
		throttle = clampf(float(control.throttle), 0.0, 1.0)
	if float(flight.fuel_kg) <= 0.0:
		throttle = 0.0
	var acceleration: float = throttle * float(p.acceleration_mps2) * propulsion - drag - induced - 9.80665 * sin(pitch)
	speed = clampf(speed + acceleration * dt, 1.0, float(p.max_level_mps) * 1.25)
	yaw = wrapf(yaw + turn_rate * dt, -PI, PI)
	unit.rotation_rad = Vector3(pitch, yaw, roll)
	var next_velocity: Vector3 = Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * speed
	var travel: Vector3 = (unit.velocity_mps + next_velocity) * (0.5 * dt)
	var previous_position: Vector3 = unit.position_m
	unit.position_m += travel
	unit.velocity_mps = next_velocity
	var burn: float = lerpf(float(p.cruise_burn_kgps) * 0.35, float(p.full_burn_kgps), throttle) * propulsion * dt
	burn = minf(burn, float(flight.fuel_kg))
	flight.fuel_kg = maxf(0.0, float(flight.fuel_kg) - burn)
	flight.fuel_used_kg += burn
	flight.distance_m += travel.length()
	flight.speed_mps = speed
	flight.throttle = throttle
	flight.turn_rate_radps = turn_rate
	flight.energy_height_m = unit.position_m.y + speed * speed / 19.6133
	flight.propeller_phase_rad = fmod(float(flight.propeller_phase_rad) + dt * 120.0 * maxf(throttle, 0.15) * propulsion, TAU)
	flight.aileron_rad = clampf((roll - old_roll) / dt * 0.12, -0.24, 0.24)
	flight.elevator_rad = clampf((pitch - old_pitch) / dt * 0.25, -0.16, 0.16)
	if unit.position_m.y <= 0.0:
		var fraction: float = clampf(previous_position.y / maxf(0.0001, previous_position.y - unit.position_m.y), 0.0, 1.0)
		unit.position_m = previous_position.lerp(unit.position_m, fraction)
		flight["surface_contact"] = true
		unit.module_data["combat_intent"] = {"fire": false, "allow_aa": false, "burst_until_tick": -1}
		# S05 consumes at 650 in this tick and owns active/damage/wreck/impact.
		world.emit_event("unit_surface_contact", unit.id, "", unit.position_m, {"velocity_mps": unit.velocity_mps, "surface": "sea", "reason": "forced_ditch"})

func snapshot_state() -> Dictionary:
	return {"unit_ids": profiles.keys()}
