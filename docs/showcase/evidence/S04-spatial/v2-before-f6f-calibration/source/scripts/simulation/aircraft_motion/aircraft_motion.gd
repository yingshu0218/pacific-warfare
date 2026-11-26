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
			"height_agl_m":unit.position_m.y,"bank_rad":0.0,"load_factor":1.0,"load_limit":1.0,"stall_margin":1.0,
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
	var max_bank: float = minf(deg_to_rad(float(limits.combat_bank_deg)),float(control.get("max_bank_rad",deg_to_rad(float(p.max_bank_deg)))))
	var stall_speed: float = float(p.stall_mps)*exp(altitude/(2.0*float(limits.density_scale_m)))
	var lift_cap: float = minf(float(limits.operating_load_g),pow(speed/stall_speed,2.0))*authority
	var stalled: bool = speed < stall_speed*(1.36 if bool(flight.stalled) else 1.10)
	var safety: String = "normal"
	var height: float = unit.position_m.y-_surface_height(world,unit.position_m)
	var pull_g: float = maxf(0.7,lift_cap-1.0)
	var roll_delay: float = absf(bank)/maxf(0.1,deg_to_rad(float(p.roll_rate_degps))*authority)
	var descent: float = minf(gamma,AircraftFlightMath.pitch(desired))
	var loss: float = speed*speed/(G*pull_g)*(1.0-cos(minf(0,descent)))+maxf(0,-unit.velocity_mps.y)*roll_delay
	var reserve_speed: float = stall_speed*1.45
	var kinetic_margin: float = maxf(0,(speed*speed-reserve_speed*reserve_speed)/(2.0*G))
	var energy_horizon: float = float(limits.zoom_energy_horizon_s)
	var zoom_limit: float = asin(clampf((kinetic_margin+sustained_climb*energy_horizon)/(speed*energy_horizon),0,0.95))
	if AircraftFlightMath.pitch(desired) > zoom_limit:
		desired = AircraftFlightMath.elevated(desired,zoom_limit,forward)
	if gamma > zoom_limit+deg_to_rad(12.0) and gamma > deg_to_rad(25.0):
		safety = "energy_recovery"
		desired = AircraftFlightMath.elevated(forward,-0.15,forward)
		max_bank = deg_to_rad(25.0)
	var terrain_ahead: Dictionary = _terrain_probe(world,unit,forward,desired,speed,lift_cap,roll_delay,p)
	if bool(terrain_ahead.threat):
		safety = "terrain_recovery"
		desired = AircraftFlightMath.elevated(terrain_ahead.escape,deg_to_rad(32.0 if kinetic_margin > 200 else 18.0),forward)
		max_bank = deg_to_rad(60.0)
	if float(flight.fuel_kg) <= 0 or propulsion < 0.05:
		safety = "glide"
		desired = AircraftFlightMath.elevated(desired,minf(-0.11,AircraftFlightMath.pitch(desired)),forward)
	if height < float(limits.recovery_floor_m)+loss and (forward.y < -0.05 or desired.y < -0.05):
		safety = "low_altitude_recovery"
		desired = AircraftFlightMath.elevated(forward,deg_to_rad(18.0),forward)
		max_bank = deg_to_rad(22.0)
	if speed > max_speed*1.10:
		safety = "overspeed_recovery"
		desired = AircraftFlightMath.elevated(forward,deg_to_rad(25.0),forward)
		max_bank = deg_to_rad(30.0)
	if stalled:
		safety = "stall_recovery"
		desired = AircraftFlightMath.elevated(forward,-0.16 if height > float(limits.clearance_m) else -0.035,forward)
		max_bank = 0.0
	var gravity: Vector3 = Vector3.DOWN*G
	var gravity_normal: Vector3 = gravity-forward*gravity.dot(forward)
	var tangent: Vector3 = desired-forward*desired.dot(forward)
	var error_angle: float = forward.angle_to(desired)
	if tangent.length_squared() < 0.000001 and desired.dot(forward) < 0:
		tangent = basis.x*float(control.get("turn_side",1.0))
	var normal_acc: Vector3 = tangent.normalized()*speed*minf(error_angle*float(limits.guidance_gain),deg_to_rad(float(p.pitch_rate_degps))*1.5)
	# Unload for a dive instead of commanding an instantaneous inverted roll.
	var vertical_acc: float = normal_acc.dot(reference)
	normal_acc += reference*(maxf(-0.82*G,vertical_acc)-vertical_acc)
	var lift_demand: Vector3 = normal_acc-gravity_normal
	var desired_bank: float = clampf(AircraftFlightMath.signed_roll(reference,lift_demand.normalized(),forward),-max_bank,max_bank)
	var target_up: Vector3 = reference.rotated(forward,desired_bank)
	var roll_change: float = clampf(AircraftFlightMath.signed_roll(up,target_up,forward),-deg_to_rad(float(p.roll_rate_degps))*authority*dt,deg_to_rad(float(p.roll_rate_degps))*authority*dt)
	up = up.rotated(forward,roll_change).normalized()
	# When bank is still rolling toward a turn, preserve the requested vertical
	# curvature instead of projecting lateral demand into an unrequested pull-up.
	var requested_load: float = lift_demand.dot(reference)/(G*maxf(0.20,up.dot(reference)))
	if stalled:
		requested_load = minf(0.0,requested_load)
	var minimum_load: float = float(limits.minimum_load_g)*minf(1.0,lift_cap)
	var target_load: float = clampf(requested_load,minimum_load,maxf(minimum_load,lift_cap))
	var load_g: float = move_toward(float(flight.load_factor),target_load,float(limits.load_slew_gps)*dt)
	load_g = clampf(load_g,minimum_load,maxf(minimum_load,lift_cap))
	var parasite: float = float(p.drag_mps2)*pow(speed/max_speed,2)
	var induced: float = float(p.turn_drag_mps2)*maxf(0,load_g*load_g-1.0)*pow(float(p.cruise_mps)/maxf(speed,stall_speed),2)
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
	var next_speed: float = maxf(0.5,speed+(thrust-drag+gravity.dot(forward))*dt)
	var acceleration: Vector3 = up*(load_g*G)+gravity_normal
	var angle: float = minf(acceleration.length()/maxf(1.0,(speed+next_speed)*0.5)*dt,deg_to_rad(float(p.pitch_rate_degps))*2.5*dt)
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
	flight.propeller_phase_rad = fmod(float(flight.propeller_phase_rad)+dt*120*maxf(throttle,0.15)*propulsion,TAU)
	flight.aileron_rad = clampf(-roll_change/dt*0.12,-0.24,0.24)
	flight.elevator_rad = clampf((float(flight.path_pitch_rad)-gamma)/dt*0.25,-0.16,0.16)
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
