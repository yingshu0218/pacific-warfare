class_name DefinitionCatalog
extends RefCounted

## Store private source dictionaries; getters return fresh typed definitions.
var _units: Dictionary = {}
var _weapons: Dictionary = {}
var _ammunition: Dictionary = {}

func load_files(unit_paths: Array[String], ammo_paths: Array[String], weapon_paths: Array[String] = []) -> PackedStringArray:
	var errors: PackedStringArray = []
	var units: Array = []
	var ammunition: Array = []
	var shared_weapons: Array = []
	for pair: Array in [[unit_paths, units], [ammo_paths, ammunition], [weapon_paths, shared_weapons]]:
		for path: String in pair[0]:
			if not FileAccess.file_exists(path):
				errors.append("missing_file:" + path)
				continue
			var parser: JSON = JSON.new()
			if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
				errors.append("invalid_json:" + path)
				continue
			pair[1].append(parser.data)
	if not errors.is_empty():
		return errors
	return load_data(units, ammunition, shared_weapons)

func load_data(unit_records: Array, ammo_records: Array, weapon_records: Array = []) -> PackedStringArray:
	var errors: PackedStringArray = []
	var units: Dictionary = {}
	var weapons: Dictionary = {}
	var ammunition: Dictionary = {}
	var ids: Dictionary = {}
	var all_weapons: Array = weapon_records.duplicate(true)
	for record: Variant in ammo_records:
		if not _record(record, "ammo", ids, errors):
			continue
		ammunition[record.id] = record.duplicate(true)
		for field: String in ["caliber_m", "projectile_mass_kg", "max_lifetime_s"]:
			_number(record, field, 0.000000001, 100000.0, errors)
		_number(record, "gravity_mps2", 0.0, 100.0, errors)
		var mode: String = str(record.get("release_mode", "gun"))
		if mode not in ["gun", "gravity_release"]: errors.append("invalid_release_mode:" + record.id)
		_number(record, "muzzle_speed_mps", 0.0 if mode == "gravity_release" else 0.000000001, 100000.0, errors)
		if mode == "gravity_release":
			if float(record.get("muzzle_speed_mps", -1)) != 0.0: errors.append("bomb_has_no_muzzle:" + record.id)
			for key: String in ["drag_per_m", "arming_s", "arming_distance_m", "impact_delay_s"]:
				_number(record, key, 0.0, 1000.0, errors)
	for record: Variant in unit_records:
		if not _record(record, "unit", ids, errors):
			continue
		units[record.id] = record.duplicate(true)
		for field: String in ["display_name", "country_id", "configuration_date", "model_scene"]:
			if not record.get(field) is String or record[field].is_empty():
				errors.append("invalid_string:" + record.id + ":" + field)
		if record.get("domain") not in ["ship", "aircraft", "ground"]:
			errors.append("invalid_domain:" + record.id)
		# Zero explicitly means unknown; never turn a manual's publication date into
		# an invented first-service date for a precisely selected ground variant.
		if record.get("domain") == "ground" and record.get("service_entry_year") == 0 and record.source.get("service_entry_year_status") == "unknown":
			pass
		else:
			_integer(record, "service_entry_year", 1900, 2100, errors)
		if not SimData.valid_vector(record.get("dimensions_m")):
			errors.append("invalid_dimensions:" + record.id)
		else:
			for value: Variant in record.dimensions_m:
				if float(value) <= 0.0:
					errors.append("invalid_dimensions:" + record.id)
		for field: String in ["mounts", "weapon_definitions", "historical_fixed_armament", "dedicated_aa_historical", "dedicated_aa_game"]:
			if not record.get(field) is Array:
				errors.append("missing_array:" + record.id + ":" + field)
		if not record.get("weapon_definitions") is Array:
			continue
		all_weapons.append_array(record.weapon_definitions)
	for weapon: Variant in all_weapons:
		if weapon is Dictionary and weapons.has(weapon.get("id", "")):
			if weapons[weapon.id] != weapon:
				errors.append("conflicting_weapon_definition:" + str(weapon.id))
			continue
		if not _record(weapon, "weapon", ids, errors):
			continue
		weapons[weapon.id] = weapon.duplicate(true)
		if not ammunition.has(weapon.get("ammo_id", "")):
			errors.append("missing_ammo:" + weapon.id)
		_integer(weapon, "barrel_count", 1, 16, errors)
		_integer(weapon, "initial_rounds_per_barrel", 0, 100000, errors)
		_number(weapon, "cycle_s", 0.000001, 3600.0, errors)
		_number(weapon, "train_rate_degps", 0.0, 10000.0, errors)
		_number(weapon, "elevation_rate_degps", 0.0, 10000.0, errors)
		for field: String in ["train_limits_deg", "elevation_limits_deg"]:
			var limits: Variant = weapon.get(field)
			if not limits is Array or limits.size() != 2:
				errors.append("invalid_limits:" + weapon.id + ":" + field)
			elif not SimData.finite_number(limits[0]) or not SimData.finite_number(limits[1]):
				errors.append("invalid_limits:" + weapon.id + ":" + field)
			elif float(limits[0]) > 0.0 or float(limits[1]) < 0.0 or float(limits[0]) < -360.0 or float(limits[1]) > 360.0:
				errors.append("invalid_limits:" + weapon.id + ":" + field)
	if not errors.is_empty():
		return errors
	for record: Dictionary in units.values():
		_validate_mounts(record, weapons, errors)
	if errors.is_empty():
		_units = units
		_weapons = weapons
		_ammunition = ammunition
	return errors

func _record(record: Variant, kind: String, ids: Dictionary, errors: PackedStringArray) -> bool:
	if not record is Dictionary or not SimData.pure_data(record):
		errors.append("invalid_record:" + kind)
		return false
	if not SimData.valid_id(record.get("id")):
		errors.append("invalid_id:" + kind)
		return false
	if ids.has(record.id):
		errors.append("duplicate_id:" + record.id)
		return false
	ids[record.id] = true
	if not record.get("source") is Dictionary or record.source.get("status", "") not in ["provisional", "verified"]:
		errors.append("missing_source_status:" + record.id)
	return true

func _number(record: Dictionary, field: String, minimum: float, maximum: float, errors: PackedStringArray) -> void:
	var value: Variant = record.get(field)
	if not SimData.finite_number(value) or float(value) < minimum or float(value) > maximum:
		errors.append("invalid_number:" + str(record.get("id", "scenario")) + ":" + field)

func _integer(record: Dictionary, field: String, minimum: int, maximum: int, errors: PackedStringArray) -> void:
	_number(record, field, float(minimum), float(maximum), errors)
	if SimData.finite_number(record.get(field)) and float(record[field]) != floorf(float(record[field])):
		errors.append("invalid_integer:" + str(record.get("id", "scenario")) + ":" + field)

func _validate_mounts(unit: Dictionary, weapons: Dictionary, errors: PackedStringArray) -> void:
	if not unit.get("mounts") is Array:
		return
	var ids: Dictionary = {}
	var fixed_counts: Dictionary = {}
	var aa_counts: Dictionary = {}
	for mount: Variant in unit.mounts:
		if not _record(mount, "mount", ids, errors):
			continue
		if not SimData.valid_id(mount.get("host_id")):
			errors.append("invalid_host:" + mount.id)
		var weapon_id: String = str(mount.get("weapon_definition_id", ""))
		if not weapons.has(weapon_id):
			errors.append("missing_weapon:" + mount.id)
			continue
		var weapon: Dictionary = weapons[weapon_id]
		if mount.get("role") not in ["main", "secondary", "aircraft_fixed", "dedicated_aa"]:
			errors.append("invalid_role:" + mount.id)
		var counts: Dictionary = aa_counts if mount.get("role") == "dedicated_aa" else fixed_counts
		counts[weapon_id] = int(counts.get(weapon_id, 0)) + 1
		for field: String in ["position_m", "elevation_pivot_m"]:
			if not SimData.valid_vector(mount.get(field)):
				errors.append("invalid_vector:" + mount.id + ":" + field)
		_number(mount, "base_yaw_deg", -360.0, 360.0, errors)
		if not mount.get("muzzle_positions_m") is Array or mount.muzzle_positions_m.is_empty():
			errors.append("missing_muzzle:" + mount.id)
		else:
			if mount.muzzle_positions_m.size() != int(weapon.get("barrel_count", -1)):
				errors.append("muzzle_count_mismatch:" + mount.id)
			for muzzle: Variant in mount.muzzle_positions_m:
				if not SimData.valid_vector(muzzle):
					errors.append("invalid_muzzle:" + mount.id)
	_validate_armament(unit.get("historical_fixed_armament"), fixed_counts, weapons, "fixed_armament", errors)
	_validate_armament(unit.get("dedicated_aa_game"), aa_counts, weapons, "aa_game", errors)
	if unit.get("dedicated_aa_historical") is Array:
		for item: Variant in unit.dedicated_aa_historical:
			if not item is Dictionary or not item.get("description") is String:
				errors.append("invalid_aa_historical:" + unit.id)
				continue
			_integer(item, "mount_count", 0, 1000, errors)
			_integer(item, "barrels_per_mount", 1, 16, errors)

func _validate_armament(records: Variant, actual: Dictionary, weapons: Dictionary, label: String, errors: PackedStringArray) -> void:
	if not records is Array:
		return
	var expected: Dictionary = {}
	for item: Variant in records:
		if not item is Dictionary:
			errors.append("invalid_" + label)
			continue
		var weapon_id: String = str(item.get("weapon_definition_id", ""))
		if not weapons.has(weapon_id) or expected.has(weapon_id):
			errors.append("invalid_armament_weapon:" + weapon_id)
			continue
		_integer(item, "mount_count", 1, 1000, errors)
		_integer(item, "barrels_per_mount", 1, 16, errors)
		if not SimData.finite_number(item.get("mount_count")) or not SimData.finite_number(item.get("barrels_per_mount")):
			continue
		if int(item.get("barrels_per_mount", -1)) != int(weapons[weapon_id].get("barrel_count", -2)):
			errors.append("armament_barrel_mismatch:" + weapon_id)
		expected[weapon_id] = int(item.get("mount_count", -1))
	if expected != actual:
		errors.append("armament_count_mismatch:" + label)

func validate_scenario(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not SimData.pure_data(data):
		return ["scenario_requires_pure_data"]
	if not SimData.valid_id(data.get("id")):
		errors.append("invalid_scenario_id")
	_integer(data, "seed", 0, 2147483647, errors)
	_integer(data, "tick_hz", 1, 240, errors)
	if not data.get("factions") is Array or data.factions.is_empty():
		return ["missing_factions"]
	var factions: Dictionary = {}
	for faction: Variant in data.factions:
		if not SimData.valid_id(faction) or factions.has(faction):
			errors.append("invalid_or_duplicate_faction")
		else:
			factions[faction] = true
	if not data.get("spawns") is Array:
		return ["missing_spawns"]
	var ids: Dictionary = {}
	for spawn: Variant in data.spawns:
		if not spawn is Dictionary or not SimData.valid_id(spawn.get("id")):
			errors.append("invalid_spawn")
			continue
		if ids.has(spawn.id):
			errors.append("duplicate_id:" + spawn.id)
		ids[spawn.id] = spawn.get("faction_id", "")
		if not _units.has(spawn.get("unit_definition_id", "")) or not factions.has(spawn.get("faction_id", "")):
			errors.append("invalid_spawn_reference:" + spawn.id)
		for field: String in ["position_m", "velocity_mps", "rotation_rad"]:
			if not SimData.valid_vector(spawn.get(field, [0.0, 0.0, 0.0])):
				errors.append("invalid_spawn_vector:" + spawn.id + ":" + field)
		if not spawn.get("module_data", {}) is Dictionary:
			errors.append("invalid_spawn_module_data:" + spawn.id)
	var groups: Variant = data.get("groups", [])
	if not groups is Array:
		return ["invalid_groups"]
	var group_ids: Dictionary = {}
	for group: Variant in groups:
		if not group is Dictionary or not SimData.valid_id(group.get("id")):
			errors.append("invalid_group")
			continue
		if ids.has(group.id) or group_ids.has(group.id):
			errors.append("duplicate_id:" + group.id)
		group_ids[group.id] = true
		if not factions.has(group.get("faction_id", "")) or not group.get("member_ids") is Array or group.member_ids.is_empty():
			errors.append("invalid_group_members:" + group.id)
			continue
		var seen: Dictionary = {}
		for member: Variant in group.member_ids:
			if not member is String or seen.has(member) or not ids.has(member) or ids.get(member) != group.faction_id:
				errors.append("invalid_group_member:" + group.id)
			else:
				seen[member] = true
	return errors

func unit(id: String) -> UnitDefinition:
	return UnitDefinition.from_data(_units[id]) if _units.has(id) else null

## Immutable scalar read. Domain checks do not need a reconstructed unit model.
func unit_domain(id: String) -> String:
	return str(_units[id].get("domain", "")) if _units.has(id) else ""

func weapon(id: String) -> WeaponDefinition:
	return WeaponDefinition.from_data(_weapons[id]) if _weapons.has(id) else null

func ammo(id: String) -> AmmoDefinition:
	return AmmoDefinition.from_data(_ammunition[id]) if _ammunition.has(id) else null

func copy() -> DefinitionCatalog:
	var result: DefinitionCatalog = DefinitionCatalog.new()
	result._units = _units.duplicate(true)
	result._weapons = _weapons.duplicate(true)
	result._ammunition = _ammunition.duplicate(true)
	return result
