extends SceneTree
## Check the standalone scene, not the literal source of the label.

const VIEWER: PackedScene = preload("res://scenes/iowa_viewer.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewer: Node3D = VIEWER.instantiate() as Node3D
	root.add_child(viewer)
	var ship: IowaShip = viewer.get("ship") as IowaShip
	var label: Label = viewer.get_node_or_null("InspectionHUD/InfoPanel/ModelStatus") as Label
	if ship == null or label == null:
		push_error("Standalone Iowa ship or HUD did not load")
		quit(1)
		return
	var counts: Dictionary = ship.get_weapon_counts()
	var phrases: PackedStringArray = [
		"Digital model mounts:",
		"%d × 16-inch turrets" % counts["main_16in"],
		"%d × twin 5-inch mounts" % counts["secondary_5in"],
		"%d × quad 40 mm" % counts["bofors_40mm"],
		"%d × single 20 mm" % counts["oerlikon_20mm"],
		"Independent weapon mounts: %d" % ship.get_weapon_mounts().size()
	]
	for phrase: String in phrases:
		if not label.text.contains(phrase):
			push_error("Missing live Iowa readout: " + phrase)
			quit(1)
			return
	print("IOWA_VIEWER_HUD passed")
	quit(0)
