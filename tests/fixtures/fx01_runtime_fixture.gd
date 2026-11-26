extends RefCounted

## Release-safe equivalent of the controlled combat fixture. Assertions never
## own setup side effects, so Web release executes identical real modules/data.
const BASE: Script=preload("res://tests/fixtures/combat_fixture.gd")

static func arena(spawns: Array) -> Dictionary:
	var config: CombatConfig=CombatConfig.new()
	var errors: PackedStringArray=config.load_file("res://data/combat/showcase.json")
	if not errors.is_empty():return _fail(errors)
	var world: SimulationWorld=SimulationWorld.new()
	errors=world.configure(BASE.catalog(),{"id":"combat_test","seed":505,"tick_hz":60,"factions":["jp","us"],"spawns":spawns,"groups":[]})
	if not errors.is_empty():return _fail(errors)
	errors=config.validate_world(world)
	if not errors.is_empty():return _fail(errors)
	var frame: CombatFrame=CombatFrame.new(config)
	var contacts: CombatContacts=CombatContacts.new(config,frame)
	var projectiles: CombatProjectiles=CombatProjectiles.new(config,frame)
	var launcher: SimulationModule=BASE.Launcher.new(projectiles)
	for module: SimulationModule in [frame,contacts,CombatTargeting.new(config,frame,contacts),CombatWeapons.new(config,frame,contacts,projectiles),projectiles,CombatDamage.new(config,frame),launcher,BASE.LinearMotion.new()]:
		var result: Dictionary=world.register_module(module)
		if not result.accepted:return _fail(PackedStringArray(["module rejected: "+module.module_id]))
	return {"world":world,"config":config,"frame":frame,"contacts":contacts,"projectiles":projectiles,"launcher":launcher}

static func _fail(errors: PackedStringArray) -> Dictionary:
	push_error("FX01 runtime fixture rejected: "+str(errors))
	(Engine.get_main_loop() as SceneTree).quit(1)
	return {}
