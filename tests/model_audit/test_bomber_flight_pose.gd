extends SceneTree
const IDS: PackedStringArray = [
	"jp_d4y2_model12_1944_10",
	"jp_g4m1_1942_07",
	"us_b25j_1944_07",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id: String in IDS:
		var flight: PackedScene = load("res://scenes/units/aircraft/" + id + ".tscn") as PackedScene
		var model: Node3D = flight.instantiate() as Node3D
		root.add_child(model)
		var aircraft: Node3D = model.get("visual").model
		var groups: Variant = aircraft.get("gear_axes")
		var gears: Array = groups.values() if groups is Dictionary else groups
		if gears.is_empty():
			_fail(id + ": gear nodes missing in flight model")
			return
		for gear: Node3D in gears:
			if gear.is_visible_in_tree():
				_fail(id + ": gear visible before any simulation snapshot")
				return
		model.free()
		var short: String = "d4y2" if "d4y2" in id else "g4m1" if "g4m1" in id else "b25j"
		var inspection: PackedScene = load("res://aircraft/%s/%s.tscn" % [short, short]) as PackedScene
		var parked: Node3D = inspection.instantiate() as Node3D
		root.add_child(parked)
		groups = parked.get("gear_axes")
		gears = groups.values() if groups is Dictionary else groups
		if gears.is_empty():
			_fail(id + ": gear nodes missing in parked model")
			return
		for gear: Node3D in gears:
			if not gear.is_visible_in_tree():
				_fail(id + ": existing parked model no longer shows gear")
				return
		parked.free()
	print("PASS initial flight pose for D4Y2, G4M1 and B-25J; parked geometry unchanged")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
