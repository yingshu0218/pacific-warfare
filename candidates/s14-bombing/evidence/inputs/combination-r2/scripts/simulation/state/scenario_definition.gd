class_name ScenarioDefinition
extends RefCounted

var id: String
var seed_value: int
var tick_hz: int
var factions: Array[String] = []
var spawns: Array = []
var groups: Array = []

static func from_data(data: Dictionary) -> ScenarioDefinition:
	var result: ScenarioDefinition = ScenarioDefinition.new()
	result.id = data.id
	result.seed_value = int(data.seed)
	result.tick_hz = int(data.tick_hz)
	result.factions.assign(data.factions)
	result.spawns = data.spawns.duplicate(true)
	result.groups = data.get("groups", []).duplicate(true)
	return result

func to_data() -> Dictionary:
	return {"id": id, "seed": seed_value, "tick_hz": tick_hz, "factions": factions.duplicate(),
		"spawns": spawns.duplicate(true), "groups": groups.duplicate(true)}
