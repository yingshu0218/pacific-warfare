extends SimulationModule

## Resolves holonomic wheel support, longitudinal thrust/braking and swept deck
## contact after the real ShipMotion tick. Never integrates an airborne aircraft.
var operations: CarrierOperations

func _init() -> void:
	module_id = "carrier_deck_motion"
	priority = 430

func fixed_update(world_ref: RefCounted, dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	var ship: UnitState = world.get_unit(operations.carrier_id)
	if ship == null: return
	var pose: Transform3D = ship.world_transform()
	var q: Quaternion = (pose.basis*operations.last_ship_basis.inverse()).get_rotation_quaternion().normalized()
	if q.w < 0: q = -q
	var v: Vector3 = Vector3(q.x,q.y,q.z)
	operations.angular_velocity = v*(2.0*atan2(v.length(),q.w)/(v.length()*dt)) if v.length() > 0.00000001 else Vector3.ZERO
	operations.last_ship_basis = pose.basis
	for id: String in operations.roster:
		var unit: UnitState = world.get_unit(id)
		var s: Dictionary = operations.roster[id]
		if operations.terminal_owns(unit) or s.phase in ["lost","diverted"]: continue
		if s.on_deck:
			_ground(world,unit,ship,dt)
		else:
			var local: Vector3 = pose.affine_inverse()*unit.position_m
			var old_local: Vector3 = s.last_local_m
			var swept: Dictionary = _swept_contact(ship,unit,s,old_local,local)
			if not swept.is_empty():
				var fraction: float = float(swept.fraction)
				var contact: Vector3 = swept.local_m
				var surface: Dictionary = operations.deck.surface(Vector2(contact.x,contact.z))
				if not surface.supported or absf(float(surface.height_m)-float(operations.parameters.deck_height_m)) > 0.02: continue
				var check: Dictionary = touchdown_check(unit,ship,contact,world)
				if s.phase != "approach": check.accepted = false; check.reason = "uncontrolled_deck_contact"
				if bool(check.accepted):
					s.on_deck = true; s.local_m = contact; s.local_yaw_rad = 0.0
					s["local_rotation_rad"] = swept.local_rotation_rad
					s.relative_velocity_mps = pose.basis.inverse()*(unit.velocity_mps-CarrierDeckGeometry.velocity_at(ship,contact,operations.angular_velocity))
					s.relative_velocity_mps.y = 0.0
					s.touchdown_count += 1
					world.emit_event("carrier_touchdown",id,"",pose*contact,check,ship.id)
					operations._phase(world,unit,"touchdown","wheel_contact_in_envelope")
					_ground(world,unit,ship,dt*(1.0-fraction))
				else:
					world.emit_event("carrier_touchdown_rejected",id,"",pose*contact,check,ship.id)
					# Contact already happened. A wave-off here would tunnel below
					# the deck. Emit the existing physical surface-contact contract;
					# CombatDamage owns the impact outcome in this very tick.
					unit.position_m = pose*contact
					unit.rotation_rad = (pose.basis*Basis.from_euler(swept.local_rotation_rad)).get_euler()
					unit.module_data["carrier_deck_contact"] = {"carrier_id":ship.id,"local_m":contact,"local_rotation_rad":swept.local_rotation_rad,"supporting":true}
					world.emit_event("unit_surface_contact",id,"",unit.position_m,{"surface":"ground","surface_id":"carrier_flight_deck","carrier_id":ship.id,"normal":pose.basis.y,"velocity_mps":unit.velocity_mps,"reason":"carrier_deck_collision:"+str(check.reason)},ship.id)
					operations._release(id); s.on_deck = false
					operations._phase(world,unit,"lost","physical_deck_contact_damage_handoff")
			elif s.phase == "climb" and local.z < -165.0 and operations.strip_owner == id:
				operations._release(id)
			operations._publish(unit)

func _swept_contact(ship: UnitState, unit: UnitState, state: Dictionary, old_local: Vector3, local: Vector3) -> Dictionary:
	var previous: Basis = Basis.from_euler(state.get("pre_ship_rotation_rad",ship.rotation_rad)).inverse()*Basis.from_euler(state.get("pre_flight_rotation_rad",unit.rotation_rad))
	var current: Basis = ship.world_transform().basis.inverse()*unit.world_transform().basis
	var best: float = INF
	var result: Dictionary = {}
	var height: float = float(operations.parameters.deck_height_m)
	for point: Vector3 in CarrierDeckGeometry.contact_points(bool(state.gear_down)):
		var before: Vector3 = old_local+previous*point
		var after: Vector3 = local+current*point
		if before.y < height or after.y > height or before.y <= after.y: continue
		var fraction: float = (before.y-height)/(before.y-after.y)
		var contact_point: Vector3 = before.lerp(after,fraction)
		var surface: Dictionary = operations.deck.surface(Vector2(contact_point.x,contact_point.z))
		if not surface.supported or absf(float(surface.height_m)-height) > 0.02: continue
		if fraction < best:
			best = fraction
			var basis: Basis = Basis(previous.get_rotation_quaternion().slerp(current.get_rotation_quaternion(),fraction))
			result = {"fraction":fraction,"local_m":old_local.lerp(local,fraction),"local_rotation_rad":basis.get_euler(),"feature_local_m":point}
	return result

func touchdown_check(unit: UnitState, ship: UnitState, local: Vector3, world: SimulationWorld = null) -> Dictionary:
	var p: Dictionary = operations.parameters
	var relative: Vector3 = ship.world_transform().basis.inverse()*(unit.velocity_mps-CarrierDeckGeometry.velocity_at(ship,local,operations.angular_velocity))
	var forward: Vector3 = ship.world_transform().basis.inverse()*(-unit.world_transform().basis.z)
	var heading_error: float = absf(atan2(forward.x,-forward.z))
	var bank: float = absf(float(unit.module_data.aircraft_motion.get("bank_rad",0)))
	var speed: float = unit.velocity_mps.length()
	var reason: String = operations._base_reason(world) if world != null else operations._base_reason_for_contact(ship)
	if operations.external_block or operations.strip_owner != unit.id: reason = "landing_deck_occupied"
	elif local.z < 81.0 or local.z > 122.0 or absf(local.x+3.0) > 3.0: reason = "outside_touchdown_zone"
	elif speed < float(p.touch_min_air_mps) or speed > float(p.touch_max_air_mps): reason = "touchdown_speed_outside_envelope"
	elif relative.y > 0.2 or relative.y < -float(p.max_sink_mps): reason = "touchdown_sink_outside_envelope"
	elif heading_error > deg_to_rad(float(p.max_heading_error_deg)) or bank > deg_to_rad(float(p.max_bank_deg)): reason = "touchdown_attitude_outside_envelope"
	elif not bool(operations.roster[unit.id].gear_down) or not bool(operations.roster[unit.id].hook_down): reason = "landing_configuration_invalid"
	elif not operations.deck.footprint_reason(local-Vector3.UP*float(p.origin_above_wheels_m),0.0).is_empty(): reason = "touchdown_footprint_unsupported"
	return {"accepted":reason.is_empty(),"reason":reason,"local_m":local,"relative_velocity_mps":relative,"air_speed_mps":speed,"heading_error_rad":heading_error,"bank_rad":bank}

func _ground(world: SimulationWorld, unit: UnitState, ship: UnitState, dt: float) -> void:
	var s: Dictionary = operations.roster[unit.id]
	var p: Dictionary = operations.parameters
	var local: Vector3 = s.local_m
	var previous: Vector3 = local
	var velocity: Vector3 = s.relative_velocity_mps
	var goal: Vector3 = local
	var desired_speed: float = 0.0
	var acceleration: float = float(p.taxi_acceleration_mps2)
	match str(s.phase):
		"respotting":
			# Coarse crew/tow traction, not engine reverse thrust or a model
			# animation. Wheels roll aft under bounded force on the moving deck.
			goal = Vector3(-3,local.y,float(s.respot_target_z))
			acceleration = float(p.respot_acceleration_mps2)
			desired_speed = minf(float(p.respot_speed_mps),sqrt(maxf(0.0,goal.z-local.z)*2.0*acceleration))
			if goal.distance_to(local) < 0.3 and velocity.length() < 0.05:
				operations.strip_owner = ""; operations.strip_use = ""
				operations._phase(world,unit,str(s.respot_return_phase),"deck_respot_physically_complete")
		"taxi_out":
			goal = Vector3(-3,local.y,60)
			desired_speed = minf(float(p.taxi_speed_mps),sqrt(maxf(0.0,local.z-60.0)*2.0*acceleration))
			if local.z <= 60.3 and velocity.length() < 0.7:
				operations._phase(world,unit,"takeoff_roll","roll_length_and_wind_cleared")
		"takeoff_roll":
			desired_speed = 50.0; acceleration = float(p.roll_acceleration_mps2)*clampf(float(unit.module_data.get("damage",{}).get("propulsion_factor",1.0)),0.0,1.0)
			goal = Vector3(-3,local.y,-200)
		"touchdown":
			goal = local+Vector3.FORWARD*100
			desired_speed = velocity.length(); acceleration = 0.0
		"arresting":
			goal = local+Vector3.FORWARD*100
			acceleration = float(p.arrest_deceleration_mps2)
			if velocity.length() < 0.2:
				operations._phase(world,unit,"taxi_clear","arrest_complete_clear_landing_area")
		"taxi_clear":
			if str(s.parking_slot).is_empty():
				for slot: String in ["forward_1","forward_2"]:
					if not operations.parking.has(slot):
						operations.parking[slot] = unit.id; s.parking_slot = slot; break
			# First moves furthest forward, second stops aft of it. Both are
			# beyond the -40m landing-area release boundary, within CV01 park.
			goal = Vector3(-3,local.y,-72 if s.parking_slot == "forward_1" else -52)
			desired_speed = minf(float(p.taxi_speed_mps),sqrt(maxf(0.0,local.z-goal.z)*2.0*acceleration))
			if local.distance_to(goal) < 0.3 and velocity.length() < 0.05:
				operations._release(unit.id)
				operations.parking[s.parking_slot] = unit.id
				s.recoveries += 1; s.service_done = false
				operations._phase(world,unit,"servicing","recovered_and_parked")
		"servicing":
			if world.time_s()-float(s.since_s) >= float(p.service_seconds) and operations.available:
				_service(world,unit)
	if s.phase in ["deck_hold","standby","preparing","queued","servicing"]: desired_speed = 0.0
	var direction: Vector3 = (goal-local).normalized() if goal.distance_to(local) > 0.0001 else Vector3.FORWARD
	var next_velocity: Vector3 = velocity.move_toward(direction*desired_speed,acceleration*dt)
	if s.phase in ["touchdown","arresting"]:
		next_velocity.x = move_toward(velocity.x,0.0,3.0*dt)
	# Braking before a peer is part of simulation, irrespective of rendering.
	for id: String in operations.roster:
		var peer: Dictionary = operations.roster[id]
		if id != unit.id and peer.on_deck and (peer.local_m as Vector3).z < local.z and local.z-(peer.local_m as Vector3).z < 13.0+velocity.length_squared()/(2.0*maxf(acceleration,0.7)):
			next_velocity = velocity.move_toward(Vector3.ZERO,2.0*dt)
		if s.phase == "respotting" and id != unit.id and peer.on_deck and (peer.local_m as Vector3).z > local.z and (peer.local_m as Vector3).z-local.z < 13.0+velocity.length_squared()/(2.0*maxf(acceleration,0.35)):
			next_velocity = velocity.move_toward(Vector3.ZERO,0.7*dt)
	local += (velocity+next_velocity)*(0.5*dt)
	var angles: Vector3 = s.get("local_rotation_rad",Vector3(0,float(s.local_yaw_rad),0))
	angles.x = move_toward(angles.x,0.0,deg_to_rad(30.0)*dt)
	angles.z = move_toward(angles.z,0.0,deg_to_rad(30.0)*dt)
	angles.y = move_toward(angles.y,0.0,deg_to_rad(15.0)*dt)
	s["local_rotation_rad"] = angles
	var relative_basis: Basis = Basis.from_euler(angles)
	var lowest: float = INF
	for point: Vector3 in CarrierDeckGeometry.contact_points(true): lowest = minf(lowest,(relative_basis*point).y)
	local.y = float(p.deck_height_m)-lowest
	s.local_m = local; s.relative_velocity_mps = next_velocity
	unit.position_m = ship.world_transform()*local
	unit.velocity_mps = CarrierDeckGeometry.velocity_at(ship,local,operations.angular_velocity)+ship.world_transform().basis*next_velocity
	unit.rotation_rad = (ship.world_transform().basis*relative_basis).get_euler()
	var flight: Dictionary = unit.module_data.aircraft_motion
	flight.speed_mps = unit.velocity_mps.length()
	flight.forward_m = -unit.world_transform().basis.z; flight.lift_up_m = unit.world_transform().basis.y
	flight.path_pitch_rad = 0.0; flight.bank_rad = 0.0; flight.roll_velocity_radps = 0.0; flight.path_pitch_rate_radps = 0.0
	flight.body_angular_velocity_radps = unit.world_transform().basis.inverse()*operations.angular_velocity
	flight.safety_state = "deck_constraint"; flight.stalled = false
	flight.distance_m += (local-previous).length()
	var throttle: float = 1.0 if s.phase == "takeoff_roll" else (0.15 if s.phase in ["taxi_out","taxi_clear"] else 0.0)
	var burn: float = minf(float(flight.fuel_kg),0.275*throttle*dt)
	flight.fuel_kg -= burn; flight.fuel_used_kg += burn
	var propeller_rate: float = 12.0+100.0*throttle if throttle > 0.0 else (unit.velocity_mps.length()*0.12 if s.phase in ["touchdown","arresting"] else 0.0)
	flight.propeller_phase_rad = fmod(float(flight.propeller_phase_rad)+dt*propeller_rate,TAU)
	var supported: bool = ship.active
	for point: Vector3 in CarrierDeckGeometry.contact_points(true):
		var at: Vector3 = local+relative_basis*point
		var surface: Dictionary = operations.deck.surface(Vector2(at.x,at.z))
		if not surface.supported or absf(float(surface.height_m)-float(p.deck_height_m)) > 0.02: supported = false
	if not supported:
		# An aborted roll cannot keep driving over an imaginary infinite deck.
		# Leave at the actual edge pose/velocity; inherited flight/DM continues.
		s.on_deck = false; operations._release(unit.id)
		unit.module_data.erase("aircraft_control")
		operations._phase(world,unit,"diverted","wheel_support_lost_at_actual_deck_edge")
		if not str(s.order_id).is_empty(): world.report_order_unit_status(s.order_id,unit.id,"failed","wheel_support_lost_at_actual_deck_edge","diverted")
		return
	if s.phase == "touchdown":
		# Hook (4.4m aft) must physically sweep a real CV01 wire after wheels
		# contact. It does not attach on approach or at an arbitrary timer.
		for wire: Dictionary in operations.deck.data.arresting_wires:
			var z: float = float(wire.points_m[0][2])
			if previous.z+4.4 >= z and local.z+4.4 <= z:
				s["wire_id"] = str(wire.id)
				world.emit_event("carrier_wire_caught",unit.id,"",unit.position_m,{"wire_id":wire.id,"relative_velocity_mps":next_velocity},ship.id)
				operations._phase(world,unit,"arresting","hook_swept_arresting_wire")
				break
	if s.phase == "takeoff_roll":
		if unit.velocity_mps.length() >= float(p.rotate_air_mps):
			s.on_deck = false; s.sorties += 1
			operations._phase(world,unit,"climb","airspeed_and_deck_run_complete")
			operations._steer(unit,ship.world_transform()*Vector3(-3,500,-3500),78.0)
		elif local.z < -120.0:
			operations._phase(world,unit,"deck_hold","takeoff_speed_not_reached_abort")
	operations._publish(unit)

func _service(world: SimulationWorld, unit: UnitState) -> void:
	var s: Dictionary = operations.roster[unit.id]
	if s.service_done or int(s.recoveries) <= 0 or not s.on_deck or (s.relative_velocity_mps as Vector3).length() > 0.5: return
	var flight: Dictionary = unit.module_data.aircraft_motion
	var fuel: float = minf(float(flight.fuel_capacity_kg)-float(flight.fuel_kg),operations.fuel_stock_kg)
	flight.fuel_kg += fuel; operations.fuel_stock_kg -= fuel; operations.fuel_delivered_kg += fuel
	var ammo: int = 0
	for weapon: WeaponState in unit.weapons.values():
		# Current stock belongs to the existing WeaponState, never an OPS clone.
		var definition: WeaponDefinition = world.weapon_definition(weapon.definition_id)
		for barrel: int in range(weapon.remaining_rounds.size()):
			var missing: int = maxi(0,definition.initial_rounds_per_barrel-weapon.remaining_rounds[barrel])
			var supplied: int = mini(missing,operations.ammo_stock_rounds)
			weapon.remaining_rounds[barrel] += supplied
			operations.ammo_stock_rounds -= supplied; ammo += supplied
	operations.ammo_delivered += ammo; s.service_done = true
	world.emit_event("carrier_service_completed",unit.id,"",unit.position_m,{"fuel_kg":fuel,"ammo_rounds":ammo},operations.carrier_id)
	var order_id: String = s.order_id
	operations._phase(world,unit,"standby","service_complete")
	if not order_id.is_empty(): world.report_order_unit_status(order_id,unit.id,"completed","sortie_recovered_and_serviced","standby")
