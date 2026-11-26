class_name AmmoDefinition
extends RefCounted

var id: String
var caliber_m: float
var projectile_mass_kg: float
var muzzle_speed_mps: float
var gravity_mps2: float
var max_lifetime_s: float
var source: Dictionary

static func from_data(data: Dictionary) -> AmmoDefinition:
	var result: AmmoDefinition = AmmoDefinition.new()
	result.id = data.id
	result.caliber_m = float(data.caliber_m)
	result.projectile_mass_kg = float(data.projectile_mass_kg)
	result.muzzle_speed_mps = float(data.muzzle_speed_mps)
	result.gravity_mps2 = float(data.gravity_mps2)
	result.max_lifetime_s = float(data.max_lifetime_s)
	result.source = data.source.duplicate(true)
	return result
