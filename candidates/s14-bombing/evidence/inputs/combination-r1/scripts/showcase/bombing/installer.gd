extends RefCounted

static func prepare(world: SimulationWorld) -> Dictionary:
	var parameters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bombing/parameters.json"))
	var errors: PackedStringArray = BombingConfiguration.validate(parameters)
	if not errors.is_empty(): return {"errors":errors}
	var projectiles: CombatProjectiles
	for module: SimulationModule in world._modules:
		if module is CombatProjectiles:
			if projectiles != null: return {"errors":PackedStringArray(["duplicate_projectiles"])}
			projectiles = module
	if projectiles == null: return {"errors":PackedStringArray(["bombing_requires_existing_combat"])}
	var stores: BombStores = BombStores.new(projectiles,parameters)
	var receipt: Dictionary = world.register_module(stores)
	if not receipt.accepted: return {"errors":PackedStringArray(["bomb_stores_install:"+str(receipt.reason)])}
	return {"errors":PackedStringArray(),"stores":stores,"delegate":BombingMissionDelegate.new(parameters,stores)}
