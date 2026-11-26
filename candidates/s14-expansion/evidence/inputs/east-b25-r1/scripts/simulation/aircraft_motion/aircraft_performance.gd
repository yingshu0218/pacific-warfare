class_name AircraftPerformance
extends RefCounted

const PATH: String = "res://data/aircraft/performance.json"
var records: Dictionary = {}

func _init() -> void:
	records = JSON.parse_string(FileAccess.get_file_as_string(PATH))

func profile(id: String) -> Dictionary:
	return records.get(id, {}).duplicate(true)

func supports(id: String) -> bool:
	return records.has(id) and records[id] is Dictionary
