extends RefCounted

static func material(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

static func add_box(parent: Node3D, part_name: String, center: Vector3, size: Vector3, mat: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = part_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = mat
	mesh_instance.position = center
	mesh_instance.rotation = rotation
	parent.add_child(mesh_instance)
	return mesh_instance

static func add_box_batch(parent: Node3D, part_name: String, records: Array[Dictionary], mat: Material) -> MeshInstance3D:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_indices: Array[Array] = [
		[0, 2, 1, 0, 3, 2], [4, 5, 6, 4, 6, 7],
		[0, 1, 5, 0, 5, 4], [1, 2, 6, 1, 6, 5],
		[2, 3, 7, 2, 7, 6], [3, 0, 4, 3, 4, 7]
	]
	for record: Dictionary in records:
		var center: Vector3 = record.get("center", Vector3.ZERO)
		var size: Vector3 = record.get("size", Vector3.ONE)
		var rotation: Vector3 = record.get("rotation", Vector3.ZERO)
		var basis: Basis = Basis.from_euler(rotation)
		var half: Vector3 = size * 0.5
		var points: Array[Vector3] = [
			center + basis * Vector3(-half.x, -half.y, -half.z),
			center + basis * Vector3(half.x, -half.y, -half.z),
			center + basis * Vector3(half.x, half.y, -half.z),
			center + basis * Vector3(-half.x, half.y, -half.z),
			center + basis * Vector3(-half.x, -half.y, half.z),
			center + basis * Vector3(half.x, -half.y, half.z),
			center + basis * Vector3(half.x, half.y, half.z),
			center + basis * Vector3(-half.x, half.y, half.z)
		]
		for face: Array in face_indices:
			for point_index: int in face:
				surface_tool.add_vertex(points[point_index])
	surface_tool.generate_normals()
	var mesh: ArrayMesh = surface_tool.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, mat)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	parent.add_child(instance)
	return instance

static func add_beam_batch(parent: Node3D, part_name: String, segments: Array[Dictionary], mat: Material, radial_segments: int = 6) -> MeshInstance3D:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count: int = maxi(3, radial_segments)
	for segment: Dictionary in segments:
		var from_point: Vector3 = segment.get("from", Vector3.ZERO)
		var to_point: Vector3 = segment.get("to", Vector3.ZERO)
		var direction: Vector3 = to_point - from_point
		if direction.length_squared() < 0.0001:
			continue
		var radius: float = float(segment.get("diameter", 0.08)) * 0.5
		var axis: Vector3 = direction.normalized()
		var right: Vector3 = Vector3.UP.cross(axis)
		if right.length_squared() < 0.0001:
			right = Vector3.RIGHT.cross(axis)
		right = right.normalized()
		var forward: Vector3 = axis.cross(right).normalized()
		for radial_index: int in range(segment_count):
			var angle_a: float = TAU * float(radial_index) / float(segment_count)
			var angle_b: float = TAU * float(radial_index + 1) / float(segment_count)
			var radial_a: Vector3 = right * cos(angle_a) + forward * sin(angle_a)
			var radial_b: Vector3 = right * cos(angle_b) + forward * sin(angle_b)
			var lower_a: Vector3 = from_point + radial_a * radius
			var lower_b: Vector3 = from_point + radial_b * radius
			var upper_a: Vector3 = to_point + radial_a * radius
			var upper_b: Vector3 = to_point + radial_b * radius
			for vertex: Vector3 in [lower_a, lower_b, upper_b, lower_a, upper_b, upper_a]:
				surface_tool.add_vertex(vertex)
	var mesh: ArrayMesh = surface_tool.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, mat)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	parent.add_child(instance)
	return instance

static func add_cylinder(parent: Node3D, part_name: String, center: Vector3, radius: float, height: float, mat: Material, sides: int = 16, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = part_name
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.rings = 0
	cylinder.top_radius = radius if top_radius < 0.0 else top_radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = sides
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = mat
	mesh_instance.position = center
	parent.add_child(mesh_instance)
	return mesh_instance

static func add_beam(parent: Node3D, part_name: String, from_point: Vector3, to_point: Vector3, diameter: float, mat: Material, sides: int = 8, end_diameter: float = -1.0) -> MeshInstance3D:
	var direction: Vector3 = to_point - from_point
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = part_name
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.rings = 0
	cylinder.top_radius = (diameter if end_diameter < 0.0 else end_diameter) * 0.5
	cylinder.bottom_radius = diameter * 0.5
	cylinder.height = direction.length()
	cylinder.radial_segments = sides
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = mat
	mesh_instance.position = (from_point + to_point) * 0.5
	var y_axis: Vector3 = direction.normalized()
	var x_axis: Vector3 = Vector3.UP.cross(y_axis)
	if x_axis.length_squared() < 0.0001:
		x_axis = Vector3.RIGHT.cross(y_axis)
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	mesh_instance.basis = Basis(x_axis, y_axis, z_axis)
	parent.add_child(mesh_instance)
	return mesh_instance

static func add_prism(parent: Node3D, part_name: String, outline: PackedVector2Array, bottom_y: float, top_y: float, mat: Material, omit_side_segment: int = -1) -> MeshInstance3D:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var count: int = outline.size()
	for point: Vector2 in outline:
		vertices.append(Vector3(point.x, bottom_y, point.y))
	for point: Vector2 in outline:
		vertices.append(Vector3(point.x, top_y, point.y))
	for index: int in range(1, count - 1):
		indices.append(0)
		indices.append(index)
		indices.append(index + 1)
		indices.append(count)
		indices.append(count + index + 1)
		indices.append(count + index)
	for index: int in range(count):
		if index == omit_side_segment:
			continue
		var next_index: int = (index + 1) % count
		indices.append(index)
		indices.append(count + next_index)
		indices.append(next_index)
		indices.append(index)
		indices.append(count + index)
		indices.append(count + next_index)
	var array_mesh: ArrayMesh = _indexed_triangle_mesh(vertices, indices, mat)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = array_mesh
	parent.add_child(instance)
	return instance

static func add_annulus(parent: Node3D, part_name: String, center: Vector3, outer_radius: float, inner_radius: float, depth: float, mat: Material, segments: int = 24, rotation_x: float = 0.0) -> MeshInstance3D:
	if inner_radius <= 0.0 or outer_radius <= inner_radius or depth <= 0.0 or segments < 8:
		push_error("Annulus %s requires positive depth, a larger outer radius, and at least eight segments" % part_name)
		return null
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_depth: float = depth * 0.5
	for segment: int in range(segments):
		var angle_a: float = TAU * float(segment) / float(segments)
		var angle_b: float = TAU * float(segment + 1) / float(segments)
		var outer_a_front: Vector3 = Vector3(cos(angle_a) * outer_radius, sin(angle_a) * outer_radius, -half_depth)
		var outer_b_front: Vector3 = Vector3(cos(angle_b) * outer_radius, sin(angle_b) * outer_radius, -half_depth)
		var inner_a_front: Vector3 = Vector3(cos(angle_a) * inner_radius, sin(angle_a) * inner_radius, -half_depth)
		var inner_b_front: Vector3 = Vector3(cos(angle_b) * inner_radius, sin(angle_b) * inner_radius, -half_depth)
		var outer_a_back: Vector3 = Vector3(outer_a_front.x, outer_a_front.y, half_depth)
		var outer_b_back: Vector3 = Vector3(outer_b_front.x, outer_b_front.y, half_depth)
		var inner_a_back: Vector3 = Vector3(inner_a_front.x, inner_a_front.y, half_depth)
		var inner_b_back: Vector3 = Vector3(inner_b_front.x, inner_b_front.y, half_depth)
		for vertex: Vector3 in [outer_a_front, outer_b_front, inner_b_front, outer_a_front, inner_b_front, inner_a_front]:
			surface.add_vertex(vertex)
		for vertex: Vector3 in [outer_a_back, inner_b_back, outer_b_back, outer_a_back, inner_a_back, inner_b_back]:
			surface.add_vertex(vertex)
		for vertex: Vector3 in [outer_a_front, outer_a_back, outer_b_back, outer_a_front, outer_b_back, outer_b_front]:
			surface.add_vertex(vertex)
		for vertex: Vector3 in [inner_a_front, inner_b_back, inner_a_back, inner_a_front, inner_b_front, inner_b_back]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = surface.commit()
	instance.material_override = mat
	instance.position = center
	instance.rotation.x = rotation_x
	parent.add_child(instance)
	return instance

static func add_tapered_prism(parent: Node3D, part_name: String, bottom_outline: PackedVector2Array, top_outline: PackedVector2Array, bottom_y: float, top_y: float, mat: Material, omit_side_segment: int = -1) -> MeshInstance3D:
	if bottom_outline.size() < 3 or bottom_outline.size() != top_outline.size():
		push_error("Tapered prism %s requires matching outlines with at least three points" % part_name)
		return null
	var count: int = bottom_outline.size()
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for point: Vector2 in bottom_outline:
		vertices.append(Vector3(point.x, bottom_y, point.y))
	for point: Vector2 in top_outline:
		vertices.append(Vector3(point.x, top_y, point.y))
	for index: int in range(1, count - 1):
		indices.append(0)
		indices.append(index)
		indices.append(index + 1)
		indices.append(count)
		indices.append(count + index + 1)
		indices.append(count + index)
	for index: int in range(count):
		if index == omit_side_segment:
			continue
		var next_index: int = (index + 1) % count
		indices.append(index)
		indices.append(count + next_index)
		indices.append(next_index)
		indices.append(index)
		indices.append(count + index)
		indices.append(count + next_index)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = _indexed_triangle_mesh(vertices, indices, mat)
	parent.add_child(instance)
	return instance

static func chamfered_outline(width: float, length: float, chamfer: float = 1.5, center_z: float = 0.0) -> PackedVector2Array:
	var half_width: float = width * 0.5
	var half_length: float = length * 0.5
	var bevel: float = minf(chamfer, minf(half_width * 0.7, half_length * 0.7))
	var result: PackedVector2Array = PackedVector2Array()
	result.append(Vector2(-half_width + bevel, center_z - half_length))
	result.append(Vector2(half_width - bevel, center_z - half_length))
	result.append(Vector2(half_width, center_z - half_length + bevel))
	result.append(Vector2(half_width, center_z + half_length - bevel))
	result.append(Vector2(half_width - bevel, center_z + half_length))
	result.append(Vector2(-half_width + bevel, center_z + half_length))
	result.append(Vector2(-half_width, center_z + half_length - bevel))
	result.append(Vector2(-half_width, center_z - half_length + bevel))
	return result

static func add_lofted_hull(parent: Node3D, stations: Array[Dictionary], mat: Material) -> MeshInstance3D:
	var ring: Array[Vector3] = []
	for station: Dictionary in stations:
		var z_value: float = float(station.z)
		var breadth: float = float(station.breadth)
		var deck_y: float = float(station.deck_y)
		var keel_y: float = float(station.keel_y)
		ring.append(Vector3(0.0, keel_y, z_value))
		ring.append(Vector3(breadth * 0.34, keel_y + 0.65, z_value))
		ring.append(Vector3(breadth * 0.69, -8.25, z_value))
		ring.append(Vector3(breadth * 0.9, -5.0, z_value))
		ring.append(Vector3(breadth, deck_y - 1.1, z_value))
		ring.append(Vector3(breadth, deck_y, z_value))
		ring.append(Vector3(-breadth, deck_y, z_value))
		ring.append(Vector3(-breadth, deck_y - 1.1, z_value))
		ring.append(Vector3(-breadth * 0.9, -5.0, z_value))
		ring.append(Vector3(-breadth * 0.69, -8.25, z_value))
		ring.append(Vector3(-breadth * 0.34, keel_y + 0.65, z_value))
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var ring_count: int = 11
	for point: Vector3 in ring:
		var stem_influence: float = pow(clampf((-point.z-80.0)/55.2,0.0,1.0),3.0)
		var deck_y: float = float(stations[0].deck_y)
		var below_deck: float = maxf(0.0,deck_y-point.y)
		point.z += minf(7.2,below_deck*0.72)*stem_influence
		vertices.append(point)
	for section_index: int in range(stations.size() - 1):
		for ring_index: int in range(ring_count):
			var next_ring: int = (ring_index + 1) % ring_count
			var a: int = section_index * ring_count + ring_index
			var b: int = section_index * ring_count + next_ring
			var c: int = (section_index + 1) * ring_count + next_ring
			var d: int = (section_index + 1) * ring_count + ring_index
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(a)
			indices.append(c)
			indices.append(d)
	for end_section: int in [0, stations.size() - 1]:
		var center_index: int = vertices.size()
		var center_station: Dictionary = stations[end_section]
		var center: Vector3 = Vector3.ZERO
		for ring_index: int in range(ring_count):
			center += vertices[end_section*ring_count+ring_index] / float(ring_count)
		vertices.append(center)
		for ring_index: int in range(ring_count):
			var next_ring: int = (ring_index + 1) % ring_count
			var offset: int = end_section * ring_count
			if end_section == 0:
				indices.append(center_index)
				indices.append(offset + ring_index)
				indices.append(offset + next_ring)
			else:
				indices.append(center_index)
				indices.append(offset + next_ring)
				indices.append(offset + ring_index)
	var array_mesh: ArrayMesh = _indexed_triangle_mesh(vertices, indices, mat)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Hull"
	mesh_instance.mesh = array_mesh
	parent.add_child(mesh_instance)
	return mesh_instance

static func add_weather_deck(parent: Node3D, stations: Array[Dictionary], mat: Material) -> MeshInstance3D:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var across_count: int = 6
	for station: Dictionary in stations:
		var breadth: float = float(station.breadth) - 0.1
		for across_index: int in range(across_count + 1):
			var x_value: float = lerpf(-breadth, breadth, float(across_index) / across_count)
			vertices.append(Vector3(x_value, float(station.deck_y) + 0.015, float(station.z)))
	for section_index: int in range(stations.size() - 1):
		for across_index: int in range(across_count):
			var a: int = section_index * (across_count + 1) + across_index
			var b: int = (section_index + 1) * (across_count + 1) + across_index
			var c: int = b + 1
			var d: int = a + 1
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(a)
			indices.append(c)
			indices.append(d)
	var array_mesh: ArrayMesh = _indexed_triangle_mesh(vertices, indices, mat)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MainWeatherDeck"
	mesh_instance.mesh = array_mesh
	parent.add_child(mesh_instance)
	return mesh_instance

static func _indexed_triangle_mesh(vertices: PackedVector3Array, indices: PackedInt32Array, mat: Material) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex_index: int in indices:
		surface_tool.add_vertex(vertices[vertex_index])
	surface_tool.generate_normals()
	var result: ArrayMesh = surface_tool.commit()
	if result.get_surface_count() > 0:
		result.surface_set_material(0, mat)
	return result

