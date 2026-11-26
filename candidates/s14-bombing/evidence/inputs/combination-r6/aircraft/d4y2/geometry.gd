extends RefCounted
## AV02-only geometry. Does not depend on the shared AircraftBuilder.

static func group(parent: Node3D, id: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = id
	node.position = at
	parent.add_child(node)
	return node

static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = 0.72
	return result

static func part(parent: Node3D, id: String, mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var result: MeshInstance3D = MeshInstance3D.new()
	result.name = id
	result.mesh = mesh
	result.material_override = mat
	result.position = at
	parent.add_child(result)
	return result

static func box(parent: Node3D, id: String, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return part(parent, id, mesh, mat, at)

static func rod(parent: Node3D, id: String, a: Vector3, b: Vector3, radius: float, mat: Material, tip_radius: float = -1.0) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = a.distance_to(b)
	mesh.bottom_radius = radius
	mesh.top_radius = radius if tip_radius < 0.0 else tip_radius
	mesh.radial_segments = 12
	var result: MeshInstance3D = part(parent, id, mesh, mat, (a + b) * 0.5)
	var axis: Vector3 = (b - a).normalized()
	var tangent: Vector3 = Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var right: Vector3 = axis.cross(tangent).normalized()
	result.basis = Basis(right, axis, right.cross(axis))
	return result

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color = Color.WHITE) -> void:
	st.set_color(color)
	if (b - a).cross(c - a).dot(normal) > 0.0:
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
	else:
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color = Color.WHITE) -> void:
	triangle(st, a, b, c, normal, color)
	triangle(st, a, c, d, normal, color)

static func finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

static func sample(profile: Array, z: float) -> Array:
	for i: int in range(profile.size() - 1):
		var a: Array = profile[i]
		var b: Array = profile[i + 1]
		if z <= float(b[0]):
			var t: float = clampf((z - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return [z, lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t), lerpf(a[4], b[4], t)]
	return profile[-1].duplicate()

static func shell_point(profile: Array, z: float, angle: float) -> Vector3:
	var s: Array = sample(profile, z)
	return Vector3(s[2] * sin(angle), s[1] + cos(angle) * (s[3] if cos(angle) >= 0.0 else s[4]), z)

static func shell(profile: Array, start: float, end: float, top: Color, bottom: Color, bay: bool = false) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var zs: Array[float] = [start]
	for s: Array in profile:
		if float(s[0]) > start and float(s[0]) < end:
			zs.append(float(s[0]))
	zs.append(end)
	for j: int in range(zs.size() - 1):
		for i: int in range(48):
			var angle: float = float(i) * TAU / 48.0
			var next: float = float(i + 1) * TAU / 48.0
			if bay and zs[j] >= -0.90 and zs[j + 1] <= 1.45 and i >= 19 and i < 29:
				continue
			var normal: Vector3 = Vector3(sin((angle + next) * 0.5), cos((angle + next) * 0.5), 0.0)
			quad(st, shell_point(profile, zs[j], angle), shell_point(profile, zs[j + 1], angle),
				shell_point(profile, zs[j + 1], next), shell_point(profile, zs[j], next), normal, top if normal.y > -0.26 else bottom)
	st.set_smooth_group(-1)
	for z: float in [start, end]:
		var s: Array = sample(profile, z)
		for i: int in range(48):
			triangle(st, Vector3(0.0, s[1], z), shell_point(profile, z, TAU * float(i) / 48.0),
				shell_point(profile, z, TAU * float(i + 1) / 48.0), Vector3.FORWARD if z == start else Vector3.BACK, top)
	return finish(st)

static func airfoil_y(t: float, chord: float, upper: bool, thickness: float = 0.12) -> float:
	var h: float = 5.0 * thickness * chord * (0.2969 * sqrt(maxf(t, 0.0)) - 0.1260 * t - 0.3516 * t * t + 0.2843 * pow(t, 3) - 0.1036 * pow(t, 4))
	return (h if upper else -h) + 0.018 * chord * sin(PI * t)

static func wing_point(profile: Array, span: float, t: float, upper: bool) -> Vector3:
	# The same interpolation helper is used with [span, LE_z, chord, base_y, thickness].
	var s: Array = sample(profile, span)
	return Vector3(span, s[3] + airfoil_y(t, s[2], upper, s[4]), s[1] + s[2] * t)

static func wing(profile: Array, side: float, x0: float, x1: float, t0: float, t1: float, pivot: Vector3, top: Color, bottom: Color, yellow_edge: bool = false) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var steps: int = maxi(5, int((x1 - x0) * 9.0))
	for upper: bool in [true, false]:
		for i: int in range(steps):
			for j: int in range(16):
				var a: Vector3 = wing_point(profile, lerpf(x0, x1, float(i) / steps), lerpf(t0, t1, float(j) / 16.0), upper)
				var b: Vector3 = wing_point(profile, lerpf(x0, x1, float(i + 1) / steps), lerpf(t0, t1, float(j) / 16.0), upper)
				var c: Vector3 = wing_point(profile, lerpf(x0, x1, float(i + 1) / steps), lerpf(t0, t1, float(j + 1) / 16.0), upper)
				var d: Vector3 = wing_point(profile, lerpf(x0, x1, float(i) / steps), lerpf(t0, t1, float(j + 1) / 16.0), upper)
				a.x *= side; b.x *= side; c.x *= side; d.x *= side
				var paint: Color = top if upper else bottom
				var span: float = lerpf(x0, x1, (float(i) + 0.5) / steps)
				if yellow_edge and span >= 0.65 and span <= 3.45 and lerpf(t0, t1, (float(j) + 0.5) / 16.0) < 0.075:
					paint = Color("c9a13e")
				quad(st, a - pivot, b - pivot, c - pivot, d - pivot, Vector3.UP if upper else Vector3.DOWN, paint)
	# Close the span and chord cuts. No open tips when a damage module separates.
	st.set_smooth_group(-1)
	for span: float in [x0, x1]:
		for j: int in range(16):
			var a: Vector3 = wing_point(profile, span, lerpf(t0, t1, float(j) / 16.0), true)
			var b: Vector3 = wing_point(profile, span, lerpf(t0, t1, float(j + 1) / 16.0), true)
			var c: Vector3 = wing_point(profile, span, lerpf(t0, t1, float(j + 1) / 16.0), false)
			var d: Vector3 = wing_point(profile, span, lerpf(t0, t1, float(j) / 16.0), false)
			a.x *= side; b.x *= side; c.x *= side; d.x *= side
			quad(st, a - pivot, b - pivot, c - pivot, d - pivot, Vector3(side * (-1.0 if span == x0 else 1.0), 0.0, 0.0), top)
	for t: float in [t0, t1]:
		for i: int in range(steps):
			var a: Vector3 = wing_point(profile, lerpf(x0, x1, float(i) / steps), t, true)
			var b: Vector3 = wing_point(profile, lerpf(x0, x1, float(i + 1) / steps), t, true)
			var c: Vector3 = wing_point(profile, lerpf(x0, x1, float(i + 1) / steps), t, false)
			var d: Vector3 = wing_point(profile, lerpf(x0, x1, float(i) / steps), t, false)
			a.x *= side; b.x *= side; c.x *= side; d.x *= side
			quad(st, a - pivot, b - pivot, c - pivot, d - pivot, Vector3.FORWARD if t == t0 else Vector3.BACK, bottom)
	return finish(st)

static func plate(parent: Node3D, id: String, outline_yz: PackedVector2Array, thickness: float, mat: Material, pivot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline_yz)
	for side: float in [-1.0, 1.0]:
		for i: int in range(0, indices.size(), 3):
			var a: Vector2 = outline_yz[indices[i]]; var b: Vector2 = outline_yz[indices[i + 1]]; var c: Vector2 = outline_yz[indices[i + 2]]
			triangle(st, Vector3(side * thickness * 0.5, a.x, a.y) - pivot, Vector3(side * thickness * 0.5, b.x, b.y) - pivot,
				Vector3(side * thickness * 0.5, c.x, c.y) - pivot, Vector3(side, 0.0, 0.0))
	for i: int in range(outline_yz.size()):
		var a: Vector2 = outline_yz[i]; var b: Vector2 = outline_yz[(i + 1) % outline_yz.size()]
		quad(st, Vector3(-thickness * 0.5, a.x, a.y) - pivot, Vector3(thickness * 0.5, a.x, a.y) - pivot,
			Vector3(thickness * 0.5, b.x, b.y) - pivot, Vector3(-thickness * 0.5, b.x, b.y) - pivot, Vector3(0.0, b.y - a.y, a.x - b.x))
	return part(parent, id, finish(st), mat)

static func meshes(node: Node3D, visible_only: bool = true) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if visible_only and not node.visible:
		return result
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		if child is Node3D:
			result.append_array(meshes(child as Node3D, visible_only))
	return result
