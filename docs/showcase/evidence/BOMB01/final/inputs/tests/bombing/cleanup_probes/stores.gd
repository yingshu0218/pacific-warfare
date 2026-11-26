extends SceneTree
const LOADED: Script=preload("res://scripts/bombing/stores.gd")
func _initialize() -> void:
	print("CLEANUP_PROBE stores",LOADED!=null)
	quit()
