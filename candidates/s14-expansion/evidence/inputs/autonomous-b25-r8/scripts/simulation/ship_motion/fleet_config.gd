class_name FleetConfig
extends RefCounted

const PATH: String = "res://data/fleet/showcase.json"
const KNOT_MPS: float = 1852.0 / 3600.0
var data: Dictionary = {}

func load_file(path: String = PATH) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return ["fleet_config_missing:" + path]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return ["fleet_config_not_object"]
	return load_data(parsed)

func load_data(record: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	for section: String in ["profiles", "navigation", "policy", "commanders"]:
		if not record.get(section) is Dictionary:
			errors.append("fleet_missing_section:" + section)
	if not errors.is_empty():
		return errors
	for id: String in record.profiles:
		var p: Variant = record.profiles[id]
		if not p is Dictionary:
			errors.append("fleet_invalid_profile:" + id)
			continue
		for key: String in ["historical_max_knots", "cruise_mps", "acceleration_mps2", "braking_mps2", "coast_drag_mps2", "turn_radius_m", "yaw_acceleration_degps2", "engagement_range_m", "flag_rank"]:
			if not _positive(p.get(key)):
				errors.append("fleet_invalid_profile:" + id + ":" + key)
		if _positive(p.get("cruise_mps")) and _positive(p.get("historical_max_knots")) and float(p.cruise_mps) > float(p.historical_max_knots) * KNOT_MPS:
			errors.append("fleet_cruise_exceeds_max:" + id)
	for key: String in ["clearance_m", "prediction_s", "station_spacing_m", "reform_distance_m", "search_timeout_s"]:
		if not _positive(record.navigation.get(key)):
			errors.append("fleet_invalid_navigation:" + key)
	for key: String in ["decision_period_s", "order_cooldown_s", "contact_hysteresis_s", "air_threat_radius_m", "ship_retreat_radius_m", "air_retreat_radius_m"]:
		if not _positive(record.policy.get(key)):
			errors.append("fleet_invalid_policy:" + key)
	var solids: Variant = record.navigation.get("solids")
	if not solids is Array:
		errors.append("fleet_invalid_solids")
	else:
		for solid: Variant in solids:
			if not solid is Dictionary or not SimData.valid_vector(solid.get("center_m")) or not SimData.valid_vector(solid.get("half_extents_m")):
				errors.append("fleet_invalid_coast_box")
			elif SimData.vec3(solid.half_extents_m).x <= 0.0 or SimData.vec3(solid.half_extents_m).z <= 0.0:
				errors.append("fleet_invalid_coast_size")
	for faction: String in record.commanders:
		var c: Variant = record.commanders[faction]
		if not SimData.valid_id(faction) or not c is Dictionary:
			errors.append("fleet_invalid_commander:" + faction)
			continue
		for key: String in ["patrol_center_m", "retreat_center_m", "air_retreat_center_m"]:
			if not SimData.valid_vector(c.get(key)):
				errors.append("fleet_invalid_destination:" + faction + ":" + key)
		if not _positive(c.get("patrol_radius_m")):
			errors.append("fleet_invalid_patrol_radius:" + faction)
	if errors.is_empty():
		data = record.duplicate(true)
	return errors

func supports(id: String) -> bool:
	return data.get("profiles", {}).has(id)

func profile(id: String) -> Dictionary:
	var result: Dictionary = data.get("profiles", {}).get(id, {}).duplicate(true)
	if not result.is_empty():
		result["max_mps"] = float(result.historical_max_knots) * KNOT_MPS
	return result

static func _positive(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) > 0.0
