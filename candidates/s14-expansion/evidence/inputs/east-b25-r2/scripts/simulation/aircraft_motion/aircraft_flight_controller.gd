class_name AircraftFlightController
extends RefCounted

## Pilot inputs only. Forces still act along the actual transported body-up axis.
## Separate heading and flight-path pitch; a target behind cannot command a loop.
static func coordinated(forward: Vector3, up: Vector3, desired: Vector3, speed: float, lift_cap: float, max_bank: float, p: Dictionary, flight: Dictionary) -> Dictionary:
	var reference: Vector3 = AircraftFlightMath.level_up(forward,up)
	var gamma: float = AircraftFlightMath.pitch(forward)
	var error_gamma: float = AircraftFlightMath.pitch(desired)-gamma
	var error_heading: float = wrapf(AircraftFlightMath.heading(desired)-AircraftFlightMath.heading(forward),-PI,PI)
	var gamma_rate: float = clampf(error_gamma*float(p.spatial.guidance_gain)-float(flight.get("path_pitch_rate_radps",0))*0.18,-deg_to_rad(float(p.pitch_rate_degps)),deg_to_rad(float(p.pitch_rate_degps)))
	var vertical_g: float = maxf(0.15,cos(gamma)+speed*gamma_rate/9.80665)
	var safe_load: float = maxf(0.2,lift_cap/pow(float(p.spatial.get("stall_control_margin",1.12)),2))
	var available_bank: float = acos(clampf(vertical_g/safe_load,0,1))
	var heading_rate: float = clampf(error_heading*float(p.spatial.guidance_gain),-0.65,0.65)
	var lateral_g: float = -speed*maxf(0.15,cos(gamma))*heading_rate/9.80665
	var desired_bank: float = clampf(atan2(lateral_g,vertical_g),-minf(max_bank,available_bank),minf(max_bank,available_bank))
	var target_up: Vector3 = reference.rotated(forward,desired_bank)
	var requested: float = vertical_g/maxf(0.2,up.dot(reference))
	var roll_error: float = AircraftFlightMath.signed_roll(up,target_up,forward)
	# Roll first, then pull: do not request maximum load while reversing bank.
	if absf(roll_error) > deg_to_rad(25) or up.dot(reference) < 0.2:
		requested = minf(requested,0.8)
	return {"up":target_up,"load_g":clampf(requested,0.15,safe_load),"heading_error_rad":error_heading,"gamma_error_rad":error_gamma}

static func induced_drag(p: Dictionary, speed: float, altitude: float, load: float) -> float:
	if not p.spatial.has("wing_span_m"):
		return float(p.turn_drag_mps2)*maxf(0,load*load-1)*pow(float(p.cruise_mps)/maxf(speed,float(p.stall_mps)),2)
	var span: float = p.spatial.wing_span_m
	var efficiency: float = p.spatial.oswald_efficiency
	var density: float = 1.225*exp(-altitude/float(p.spatial.density_scale_m))
	# Existing one-g drag is already in the level-flight envelope. Add only the
	# load-induced increment: k=1/(pi*e*AR), AR=b²/S, so S cancels.
	return 2*float(p.reference_mass_kg)*9.80665*9.80665*maxf(0,load*load-1)/(PI*efficiency*span*span*density*maxf(speed*speed,1))
