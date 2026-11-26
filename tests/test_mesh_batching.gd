extends SceneTree

const BUILDER: Script = preload("res://scripts/ship_geometry.gd")
var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var builder: Node3D = BUILDER.new() as Node3D
	root.add_child(builder)
	var box: MeshInstance3D = builder.box(Vector3(-20,2,4),Vector3(2,2,2),builder.steel) as MeshInstance3D
	box.rotation = Vector3(0.12,0.31,-0.08)
	# Exercise the actual remaining non-indexed loft helper, rather than the removed
	# whole-ship armored_housing API. Both sources deliberately share one material.
	var sections: Array[Array] = [builder.bridge_section(7.0,-5.0,5.0,0.0),builder.bridge_section(5.0,-4.0,4.0,5.0)]
	var custom: MeshInstance3D = builder.section_loft(sections,Vector3(0,2.5,0)) as MeshInstance3D
	custom.position = Vector3(20,1,-3)
	custom.rotation = Vector3(-0.15,-0.42,0.10)
	custom.material_override = builder.steel
	var box_arrays: Array = box.mesh.surface_get_arrays(0)
	var custom_arrays: Array = custom.mesh.surface_get_arrays(0)
	_check(box_arrays[Mesh.ARRAY_INDEX] != null and not (box_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty(),"BoxMesh fixture must actually be indexed")
	_check(custom_arrays[Mesh.ARRAY_INDEX] == null or (custom_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty(),"Procedural loft fixture must actually be non-indexed")
	var expected_vertices: PackedVector3Array = []
	for part: MeshInstance3D in [box,custom]:
		for point: Vector3 in part.mesh.get_faces():
			expected_vertices.append(part.transform*point)
	var expected_counts: Dictionary = _vertex_counts(expected_vertices)
	var expected_bounds: AABB = AABB(expected_vertices[0],Vector3.ZERO)
	for point: Vector3 in expected_vertices:
		expected_bounds = expected_bounds.expand(point)
	builder.batch_static_geometry(builder)
	_check(builder.get_child_count()==1,"Same-material indexed/non-indexed meshes must become one batch")
	if builder.get_child_count()==1:
		var merged: MeshInstance3D = builder.get_child(0) as MeshInstance3D
		var actual_vertices: PackedVector3Array = merged.mesh.get_faces()
		_check(actual_vertices.size()==expected_vertices.size(),"Batch must retain every rendered triangle of both indexed and non-indexed inputs")
		_check(_vertex_counts(actual_vertices)==expected_counts,"Every transformed source vertex and its multiplicity must survive batching")
		var bounds: AABB = merged.mesh.get_aabb()
		_check(bounds.position.is_equal_approx(expected_bounds.position) and bounds.end.is_equal_approx(expected_bounds.end),"Merged bounds must retain both translated and rotated input objects")
		_check(bounds.position.x < -20.0 and bounds.end.x > 27.0,"Both separated objects must remain in the merged mesh")
		_check(merged.transform.is_equal_approx(Transform3D.IDENTITY),"Input transforms must be baked once into batch-local geometry")
	builder.free()
	if failures.is_empty():
		print("PASS: mixed indexed BoxMesh/non-indexed loft batching preserves all triangles, vertex multiplicities and translated/rotated transforms")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

func _vertex_counts(points: PackedVector3Array) -> Dictionary:
	var counts: Dictionary = {}
	for point: Vector3 in points:
		# 0.1 mm quantization covers SurfaceTool float32 round-trips only.
		var key: Vector3i = Vector3i(roundi(point.x*10000.0),roundi(point.y*10000.0),roundi(point.z*10000.0))
		counts[key] = int(counts.get(key,0))+1
	return counts
