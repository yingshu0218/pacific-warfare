extends "res://tests/fixtures/combat_test.gd"

const IOWA: String = "us_iowa_bb61_1944_12_28"
const YAMATO: String = "jp_yamato_1944_04"
const BOW: String = "main_01"
const STERN: String = "main_03"
const DUAL: String = "secondary_01_starboard"

func run_test() -> void:
	_test_mixed_fire_and_salvos()
	_test_postures_and_permissions()
	_test_single_target_and_reassignment()
	_test_dual_purpose_main()
	finish("GUN01 naval target allocation")

func _test_mixed_fire_and_salvos() -> void:
	var a: Dictionary = FIX.arena([
		FIX.spawn("iowa", "us", Vector3.ZERO, IOWA),
		FIX.spawn("task", "jp", Vector3(0, 0, -3000), YAMATO),
		FIX.spawn("aft", "jp", Vector3(0, 0, 3000), YAMATO),
		FIX.spawn("air", "jp", Vector3(1050, 300, -200)),
	])
	var world: SimulationWorld = a.world
	var signature: Array = _mixed_run(world)
	expect(world.reset(), "Reopen the same world with its original seed")
	expect(_mixed_run(world) == signature, "Reopened world reproduces mount choices, actual event ticks, targets and debit")

func _mixed_run(world: SimulationWorld) -> Array:
	var iowa: UnitState = world.get_unit("iowa")
	_posture(world, "offensive")
	iowa.module_data.combat_intent = {"fire": true, "allow_aa": true}
	FIX.target(world, iowa.id, "task")
	# Existing reload clock gives the already-facing main groups time to lay
	# before both become ready. The executor still has to clear each barrel.
	for mount_id: String in [BOW, "main_02", STERN]:
		iowa.weapons[mount_id].cycle_remaining_s = 1.0
	var before: Dictionary = _inventory(iowa)
	var matching_salvos: bool = true
	var simultaneous_main: bool = false
	var mixed: bool = false
	var mixed_example: Array = []
	var last_surface: int = -1000
	var last_air: int = -1000
	var last_aa_mount: String = ""
	var signature: Array = []
	var fired: Dictionary = {}
	var first_main: Dictionary = {}
	for _tick: int in range(120):
		world.step_ticks(1)
		var main_fired: Dictionary = {}
		var salvos: Dictionary = {}
		for event: BattleEvent in world.drain_events():
			if event.entity_id != iowa.id:
				continue
			if event.kind == "fired":
				var mount_id: String = event.weapon_id.get_slice("/", 1)
				fired[mount_id] = int(fired.get(mount_id, 0)) + 1
				signature.append([event.tick, event.weapon_id, event.target_id, event.data.barrel_index])
				if event.data.mount_role == "main":
					last_surface = event.tick
					if not main_fired.has(event.target_id):
						main_fired[event.target_id] = {"mount_ids": [], "rounds": 0}
					var group: Dictionary = main_fired[event.target_id]
					if mount_id not in group.mount_ids:
						group.mount_ids.append(mount_id)
					group.rounds += 1
					if not first_main.has(mount_id):
						first_main[mount_id] = [event.tick, event.weapon_id, event.target_id]
				elif event.data.mount_role == "dedicated_aa" and event.target_id == "air":
					last_air = event.tick
					last_aa_mount = event.weapon_id
			elif event.kind == "salvo":
				matching_salvos = matching_salvos and not salvos.has(event.target_id)
				salvos[event.target_id] = event.data
				signature.append([event.tick, event.target_id, event.data])
		matching_salvos = matching_salvos and main_fired == salvos
		simultaneous_main = simultaneous_main or (main_fired.has("task") and main_fired.has("aft"))
		if not mixed and last_surface > 0 and last_air > 0 and absi(last_surface - last_air) <= 60:
			mixed = true
			mixed_example = [last_surface, last_air, last_aa_mount]
	expect(simultaneous_main, "Bow and stern main mounts fire on their respective surface contacts in the same tick")
	expect(mixed, "Main and dedicated AA fire on different domains within one second")
	expect(matching_salvos, "Every salvo equals the complete actual same-tick main fire group by target, mount and rounds")
	expect(iowa.target_id == "task", "Mount allocation preserves the ship task target")
	_check_debits(iowa, before, fired)
	signature.append(_inventory(iowa))
	print("GUN01 mixed first main fire ", first_main, " [main_tick, aa_tick, aa_weapon] ", mixed_example, " debits ", fired)
	return signature

func _test_postures_and_permissions() -> void:
	var a: Dictionary = FIX.arena([
		FIX.spawn("iowa", "us", Vector3.ZERO, IOWA),
		FIX.spawn("task", "jp", Vector3(3800, 0, -700), YAMATO),
		FIX.spawn("other", "jp", Vector3(4100, 0, 1100), YAMATO),
		FIX.spawn("air", "jp", Vector3(1300, 370, -100)),
		FIX.spawn("friend", "us", Vector3(750, 370, 200)),
	])
	var world: SimulationWorld = a.world
	var dual_targets: Dictionary = {}
	for posture: String in ["", "balanced", "offensive", "conservative"]:
		world.reset()
		var iowa: UnitState = world.get_unit("iowa")
		_posture(world, posture)
		iowa.module_data.combat_intent = {"fire": true, "allow_aa": true}
		FIX.target(world, iowa.id, "task")
		world.step_ticks(1)
		var targets: Dictionary = iowa.module_data.combat_runtime.mount_targets
		dual_targets[posture] = targets.duplicate()
		expect("friend" not in targets.values(), "Only enemy contacts from the firing ship's faction view are eligible")
		expect(targets[BOW] == "task", "A viable primary task remains the main battery priority")
		var before: Dictionary = _inventory(iowa)
		var fired: Dictionary = {}
		var dual: Dictionary = {}
		for _interval: int in range(10):
			world.step_ticks(30)
			for event: BattleEvent in FIX.events(world, "fired"):
				if event.entity_id != iowa.id:
					continue
				var mount_id: String = event.weapon_id.get_slice("/", 1)
				fired[mount_id] = int(fired.get(mount_id, 0)) + 1
				if event.data.mount_role == "secondary":
					dual[event.target_id] = int(dual.get(event.target_id, 0)) + 1
		_check_debits(iowa, before, fired)
		if posture == "offensive":
			expect(dual.has("other") and not dual.has("air"), "Offensive dual mounts share available surface contacts")
		elif posture == "conservative":
			expect(dual.has("air") and not dual.has("other"), "Conservative dual mounts prioritize air cover and skip incidental surface contacts")
		else:
			expect(dual.has("air") and (dual.has("other") or dual.has("task")), "Balanced dual mounts use legal air and surface opportunities")
		print("GUN01 posture ", posture if not posture.is_empty() else "default", " dual fire ", dual)
	expect(dual_targets[""] == dual_targets.balanced, "Missing fleet posture exactly matches explicit balanced")
	expect(dual_targets.offensive[DUAL] != dual_targets.conservative[DUAL], "Fleet posture changes an otherwise identical dual mount assignment")

	world.reset()
	var switching: UnitState = world.get_unit("iowa")
	switching.module_data.combat_intent = {"fire": true, "allow_aa": true}
	FIX.target(world, switching.id, "task")
	_posture(world, "conservative")
	world.step_ticks(1)
	expect(switching.module_data.combat_runtime.mount_targets[DUAL] == "air", "Conservative posture opens with a defensive assignment")
	_posture(world, "offensive")
	world.step_ticks(1)
	expect(switching.module_data.combat_runtime.mount_targets[DUAL] in ["task", "other"], "New fleet posture supersedes the previous mount commitment")

	world.reset()
	var ship: UnitState = world.get_unit("iowa")
	_posture(world, "offensive")
	ship.module_data.combat_intent = {"fire": true, "allow_aa": true, "lock_target": true}
	FIX.target(world, ship.id, "task")
	var before_lock: Dictionary = _inventory(ship)
	world.step_ticks(120)
	expect(_targets_only(ship, ["task", ""]), "Target lock removes alternative surface and air tracks")
	for event: BattleEvent in FIX.events(world, "fired"):
		expect(event.target_id == "task", "Locked actual fire targets the exact designation")
	expect(_inventory(ship) != before_lock, "Target lock still permits actual fire at the designation")
	ship.module_data.combat_intent = {"fire": true, "allow_aa": false}
	world.step_ticks(30)
	expect(_targets_only(ship, ["task", "other", ""]), "Revoking task AA permission immediately clears all air assignments")
	for event: BattleEvent in FIX.events(world, "fired"):
		expect(event.target_id != "air", "AA permission blocks actual air-directed fire")
	ship.module_data.combat_intent = {"fire": false, "allow_aa": true}
	world.step_ticks(1)
	expect(_targets_only(ship, ["air", ""]) and ship.module_data.combat_runtime.mount_targets[DUAL] == "air", "AA-only intent clears previous surface assignments")
	var cease: BattleCommand = BattleCommand.new()
	cease.command_id = "hold:iowa"
	cease.faction_id = ship.faction_id
	cease.issuer_id = "test_executor"
	cease.entity_id = ship.id
	cease.kind = BattleCommand.CEASE_FIRE
	cease.payload = {"enabled": true}
	expect(world.submit_command(cease).accepted, "World accepts cease-fire via the normal command channel")
	var before_cease: Dictionary = _inventory(ship)
	world.drain_events()
	world.step_ticks(120)
	expect(_targets_only(ship, [""]) and ship.module_data.combat_runtime.mount_status[DUAL] == "hold_fire", "Cease-fire clears assignments and reports hold fire")
	expect(FIX.events(world, "fired").is_empty() and _inventory(ship) == before_cease, "Cease-fire prevents actual release and preserves inventory")
	cease.command_id = "resume:iowa"
	cease.payload = {"enabled": false}
	expect(world.submit_command(cease).accepted, "World accepts resuming fire")
	world.step_ticks(90)
	expect(not FIX.events(world, "fired").is_empty(), "Permitted AA resumes through the real executor after cease-fire")

func _test_single_target_and_reassignment() -> void:
	var a: Dictionary = FIX.arena([
		FIX.spawn("iowa", "us", Vector3.ZERO, IOWA),
		FIX.spawn("task", "jp", Vector3(4200, 0, -2000), YAMATO),
		FIX.spawn("fallback", "jp", Vector3(50000, 0, 0), YAMATO),
	])
	var world: SimulationWorld = a.world
	var iowa: UnitState = world.get_unit("iowa")
	var fallback: UnitState = world.get_unit("fallback")
	_posture(world, "offensive")
	iowa.module_data.combat_intent = {"fire": true}
	FIX.target(world, iowa.id, "task")
	world.step_ticks(1)
	var runtime: Dictionary = iowa.module_data.combat_runtime
	expect(_targets_only(iowa, ["task", ""]) and runtime.mount_targets[BOW] == "task" and runtime.mount_targets[STERN] == "task" and runtime.mount_targets[DUAL] == "task", "Multiple eligible mounts concentrate when presented with a single target")
	var initial: Dictionary = runtime.mount_targets.duplicate()
	fallback.position_m = Vector3(4100, 0, 2200)
	world.step_ticks(60)
	expect(runtime.mount_targets == initial, "New contact cannot break a feasible assignment during the commitment interval")
	world.step_ticks(90)
	expect("fallback" in runtime.mount_targets.values(), "Available secondary mounts share the newly observed contact after commitment")
	iowa.module_data.damage.parts["weapon:" + BOW] = 0.0
	iowa.weapons[DUAL].remaining_rounds.fill(0)
	world.step_ticks(1)
	expect(runtime.mount_targets[BOW].is_empty() and runtime.mount_status[BOW] == "disabled", "A damage-disabled mount loses assignment immediately")
	expect(runtime.mount_targets[DUAL].is_empty() and runtime.mount_status[DUAL] == "empty", "An exhausted mount loses assignment immediately")
	var task: UnitState = world.get_unit("task")
	task.position_m = Vector3(60000, 0, -2000)
	world.step_ticks(240)
	expect(CombatContacts.find(world, iowa.faction_id, task.id).is_empty(), "Moved target drops out of the firing faction's fresh view")
	expect(_targets_only(iowa, ["fallback", ""]) and "fallback" in runtime.mount_targets.values(), "Loss of fresh contact releases assignment and remaining mounts may reassign")
	fallback.position_m = Vector3(65000, 0, 2000)
	world.step_ticks(240)
	expect(_targets_only(iowa, [""]), "Loss of all fresh eligible contacts leaves every mount idle")

func _test_dual_purpose_main() -> void:
	var a: Dictionary = FIX.arena([
		FIX.spawn("fletcher", "us", Vector3.ZERO, "us_fletcher_dd445_1942_07_18"),
		FIX.spawn("air", "jp", Vector3(200, 240, -1100)),
	])
	var world: SimulationWorld = a.world
	var ship: UnitState = world.get_unit("fletcher")
	ship.module_data.combat_intent = {"fire": false, "allow_aa": true}
	var before: Dictionary = _inventory(ship)
	var fired: Dictionary = {}
	var main_fired: int = 0
	var main_salvo: int = 0
	for _interval: int in range(4):
		world.step_ticks(30)
		for event: BattleEvent in world.drain_events():
			if event.entity_id != ship.id:
				continue
			if event.kind == "fired":
				var mount_id: String = event.weapon_id.get_slice("/", 1)
				fired[mount_id] = int(fired.get(mount_id, 0)) + 1
				if event.target_id == "air" and event.data.mount_role == "main":
					main_fired += 1
			elif event.kind == "salvo" and event.target_id == "air":
				main_salvo += int(event.data.rounds)
	expect(ship.target_id.is_empty() and main_fired > 0 and main_fired == main_salvo, "Balanced Fletcher main mounts retain AA fire and salvos name the actual air contact without a ship task target")
	_check_debits(ship, before, fired)

func _posture(world: SimulationWorld, posture: String) -> void:
	if not posture.is_empty():
		world.shared_state["command_postures"] = {"us": {"fleet": {"posture": posture}}}

func _targets_only(unit: UnitState, allowed: Array) -> bool:
	return unit.module_data.combat_runtime.mount_targets.values().all(func(target: String) -> bool: return target in allowed)

func _inventory(unit: UnitState) -> Dictionary:
	var totals: Dictionary = {}
	for mount_id: String in unit.weapons:
		var weapon: WeaponState = unit.weapons[mount_id]
		var total: int = 0
		for count: int in weapon.remaining_rounds:
			total += count
		totals[mount_id] = total
	return totals

func _check_debits(unit: UnitState, before: Dictionary, fired: Dictionary) -> void:
	var after: Dictionary = _inventory(unit)
	var conserved: bool = true
	for mount_id: String in before:
		conserved = conserved and int(before[mount_id]) - int(after[mount_id]) == int(fired.get(mount_id, 0))
	expect(conserved, "Each mount's actual inventory debit equals its own fired event count")
