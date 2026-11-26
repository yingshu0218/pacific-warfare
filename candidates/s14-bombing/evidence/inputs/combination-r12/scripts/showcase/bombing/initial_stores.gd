extends "res://scripts/bombing/stores.gd"

## Explicit scenario loadout only, applied at ordinary module reset.
## Inherited BombStores remains the sole finite-inventory/release writer.
func _init(flight: CombatProjectiles, data: Dictionary) -> void:
	super._init(flight,data)

func reset(world_ref: RefCounted) -> void:
	super.reset(world_ref)
	var world: SimulationWorld=world_ref as SimulationWorld
	for id: String in world.unit_ids():
		var unit: UnitState=world.get_unit(id)
		if not unit.module_data.has("initial_bomb_loadout"):continue
		var mask: Array=unit.module_data.initial_bomb_loadout
		var rack: Dictionary=unit.module_data.bomb_rack
		var remaining: int=0
		for i: int in mask.size():
			rack.slots[i].loaded=mask[i]
			if mask[i]:remaining+=1
		rack.remaining=remaining
		rack.mass_kg=remaining*float(parameters.ammunition[rack.ammo_id].projectile_mass_kg)
		rack.reason="initial_loadout_empty" if remaining==0 else "initial_loadout_selected"
