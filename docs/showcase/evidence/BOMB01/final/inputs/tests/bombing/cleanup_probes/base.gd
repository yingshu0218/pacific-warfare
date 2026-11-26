extends SceneTree
const LOADED: Script=preload("res://tests/fixtures/combat_fixture.gd")
func _initialize() -> void:
	print("CLEANUP_PROBE base",LOADED!=null)
	quit()
