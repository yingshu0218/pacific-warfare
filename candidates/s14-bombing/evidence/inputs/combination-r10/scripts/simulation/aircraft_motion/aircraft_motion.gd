class_name AircraftMotion
extends SimulationModule

## Point mass with a transported lift frame: roll tilts lift, lift/gravity bend the
## real velocity, and thrust/drag/gravity exchange speed and altitude. Zero sideslip.
const G: float = 9.80665
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
		var fuel: float = clampf(float(initial.get("fuel_kg",p.fuel_capacity_kg)),0.0,float(p.fuel_capacity_kg))
		var basis: Basis = Basis.from_euler(unit.rotation_rad)
		unit.module_data["aircraft_motion"] = {"fuel_kg":fuel,"fuel_capacity_kg":p.fuel_capacity_kg,
			"fuel_used_kg":0.0,"distance_m":0.0,"propeller_phase_rad":0.0,"exited":false,
			"speed_mps":unit.velocity_mps.length(),"throttle":0.0,"turn_rate_radps":0.0,
			"aileron_rad":0.0,"elevator_rad":0.0,"energy_height_m":unit.position_m.y+unit.velocity_mps.length_squared()/(2*G),
			"forward_m":-basis.z,"lift_up_m":basis.y,"path_pitch_rad":AircraftFlightMath.pitch(-basis.z),
			"height_agl_m":unit.position_m.y-_surface_height(world,unit.position_m),"bank_rad":0.0,"load_factor":1.0,"load_limit":1.0,"stall_margin":1.0,
			"roll_velocity_radps":0.0,"body_angular_velocity_radps":Vector3.ZERO,"body_roll_rate_radps":0.0,"heading_rate_radps":0.0,"path_pitch_rate_radps":0.0,
			"vertical_speed_mps":unit.velocity_mps.y,"safety_state":"normal","stalled":false,"path_turn_rate_radps":0.0}

func fixed_update(world_ref: RefCounted, delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in profiles:
		var unit: UnitState = world.get_unit(id)
		if unit.active and not bool(unit.module_data.aircraft_motion.exited) and not bool(unit.module_data.aircraft_motion.get("surface_contact",false)):
			_fly(world,unit,profiles[id],delta_s)

func _surface_height(world: SimulationWorld, position: Vector3) -> float:
	return TerrainQueries.height_m(world,position,true)

func _terrain_probe(world: SimulationWorld, unit: UnitState, forward: Vector3, desired: Vector3, speed: float, lift_cap: float, roll_delay: float, p: Dictionary) -> Dictionary:
	var horizon: float = clampf(speed/(G*maxf(1.0,lift_cap-1.0))+roll_delay+2.0,4.0,10.0)
	var result: Dictionary = {"threat":false,"height_m":0.0,"clearance_m":unit.position_m.y,"horizon_s":horizon,"escape":forward}
	var terrain: Dictionary = world.shared_state.get("terrain",{})
	if terrain.is_empty(): return result
	var predicted_vy: float = minf(unit.velocity_mps.y,speed*desired.y)
	if minf(unit.position_m.y,unit.position_m.y+minf(0,predicted_vy)*horizon) > float(terrain.get("max_height_m",0.0))+float(p.spatial.recovery_floor_m):
		return result
	var flat: Vector3 = AircraftFlightMath.elevated(forward,0)
	var maximum: float = 0.0
	var clearance: float = 100000.0
	for i: int in range(1,7):
		var time: float = horizon*i/6.0
		var point: Vector3 = unit.position_m+flat*speed*time
		var surface: float = _surface_height(world,point)
		maximum = maxf(maximum,surface)
		clearance = minf(clearance,unit.position_m.y+minf(0,predicted_vy)*time-surface)
	result.height_m = maximum
	result.clearance_m = clearance
	var forecast_end: Vector3 = unit.position_m+flat*speed*horizon+Vector3.UP*minf(0,predicted_vy)*horizon
	var direct_hit: Dictionary = TerrainQueries.segment_hit(world,unit.position_m,forecast_end,false)
	result.threat = not direct_hit.is_empty() or (maximum > 1.0 and clearance < float(p.spatial.recovery_floor_m))
	if result.threat:
		var right: Vector3 = flat.cross(Vector3.UP).normalized()
		var left_path: Vector3 = (flat*0.35-right*0.94).normalized()
		var right_path: Vector3 = (flat*0.35+right*0.94).normalized()
		var left_height: float = _surface_height(world,unit.position_m+left_path*speed*horizon)
		var right_height: float = _surface_height(world,unit.position_m+right_path*speed*horizon)
		result.escape = left_path if left_height <= right_height else right_path
	return result

func _fly(world: SimulationWorld, unit: UnitState, p: Dictionary, dt: float) -> void:
	var flight: Dictionary = unit.module_data.aircraft_motion
	var control: Dictionary = unit.module_data.get("aircraft_control",{})
	var damage: Dictionary = unit.module_data.get("damage",{})
	var limits: Dictionary = p.spatial
	var propulsion: float = clampf(float(damage.get("propulsion_factor",1.0)),0.0,1.0)
	var authority: float = clampf(float(damage.get("control_factor",1.0)),0.0,1.0)
	var speed: float = maxf(0.5,unit.velocity_mps.length())
	var old_basis: Basis = Basis.from_euler(unit.rotation_rad)
	var forward: Vector3 = unit.velocity_mps.normalized() if speed > 0.5 else -old_basis.z
	var basis: Basis = AircraftFlightMath.frame(forward,old_basis.y)
	var up: Vector3 = basis.y
	var reference: Vector3 = AircraftFlightMath.level_up(forward,up)
	var bank: float = AircraftFlightMath.signed_roll(reference,up,forward)
	var gamma: float = AircraftFlightMath.pitch(forward)
	var altitude: float = maxf(0.0,unit.position_m.y)
	var max_speed: float = lerpf(float(p.sea_level_max_mps),float(p.max_level_mps),clampf(altitude/float(p.optimum_altitude_m),0,1))
	max_speed *= maxf(0.4,1.0-maxf(0,altitude-float(p.optimum_altitude_m))/float(p.ceiling_m))
	var sustained_climb: float = float(p.climb_mps)*maxf(0,1.0-pow(altitude/float(p.ceiling_m),2))*propulsion
	var desired_speed: float = clampf(float(control.get("speed_mps",p.cruise_mps)),float(p.stall_mps)*1.22,max_speed)
	var desired: Vector3 = _requested_direction(unit,control,speed,sustained_climb,p,forward)
	var explicit_lift: bool = control.get("lift_plane_normal") is Vector3
	var max_bank: float = minf(deg_to_rad(float(limits.combat_bank_deg)),float(control.get("max_bank_rad",deg_to_rad(float(p.max_bank_deg)))))
	var stall_speed: float = float(p.stall_mps)*exp(altitude/(2.0*float(limits.density_scale_m)))
	var load_ratio: float = 1.0 + float(unit.module_data.get("bomb_rack",{}).get("mass_kg",0.0))/float(p.reference_mass_kg)
	stall_speed *= sqrt(load_ratio)
	var lift_cap: float = minf(float(limits.operating_load_g),pow(speed/stall_speed,2.0))*authority
	var stalled: bool = speed < stall_speed*(1.36 if bool(flight.stalled) else 1.10)
	var safety: String = "normal"
	var height: float = unit.position_m.y-_surface_height(world,unit.position_m)
	var pull_g: float = maxf(0.7,lift_cap-1.0)
	var indicated_speed: float = speed*exp(-altitude/(2*float(limits.density_scale_m)))
	var aileron_limit: float = float(limits.get("full_aileron_limit_eas_mps",10000.0))
	var roll_limit: float = deg_to_rad(float(p.roll_rate_degps))*authority*minf(1.0,pow(aileron_limit/maxf(indicated_speed,1),2))*clampf(indicated_speed/(float(p.stall_mps)*1.8),0.3,1)
	var roll_delay: float = absf(bank)/maxf(0.1,roll_limit)
	var descent: float = minf(gamma,AircraftFlightMath.pitch(desired))
	var loss: float = speed*speed/(G*pull_g)*(1.0-cos(minf(0,descent)))+maxf(0,-unit.velocity_mps.y)*roll_delay
	var reserve_speed: float = stall_speed*1.45
	var kinetic_margin: float = maxf(0,(speed*speed-reserve_speed*reserve_speed)/(2.0*G))
	var energy_horizon: float = float(limits.zoom_energy_horizon_s)
	var zoom_limit: float = asin(clampf((kinetic_margin+sustained_climb*energy_horizon)/(speed*energy_horizon),0,0.95))
	if AircraftFlightMath.pitch(desired) > zoom_limit:
		desired = AircraftFlightMath.elevated(desired,zoom_limit,forward)
	var terrain_ahead: Dictionary = _terrain_probe(world,unit,forward,desired,speed,lift_cap,roll_delay,p)
	var old_safety: String = flight.safety_state
	var dive_limit: float = max_speed*float(limits.dive_speed_factor)
	# One controller owns each tick. Hysteresis prevents navigation and recovery
	# from alternately issuing contradictory lift/roll requests at the boundary.
	if stalled:
		safety = "stall_recovery"
	elif bool(terrain_ahead.threat):
		safety = "terrain_recovery"
	elif height < float(limits.recovery_floor_m)+loss+(55.0 if old_safety == "low_altitude_recovery" else 0.0) and (forward.y < 0.035 or desired.y < -0.05):
		safety = "low_altitude_recovery"
	elif speed > dive_limit*(0.96 if old_safety == "overspeed_recovery" else 1.0):
		safety = "overspeed_recovery"
	elif not explicit_lift and ((gamma > zoom_limit+deg_to_rad(12) and gamma > deg_to_rad(25)) or (old_safety == "energy_recovery" and gamma > deg_to_rad(15))):
		safety = "energy_recovery"
	elif float(flight.fuel_kg) <= 0 or propulsion < 0.05:
		safety = "glide"
	if safety in ["stall_recovery","energy_recovery"]:
		desired = AircraftFlightMath.elevated(forward,-0.12 if height > float(limits.clearance_m) else -0.035,forward)
		max_bank = 0.0
	elif safety == "terrain_recovery":
		desired = AircraftFlightMath.elevated(terrain_ahead.escape,deg_to_rad(22 if kinetic_margin > 200 else 12),forward)
		max_bank = deg_to_rad(45)
	elif safety == "low_altitude_recovery":
		desired = AircraftFlightMath.elevated(forward,deg_to_rad(8),forward)
		max_bank = deg_to_rad(15)
	elif safety == "overspeed_recovery":
		desired = AircraftFlightMath.elevated(forward,deg_to_rad(12),forward)
		max_bank = deg_to_rad(20)
	elif safety == "glide":
		desired = AircraftFlightMath.elevated(desired,minf(-0.11,AircraftFlightMath.pitch(desired)),forward)
	var gravity: Vector3 = Vector3.DOWN*G
	var gravity_normal: Vector3 = gravity-forward*gravity.dot(forward)
	var pilot: Dictionary = AircraftFlightController.coordinated(forward,up,desired,speed,lift_cap,max_bank,p,flight)
	if explicit_lift and (safety == "normal" or (safety == "low_altitude_recovery" and bool(control.get("pull_through",false)))):
		var normal: Vector3 = control.lift_plane_normal
		pilot.up = AircraftFlightMath.frame(forward,normal.cross(forward)).y
		pilot.load_g = float(control.get("load_factor_g",1.0))
		if safety == "low_altitude_recovery": pilot.load_g = lift_cap*0.95
	var target_up: Vector3 = pilot.up
	var roll_error: float = AircraftFlightMath.signed_roll(up,target_up,forward)
	if absf(absf(roll_error)-PI) < 0.015: roll_error = absf(roll_error)*float(control.get("turn_side",1.0))
	var wanted_roll_rate: float = clampf(roll_error*4.0,-roll_limit,roll_limit)
	var roll_velocity: float = move_toward(float(flight.roll_velocity_radps),wanted_roll_rate,deg_to_rad(float(limits.roll_acceleration_degps2))*authority*dt)
	var roll_change: float = roll_velocity*dt
	up = up.rotated(forward,roll_change).normalized()
	var requested_load: float = pilot.load_g
	if stalled:
		requested_load = -0.25 if gamma > deg_to_rad(25) else 0.15
	var minimum_load: float = float(limits.minimum_load_g)*minf(1.0,lift_cap) if stalled else minf(0.15,lift_cap)
	var operating_cap: float = minf(lift_cap,float(limits.get("roll_load_limit_g",limits.operating_load_g))) if absf(roll_velocity) > deg_to_rad(2) else lift_cap
	var target_load: float = clampf(requested_load,minimum_load,maxf(minimum_load,operating_cap))
	var load_g: float = move_toward(float(flight.load_factor),target_load,float(limits.load_slew_gps)*dt)
	load_g = clampf(load_g,minimum_load,maxf(minimum_load,lift_cap))
	var parasite: float = float(p.drag_mps2)*pow(speed/max_speed,2)
	var induced: float = AircraftFlightController.induced_drag(p,maxf(speed,stall_speed),altitude,load_g)
	var throttle: float = clampf(parasite/float(p.acceleration_mps2)+(desired_speed-speed)*0.09,0,1)
	if control.has("throttle"):
		throttle = clampf(float(control.throttle),0,1)
	if stalled:
		throttle = 1.0
	elif safety == "overspeed_recovery":
		throttle = 0.0
	if float(flight.fuel_kg) <= 0:
		throttle = 0.0
	var thrust: float = float(p.acceleration_mps2)*throttle*propulsion
	# A steep zoom spends kinetic energy; rated climb caps excess engine power only.
	thrust = minf(thrust,parasite+G*sustained_climb/maxf(speed,1.0))
	var drag: float = parasite+induced+18.0*pow(maxf(0.0,speed/max_speed-1.10),2)
	var stores: Dictionary = unit.module_data.get("bomb_rack",{})
	if not stores.is_empty():
		drag += float(stores.get("brake",0.0))*float(p.get("bomb_brake_drag_mps2",0.0))*pow(speed/100.0,2)
		drag += (load_ratio-1.0)*parasite
		thrust /= load_ratio
	var next_speed: float = maxf(0.5,speed+(thrust-drag+gravity.dot(forward))*dt)
	var acceleration: Vector3 = up*(load_g*G)+gravity_normal
	var angle: float = acceleration.length()/maxf(1.0,(speed+next_speed)*0.5)*dt
	var axis: Vector3 = forward.cross(acceleration).normalized()
	var next_forward: Vector3 = forward.rotated(axis,angle).normalized() if axis.length_squared() > 0.5 else forward
	var transported_up: Vector3 = up.rotated(axis,angle) if axis.length_squared() > 0.5 else up
	var next_basis: Basis = AircraftFlightMath.frame(next_forward,transported_up)
	var next_velocity: Vector3 = next_forward*next_speed
	var travel: Vector3 = (unit.velocity_mps+next_velocity)*(0.5*dt)
	var previous_position: Vector3 = unit.position_m
	unit.position_m += travel
	unit.velocity_mps = next_velocity
	unit.rotation_rad = next_basis.get_euler()
	# True relative body rotation, not a mixture of world heading and path rates.
	# This telemetry changes no healthy forces, controller decisions or attitude.
	var relative_q: Quaternion = (old_basis.inverse()*next_basis).get_rotation_quaternion().normalized()
	if relative_q.w < 0: relative_q = -relative_q
	var vector_q: Vector3 = Vector3(relative_q.x,relative_q.y,relative_q.z)
	var sin_half: float = vector_q.length()
	flight["body_angular_velocity_radps"] = vector_q*(2.0*atan2(sin_half,relative_q.w)/(sin_half*dt)) if sin_half > 0.00000001 else Vector3.ZERO
	var burn: float = minf(float(flight.fuel_kg),lerpf(float(p.cruise_burn_kgps)*0.35,float(p.full_burn_kgps),throttle)*propulsion*dt)
	flight.fuel_kg = maxf(0,float(flight.fuel_kg)-burn)
	flight.fuel_used_kg += burn
	flight.distance_m += travel.length()
	flight.speed_mps = next_speed
	flight.throttle = throttle
	flight.forward_m = next_forward
	flight.lift_up_m = next_basis.y
	flight.path_pitch_rad = AircraftFlightMath.pitch(next_forward)
	flight.bank_rad = AircraftFlightMath.signed_roll(AircraftFlightMath.level_up(next_forward,next_basis.y),next_basis.y,next_forward)
	flight.roll_velocity_radps = roll_velocity
	flight.body_roll_rate_radps = roll_change/dt
	flight.heading_rate_radps = wrapf(AircraftFlightMath.heading(next_forward)-AircraftFlightMath.heading(forward),-PI,PI)/dt
	flight.path_pitch_rate_radps = (AircraftFlightMath.pitch(next_forward)-gamma)/dt
	flight["induced_drag_mps2"] = induced
	flight["requested_load_g"] = requested_load
	flight["roll_error_rad"] = roll_error
	flight.load_factor = load_g
	flight.load_limit = lift_cap
	flight.stall_margin = next_speed/(stall_speed*sqrt(maxf(1.0,load_g)))
	flight.vertical_speed_mps = next_velocity.y
	flight.height_agl_m = unit.position_m.y-_surface_height(world,unit.position_m)
	flight["kinetic_margin_m"] = kinetic_margin
	flight["terrain_ahead_m"] = terrain_ahead.height_m
	flight["terrain_clearance_m"] = terrain_ahead.clearance_m
	flight["terrain_lookahead_s"] = terrain_ahead.horizon_s
	flight.safety_state = safety
	flight.stalled = stalled
	flight.path_turn_rate_radps = angle/dt
	flight.turn_rate_radps = angle/dt*signf(axis.y)
	flight.energy_height_m = unit.position_m.y+next_speed*next_speed/(2*G)
	var propeller_rate: float = 120*maxf(throttle,0.15)*propulsion
	if propulsion < 0.999:
		var windmill: float = clampf(next_speed*0.12,0,24)*(1.0-propulsion)
		propeller_rate = move_toward(float(flight.get("propeller_speed_radps",propeller_rate)),propeller_rate+windmill,18.0*dt)
	flight["propeller_speed_radps"] = propeller_rate
	flight.propeller_phase_rad = fmod(float(flight.propeller_phase_rad)+dt*propeller_rate,TAU)
	flight.aileron_rad = clampf(-roll_change/dt*0.12,-0.24,0.24)
	# Back-stick remains back-stick while inverted or passing the vertical;
	# differentiating world flight-path pitch would flip the visual elevator.
	flight.elevator_rad = clampf((load_g-1.0)*0.04*pow(float(p.cruise_mps)/maxf(speed,stall_speed),2),-0.12,0.16)
	var contact: Dictionary = TerrainQueries.segment_hit(world,previous_position,unit.position_m,true)
	if not contact.is_empty():
		unit.position_m = contact.position_m
		flight.height_agl_m = unit.position_m.y-_surface_height(world,unit.position_m)
		flight["surface_contact"] = true
		unit.module_data["combat_intent"] = {"fire":false,"allow_aa":false,"burst_until_tick":-1}
		var surface: String = contact.surface
		var reason: String = "forced_ditch" if surface == "sea" else ("building_collision" if surface == "building" else "terrain_collision")
		world.emit_event("unit_surface_contact",unit.id,"",unit.position_m,{"velocity_mps":unit.velocity_mps,"surface":surface,"reason":reason,"normal":contact.normal},str(contact.target_id))

func _requested_direction(unit: UnitState, control: Dictionary, speed: float, climb: float, p: Dictionary, forward: Vector3) -> Vector3:
	if control.get("flight_direction") is Vector3 and (control.flight_direction as Vector3).length_squared() > 0.00001:
		return (control.flight_direction as Vector3).normalized()
	var heading: float = float(control.get("heading_rad",AircraftFlightMath.heading(forward)))
	var vertical: float = clampf((float(control.get("altitude_m",unit.position_m.y))-unit.position_m.y)*0.035,-float(p.sink_mps),climb)
	var pitch: float = float(control.get("pitch_rad",asin(clampf(vertical/speed,-0.6,0.6))))
	return AircraftFlightMath.direction(heading,pitch)

func snapshot_state() -> Dictionary:
	return {"unit_ids":profiles.keys()}
