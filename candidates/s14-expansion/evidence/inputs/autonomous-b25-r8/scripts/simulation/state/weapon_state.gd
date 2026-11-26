class_name WeaponState
extends RefCounted

var id: String
var mount_id: String
var definition_id: String
var train_rad: float = 0.0
var elevation_rad: float = 0.0
var remaining_rounds: Array[int] = []
var cycle_remaining_s: float = 0.0
var enabled: bool = true

static func create(unit_id: String, socket: MountSocket, definition: WeaponDefinition) -> WeaponState:
	var result: WeaponState = WeaponState.new()
	result.id = unit_id + "/" + socket.id
	result.mount_id = socket.id
	result.definition_id = definition.id
	for index: int in range(definition.barrel_count):
		result.remaining_rounds.append(definition.initial_rounds_per_barrel)
	return result

func snapshot() -> Dictionary:
	return {"id": id, "mount_id": mount_id, "definition_id": definition_id,
		"train_rad": train_rad, "elevation_rad": elevation_rad,
		"remaining_rounds": remaining_rounds.duplicate(), "cycle_remaining_s": cycle_remaining_s, "enabled": enabled}
