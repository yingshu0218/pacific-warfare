extends SceneTree
const LOADED: Script=preload("res://tests/bombing/fixture.gd")
func _initialize() -> void:
	print("CLEANUP_PROBE fixture",LOADED!=null)
	quit()
