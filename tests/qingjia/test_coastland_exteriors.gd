extends SceneTree
## Small asset gate. Run from the project root with --headless --script.

const SCENES: Array[PackedScene] = [
	preload("res://scenes/qingjia/qj03_props/open_plinth.tscn"),
	preload("res://scenes/qingjia/qj03_props/shielded_housing.tscn"),
	preload("res://scenes/qingjia/qj03_props/cliff_facade.tscn"),
]

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	for i: int in range(SCENES.size()):
		var prop: Node3D = SCENES[i].instantiate()
		root.add_child(prop)
		var bounds: AABB
		var parts: int = 0
		for child: Node in prop.get_children():
			if not child is MeshInstance3D:
				push_error("%s contains a non-exterior node: %s" % [prop.name, child])
				quit(1)
				return
			var mesh: MeshInstance3D = child
			if mesh.mesh == null or mesh.mesh.get_faces().size() < 3:
				push_error("%s has empty mesh" % prop.name)
				quit(1)
				return
			bounds = mesh.get_aabb() if parts == 0 else bounds.merge(mesh.get_aabb())
			parts += 1
		if parts < 7 or parts > 15 or bounds.position.y < -0.15 or bounds.position.y > 0.15 or bounds.size.length() < 3:
			push_error("%s has bad parts or ground origin: %d, %s" % [prop.name, parts, bounds])
			quit(1)
			return
		print("%s: %d matte exterior batches, bounds %s" % [prop.name, parts, bounds])
		prop.free()
	print("3 scenic scene checks passed.")
	quit(0)
