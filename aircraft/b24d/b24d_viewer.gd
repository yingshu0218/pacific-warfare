extends "res://aircraft/visual_study/airframe_viewer.gd"

func _set_view(view: int) -> void:
	super._set_view(view)
	_camera.keep_aspect=Camera3D.KEEP_WIDTH
	_camera.size=39.0
	_camera.position*=1.65
