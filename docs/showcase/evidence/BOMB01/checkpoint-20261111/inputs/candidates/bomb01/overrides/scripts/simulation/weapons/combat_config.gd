class_name CombatConfig
extends RefCounted

## Independent, explicit combat parameters; never mutate the S01 catalog.
var data: Dictionary = {}

func load_file(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return ["combat_config_missing:" + path]
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return ["combat_config_invalid_json:" + path]
	return load_data(parser.data)

func load_data(record: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	for key: String in ["contacts", "unit_profiles", "weapon_profiles", "ammo_profiles", "environment", "limits"]:
		if not record.get(key) is Dictionary:
			errors.append("combat_config_missing_dictionary:" + key)
	if not SimData.pure_data(record) or not _finite_data(record):
		errors.append("combat_config_requires_finite_pure_data")
	if errors.is_empty():
		if float(record.contacts.get("scan_interval_s", 0.0)) <= 0.0 or float(record.contacts.get("fresh_s", 0.0)) <= 0.0 or float(record.contacts.get("expiry_s", 0.0)) < float(record.contacts.get("fresh_s", 0.0)):
			errors.append("invalid_contact_intervals")
		if int(record.limits.get("projectiles", 0)) < 1:
			errors.append("invalid_projectile_limit")
		if int(record.limits.get("tracer_every", 0)) < 1:
			errors.append("invalid_tracer_interval")
		if not record.environment.get("friendly_fire") is bool or not SimData.finite_number(record.environment.get("sea_level_m")):
			errors.append("invalid_environment_rules")
		for id: String in record.unit_profiles:
			var p: Dictionary = record.unit_profiles[id]
			if float(p.get("structure", 0)) <= 0 or not p.get("boxes") is Array or p.boxes.is_empty():
				errors.append("invalid_unit_profile:" + id)
			for key: String in ["sensor_height_m", "visual_m", "radar_ship_m", "radar_aircraft_m", "part_durability", "weapon_durability"]:
				if not SimData.finite_number(p.get(key)) or float(p[key]) < 0.0:
					errors.append("invalid_unit_parameter:" + id + ":" + key)
			for key: String in ["part_durability", "weapon_durability"]:
				if float(p.get(key,0))<=0.0:errors.append("nonpositive_durability:"+id+":"+key)
			for box: Dictionary in p.get("boxes", []):
				if not _box_valid(box) or not box.get("part") is String:
					errors.append("invalid_unit_box:" + id)
			if p.has("damage_effects"):
				for key: String in ["fire_anchor_m","smoke_anchor_m"]:
					if not SimData.valid_vector(p.damage_effects.get(key)):
						errors.append("invalid_damage_effect_anchor:"+id+":"+key)
		for id: String in record.weapon_profiles:
			var p: Dictionary = record.weapon_profiles[id]
			if float(p.get("cycle_s", 1.0)) <= 0 or float(p.get("range_m", 0)) <= 0 or float(p.get("dispersion_rad", -1)) < 0:
				errors.append("invalid_weapon_profile:" + id)
			if not p.get("domains") is Array or p.domains.is_empty():
				errors.append("invalid_weapon_domains:" + id)
			else:
				for domain: Variant in p.domains:
					if domain not in ["ship", "aircraft", "ground"]:
						errors.append("invalid_weapon_domain:" + id)
			for key: String in ["initial_rounds_per_barrel", "train_rate_degps", "elevation_rate_degps", "aim_tolerance_rad", "fuze_error_s", "reload_track_interval_s"]:
				if p.has(key) and (not SimData.finite_number(p[key]) or float(p[key]) < 0.0):
					errors.append("invalid_weapon_parameter:" + id + ":" + key)
			if p.has("initial_rounds_per_barrel") and float(p.initial_rounds_per_barrel)!=floorf(float(p.initial_rounds_per_barrel)):
				errors.append("fractional_ammunition_inventory:"+id)
		for id: String in record.ammo_profiles:
			var p: Dictionary = record.ammo_profiles[id]
			if p.get("kind", "") not in ["ap", "he", "ball"] or float(p.get("damage_scale", 0)) <= 0 or float(p.get("burst_radius_m", -1)) < 0:
				errors.append("invalid_ammo_profile:" + id)
			for key: String in ["caliber_m", "projectile_mass_kg", "muzzle_speed_mps", "max_lifetime_s"]:
				if p.has(key) and (not SimData.finite_number(p[key]) or (float(p[key]) <= 0.0 and not (key == "muzzle_speed_mps" and p.get("release_mode", "gun") == "gravity_release" and float(p[key]) == 0.0))):
					errors.append("invalid_ammo_override:" + id + ":" + key)
		for box: Dictionary in record.environment.get("solids", []):
			if not _box_valid(box) or box.get("surface", "") not in ["ground", "building"]:
				errors.append("invalid_environment_box")
	if errors.is_empty():
		data = record.duplicate(true)
	return errors

func validate_world(world: SimulationWorld) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.is_empty():
		return ["combat_config_not_loaded"]
	for id: String in world.unit_ids():
		var unit: UnitDefinition = world.unit_definition(world.get_unit(id).definition_id)
		if not data.unit_profiles.has(unit.id):
			errors.append("missing_combat_unit:" + unit.id)
		for mount: MountSocket in unit.mounts:
			var gun: WeaponDefinition = world.weapon_definition(mount.weapon_definition_id)
			if not data.weapon_profiles.has(gun.id):
				errors.append("missing_combat_weapon:" + gun.id)
			var ammo_id: String = str(data.weapon_profiles.get(gun.id, {}).get("ammo_id", gun.ammo_id))
			if world.ammo_definition(ammo_id) == null or not data.ammo_profiles.has(ammo_id):
				errors.append("missing_combat_ammo:" + ammo_id)
			elif float(data.ammo_profiles[ammo_id].burst_radius_m) > 0.0 and effective_ammo(world, ammo_id).caliber_m < 0.075:
				errors.append("light_ammo_cannot_have_timed_flak:" + ammo_id)
	return errors

func unit_profile(id: String) -> Dictionary:
	return data.unit_profiles.get(id, {}).duplicate(true)

func weapon_profile(id: String) -> Dictionary:
	return data.weapon_profiles.get(id, {}).duplicate(true)

func ammo_profile(id: String) -> Dictionary:
	return data.ammo_profiles.get(id, {}).duplicate(true)

func effective_ammo(world: SimulationWorld, id: String) -> AmmoDefinition:
	var ammo: AmmoDefinition = world.ammo_definition(id)
	if ammo == null: return null
	var profile: Dictionary = data.ammo_profiles.get(id, {})
	for key: String in ["caliber_m", "projectile_mass_kg", "muzzle_speed_mps", "max_lifetime_s"]:
		if profile.has(key): ammo.set(key, float(profile[key]))
	return ammo

static func _box_valid(box: Dictionary) -> bool:
	for key: String in ["center_m", "half_extents_m"]:
		if not SimData.valid_vector(box.get(key)):
			return false
	for value: Variant in box.half_extents_m:
		if not value is float and not value is int:
			return false
		if float(value) <= 0:
			return false
	return true

static func _finite_data(value: Variant) -> bool:
	if value is float:
		return is_finite(value)
	if value is Dictionary:
		for key: Variant in value:
			if not _finite_data(value[key]):
				return false
	if value is Array:
		for item: Variant in value:
			if not _finite_data(item):
				return false
	return true
