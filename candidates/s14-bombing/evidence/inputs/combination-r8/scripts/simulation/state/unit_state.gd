class_name UnitState
extends RefCounted

var id: String
var definition_id: String
var faction_id: String
var position_m: Vector3 = Vector3.ZERO
var velocity_mps: Vector3 = Vector3.ZERO
var rotation_rad: Vector3 = Vector3.ZERO
var active: bool = true
var target_id: String = ""
var cease_fire: bool = false
var active_order_id: String = ""
var task: Dictionary = {}
## Module-owned pure data; e.g. fuel, damage, formation role. No scene objects.
var module_data: Dictionary = {}
var weapons: Dictionary = {}

func world_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(rotation_rad), position_m)

func snapshot() -> Dictionary:
	var weapon_data: Dictionary = {}
	for mount_id: String in weapons:
		weapon_data[mount_id] = (weapons[mount_id] as WeaponState).snapshot()
	return {"id": id, "definition_id": definition_id, "faction_id": faction_id,
		"position_m": position_m, "velocity_mps": velocity_mps, "rotation_rad": rotation_rad,
		"active": active, "target_id": target_id, "cease_fire": cease_fire,
		"active_order_id": active_order_id, "task": task.duplicate(true),
		"module_data": module_data.duplicate(true), "weapons": weapon_data}
