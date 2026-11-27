extends Node
const FINISH = preload("res://scripts/presentation/models/archive_finish.gd")
const OPT_OUT: StringName = &"pacific_archive_compare_original"

@export_enum("ship", "aircraft") var domain: String = "ship"

func _ready() -> void:
	_apply_finished_model.call_deferred()

func _apply_finished_model() -> void:
	if not is_inside_tree():
		return
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor.has_meta(OPT_OUT):
			return
		cursor = cursor.get_parent()
	var model: Node3D = get_parent() as Node3D
	if model != null:
		FINISH.apply(model, domain)
