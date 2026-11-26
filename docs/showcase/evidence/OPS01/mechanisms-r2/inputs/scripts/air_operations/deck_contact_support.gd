extends SimulationModule

## Physical static support for an already-disabled wreck, after CombatDamage.
## Does not restore aircraft activity, order ownership, fuel or OPS parking.
var operations: CarrierOperations

func _init() -> void:
	module_id = "carrier_wreck_support"
	priority = 690

func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not unit.module_data.has("carrier_deck_contact"): continue
		var support: Dictionary = unit.module_data.carrier_deck_contact
		var damage: Dictionary = unit.module_data.get("damage",{})
		if damage.get("phase","") == "removed": unit.module_data.erase("carrier_deck_contact"); continue
		if damage.get("phase","") != "wreck": continue
		var ship: UnitState = world.get_unit(str(support.carrier_id))
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
		unit.position_m = ship.world_transform()*local
		unit.rotation_rad = (ship.world_transform().basis*Basis.from_euler(support.local_rotation_rad)).get_euler()
		unit.velocity_mps = CarrierDeckGeometry.velocity_at(ship,local,operations.angular_velocity)
