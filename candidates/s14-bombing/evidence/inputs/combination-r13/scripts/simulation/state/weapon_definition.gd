class_name WeaponDefinition
extends RefCounted

var id: String
var ammo_id: String
var barrel_count: int
var cycle_s: float
var initial_rounds_per_barrel: int
var train_limits_rad: Vector2
var elevation_limits_rad: Vector2
var train_rate_radps: float
var elevation_rate_radps: float
var source: Dictionary

static func from_data(data: Dictionary) -> WeaponDefinition:
	var result: WeaponDefinition = WeaponDefinition.new()
	result.id = data.id
	result.ammo_id = data.ammo_id
	result.barrel_count = int(data.barrel_count)
	result.cycle_s = float(data.cycle_s)
	result.initial_rounds_per_barrel = int(data.initial_rounds_per_barrel)
	result.train_limits_rad = Vector2(deg_to_rad(float(data.train_limits_deg[0])), deg_to_rad(float(data.train_limits_deg[1])))
	result.elevation_limits_rad = Vector2(deg_to_rad(float(data.elevation_limits_deg[0])), deg_to_rad(float(data.elevation_limits_deg[1])))
	result.train_rate_radps = deg_to_rad(float(data.train_rate_degps))
	result.elevation_rate_radps = deg_to_rad(float(data.elevation_rate_degps))
	result.source = data.source.duplicate(true)
	return result
