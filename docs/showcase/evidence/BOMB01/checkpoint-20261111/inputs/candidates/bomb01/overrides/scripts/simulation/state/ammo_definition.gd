class_name AmmoDefinition
extends RefCounted

var id: String
var caliber_m: float
var projectile_mass_kg: float
var muzzle_speed_mps: float
var gravity_mps2: float
var max_lifetime_s: float
var source: Dictionary
## gun retains strictly positive muzzle speed; gravity_release has no muzzle.
var release_mode: String = "gun"
var drag_per_m: float = 0.0
var arming_s: float = 0.0
var arming_distance_m: float = 0.0
var impact_delay_s: float = 0.0

static func from_data(data: Dictionary) -> AmmoDefinition:
	var result: AmmoDefinition = AmmoDefinition.new()
	result.id = data.id
	result.caliber_m = float(data.caliber_m)
	result.projectile_mass_kg = float(data.projectile_mass_kg)
	result.muzzle_speed_mps = float(data.muzzle_speed_mps)
	result.gravity_mps2 = float(data.gravity_mps2)
	result.max_lifetime_s = float(data.max_lifetime_s)
	result.source = data.source.duplicate(true)
	result.release_mode = str(data.get("release_mode", "gun"))
	result.drag_per_m = float(data.get("drag_per_m", 0.0))
	result.arming_s = float(data.get("arming_s", 0.0))
	result.arming_distance_m = float(data.get("arming_distance_m", 0.0))
	result.impact_delay_s = float(data.get("impact_delay_s", 0.0))
	return result
