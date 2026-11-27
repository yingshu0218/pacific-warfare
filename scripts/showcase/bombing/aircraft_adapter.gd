extends Node3D

@export var definition_id: String = "us_b25j_1944_07"
var visual: BombingAircraftView
var sample: UnitState = UnitState.new()

func _ready() -> void:
	visual = BombingAircraftView.new(definition_id)
	add_child(visual)
	preload("res://scripts/showcase/bombing/live_model_batch.gd").apply(visual.model,"s14_bombing_live_"+definition_id)
	# The shared models default to an inspection (gear-down) pose. A flight scene
	# is also instantiated standalone by model viewers, without a world snapshot.
	visual.apply(sample)

func apply_state(state: Dictionary) -> void:
	position = state.position_m
	rotation = state.rotation_rad
	sample.position_m = Vector3.ZERO
	sample.rotation_rad = Vector3.ZERO
	sample.active = bool(state.active)
	sample.module_data = state.module_data
	visual.apply(sample)
	if definition_id == "us_b25j_1944_07" and state.get("weapons", {}).has("dorsal"):
		apply_weapon_state("dorsal", state.weapons.dorsal)

func bomb_template(index: int) -> Node3D:
	return visual.bomb_template(index)

func slot_position(index: int) -> Vector3: return visual.slot_position(index)

func mount_sockets() -> Array[Dictionary]: return []

func apply_weapon_state(id: String, state: Dictionary) -> bool:
	if definition_id != "us_b25j_1944_07" or id != "dorsal":
		return false
	visual.model.apply_visual_state({"guns": {id: {"yaw_rad": state.train_rad, "elevation_rad": state.elevation_rad}}})
	return true
