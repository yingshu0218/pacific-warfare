extends SceneTree

const FIXTURE: Script = preload("res://tests/fixtures/simulation_fixture.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run_test")

func expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary

func run_test() -> void:
	var catalog: DefinitionCatalog = FIXTURE.catalog()
	var yamato: UnitDefinition = catalog.unit("jp_yamato_1944_04")
	var f6f: UnitDefinition = catalog.unit("us_f6f5_1944")
	expect(yamato.mounts.filter(func(s: MountSocket) -> bool: return s.role in ["main","secondary"]).size() == 5 and yamato.mounts.size() == 39 and f6f.mounts.size() == 6, "Actual first data must contain all fixed main/secondary and six aircraft guns")
	expect(yamato.dedicated_aa_historical.size() == 4 and yamato.dedicated_aa_game.size() == 4, "Historical AA baseline and explicit game AA are distinct")
	var mount: MountSocket = yamato.mounts[0]
	var muzzle: Transform3D = mount.local_muzzle_transform(1, 0.0, 0.0)
	expect(muzzle.origin.is_equal_approx(mount.position_m + Vector3(0.0, 4.4, -20.75)), "Main muzzle uses actual pivot, trunnion and barrel reach")
	expect((mount.local_muzzle_transform(1, PI, 0.0).basis * Vector3.FORWARD).is_equal_approx(Vector3.BACK), "Train transform rotates forward direction")
	expect((mount.local_muzzle_transform(1, 0.0, PI / 4.0).basis * Vector3.FORWARD).y > 0.7, "Positive elevation raises bore")
	yamato.mounts[0].position_m = Vector3.ONE
	yamato.source["note"] = "mutated"
	expect(catalog.unit(yamato.id).mounts[0].position_m != Vector3.ONE, "Typed definition getters cannot mutate canonical catalog")
	var raw_unit: Dictionary = read_json("res://data/units/jp_yamato_1944_04.json")
	var ammo: Array = [read_json("res://data/ammunition/jp_460mm_ap.json"), read_json("res://data/ammunition/jp_155mm_shell.json"), read_json("res://data/ammunition/jp_127mm_type89_shell.json"), read_json("res://data/ammunition/jp_25mm_type96_shell.json"), read_json("res://data/ammunition/jp_13mm_type93_ball.json")]
	var bad: Dictionary = raw_unit.duplicate(true)
	var checks: Array[Dictionary] = []
	checks.append({"units": [bad, bad], "ammo": ammo, "contains": "duplicate_id:"})
	bad = raw_unit.duplicate(true)
	bad.mounts.append(bad.mounts[0].duplicate(true))
	checks.append({"units": [bad], "ammo": ammo, "contains": "duplicate_id:"})
	bad = raw_unit.duplicate(true)
	bad.mounts[0].erase("muzzle_positions_m")
	checks.append({"units": [bad], "ammo": ammo, "contains": "missing_muzzle:"})
	bad = raw_unit.duplicate(true)
	bad.mounts[0].muzzle_positions_m.pop_back()
	checks.append({"units": [bad], "ammo": ammo, "contains": "muzzle_count_mismatch:"})
	bad = raw_unit.duplicate(true)
	bad.weapon_definitions[0].cycle_s = -1.0
	checks.append({"units": [bad], "ammo": ammo, "contains": "invalid_number:"})
	bad = raw_unit.duplicate(true)
	bad.weapon_definitions[0].barrel_count = 2.5
	checks.append({"units": [bad], "ammo": ammo, "contains": "invalid_integer:"})
	bad = raw_unit.duplicate(true)
	bad.weapon_definitions[0].barrel_count = {"invalid": "type"}
	checks.append({"units": [bad], "ammo": ammo, "contains": "invalid_number:"})
	bad = raw_unit.duplicate(true)
	bad.historical_fixed_armament[0].barrels_per_mount = {}
	checks.append({"units": [bad], "ammo": ammo, "contains": "invalid_number:"})
	bad = raw_unit.duplicate(true)
	bad.mounts[0].weapon_definition_id = "does_not_exist"
	checks.append({"units": [bad], "ammo": ammo, "contains": "missing_weapon:"})
	bad = raw_unit.duplicate(true)
	bad.mounts.pop_back()
	checks.append({"units": [bad], "ammo": ammo, "contains": "armament_count_mismatch:"})
	var bad_ammo: Array = ammo.duplicate(true)
	bad_ammo[0].muzzle_speed_mps = NAN
	checks.append({"units": [raw_unit], "ammo": bad_ammo, "contains": "invalid_record:"})
	for entry: Dictionary in checks:
		var before: String = catalog.unit("jp_yamato_1944_04").source.note
		var errors: PackedStringArray = catalog.load_data(entry.units, entry.ammo)
		expect(not errors.is_empty() and str(errors).contains(entry.contains), "Validator must reject " + entry.contains + " got " + str(errors))
		expect(catalog.unit("jp_yamato_1944_04").source.note == before, "Invalid reload is atomic and preserves valid catalog")
	var scenario: Dictionary = FIXTURE.scenario()
	expect(catalog.validate_scenario(scenario).is_empty(), "Scenario references valid")
	scenario.spawns.append(scenario.spawns[0].duplicate(true))
	expect(str(catalog.validate_scenario(scenario)).contains("duplicate_id:"), "Duplicate entity ID rejected")
	scenario = FIXTURE.scenario()
	scenario.tick_hz = 0
	scenario.groups[0].member_ids.append("yamato_01")
	scenario.spawns[0].position_m = [NAN, 0.0, 0.0]
	expect(catalog.validate_scenario(scenario).size() >= 1, "Invalid tick/faction/NaN data rejected")
	test_shared_weapon_definitions()
	print("PASS simulation definition/reference/muzzle validation" if failures == 0 else "FAIL simulation definitions: %d" % failures)
	quit(0 if failures == 0 else 1)

func test_shared_weapon_definitions() -> void:
	var first: Dictionary = read_json("res://data/units/us_f6f5_1944.json")
	var second: Dictionary = first.duplicate(true)
	second.id = "test_second_aircraft_type"
	var common_weapon: Dictionary = read_json("res://data/units/weapons/us_an_m2_127mm_single.json")
	first.weapon_definitions = []
	second.weapon_definitions = []
	var ammo: Array = [read_json("res://data/ammunition/us_127mm_m2_ball.json")]
	var catalog: DefinitionCatalog = DefinitionCatalog.new()
	expect(catalog.load_data([first, second], ammo, [common_weapon]).is_empty(), "Two different unit types can reference one canonical external weapon definition")
	var data: Dictionary = {"id": "shared_weapon_test", "seed": 1, "tick_hz": 60, "factions": ["us"], "spawns": [
		{"id": "one", "unit_definition_id": first.id, "faction_id": "us"},
		{"id": "two", "unit_definition_id": second.id, "faction_id": "us"}]}
	var world: SimulationWorld = SimulationWorld.new()
	expect(world.configure(catalog, data).is_empty(), "Shared canonical weapon is consumed by real world instances")
	var weapon_one: WeaponState = world.get_unit("one").weapons.wing_port_01
	var weapon_two: WeaponState = world.get_unit("two").weapons.wing_port_01
	weapon_one.remaining_rounds[0] = 0
	weapon_one.train_rad = 0.3
	expect(weapon_two.remaining_rounds[0] == 400 and weapon_two.train_rad == 0.0, "Cross-type shared definition does not share ammunition or pose")
	var same: Dictionary = common_weapon.duplicate(true)
	expect(catalog.load_data([first, second], ammo, [common_weapon, same]).is_empty(), "Identical legacy definitions deduplicate")
	same.cycle_s = common_weapon.cycle_s * 2.0
	expect(str(catalog.load_data([first, second], ammo, [common_weapon, same])).contains("conflicting_weapon_definition:"), "Conflicting canonical weapon values rejected")
