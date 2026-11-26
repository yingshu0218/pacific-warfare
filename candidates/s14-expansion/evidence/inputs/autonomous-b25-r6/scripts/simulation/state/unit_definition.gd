class_name UnitDefinition
extends RefCounted

var id: String
var display_name: String
var country_id: String
var domain: String
var service_entry_year: int
var configuration_date: String
var dimensions_m: Vector3
var model_scene: String
var mounts: Array[MountSocket] = []
var historical_fixed_armament: Array = []
var dedicated_aa_historical: Array = []
var dedicated_aa_game: Array = []
var source: Dictionary

static func from_data(data: Dictionary) -> UnitDefinition:
	var result: UnitDefinition = UnitDefinition.new()
	result.id = data.id
	result.display_name = data.display_name
	result.country_id = data.country_id
	result.domain = data.domain
	result.service_entry_year = int(data.service_entry_year)
	result.configuration_date = data.configuration_date
	result.dimensions_m = SimData.vec3(data.dimensions_m)
	result.model_scene = data.model_scene
	for mount: Dictionary in data.mounts:
		result.mounts.append(MountSocket.from_data(mount))
	result.historical_fixed_armament = data.historical_fixed_armament.duplicate(true)
	result.dedicated_aa_historical = data.dedicated_aa_historical.duplicate(true)
	result.dedicated_aa_game = data.dedicated_aa_game.duplicate(true)
	result.source = data.source.duplicate(true)
	return result
