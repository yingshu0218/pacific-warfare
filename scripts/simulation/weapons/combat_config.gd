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
			if p.has("main_weapon_durability") and (not SimData.finite_number(p.main_weapon_durability) or float(p.main_weapon_durability)<=0.0):
				errors.append("invalid_main_weapon_durability:"+id)
			if p.has("ship_damage"):
				if not p.ship_damage is Dictionary:
					errors.append("invalid_ship_damage:"+id)
				else:
					for key: String in ["above_water_hull_transfer","superstructure_transfer"]:
						if not SimData.finite_number(p.ship_damage.get(key)) or float(p.ship_damage[key])<0.0 or float(p.ship_damage[key])>1.0:
							errors.append("invalid_ship_transfer:"+id+":"+key)
					for key: String in ["weather_deck_m","vital_space_top_m"]:
						if not SimData.finite_number(p.ship_damage.get(key)) or float(p.ship_damage[key])<=0.0:
							errors.append("invalid_ship_damage_height:"+id+":"+key)
			for box: Dictionary in p.get("boxes", []):
				if not _box_valid(box) or not box.get("part") is String:
					errors.append("invalid_unit_box:" + id)
			if p.has("mount_limits"):
				if not p.mount_limits is Dictionary:
					errors.append("invalid_mount_limits:" + id)
				else:
					for mount_id: Variant in p.mount_limits:
						if not mount_id is String or not _mount_limit_valid(p.mount_limits[mount_id]):
							errors.append("invalid_mount_limit:" + id + ":" + str(mount_id))
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
				if p.has(key) and (not SimData.finite_number(p[key]) or float(p[key]) <= 0.0):
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
		var overrides: Dictionary = data.unit_profiles.get(unit.id, {}).get("mount_limits", {})
		for mount_id: String in overrides:
			if not unit.mounts.any(func(socket: MountSocket) -> bool: return socket.id == mount_id):
				errors.append("unknown_mount_limit:" + unit.id + ":" + mount_id)
		for mount: MountSocket in unit.mounts:
			var gun: WeaponDefinition = world.weapon_definition(mount.weapon_definition_id)
			if not data.weapon_profiles.has(gun.id):
				errors.append("missing_combat_weapon:" + gun.id)
			var envelope := mount_envelope(unit.id, mount.id, gun)
			if envelope.train_rad.x > envelope.train_rad.y or envelope.pitch_rad.x > envelope.pitch_rad.y:
				errors.append("empty_mount_envelope:" + unit.id + ":" + mount.id)
			var ammo_id: String = str(data.weapon_profiles.get(gun.id, {}).get("ammo_id", gun.ammo_id))
			if world.ammo_definition(ammo_id) == null or not data.ammo_profiles.has(ammo_id):
				errors.append("missing_combat_ammo:" + ammo_id)
			elif float(data.ammo_profiles[ammo_id].burst_radius_m) > 0.0 and effective_ammo(world, ammo_id).caliber_m < 0.075:
				errors.append("light_ammo_cannot_have_timed_flak:" + ammo_id)
	return errors

## Optional per-station constraints only narrow the existing fictional weapon profile.
func mount_envelope(unit_id: String, mount_id: String, gun: WeaponDefinition) -> Dictionary:
	var profile: Dictionary = data.weapon_profiles.get(gun.id, {})
	var limit: Dictionary = data.unit_profiles.get(unit_id, {}).get("mount_limits", {}).get(mount_id, {})
	var train := gun.train_limits_rad
	var pitch := gun.elevation_limits_rad
	if limit.has("train_window_deg"):
		train.x = maxf(train.x, deg_to_rad(float(limit.train_window_deg[0])))
		train.y = minf(train.y, deg_to_rad(float(limit.train_window_deg[1])))
	if limit.has("minimum_elevation_deg"):
		pitch.x = maxf(pitch.x, deg_to_rad(float(limit.minimum_elevation_deg)))
	if limit.has("maximum_elevation_deg"):
		pitch.y = minf(pitch.y, deg_to_rad(float(limit.maximum_elevation_deg)))
	return {"range_m": float(profile.get("range_m", 0.0))*float(limit.get("range_scale", 1.0)), "train_rad": train, "pitch_rad": pitch}

static func _mount_limit_valid(entry: Variant) -> bool:
	if not entry is Dictionary:
		return false
	if entry.has("range_scale") and (not SimData.finite_number(entry.range_scale) or float(entry.range_scale) <= 0.0 or float(entry.range_scale) > 1.0):
		return false
	if entry.has("train_window_deg"):
		var window: Variant = entry.train_window_deg
		if not window is Array or window.size() != 2:
			return false
		if not SimData.finite_number(window[0]) or not SimData.finite_number(window[1]) or float(window[0]) < -360.0 or float(window[1]) > 360.0 or float(window[0]) > float(window[1]):
			return false
	for key: String in ["minimum_elevation_deg", "maximum_elevation_deg"]:
		if entry.has(key) and (not SimData.finite_number(entry[key]) or absf(float(entry[key])) > 90.0):
			return false
	return float(entry.get("minimum_elevation_deg", -90.0)) <= float(entry.get("maximum_elevation_deg", 90.0))

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
