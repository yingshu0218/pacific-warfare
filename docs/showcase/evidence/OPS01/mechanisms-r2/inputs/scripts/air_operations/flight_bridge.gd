extends AircraftMotion

## Narrow private prototype hook: inherited production force integrator, no copied
## flight equations. Ground constraint has exactly one other owner, after ships.
var operations: CarrierOperations

func _fly(world: SimulationWorld, unit: UnitState, p: Dictionary, dt: float) -> void:
	if operations.roster.has(unit.id):
		var s: Dictionary = operations.roster[unit.id]
		if bool(s.on_deck) or operations.terminal_owns(unit): return
		var profile: Dictionary = p.duplicate(true)
		if bool(s.flaps_down) or s.phase == "go_around":
			profile.stall_mps = float(operations.parameters.flaps_stall_mps)
		if s.phase in ["diverted","lost"]:
			# Partial engine loss, disabled-but-active and empty fuel still use
			# the inherited force/glide integrator. OPS release is not DM takeover.
			super._fly(world,unit,profile,dt)
			return
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
		super._fly(world,unit,profile,dt)
	else:
		super._fly(world,unit,p,dt)
