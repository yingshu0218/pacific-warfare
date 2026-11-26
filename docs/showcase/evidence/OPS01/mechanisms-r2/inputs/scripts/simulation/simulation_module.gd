class_name SimulationModule
extends RefCounted

## Deterministic order: ascending priority, then module_id. No Node dependency.
var module_id: String = ""
var priority: int = 100

func reset(_world: RefCounted) -> void:
	pass

func fixed_update(_world: RefCounted, _delta_s: float) -> void:
	pass

func supported_order_types() -> PackedStringArray:
	return []

## One handler per (order type, unit domain); ship and aircraft may share types.
func order_domains() -> PackedStringArray:
	return ["ship", "aircraft"]

## Return {accepted: bool, reason: String}; receiving is not execution/completion.
func accept_order(_world: RefCounted, _order: BattleOrder, _unit_ids: Array[String]) -> Dictionary:
	return {"accepted": false, "reason": "unsupported_order"}

## Release only this subset on partial reassignment/loss/cancellation.
func on_order_units_released(_world: RefCounted, _order: BattleOrder, _unit_ids: Array[String], _reason: String) -> void:
	pass

## Implementers must release cached tasks when completed/cancelled/superseded.
func on_order_ended(_world: RefCounted, _order: BattleOrder) -> void:
	pass

func snapshot_state() -> Dictionary:
	return {}
