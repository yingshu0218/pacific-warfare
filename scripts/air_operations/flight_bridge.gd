extends AircraftMotion

## Narrow private prototype hook: inherited production force integrator, no copied
## flight equations. Ground constraint has exactly one other owner, after ships.
var operations: CarrierOperations

func _fly(world: SimulationWorld, unit: UnitState, p: Dictionary, dt: float) -> void:
	if operations.roster.has(unit.id):
		var s: Dictionary = operations.roster[unit.id]
		if bool(s.on_deck) or operations.terminal_owns(unit): return
		var before: Basis = unit.world_transform().basis
		var profile: Dictionary = p.duplicate(true)
		# Keep the qualified deck chain intact. An airborne retask away
		# from carrier launch/recovery uses the normal free-flight model.
		profile["preserve_deck_envelope"] = s.phase in ["climb","return","holding","approach","go_around"] or (
			s.phase == "mission" and not str(s.sortie_order_id).is_empty() and s.order_id == s.sortie_order_id)
		if bool(s.flaps_down) or s.phase == "go_around":
			profile.stall_mps = float(operations.parameters.flaps_stall_mps)
		if s.phase in ["approach","go_around","climb"]:
			# Only an OPS-cleared marine flight phase can waive the generic low
			# altitude pull-up. Stall/energy/damage and real terrain checks remain.
			profile.spatial.recovery_floor_m = -1000.0
			profile.spatial.clearance_m = 0.0
		s.last_local_m = operations.deck_local(world,unit.position_m)
		s["pre_flight_position_m"] = unit.position_m
		s["pre_flight_velocity_mps"] = unit.velocity_mps
		s["pre_flight_rotation_rad"] = unit.rotation_rad
		s["pre_ship_rotation_rad"] = world.get_unit(operations.carrier_id).rotation_rad
		# Separate the transported lift/velocity frame from the physical body.
		# Super is still the sole translation/force integrator; healthy aircraft
		# without carrier configuration take the unchanged branch below.
		var flight: Dictionary = unit.module_data.aircraft_motion
		if not bool(profile.preserve_deck_envelope):
			super._fly(world,unit,profile,dt)
			return
		if not CarrierConfigurationAttitude.active(s):
			# Once clean trim is recovered, roster membership imposes no body
			# rate limit or extra frame reconstruction on combat/patrol flight.
			super._fly(world,unit,profile,dt)
			flight["aerodynamic_rotation_rad"] = unit.rotation_rad
			flight["body_pitch_rad"] = AircraftFlightMath.pitch(-unit.world_transform().basis.z)
			flight["angle_of_attack_rad"] = 0.0
			return
		unit.rotation_rad = AircraftFlightMath.frame(unit.velocity_mps.normalized(),flight.get("lift_up_m",before.y)).get_euler()
		super._fly(world,unit,profile,dt)
		var aerodynamic: Basis = unit.world_transform().basis
		var body: Basis = CarrierConfigurationAttitude.airborne(unit,s,aerodynamic,operations.parameters,dt,before)
		unit.rotation_rad = body.get_euler()
		flight.body_forward_m = -body.z
		flight.body_angular_velocity_radps = CarrierConfigurationAttitude.angular_velocity(before,body,dt)
	else:
		super._fly(world,unit,p,dt)
