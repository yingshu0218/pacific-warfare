extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		printerr("FAIL: ", description)
		_failures += 1


func _run() -> void:
	var demo := (load("res://scenes/woleai_1944.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	var field := demo.get("airfield_geometry") as Node3D
	var land := field.get_node("Falalap · coral island terrain") as MeshInstance3D
	var vertices: PackedVector3Array = land.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var runway := _bounds(field, "Runway · hard-packed coral")
	var taxiway := _bounds(field, "Taxiway surface")
	_expect(Vector2(runway.size.x, runway.size.z).is_equal_approx(Vector2(58, 1000)), "runway footprint")
	_expect(Vector2(taxiway.size.x, taxiway.size.z).is_equal_approx(Vector2(16, 625)), "taxiway footprint")
	for suffix: String in ["north", "south"]:
		var spur := _bounds(field, "Taxiway connector %s surface" % suffix)
		_expect(is_equal_approx(spur.position.x, taxiway.end.x), "taxiway seam " + suffix)
		_expect(is_equal_approx(spur.end.x, runway.position.x), "runway seam " + suffix)
		_expect(is_equal_approx(spur.end.y, 3.72) and is_equal_approx(taxiway.end.y, runway.end.y), "common surface grade " + suffix)
		var shoulder := _bounds(field, "Taxiway connector " + suffix)
		var cleared := _bounds(field, "Taxiway · 625 m cleared length envelope", "Taxiway · 625 m cleared width envelope")
		_expect(is_equal_approx(shoulder.position.x, cleared.end.x), "no coplanar shoulder overlap " + suffix)
	var apron := _bounds(field, "Aircraft dispersal apron · central hardstand")
	var apron_spur := _bounds(field, "Hangar apron connector")
	_expect(is_equal_approx(apron_spur.end.x, apron.position.x) and is_equal_approx(apron_spur.end.y, apron.end.y), "flush non-overlapping apron seam")
	for plate_name: String in ["North dispersal stand", "South dispersal stand", "Hangar apron connector"]:
		var plate := _bounds(field, plate_name)
		var max_ground: float = -INF
		var max_interior: float = -INF
		# A triangle touching a footprint can only draw from its adjacent grid vertices.
		for point: Vector3 in vertices:
			if point.x >= plate.position.x - 12.5 and point.x <= plate.end.x + 12.5 and point.z >= plate.position.z - 13.0 and point.z <= plate.end.z + 13.0:
				max_ground = maxf(max_ground, point.y)
			if point.x >= plate.position.x and point.x <= plate.end.x and point.z >= plate.position.z and point.z <= plate.end.z:
				max_interior = maxf(max_interior, point.y)
		print("SURFACE | %s | top %.3f m | highest inside %.3f m | highest nearby %.3f m" % [plate_name, plate.end.y, max_interior, max_ground])
		_expect(is_finite(max_ground) and plate.end.y - max_ground >= 0.07, "terrain does not intersect " + plate_name)
	var camera := demo.get("camera") as Camera3D
	for mode: String in ["overview", "runway"]:
		demo.call("_set_camera_mode", mode)
		var forward: Vector3 = -camera.global_basis.z
		var closest_depth_steps: float = INF
		for x: float in [-29.0, 29.0]:
			for z: float in [-500.0, 500.0]:
				var deck: Vector3 = Vector3(x, runway.end.y, z)
				var below: Vector3 = deck - Vector3.UP * 0.14
				var depth: float = (deck - camera.global_position).dot(forward)
				var below_depth: float = (below - camera.global_position).dot(forward)
				if depth <= camera.near:
					continue
				var steps: float = absf(1.0 / depth - 1.0 / below_depth) * camera.far * camera.near / (camera.far - camera.near) * 16777215.0
				closest_depth_steps = minf(steps, closest_depth_steps)
		print("CAMERA | %s | near %.3f m | minimum 24-bit depth separation %.2f steps" % [mode, camera.near, closest_depth_steps])
		_expect(is_finite(closest_depth_steps) and closest_depth_steps >= 2.0, "default broad view resolves paved surface depth: " + mode)
	for mode: String in ["aircraft", "antiaircraft", "machinegun", "comparison"]:
		demo.call("_set_camera_mode", mode)
		_expect(is_equal_approx(camera.near, 0.12), "close-up clipping plane unchanged: " + mode)
	demo.call("_set_camera_mode", "overview")
	demo.set("_camera_target", Vector3.ZERO)
	demo.set("_camera_distance", 4.0)
	demo.call("_update_camera", 0.0, true)
	_expect(is_equal_approx(camera.near, 0.12), "overview zoom near ground restores close plane")
	if _failures:
		quit(1)
		return
	demo.call("_set_camera_mode", "overview")
	var sortie := demo.get("sortie") as AirfieldSortieController
	sortie.playback_rate = 10.0
	sortie.sortie_completed.connect(func() -> void:
		_expect(sortie.phase == "返场停机" and absf(sortie.elapsed_seconds - 500.0) < 1.0, "existing route finishes unchanged")
		print("SORTIE | %s | %.3f s" % [sortie.phase, sortie.elapsed_seconds])
		quit(int(_failures > 0)))
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("FAIL: timed out waiting for independent demo to finish")
		quit(1))


func _bounds(field: Node3D, node_name: String, previous_name: String = "") -> AABB:
	var mesh := field.get_node_or_null(NodePath(node_name)) as MeshInstance3D
	if mesh == null and not previous_name.is_empty():
		mesh = field.get_node_or_null(NodePath(previous_name)) as MeshInstance3D
	assert(mesh != null)
	return mesh.transform * mesh.mesh.get_aabb()
