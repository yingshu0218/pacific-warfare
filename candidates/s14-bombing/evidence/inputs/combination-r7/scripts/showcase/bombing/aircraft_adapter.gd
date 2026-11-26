extends Node3D

@export var definition_id: String = "us_b25j_1944_07"
var visual: BombingAircraftView
var sample: UnitState = UnitState.new()

func _ready() -> void:
	visual = BombingAircraftView.new(definition_id)
	add_child(visual)
	StaticModelBatch.apply(visual.model,"s14_bombing_"+definition_id)

func apply_state(state: Dictionary) -> void:
	position = state.position_m
	rotation = state.rotation_rad
	sample.position_m = Vector3.ZERO
	sample.rotation_rad = Vector3.ZERO
	sample.active = bool(state.active)
	sample.module_data = state.module_data
	visual.apply(sample)

func bomb_template(index: int) -> Node3D:
	return visual.bomb_template(index)

func slot_position(index: int) -> Vector3: return visual.slot_position(index)

func mount_sockets() -> Array[Dictionary]: return []
func apply_weapon_state(_id: String, _state: Dictionary) -> bool: return false
