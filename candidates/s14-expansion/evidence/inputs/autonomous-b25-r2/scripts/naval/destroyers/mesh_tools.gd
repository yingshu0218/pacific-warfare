extends RefCounted
## S03 procedural primitives. All dimensions are metres; source modules stay separate.

static func material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	return result

static func palette(usn: bool) -> Dictionary:
	var gray: Material = material(Color("626c72") if usn else Color("626968"))
	if usn:
		var camouflage: ShaderMaterial = ShaderMaterial.new()
		camouflage.shader = preload("res://scripts/naval/destroyers/measure12.gdshader")
		gray = camouflage
	return {"gray":gray, "deck":material(Color("414f60") if usn else Color("59493c")),
		"steel":material(Color("4c5559")), "dark":material(Color("252d32")),
		"glass":material(Color("263e47")), "red":material(Color("53332f")),
		"canvas":material(Color("8c9090")), "white":material(Color("bcc5c7"))}

static func mesh_node(parent: Node3D, node_name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var result: MeshInstance3D = MeshInstance3D.new()
	result.name = node_name
	result.mesh = mesh
	result.material_override = mat
	parent.add_child(result)
	return result

static func box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var result: MeshInstance3D = mesh_node(parent, node_name, mesh, mat)
	result.position = at
	return result

static func cylinder(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, mat: Material, sides: int = 20, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = sides
	var result: MeshInstance3D = mesh_node(parent, node_name, mesh, mat)
	result.position = at
	return result

static func rod(parent: Node3D, node_name: String, start: Vector3, end: Vector3, radius: float, mat: Material, sides: int = 8) -> MeshInstance3D:
	var result: MeshInstance3D = cylinder(parent, node_name, radius, start.distance_to(end), (start + end) * 0.5, mat, sides)
	result.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	return result

static func ellipse(width: float, length: float, sides: int = 28) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index: int in range(sides):
		var angle: float = TAU * float(index) / float(sides)
		points.append(Vector2(cos(angle) * width * 0.5, sin(angle) * length * 0.5))
	return points

static func rounded_front(width: float, length: float, steps: int = 12) -> Array[Vector2]:
	var points: Array[Vector2] = []
	# Semicircular forward wall and straight aft wall, viewed in X/Z.
	for index: int in range(steps + 1):
		var angle: float = PI + PI * float(index) / float(steps)
		points.append(Vector2(cos(angle) * width * 0.5, -length * 0.5 + width * 0.5 + sin(angle) * width * 0.5))
	points.append(Vector2(width * 0.5, length * 0.5))
	points.append(Vector2(-width * 0.5, length * 0.5))
	return points

static func beveled_rect(width: float, length: float) -> Array[Vector2]:
	var x: float = width * 0.5
	var z: float = length * 0.5
	var cut: float = minf(width * 0.16,length * 0.12)
	return [Vector2(-x + cut,-z),Vector2(x - cut,-z),Vector2(x,-z + cut),Vector2(x,z - cut),
		Vector2(x - cut,z),Vector2(-x + cut,z),Vector2(-x,z - cut),Vector2(-x,-z + cut)]

static func polygon(values: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for value: Array in values:
		points.append(Vector2(float(value[0]), float(value[1])))
	return points

static func prism(parent: Node3D, node_name: String, points: Array[Vector2], bottom: float, top: float, mat: Material, top_scale: float = 1.0, top_shift: Vector2 = Vector2.ZERO) -> MeshInstance3D:
	var rings: Array[PackedVector3Array] = []
	var lower: PackedVector3Array = []
	var upper: PackedVector3Array = []
	for point: Vector2 in points:
		lower.append(Vector3(point.x, bottom, point.y))
		upper.append(Vector3(point.x * top_scale + top_shift.x, top, point.y * top_scale + top_shift.y))
	rings.append(lower)
	rings.append(upper)
	return mesh_node(parent, node_name, loft(rings, true), mat)

static func loft(rings: Array[PackedVector3Array], caps: bool) -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var side_vertex_count: int = 0
	for ring_index: int in range(rings.size() - 1):
		for index: int in range(rings[ring_index].size()):
			var next: int = (index + 1) % rings[ring_index].size()
			vertices.append_array([rings[ring_index][index], rings[ring_index + 1][next], rings[ring_index + 1][index],
				rings[ring_index][index], rings[ring_index][next], rings[ring_index + 1][next]])
	side_vertex_count = vertices.size()
	if caps:
		for end: int in [0, rings.size() - 1]:
			var ring: PackedVector3Array = rings[end]
			var center: Vector3 = Vector3.ZERO
			for vertex: Vector3 in ring:
				center += vertex / float(ring.size())
			for index: int in range(ring.size()):
				var next: int = (index + 1) % ring.size()
				if end == 0:
					vertices.append_array([center, ring[next], ring[index]])
				else:
					vertices.append_array([center, ring[index], ring[next]])
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(vertices.size()):
		# Separate cap normals from curved side walls; no inflated pillow-like roofs.
		surface.set_smooth_group(0 if index < side_vertex_count else -1)
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	surface.index()
	return surface.commit()

static func vector(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func open_gun_slot(node: MeshInstance3D, slot: AABB) -> void:
	# Subtract only the exterior gun opening, preserving the source house outline.
	# A barrel at maximum elevation must pass through an opening, not a solid roof.
	var output: SurfaceTool = SurfaceTool.new()
	output.begin(Mesh.PRIMITIVE_TRIANGLES)
	output.set_smooth_group(-1)
	var faces: PackedVector3Array = node.mesh.get_faces()
	for index: int in range(0,faces.size(),3):
		var remainder: PackedVector3Array = [faces[index],faces[index+1],faces[index+2]]
		for axis: int in range(3):
			for lower: bool in [true,false]:
				if remainder.size() < 3:
					break
				var bound: float = slot.position[axis] if lower else slot.end[axis]
				var inside: PackedVector3Array = _clip_axis(remainder,axis,bound,lower)
				var outside: PackedVector3Array = _clip_axis(remainder,axis,bound,not lower)
				for triangle: int in range(1,outside.size()-1):
					output.add_vertex(outside[0])
					output.add_vertex(outside[triangle])
					output.add_vertex(outside[triangle+1])
				remainder = inside
	output.generate_normals()
	output.index()
	node.mesh = output.commit()

static func _clip_axis(points: PackedVector3Array, axis: int, bound: float, greater: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	for index: int in range(points.size()):
		var a: Vector3 = points[index]
		var b: Vector3 = points[(index+1)%points.size()]
		var a_inside: bool = a[axis] >= bound if greater else a[axis] <= bound
		var b_inside: bool = b[axis] >= bound if greater else b[axis] <= bound
		if a_inside:
			result.append(a)
		if a_inside != b_inside:
			var fraction: float = (bound-a[axis])/(b[axis]-a[axis])
			result.append(a.lerp(b,fraction))
	return result
