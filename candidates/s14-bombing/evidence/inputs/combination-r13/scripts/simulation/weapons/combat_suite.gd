class_name CombatSuite
extends RefCounted

## Configure first. No public world/state/command changes are needed by S05.
static func install(world: SimulationWorld, parameters: CombatConfig) -> PackedStringArray:
	var errors: PackedStringArray = parameters.validate_world(world)
	if not errors.is_empty():
		return errors
	if world.tick != 0:
		return ["combat_install_once_before_first_tick"]
	var existing: Dictionary = world.snapshot().modules
	for id: String in ["combat_frame", "combat_contacts", "combat_targeting", "combat_weapons", "combat_projectiles", "combat_damage"]:
		if existing.has(id):
			return ["combat_module_id_already_registered:" + id]
	# Freeze caller-owned settings; source edits cannot alter an in-progress battle.
	var config: CombatConfig = CombatConfig.new()
	config.load_data(parameters.data)
	var frame: CombatFrame = CombatFrame.new(config)
	var contacts: CombatContacts = CombatContacts.new(config, frame)
	var projectiles: CombatProjectiles = CombatProjectiles.new(config, frame)
	var modules: Array[SimulationModule] = [frame, contacts, CombatTargeting.new(config, frame, contacts),
		CombatWeapons.new(config, frame, contacts, projectiles), projectiles, CombatDamage.new(config, frame)]
	for module: SimulationModule in modules:
		var receipt: Dictionary = world.register_module(module)
		if not receipt.accepted:
			errors.append("combat_register:" + str(receipt.reason))
	return errors
