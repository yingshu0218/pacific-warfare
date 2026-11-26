class_name CarrierConfigurationAttitude
extends RefCounted

## Simulation-owned trim/AoA proxy. Translation/lift still have one inherited
## force integrator. The resulting physical body pose drives collision and DM.
static func active(state: Dictionary) -> bool:
	return state.phase == "approach" or (state.phase in ["climb","go_around"] and bool(state.flaps_down)) or absf(float(state.get("angle_of_attack_rad",0))) > 0.000001 or bool(state.get("configuration_transition_active",false))

static func airborne(unit: UnitState, state: Dictionary, aerodynamic: Basis, parameters: Dictionary, dt: float, before: Basis) -> Basis:
	var alpha: float = float(state.get("angle_of_attack_rad",0.0))
	var desired: float = 0.0
	if state.phase == "approach":
		# Photo-constrained nose-up landing configuration. This is a bounded
		# operating estimate, not a digitized historic alpha/polar curve.
		desired = clampf(deg_to_rad(float(parameters.approach_body_pitch_deg))-AircraftFlightMath.pitch(-aerodynamic.z),deg_to_rad(6.0),deg_to_rad(14.0))
		if state.has("configuration_pitch_command_deg"):
			desired = deg_to_rad(clampf(float(state.configuration_pitch_command_deg),-10.0,15.0))-AircraftFlightMath.pitch(-aerodynamic.z)
	elif state.phase in ["climb","go_around"] and bool(state.flaps_down):
		desired = deg_to_rad(6.0)
	if state.phase in ["climb","go_around"] and float(state.get("wheel_clearance_m",0.0)) < 0.15:
		# Keep takeoff trim until the inherited lift integrator has actually
		# separated the wheels. Unloading AoA on the release tick would put
		# the short front tyres back through the deck before lift builds.
		desired = alpha
	alpha = move_toward(alpha,desired,deg_to_rad(float(parameters.configuration_rate_degps))*dt)
	var wanted: Basis = aerodynamic*Basis(Vector3.RIGHT,alpha)
	var q: Quaternion = (before.inverse()*wanted).get_rotation_quaternion().normalized()
	if q.w < 0: q = -q
	var axis: Vector3 = Vector3(q.x,q.y,q.z)
	var rotation_vector: Vector3 = axis*(2.0*atan2(axis.length(),q.w)/axis.length()) if axis.length() > 0.000000001 else Vector3.ZERO
	# Velocity can receive a sudden impulse; the fuselage cannot instantly
	# follow it. Original F6F pitch/roll rates plus bounded configuration trim.
	rotation_vector.x = clampf(rotation_vector.x,-deg_to_rad(14.0)*dt,deg_to_rad(14.0)*dt)
	rotation_vector.y = clampf(rotation_vector.y,-deg_to_rad(15.0)*dt,deg_to_rad(15.0)*dt)
	rotation_vector.z = clampf(rotation_vector.z,-deg_to_rad(65.0)*dt,deg_to_rad(65.0)*dt)
	var body: Basis = before*Basis(rotation_vector.normalized(),rotation_vector.length()) if rotation_vector.length() > 0.000000001 else before
	alpha = (aerodynamic.inverse()*body).get_euler().x
	var aligned: bool = absf(desired) < 0.000001 and body.x.distance_to(aerodynamic.x)+body.y.distance_to(aerodynamic.y)+body.z.distance_to(aerodynamic.z) < 0.00001
	if aligned: body = aerodynamic; alpha = 0.0
	state["angle_of_attack_rad"] = alpha
	state["configuration_transition_active"] = not aligned
	var flight: Dictionary = unit.module_data.aircraft_motion
	flight["aerodynamic_rotation_rad"] = aerodynamic.get_euler()
	flight["angle_of_attack_rad"] = alpha
	flight["body_pitch_rad"] = AircraftFlightMath.pitch(-body.z)
	return body

static func angular_velocity(before: Basis, after: Basis, dt: float) -> Vector3:
	var q: Quaternion = (before.inverse()*after).get_rotation_quaternion().normalized()
	if q.w < 0: q = -q
	var v: Vector3 = Vector3(q.x,q.y,q.z)
	return v*(2.0*atan2(v.length(),q.w)/(v.length()*dt)) if v.length() > 0.000000001 and dt > 0.0 else Vector3.ZERO
