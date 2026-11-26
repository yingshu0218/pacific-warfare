extends SceneTree
## Compare first-hit winding on both sides of the two intact flight shells.
## Horizontal rays through the sidewalls avoid the intentionally open belly bays.

const G4M1: PackedScene = preload("res://aircraft/g4m1/g4m1.tscn")
const D4Y2: PackedScene = preload("res://aircraft/d4y2/d4y2.tscn")
var checked: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g4m1: Node3D = G4M1.instantiate()
	var d4y2: Node3D = D4Y2.instantiate()
	root.add_child(g4m1)
	root.add_child(d4y2)
	g4m1.set_flight_configuration()
	d4y2.set_flight_configuration()
	_probe(g4m1.get_node("Center/Glazing"), [-9.70, -9.25, -8.92], [-0.21, 0.23])
	_probe(g4m1.get_node("Center/FixedSkin"), [-8.33, -7.41, -6.18, -4.65, -2.50, -1.61, 0.57, 2.41, 4.82], [-0.39, 0.41])
	_probe(g4m1.get_node("Tail/FixedSkin"), [6.15, 7.35, 8.29], [-0.20, 0.37])
	_probe(g4m1.get_node("Tail/TailGlazing"), [8.81, 9.16, 9.37], [-0.09, 0.21])
	_probe(d4y2.get_node("Engine/ContinuousSkin"), [-4.62, -4.23, -3.18, -2.37], [-0.24, 0.24])
	_probe(d4y2.get_node("Center/ContinuousSkin"), [-1.91, -1.28, -0.68, -0.03, 0.57, 1.12, 1.71, 2.53], [-0.22, 0.26])
	_probe(d4y2.get_node("Tail/ContinuousSkin"), [2.91, 3.31, 3.79, 4.17], [-0.07, 0.13])
	g4m1.free()
	d4y2.free()
	print("AV05 first-hit exterior-facing rays %d / %d" % [checked - failed, checked])
	quit(0 if failed == 0 else 1)

func _probe(host: Node3D, stations: Array, heights: Array) -> void:
	var meshes: Array[MeshInstance3D] = []
	if host is MeshInstance3D:
		meshes.append(host as MeshInstance3D)
	for child: Node in host.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	var faces: PackedVector3Array = PackedVector3Array()
	for instance: MeshInstance3D in meshes:
		if not instance.is_visible_in_tree():
			continue
		for point: Vector3 in instance.mesh.get_faces():
			faces.append(instance.global_transform * point)
	for station: float in stations:
		for height: float in heights:
			for side: float in [-1.0, 1.0]:
				checked += 1
				var direction: Vector3 = Vector3(-side, 0.0, 0.0)
				var origin: Vector3 = Vector3(side * 2.0, height, station)
				var nearest: float = INF
				var front_facing: bool = false
				for i: int in range(0, faces.size(), 3):
					var a: Vector3 = faces[i]
					var b: Vector3 = faces[i + 1]
					var c: Vector3 = faces[i + 2]
					var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, a, b, c)
					if hit != null:
						var distance: float = origin.distance_squared_to(hit)
						if distance < nearest:
							nearest = distance
							# A clockwise front face has its cross product towards the ray direction.
							front_facing = (b - a).cross(c - a).dot(direction) > 0.0
				if not front_facing:
					failed += 1
					push_error("Missing or culled first face at %s from %s" % [host.get_path(), origin])
