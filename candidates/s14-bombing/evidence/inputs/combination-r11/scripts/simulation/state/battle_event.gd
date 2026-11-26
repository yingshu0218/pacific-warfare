class_name BattleEvent
extends RefCounted

var sequence: int = 0
var event_id: String = ""
var kind: String = ""
var tick: int = 0
var time_s: float = 0.0
var entity_id: String = ""
var weapon_id: String = ""
var target_id: String = ""
var position_m: Vector3 = Vector3.ZERO
var data: Dictionary = {}

func snapshot() -> Dictionary:
	return {"sequence": sequence, "event_id": event_id, "kind": kind, "tick": tick, "time_s": time_s,
		"entity_id": entity_id, "weapon_id": weapon_id, "target_id": target_id,
		"position_m": position_m, "data": data.duplicate(true)}

func copy() -> BattleEvent:
	var result: BattleEvent = BattleEvent.new()
	result.sequence = sequence
	result.event_id = event_id
	result.kind = kind
	result.tick = tick
	result.time_s = time_s
	result.entity_id = entity_id
	result.weapon_id = weapon_id
	result.target_id = target_id
	result.position_m = position_m
	result.data = data.duplicate(true)
	return result
