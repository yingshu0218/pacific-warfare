extends RefCounted

class LinearMotion extends SimulationModule:
	func _init() -> void:
		module_id = "test_combat_linear_motion"
		priority = 400
	func fixed_update(world_ref: RefCounted, delta_s: float) -> void:
		var world: SimulationWorld = world_ref as SimulationWorld
		for id: String in world.unit_ids():
			var unit: UnitState = world.get_unit(id)
			if unit.active:
				unit.position_m += unit.velocity_mps * delta_s

class Launcher extends SimulationModule:
	var pending: Array[Dictionary] = []
	var flight: CombatProjectiles
	func _init(projectiles: CombatProjectiles) -> void:
		module_id = "test_combat_launcher"
		priority = 510
		flight = projectiles
	func fixed_update(world_ref: RefCounted, _delta_s: float) -> void:
		var world: SimulationWorld = world_ref as SimulationWorld
		for p: Dictionary in pending:
			var unit: UnitState = world.get_unit(p.get("shooter", "shooter"))
			var gun: WeaponState = unit.weapons.values()[0]
			var ammo: AmmoDefinition = world.ammo_definition(p.get("ammo", "us_127mm_m2_ball"))
			if p.has("speed"):
				ammo.muzzle_speed_mps = float(p.speed)
			if p.has("gravity"):
				ammo.gravity_mps2 = float(p.gravity)
			if p.has("lifetime"):
				ammo.max_lifetime_s = float(p.lifetime)
			flight.launch(world, unit, gun, ammo, p.get("position", Vector3(0,100,0)), p.get("direction", Vector3.FORWARD), p.get("fuze", -1.0))
		pending.clear()

static func require_ok(ok: bool, context: String) -> bool:
	if ok: return true
	push_error("Combat fixture: " + context)
	(Engine.get_main_loop() as SceneTree).quit(1)
	return false

static func require_accepted(receipt: Dictionary, context: String) -> bool:
	return require_ok(bool(receipt.get("accepted",false)),context+": "+str(receipt))

static func catalog() -> DefinitionCatalog:
	var catalog_ref: DefinitionCatalog = DefinitionCatalog.new()
	var ammo_paths: Array[String] = []
	for file: String in DirAccess.get_files_at("res://data/ammunition"):
		if file.ends_with(".json"):
			ammo_paths.append("res://data/ammunition/" + file)
	var unit_paths: Array[String] = []
	for file: String in DirAccess.get_files_at("res://data/units"):
		if file.ends_with(".json"):
			unit_paths.append("res://data/units/" + file)
	var gun_paths: Array[String] = []
	for file: String in DirAccess.get_files_at("res://data/units/weapons"):
		if file.ends_with(".json"):
			gun_paths.append("res://data/units/weapons/" + file)
	var errors: PackedStringArray = catalog_ref.load_files(unit_paths, ammo_paths, gun_paths)
	if not errors.is_empty():
		push_error("Combat fixture catalog rejected: "+str(errors))
		(Engine.get_main_loop() as SceneTree).quit(1)
		return null
	return catalog_ref

static func config() -> CombatConfig:
	var config_ref: CombatConfig = CombatConfig.new()
	var errors: PackedStringArray = config_ref.load_file("res://data/combat/showcase.json")
	if not require_ok(errors.is_empty(),str(errors)): return null
	return config_ref

static func spawn(id: String, faction: String, position: Vector3, definition: String = "us_f6f5_1944", velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"id": id, "unit_definition_id": definition, "faction_id": faction, "position_m": SimData.array3(position), "velocity_mps": SimData.array3(velocity)}

static func arena(spawns: Array, settings: CombatConfig = null, with_linear_motion: bool = true) -> Dictionary:
	var c: CombatConfig = config() if settings == null else settings
	var world: SimulationWorld = SimulationWorld.new()
	var definitions: DefinitionCatalog=catalog()
	if definitions==null:return {}
	var errors: PackedStringArray = world.configure(definitions, {"id": "combat_test", "seed": 505, "tick_hz": 60, "factions": ["jp", "us"], "spawns": spawns, "groups": []})
	if not require_ok(errors.is_empty(),str(errors)): return {}
	errors = c.validate_world(world)
	if not require_ok(errors.is_empty(),str(errors)): return {}
	var frame: CombatFrame = CombatFrame.new(c)
	var contacts: CombatContacts = CombatContacts.new(c, frame)
	var projectiles: CombatProjectiles = CombatProjectiles.new(c, frame)
	var launcher: Launcher = Launcher.new(projectiles)
	for module: SimulationModule in [frame, contacts, CombatTargeting.new(c, frame, contacts), CombatWeapons.new(c, frame, contacts, projectiles), projectiles, CombatDamage.new(c, frame), launcher]:
		var receipt: Dictionary = world.register_module(module)
		if not require_accepted(receipt,"register "+module.module_id): return {}
	if with_linear_motion:
		var receipt: Dictionary = world.register_module(LinearMotion.new())
		if not require_accepted(receipt,"register linear motion"): return {}
	return {"world": world, "config": c, "frame": frame, "contacts": contacts, "projectiles": projectiles, "launcher": launcher}

static func target(world: SimulationWorld, shooter: String, target_id: String) -> void:
	var unit: UnitState = world.get_unit(shooter)
	var command: BattleCommand = BattleCommand.new()
	command.command_id = "target:" + shooter + ":" + str(world.tick) + ":" + target_id
	command.issuer_id = "test_executor"
	command.source = "ai"
	command.faction_id = unit.faction_id
	command.entity_id = shooter
	command.kind = BattleCommand.SET_TARGET
	command.payload = {"target_id": target_id}
	var receipt: Dictionary = world.submit_command(command)
	require_accepted(receipt,"submit target")

static func events(world: SimulationWorld, kind: String) -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for event: BattleEvent in world.drain_events():
		if event.kind == kind:
			result.append(event)
	return result
