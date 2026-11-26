extends RefCounted

static func prepare(world: SimulationWorld) -> Dictionary:
	var parameters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bombing/parameters.json"))
	var errors: PackedStringArray = BombingConfiguration.validate(parameters)
	if not errors.is_empty(): return {"errors":errors}
	for id: String in world.unit_ids():
		var unit: UnitState=world.get_unit(id)
		if not unit.module_data.has("initial_bomb_loadout"):continue
		var mask: Variant=unit.module_data.initial_bomb_loadout
		if not parameters.aircraft.has(unit.definition_id) or not mask is Array: return {"errors":PackedStringArray(["invalid_initial_bomb_loadout:"+id])}
		if mask.size()!=parameters.aircraft[unit.definition_id].slots_m.size() or not mask.all(func(value: Variant)->bool:return value is bool):return {"errors":PackedStringArray(["invalid_initial_bomb_loadout:"+id])}
	var projectiles: CombatProjectiles
	for module: SimulationModule in world._modules:
		if module is CombatProjectiles:
			if projectiles != null: return {"errors":PackedStringArray(["duplicate_projectiles"])}
			projectiles = module
	if projectiles == null: return {"errors":PackedStringArray(["bombing_requires_existing_combat"])}
	var stores: BombStores = preload("res://scripts/showcase/bombing/initial_stores.gd").new(projectiles,parameters)
	var receipt: Dictionary = world.register_module(stores)
	if not receipt.accepted: return {"errors":PackedStringArray(["bomb_stores_install:"+str(receipt.reason)])}
	return {"errors":PackedStringArray(),"stores":stores,"delegate":BombingMissionDelegate.new(parameters,stores)}
