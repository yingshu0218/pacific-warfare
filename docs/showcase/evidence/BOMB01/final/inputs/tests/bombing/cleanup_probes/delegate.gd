extends SceneTree
const LOADED: Script=preload("res://scripts/bombing/mission_delegate.gd")
func _initialize() -> void:
	print("CLEANUP_PROBE delegate",LOADED!=null)
	quit()
