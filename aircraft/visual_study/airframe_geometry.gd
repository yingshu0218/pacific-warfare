extends Node3D
## Shared display-only mesh lofts, not flight or damage geometry.

const SECTION_POINTS: int = 24


func _paint(color: Color, vertex_color: bool = false) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.62
	paint.vertex_color_use_as_albedo = vertex_color
	return paint


func _body_rings(outline: Array[Vector4]) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	for contour: Vector4 in outline:
		var rim := PackedVector3Array()
		for index: int in range(SECTION_POINTS):
			var a: float = TAU * float(index) / SECTION_POINTS
			rim.append(Vector3(contour.z * cos(a), contour.y + contour.w * sin(a), contour.x))
		result.append(rim)
	return result


func _span_rings(outline: Array[Vector4], side: float, root_height: float, rise: float) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	for station: Vector4 in outline:
		var ring := PackedVector3Array()
		for index: int in range(SECTION_POINTS):
			var a: float = TAU * float(index) / SECTION_POINTS
			var chord: float = (1.0 + cos(a)) * 0.5
			var y: float = root_height + rise * station.x + station.w * sin(a) * (1.05 - 0.30 * chord)
			ring.append(Vector3(side * station.x, y, lerpf(station.y, station.z, chord)))
		result.append(ring)
	return result


func _mesh(label: String, shape: Mesh, paint: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = shape
	result.material_override = paint
	add_child(result)
	return result


func _loft(label: String, rings: Array[PackedVector3Array], paint: Material, close_ends: bool = true) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(rings.size() - 1):
		var a: PackedVector3Array = rings[row]
		var b: PackedVector3Array = rings[row + 1]
		var axis: Vector3 = (_center(a) + _center(b)) * 0.5
		for j: int in range(SECTION_POINTS):
			var k: int = (j + 1) % SECTION_POINTS
			_triangle(surface, a[j], b[j], b[k], (a[j] + b[j] + b[k]) / 3.0 - axis)
			_triangle(surface, a[j], b[k], a[k], (a[j] + b[k] + a[k]) / 3.0 - axis)
	if close_ends:
		for end: int in [0, rings.size() - 1]:
			var rim: PackedVector3Array = rings[end]
			var center: Vector3 = _center(rim)
			var other: Vector3 = _center(rings[1 if end == 0 else end - 1])
			for j: int in range(SECTION_POINTS):
				_triangle(surface, center, rim[j], rim[(j + 1) % SECTION_POINTS], center - other)
	surface.index()
	surface.generate_normals()
	return _mesh(label, surface.commit(), paint)


func _center(ring: PackedVector3Array) -> Vector3:
	var result := Vector3.ZERO
	for point: Vector3 in ring:
		result += point
	return result / float(ring.size())


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		_vertex(surface, a)
		_vertex(surface, c)
		_vertex(surface, b)
	else:
		_vertex(surface, a)
		_vertex(surface, b)
		_vertex(surface, c)


func _vertex(surface: SurfaceTool, point: Vector3) -> void:
	var u: float = smoothstep(-0.72, 0.23, point.y)
	surface.set_color(Color("f6f7f5").lerp(Color("7391b2"), u))
	surface.add_vertex(point)
