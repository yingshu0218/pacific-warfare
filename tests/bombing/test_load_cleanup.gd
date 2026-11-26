extends SceneTree
const FIX: Script=preload("res://tests/bombing/fixture.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog: DefinitionCatalog=FIX.catalog()
	print("CATALOG_CLEANUP ",catalog!=null)
	catalog=null
	quit()
