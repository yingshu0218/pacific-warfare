extends SimulationModule

## Physical static support for an already-disabled wreck, after CombatDamage.
## Does not restore aircraft activity, order ownership, fuel or OPS parking.
var operations: CarrierOperations

func _init() -> void:
	module_id = "carrier_wreck_support"
	priority = 690

func fixed_update(world_ref: RefCounted, dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not unit.module_data.has("carrier_deck_contact"): continue
		var support: Dictionary = unit.module_data.carrier_deck_contact
		var damage: Dictionary = unit.module_data.get("damage",{})
		if damage.get("phase","") == "removed": unit.module_data.erase("carrier_deck_contact"); continue
		if damage.get("phase","") != "wreck": continue
		var ship: UnitState = world.get_unit(str(support.carrier_id))
		if ship != null: _fragments(world,unit,ship)
		var local: Vector3 = support.local_m
		var hit: Dictionary = operations.deck.surface(Vector2(local.x,local.z))
		if ship == null or not ship.active or not hit.supported or absf(float(hit.height_m)-float(operations.parameters.deck_height_m)) > 0.02:
			# Actual support loss: resume existing terminal dynamics; never
			# reattach a crashing aircraft to a ship or to a raised elevator.
			support.supporting = false
			unit.module_data.erase("carrier_deck_contact")
			damage.phase = "crashing"; damage.phase_time_s = 0.0
			damage.aircraft.contact_surface = ""
			AircraftDamageMotion.begin_terminal(unit)
			world.emit_event("damage_phase",id,"",unit.position_m,{"phase":"crashing","domain":"aircraft","reason":"carrier_surface_support_lost"})
			continue
		var previous: Vector3 = local
		var before: Basis = unit.world_transform().basis
		var flight: Dictionary = unit.module_data.aircraft_motion
		if float(flight.get("propeller_speed_radps",0)) < 0.0001:
			CarrierWreckSettling.step(unit,ship,support,operations,dt)
			local = support.local_m
		unit.position_m = ship.world_transform()*local
		unit.rotation_rad = (ship.world_transform().basis*Basis.from_euler(support.local_rotation_rad)).get_euler()
		unit.velocity_mps = CarrierDeckGeometry.velocity_at(ship,local,operations.angular_velocity)+ship.world_transform().basis*((local-previous)/dt)
		flight.body_angular_velocity_radps = CarrierConfigurationAttitude.angular_velocity(before,unit.world_transform().basis,dt)
		flight.body_pitch_rad = AircraftFlightMath.pitch(-unit.world_transform().basis.z)

func _fragments(world: SimulationWorld, unit: UnitState, ship: UnitState) -> void:
	# Existing DM still owns debris forces and its fixed cap/lifetime. This is
	# only first-contact/static support on the same physical carrier surface.
	for piece: Dictionary in unit.module_data.damage.aircraft.fragments:
		if piece.surface == "carrier_deck":
			var local: Vector3 = piece.carrier_local_m
			var surface: Dictionary = operations.deck.surface(Vector2(local.x,local.z))
			if ship.active and surface.supported and absf(float(surface.height_m)-float(operations.parameters.deck_height_m)) < 0.02:
				piece.position_m = ship.world_transform()*local
				piece.velocity_mps = CarrierDeckGeometry.velocity_at(ship,local,operations.angular_velocity)
			else: piece.surface = ""
		elif str(piece.surface).is_empty():
			var previous: Vector3 = piece.get("deck_previous_position_m",piece.position_m)
			var a: Vector3 = ship.world_transform().affine_inverse()*previous
			var b: Vector3 = ship.world_transform().affine_inverse()*(piece.position_m as Vector3)
			var height: float = float(operations.parameters.deck_height_m)
			if a.y >= height and b.y <= height and a.y > b.y:
				var point: Vector3 = a.lerp(b,(a.y-height)/(a.y-b.y))
				var surface: Dictionary = operations.deck.surface(Vector2(point.x,point.z))
				if surface.supported and absf(float(surface.height_m)-height) < 0.02:
					piece.surface = "carrier_deck"; piece["carrier_local_m"] = point
					piece.position_m = ship.world_transform()*point
					piece.velocity_mps = CarrierDeckGeometry.velocity_at(ship,point,operations.angular_velocity)
		piece["deck_previous_position_m"] = piece.position_m
