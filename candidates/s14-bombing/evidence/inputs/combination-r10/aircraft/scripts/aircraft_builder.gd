extends Node3D
class_name PacificAircraftBuilder

const PI_F: float = PI
const RADIAL_SEGMENTS: int = 36
const LOFT_SEGMENTS: int = 96
const AIRFOIL_STEPS: int = 28

@export var flight_simplified: bool = false

var spec: Dictionary = {}
var materials: Dictionary = {}
var wing_profile: Array[Vector4] = []
var wing_thickness_profile: Array[Vector2] = []
var tail_profile: Array[Vector4] = []
var dorsal_profile: Array[Vector2] = []
var fuselage_stations: Array[Vector4] = []
var propeller: Node3D
var landing_gear: Node3D
var control_surfaces: Node3D
var animated_surfaces: Array[Node3D] = []
var damage_parts: Dictionary = {}


func _ready() -> void:
	_configure()
	_create_materials()
	_prepare_damage_groups()
	_build_model()
	_finish_damage_groups()


func _prepare_damage_groups() -> void:
	if not flight_simplified or str(spec.get("id", "")) not in ["f6f5", "a6m5_52ko"]:
		return
	for part_id: String in ["wing_left", "wing_right", "tail"]:
		damage_parts[part_id] = _new_group(self, "Damage_" + part_id)


func _damage_parent_id(part_id: String) -> Node3D:
	return damage_parts.get(part_id, self) as Node3D


func _wing_damage_parent(side: float) -> Node3D:
	return _damage_parent_id("wing_left" if side < 0.0 else "wing_right")


func _finish_damage_groups() -> void:
	var hellcat: bool = str(spec.get("id", "")) == "f6f5"
	for part_id: String in damage_parts:
		var group: Node3D = damage_parts[part_id]
		var anchor: Vector3 = Vector3(0, 2.60 if hellcat else 1.90, 4.1 if hellcat else 3.7)
		if part_id != "tail":
			anchor = Vector3((-1.0 if part_id == "wing_left" else 1.0) * (3.1 if hellcat else 2.8), 2.13 if hellcat else 1.62, -0.1)
		# Geometry was built in the approved original coordinates. Moving only the
		# group origin and compensating every child leaves the entire model exact.
		group.position = anchor
		for child: Node3D in group.get_children():
			child.position -= anchor


func _configure() -> void:
	pass


func _build_model() -> void:
	pass


func _create_materials() -> void:
	var airframe_top: Color = spec.get("top_color", Color("64734e"))
	var airframe_bottom: Color = spec.get("bottom_color", Color("a5a99b"))
	materials["airframe"] = _material(Color.WHITE, 0.05, 0.62, false, true)
	materials["top"] = _material(airframe_top, 0.08, 0.58)
	materials["bottom"] = _material(airframe_bottom, 0.03, 0.68)
	materials["control"] = _material(airframe_top.lightened(0.035), 0.06, 0.60)
	materials["glass"] = _material(Color("42616a"), 0.18, 0.19, true)
	if flight_simplified:
		materials["glass"] = _material(Color("304e59"), 0.08, 0.48)
	materials["frame"] = _material(spec.get("frame_color", Color("3d4938")), 0.28, 0.38)
	materials["rubber"] = _material(Color("181b1c"), 0.0, 0.9)
	materials["steel"] = _material(Color("8a9292"), 0.72, 0.32)
	materials["dark_steel"] = _material(Color("343a3c"), 0.62, 0.43)
	materials["black"] = _material(Color("111719"), 0.08, 0.52)
	materials["exhaust"] = _material(Color("574a3b"), 0.72, 0.55)
	materials["seam"] = _material(spec.get("seam_color", Color("3a4137")), 0.0, 0.72)
	materials["insignia_red"] = _material(Color("b82120"), 0.0, 0.66)
	materials["insignia_white"] = _material(Color("e7e2d1"), 0.0, 0.61)
	materials["us_blue"] = _material(Color("18395a"), 0.0, 0.62)
	materials["us_red"] = _material(Color("a83b32"), 0.0, 0.65)
	materials["yellow"] = _material(Color("d5b431"), 0.04, 0.54)
	materials["lamp_red"] = _material(Color("9e2924"), 0.12, 0.18, true)
	materials["lamp_green"] = _material(Color("247b56"), 0.12, 0.18, true)


func _material(color: Color, metallic: float = 0.0, roughness: float = 0.6, transparent: bool = false, vertex_color: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.vertex_color_use_as_albedo = vertex_color
	if transparent:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.albedo_color.a = 0.46 if color != Color("9e2924") and color != Color("247b56") else 0.78
	return result


func _part(parent: Node3D, part_name: String, mesh: Mesh, material: Material, origin: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = origin
	parent.add_child(instance)
	return instance


func _new_group(parent: Node3D, group_name: String, origin: Vector3 = Vector3.ZERO) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	group.position = origin
	parent.add_child(group)
	return group


func _build_fuselage(stations: Array[Vector4], name: String = "Fuselage") -> void:
	fuselage_stations = stations.duplicate()
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_size: int = RADIAL_SEGMENTS + 1
	for z_index in range(LOFT_SEGMENTS + 1):
		var z_fraction: float = float(z_index) / float(LOFT_SEGMENTS)
		var z: float = lerpf(stations[0].w, stations[stations.size() - 1].w, z_fraction)
		var station: Vector4 = _sample_station(stations, z)
		for ring_index in range(ring_size):
			var angle: float = TAU * float(ring_index) / float(RADIAL_SEGMENTS)
			var p := Vector3(sin(angle) * station.y, station.x + cos(angle) * station.z + _dorsal_rise(z) * pow(maxf(0.0, cos(angle)), 2.0), z)
			var up: float = cos(angle)
			surface.set_color(_fuselage_color(up))
			surface.set_uv(Vector2(z_fraction, float(ring_index) / float(RADIAL_SEGMENTS)))
			surface.add_vertex(p)
	for z_index in range(LOFT_SEGMENTS):
		for ring_index in range(RADIAL_SEGMENTS):
			var a: int = z_index * ring_size + ring_index
			var b: int = (z_index + 1) * ring_size + ring_index
			var c: int = (z_index + 1) * ring_size + ring_index + 1
			var d: int = z_index * ring_size + ring_index + 1
			surface.add_index(a)
			surface.add_index(b)
			surface.add_index(c)
			surface.add_index(a)
			surface.add_index(c)
			surface.add_index(d)
	surface.generate_normals()
	mesh = surface.commit()
	_part(self, name, mesh, materials["airframe"])


func _dorsal_rise(z: float) -> float:
	if dorsal_profile.is_empty():
		return 0.0
	var index: int = 0
	while index < dorsal_profile.size() - 2 and z > dorsal_profile[index + 1].x:
		index += 1
	var a: Vector2 = dorsal_profile[index]
	var b: Vector2 = dorsal_profile[index + 1]
	var t: float = clampf((z - a.x) / maxf(0.001, b.x - a.x), 0.0, 1.0)
	return maxf(0.0, _catmull(dorsal_profile[maxi(0,index-1)].y, a.y, b.y, dorsal_profile[mini(dorsal_profile.size()-1,index+2)].y, t))


func _fuselage_color(upper: float) -> Color:
	var split: float = 0.12
	var blend: float = clampf((upper - split + 0.035) / 0.07, 0.0, 1.0)
	blend = smoothstep(0.0, 1.0, blend)
	var top_color: Color = spec.get("top_color", Color("64734e"))
	var bottom_color: Color = spec.get("bottom_color", Color("a5a99b"))
	return bottom_color.lerp(top_color, blend)


func _sample_station(stations: Array[Vector4], z: float) -> Vector4:
	var segment: int = 0
	while segment < stations.size() - 2 and z > stations[segment + 1].w:
		segment += 1
	var a: Vector4 = stations[segment]
	var b: Vector4 = stations[segment + 1]
	var t: float = clampf((z - a.w) / maxf(0.001, b.w - a.w), 0.0, 1.0)
	var p0: Vector4 = stations[maxi(segment - 1, 0)]
	var p1: Vector4 = a
	var p2: Vector4 = b
	var p3: Vector4 = stations[mini(segment + 2, stations.size() - 1)]
	return Vector4(
		_catmull(p0.x, p1.x, p2.x, p3.x, t),
		maxf(0.015, _catmull(p0.y, p1.y, p2.y, p3.y, t)),
		maxf(0.015, _catmull(p0.z, p1.z, p2.z, p3.z, t)),
		z
	)


func _sample_profile(profile: Array[Vector4], distance: float, piecewise_linear: bool = false) -> Vector4:
	var segment: int = 0
	while segment < profile.size() - 2 and distance > profile[segment + 1].x:
		segment += 1
	var a: Vector4 = profile[segment]
	var b: Vector4 = profile[segment + 1]
	var t: float = clampf((distance - a.x) / maxf(0.001, b.x - a.x), 0.0, 1.0)
	if piecewise_linear:
		return Vector4(
			distance,
			maxf(0.025, lerpf(a.y, b.y, t)),
			lerpf(a.z, b.z, t),
			lerpf(a.w, b.w, t)
		)
	var p0: Vector4 = profile[maxi(segment - 1, 0)]
	var p1: Vector4 = a
	var p2: Vector4 = b
	var p3: Vector4 = profile[mini(segment + 2, profile.size() - 1)]
	return Vector4(
		distance,
		maxf(0.025, _catmull(p0.y, p1.y, p2.y, p3.y, t)),
		_catmull(p0.z, p1.z, p2.z, p3.z, t),
		_catmull(p0.w, p1.w, p2.w, p3.w, t)
	)


func _uses_piecewise_wing_profile(profile: Array[Vector4]) -> bool:
	if profile == wing_profile:
		return bool(spec.get("piecewise_wing_profile", false))
	if profile == tail_profile:
		return bool(spec.get("piecewise_tail_profile", false))
	return false


func _sample_wing_profile(profile: Array[Vector4], distance: float) -> Vector4:
	return _sample_profile(profile, distance, _uses_piecewise_wing_profile(profile))


func _wing_thickness_ratio(profile: Array[Vector4], distance: float) -> float:
	var has_custom_wing_thickness: bool = _uses_piecewise_wing_profile(profile) or (profile == wing_profile and not wing_thickness_profile.is_empty())
	if not has_custom_wing_thickness or wing_thickness_profile.is_empty():
		return 0.105 if distance < 1.0 else 0.095
	var span: float = absf(distance)
	var segment: int = 0
	while segment < wing_thickness_profile.size() - 2 and span > wing_thickness_profile[segment + 1].x:
		segment += 1
	var a: Vector2 = wing_thickness_profile[segment]
	var b: Vector2 = wing_thickness_profile[segment + 1]
	var t: float = clampf((span - a.x) / maxf(0.001, b.x - a.x), 0.0, 1.0)
	return lerpf(a.y, b.y, t)


func _catmull(a: float, b: float, c: float, d: float, t: float) -> float:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (-a + 3.0 * b - 3.0 * c + d) * t3)


func _build_wing(profile: Array[Vector4], side: float, target: Node3D, material: Material, name: String, sections: int = 52) -> void:
	if target == self and not damage_parts.is_empty():
		target = _wing_damage_parent(side) if profile == wing_profile else _damage_parent_id("tail")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var contour: int = (AIRFOIL_STEPS + 1) * 2
	var section_distances: Array[float] = []
	for section_index in range(sections + 1):
		section_distances.append(profile[0].x + (profile[profile.size() - 1].x - profile[0].x) * float(section_index) / float(sections))
	var piecewise_profile: bool = _uses_piecewise_wing_profile(profile)
	if piecewise_profile:
		for station in profile:
			section_distances.append(station.x)
	section_distances.sort()
	var unique_distances: Array[float] = []
	for distance in section_distances:
		if unique_distances.is_empty() or absf(distance - unique_distances[unique_distances.size() - 1]) > 0.0001:
			unique_distances.append(distance)
	if piecewise_profile:
		var fold_station: float = float(spec.get("wing_fold_station_m", -1.0))
		for index in range(unique_distances.size()):
			if absf(unique_distances[index] - fold_station) < 0.0001:
				unique_distances.insert(index + 1, fold_station)
				break
	var section_count: int = unique_distances.size() - 1
	for section_index in range(unique_distances.size()):
		var distance: float = unique_distances[section_index]
		var wing := _sample_wing_profile(profile, distance)
		for point_index in range(contour):
			var t: float
			var upper: bool
			if point_index <= AIRFOIL_STEPS:
				t = float(point_index) / float(AIRFOIL_STEPS)
				upper = true
			else:
				t = 1.0 - float(point_index - AIRFOIL_STEPS - 1) / float(AIRFOIL_STEPS)
				upper = false
			var airfoil_y: float = _airfoil_height(t, wing.y, _wing_thickness_ratio(profile, distance), upper)
			var point := Vector3(side * distance, wing.w + airfoil_y, wing.z + wing.y * t)
			var top_color: Color = spec.get("top_color", Color("64734e"))
			var bottom_color: Color = spec.get("bottom_color", top_color)
			surface.set_color(top_color if upper else bottom_color)
			surface.set_uv(Vector2(t, distance / maxf(0.01, profile[profile.size() - 1].x)))
			surface.add_vertex(point)
	for section_index in range(section_count):
		if is_equal_approx(unique_distances[section_index], unique_distances[section_index + 1]):
			continue
		for point_index in range(contour - 1):
			var a: int = section_index * contour + point_index
			var b: int = section_index * contour + point_index + 1
			var c: int = (section_index + 1) * contour + point_index + 1
			var d: int = (section_index + 1) * contour + point_index
			if side < 0.0:
				surface.add_index(a)
				surface.add_index(c)
				surface.add_index(b)
				surface.add_index(a)
				surface.add_index(d)
				surface.add_index(c)
			else:
				surface.add_index(a)
				surface.add_index(b)
				surface.add_index(c)
				surface.add_index(a)
				surface.add_index(c)
				surface.add_index(d)
	var cap_vertex_index: int = unique_distances.size() * contour
	for end_index in range(2):
		var section_index: int = 0 if end_index == 0 else section_count
		var distance: float = profile[0].x if end_index == 0 else profile[profile.size() - 1].x
		var wing := _sample_wing_profile(profile, distance)
		surface.set_color(spec.get("top_color", Color("64734e")))
		surface.set_uv(Vector2(0.5, distance / maxf(0.01, profile[profile.size() - 1].x)))
		surface.add_vertex(Vector3(side * distance, wing.w, wing.z + wing.y * 0.5))
		for point_index in range(contour - 1):
			var boundary_a: int = section_index * contour + point_index
			var boundary_b: int = boundary_a + 1
			var cap_winding: float = side if end_index == 1 else -side
			if cap_winding > 0.0:
				surface.add_index(cap_vertex_index)
				surface.add_index(boundary_a)
				surface.add_index(boundary_b)
			else:
				surface.add_index(cap_vertex_index)
				surface.add_index(boundary_b)
				surface.add_index(boundary_a)
		cap_vertex_index += 1
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	_part(target, name, mesh, materials["airframe"] if spec.get("vertex_paint_wings", true) else material)


func _airfoil_height(t: float, chord: float, thickness_ratio: float, upper: bool) -> float:
	var x: float = clampf(t, 0.0001, 0.9999)
	var thickness: float = 5.0 * thickness_ratio * chord * (0.2969 * sqrt(x) - 0.1260 * x - 0.3516 * x * x + 0.2843 * x * x * x - 0.1015 * x * x * x * x)
	var m: float = 0.018
	var p: float = 0.42
	var camber: float
	var slope: float
	if x < p:
		camber = m / (p * p) * (2.0 * p * x - x * x)
		slope = 2.0 * m / (p * p) * (p - x)
	else:
		camber = m / ((1.0 - p) * (1.0 - p)) * ((1.0 - 2.0 * p) + 2.0 * p * x - x * x)
		slope = 2.0 * m / ((1.0 - p) * (1.0 - p)) * (p - x)
	var normal_factor: float = sqrt(1.0 + slope * slope)
	return camber * chord + (1.0 if upper else -1.0) * thickness / normal_factor


func _wing_y(profile: Array[Vector4], side_x: float, z: float) -> float:
	var wing := _sample_wing_profile(profile, absf(side_x))
	var t: float = clampf((z - wing.z) / wing.y, 0.01, 0.99)
	return wing.w + _airfoil_height(t, wing.y, _wing_thickness_ratio(profile, side_x), true)


func _add_extruded_side_shape(parent: Node3D, name: String, outline: PackedVector2Array, thickness: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2.ZERO
	for point in outline:
		center += point
	center /= float(outline.size())
	var half: float = thickness * 0.5
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var front_center := Vector3(-half, center.y, center.x)
		var front_a := Vector3(-half, a.y, a.x)
		var front_b := Vector3(-half, b.y, b.x)
		surface.add_vertex(front_center)
		surface.add_vertex(front_a)
		surface.add_vertex(front_b)
		var back_center := Vector3(half, center.y, center.x)
		var back_a := Vector3(half, a.y, a.x)
		var back_b := Vector3(half, b.y, b.x)
		surface.add_vertex(back_center)
		surface.add_vertex(back_b)
		surface.add_vertex(back_a)
		var side_a := Vector3(-half, a.y, a.x)
		var side_b := Vector3(half, a.y, a.x)
		var side_c := Vector3(half, b.y, b.x)
		var side_d := Vector3(-half, b.y, b.x)
		surface.add_vertex(side_a)
		surface.add_vertex(side_b)
		surface.add_vertex(side_c)
		surface.add_vertex(side_a)
		surface.add_vertex(side_c)
		surface.add_vertex(side_d)
	surface.generate_normals()
	_part(parent, name, surface.commit(), material)


func _add_beam(parent: Node3D, name: String, start: Vector3, finish: Vector3, radius: float, material: Material, radius_end: float = -1.0, segments: int = 10) -> MeshInstance3D:
	var direction: Vector3 = finish - start
	var length: float = direction.length()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if radius_end < 0.0 else radius_end
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = segments
	var instance := _part(parent, name, mesh, material, (start + finish) * 0.5)
	var normalized: Vector3 = direction.normalized()
	if absf(normalized.dot(Vector3.UP)) < 0.995:
		instance.basis = Basis(Vector3.UP.cross(normalized).normalized(), Vector3.UP.angle_to(normalized))
	else:
		instance.rotation.x = 0.0 if normalized.y > 0.0 else PI
	return instance


func _add_cylinder(parent: Node3D, name: String, radius: float, height: float, position: Vector3, material: Material, axis: String = "y", radial_segments: int = 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	var instance := _part(parent, name, mesh, material, position)
	if axis == "z":
		instance.rotation.x = PI * 0.5
	elif axis == "x":
		instance.rotation.z = PI * 0.5
	return instance


func _add_annulus(parent: Node3D, name: String, outer_radius: float, inner_radius: float, center_y: float, z: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 48
	for ring in range(2):
		var radius: float = outer_radius if ring == 0 else inner_radius
		for index in range(segments):
			var angle: float = TAU * float(index) / float(segments)
			surface.add_vertex(Vector3(cos(angle) * radius, center_y + sin(angle) * radius, z))
	for index in range(segments):
		var next: int = (index + 1) % segments
		var outer_a: int = index
		var outer_b: int = next
		var inner_a: int = segments + index
		var inner_b: int = segments + next
		surface.add_index(outer_a)
		surface.add_index(inner_a)
		surface.add_index(outer_b)
		surface.add_index(outer_b)
		surface.add_index(inner_a)
		surface.add_index(inner_b)
	surface.generate_normals()
	_part(parent, name, surface.commit(), material)


func _add_sphere(parent: Node3D, name: String, radius: float, position: Vector3, material: Material, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var instance := _part(parent, name, mesh, material, position)
	instance.scale = scale
	return instance


func _add_box(parent: Node3D, name: String, size: Vector3, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _part(parent, name, mesh, material, position)
	instance.rotation = rotation
	return instance


func _add_propeller(blade_count: int, diameter: float, origin: Vector3, blade_material: Material) -> Node3D:
	propeller = _new_group(self, "Propeller", origin)
	_add_cylinder(propeller, "Propeller shaft", 0.13, 0.42, Vector3(0.0, 0.0, 0.0), materials["steel"], "z")
	_add_spinner(propeller, 0.29, materials["steel"])
	var radius: float = diameter * 0.5
	var blade_profile: Array[Vector4] = [
		Vector4(0.12, 0.10, 0.00, 42.0), Vector4(0.22, 0.16, 0.00, 37.0),
		Vector4(0.40, 0.20, 0.01, 31.0), Vector4(0.60, 0.18, 0.035, 25.0),
		Vector4(0.78, 0.135, 0.065, 20.0), Vector4(0.92, 0.085, 0.09, 16.0),
		Vector4(0.99, 0.025, 0.11, 13.0)
	]
	for blade_index in range(blade_count):
		var blade_root := _new_group(propeller, "Blade %02d" % (blade_index + 1))
		blade_root.rotation.z = TAU * float(blade_index) / float(blade_count)
		_add_propeller_blade_mesh(blade_root, "Blade", radius, blade_profile, 0.12, 0.94, blade_material, true, false)
		_add_propeller_blade_mesh(blade_root, "Yellow tip band", radius, blade_profile, 0.94, 0.99, materials["yellow"], false, true)
	return propeller


func _add_spinner(parent: Node3D, radius: float, material: Material) -> void:
	var profile: Array[Vector2] = [
		Vector2(0.08, radius * 0.88), Vector2(0.025, radius), Vector2(-0.08, radius * 0.95),
		Vector2(-0.18, radius * 0.78), Vector2(-0.29, radius * 0.52), Vector2(-0.38, radius * 0.24),
		Vector2(-0.44, radius * 0.035)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 40
	var ring_stride: int = segments + 1
	for ring_index in range(profile.size()):
		for segment_index in range(ring_stride):
			var angle: float = TAU * float(segment_index) / float(segments)
			var point := Vector3(cos(angle) * profile[ring_index].y, sin(angle) * profile[ring_index].y, profile[ring_index].x)
			surface.add_vertex(point)
	for ring_index in range(profile.size() - 1):
		for segment_index in range(segments):
			var a: int = ring_index * ring_stride + segment_index
			var b: int = a + 1
			var c: int = b + ring_stride
			var d: int = a + ring_stride
			surface.add_index(a)
			surface.add_index(b)
			surface.add_index(c)
			surface.add_index(a)
			surface.add_index(c)
			surface.add_index(d)
	surface.generate_normals()
	_part(parent, "Spinner", surface.commit(), material)


func _add_propeller_blade_mesh(parent: Node3D, name: String, radius: float, profile: Array[Vector4], span_start: float, span_end: float, material: Material, cap_root: bool, cap_tip: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radial_sections: int = 18
	var chord_sections: int = 14
	var row_stride: int = (chord_sections + 1) * 2
	for radial_index in range(radial_sections + 1):
		var fraction: float = lerpf(span_start, span_end, float(radial_index) / float(radial_sections))
		var section := _sample_propeller_profile(profile, fraction)
		var chord: float = section.y * radius
		var pitch: float = deg_to_rad(section.w)
		var chord_axis := Vector3(cos(pitch), 0.0, sin(pitch))
		var thickness_axis := Vector3(-sin(pitch), 0.0, cos(pitch))
		for chord_index in range(chord_sections + 1):
			var chord_fraction: float = float(chord_index) / float(chord_sections)
			var center := Vector3(section.z * radius, fraction * radius, 0.0) + chord_axis * ((chord_fraction - 0.5) * chord)
			var upper: Vector3 = center + thickness_axis * _airfoil_height(chord_fraction, chord, 0.105, true)
			var lower: Vector3 = center + thickness_axis * _airfoil_height(chord_fraction, chord, 0.105, false)
			surface.add_vertex(upper)
			surface.add_vertex(lower)
	for radial_index in range(radial_sections):
		for chord_index in range(chord_sections):
			var upper_a: int = radial_index * row_stride + chord_index * 2
			var upper_b: int = upper_a + 2
			var upper_c: int = upper_b + row_stride
			var upper_d: int = upper_a + row_stride
			var lower_a: int = upper_a + 1
			var lower_b: int = upper_b + 1
			var lower_c: int = upper_c + 1
			var lower_d: int = upper_d + 1
			surface.add_index(upper_a)
			surface.add_index(upper_b)
			surface.add_index(upper_c)
			surface.add_index(upper_a)
			surface.add_index(upper_c)
			surface.add_index(upper_d)
			surface.add_index(lower_a)
			surface.add_index(lower_c)
			surface.add_index(lower_b)
			surface.add_index(lower_a)
			surface.add_index(lower_d)
			surface.add_index(lower_c)
	for radial_index in range(radial_sections):
		for chord_index in [0, chord_sections]:
			var edge_a: int = radial_index * row_stride + chord_index * 2
			var edge_b: int = edge_a + row_stride
			var lower_a: int = edge_a + 1
			var lower_b: int = edge_b + 1
			surface.add_index(edge_a)
			surface.add_index(edge_b)
			surface.add_index(lower_b)
			surface.add_index(edge_a)
			surface.add_index(lower_b)
			surface.add_index(lower_a)
	for chord_index in range(chord_sections):
		var root_upper_a: int = chord_index * 2
		var root_upper_b: int = root_upper_a + 2
		var root_lower_a: int = root_upper_a + 1
		var root_lower_b: int = root_upper_b + 1
		if cap_root:
			surface.add_index(root_upper_a)
			surface.add_index(root_upper_b)
			surface.add_index(root_lower_b)
			surface.add_index(root_upper_a)
			surface.add_index(root_lower_b)
			surface.add_index(root_lower_a)
		if cap_tip:
			var tip_upper_a: int = radial_sections * row_stride + chord_index * 2
			var tip_upper_b: int = tip_upper_a + 2
			var tip_lower_a: int = tip_upper_a + 1
			var tip_lower_b: int = tip_upper_b + 1
			surface.add_index(tip_upper_a)
			surface.add_index(tip_lower_b)
			surface.add_index(tip_upper_b)
			surface.add_index(tip_upper_a)
			surface.add_index(tip_lower_a)
			surface.add_index(tip_lower_b)
	surface.generate_normals()
	_part(parent, name, surface.commit(), material)


func _sample_propeller_profile(profile: Array[Vector4], fraction: float) -> Vector4:
	var segment: int = 0
	while segment < profile.size() - 2 and fraction > profile[segment + 1].x:
		segment += 1
	var a: Vector4 = profile[segment]
	var b: Vector4 = profile[segment + 1]
	var t: float = clampf((fraction - a.x) / maxf(0.001, b.x - a.x), 0.0, 1.0)
	var p0: Vector4 = profile[maxi(segment - 1, 0)]
	var p3: Vector4 = profile[mini(segment + 2, profile.size() - 1)]
	return Vector4(
		fraction,
		maxf(0.01, _catmull(p0.y, a.y, b.y, p3.y, t)),
		_catmull(p0.z, a.z, b.z, p3.z, t),
		_catmull(p0.w, a.w, b.w, p3.w, t)
	)


func _add_extruded_xy_shape(parent: Node3D, name: String, outline: PackedVector2Array, thickness: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2.ZERO
	for point in outline:
		center += point
	center /= float(outline.size())
	var half: float = thickness * 0.5
	for index in range(outline.size()):
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[(index + 1) % outline.size()]
		surface.add_vertex(Vector3(center.x, center.y, -half))
		surface.add_vertex(Vector3(a.x, a.y, -half))
		surface.add_vertex(Vector3(b.x, b.y, -half))
		surface.add_vertex(Vector3(center.x, center.y, half))
		surface.add_vertex(Vector3(b.x, b.y, half))
		surface.add_vertex(Vector3(a.x, a.y, half))
		surface.add_vertex(Vector3(a.x, a.y, -half))
		surface.add_vertex(Vector3(a.x, a.y, half))
		surface.add_vertex(Vector3(b.x, b.y, half))
		surface.add_vertex(Vector3(a.x, a.y, -half))
		surface.add_vertex(Vector3(b.x, b.y, half))
		surface.add_vertex(Vector3(b.x, b.y, -half))
	surface.generate_normals()
	_part(parent, name, surface.commit(), material)


func _add_radial_engine(engine_name: String, count: int, radius: float, cylinder_length: float, z_front: float) -> void:
	var engine := _new_group(self, engine_name, Vector3(0.0, float(spec["prop_y"]), z_front + 0.13))
	_add_cylinder(engine, "Reduction housing", radius * 0.29, cylinder_length * 0.48, Vector3(0.0, 0.0, 0.08), materials["steel"], "z", 28)
	var row_count: int = count / 2
	for row_index in range(2):
		var row_radius: float = radius * (0.69 if row_index == 0 else 0.38)
		var z_offset: float = 0.0 if row_index == 0 else 0.18
		for cylinder_index in range(row_count):
			var angle: float = TAU * float(cylinder_index) / float(row_count) + (PI_F / float(row_count) if row_index == 1 else 0.0)
			var radial_direction := Vector3(cos(angle), sin(angle), 0.0)
			var barrel_length: float = cylinder_length * 0.55
			var cylinder_position := radial_direction * (row_radius + barrel_length * 0.25) + Vector3(0.0, 0.0, z_offset)
			var cylinder := _add_cylinder(engine, "Row %02d cylinder %02d" % [row_index + 1, cylinder_index + 1], radius * 0.17, barrel_length, cylinder_position, materials["dark_steel"], "y", 10)
			var head_position: Vector3 = cylinder_position + radial_direction * (barrel_length * 0.42)
			var head := _add_cylinder(engine, "Row %02d head %02d" % [row_index + 1, cylinder_index + 1], radius * 0.115, cylinder_length * 0.16, head_position, materials["steel"], "y", 8)
			var radial_basis := Basis(Vector3(-radial_direction.y, radial_direction.x, 0.0), radial_direction, Vector3.FORWARD)
			cylinder.basis = radial_basis
			head.basis = radial_basis


func _add_cowling(z_start: float, z_end: float, center_y: float, radius_x: float, radius_y: float, color_material: Material, part_name: String) -> void:
	var stations: Array[Vector4] = [
		Vector4(center_y, radius_x * 0.77, radius_y * 0.78, z_start),
		Vector4(center_y, radius_x, radius_y, lerpf(z_start, z_end, 0.24)),
		Vector4(center_y, radius_x, radius_y * 0.98, lerpf(z_start, z_end, 0.72)),
		Vector4(center_y, radius_x * 0.92, radius_y * 0.91, z_end)
	]
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slices: int = 18
	var rings: int = 36
	var ring_size: int = rings + 1
	for zi in range(slices + 1):
		var z: float = lerpf(z_start, z_end, float(zi) / float(slices))
		var station := _sample_station(stations, z)
		for ri in range(ring_size):
			var angle: float = TAU * float(ri) / float(rings)
			mesh.set_color(Color.WHITE)
			mesh.add_vertex(Vector3(sin(angle) * station.y, station.x + cos(angle) * station.z, z))
	for zi in range(slices):
		for ri in range(rings):
			var a: int = zi * ring_size + ri
			var b: int = (zi + 1) * ring_size + ri
			var c: int = (zi + 1) * ring_size + ri + 1
			var d: int = zi * ring_size + ri + 1
			mesh.add_index(a)
			mesh.add_index(b)
			mesh.add_index(c)
			mesh.add_index(a)
			mesh.add_index(c)
			mesh.add_index(d)
	mesh.generate_normals()
	var cowling := _part(self, part_name, mesh.commit(), color_material)
	cowling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if flight_simplified:
		_add_cylinder(self, part_name + " closed front", (radius_x + radius_y) * 0.387, 0.02, Vector3(0.0, center_y, z_start + 0.02), color_material, "z", 36)
		return
	_add_annulus(self, "%s front lip" % part_name, (radius_x + radius_y) * 0.5, (radius_x + radius_y) * 0.43, center_y, z_start + 0.04, materials["steel"])
	_add_cylinder(self, "%s intake shadow" % part_name, (radius_x + radius_y) * 0.39, 0.018, Vector3(0.0, center_y, z_start + 0.08), materials["black"], "z", 40)


func _add_gear(side: float, root: Vector3, wheel: Vector3, wheel_radius: float, gear_name: String) -> Node3D:
	var gear := _new_group(landing_gear, gear_name, root)
	if flight_simplified:
		_add_beam(gear, "Simple strut", Vector3.ZERO, wheel - root, 0.055, materials["steel"])
		_add_cylinder(gear, "Tyre", wheel_radius, 0.16, wheel - root, materials["rubber"], "x", 20)
		return gear
	var knee: Vector3 = root.lerp(wheel, 0.7) + Vector3(side * 0.1, -0.14, -0.16)
	_add_beam(gear, "Main oleo", Vector3.ZERO, knee - root, 0.075, materials["steel"], 0.11, 16)
	_add_beam(gear, "Torque link", knee - root, wheel + Vector3(0.0, wheel_radius * 0.48, 0.02) - root, 0.045, materials["dark_steel"], 0.06, 12)
	_add_beam(gear, "Drag brace", Vector3(-side * 0.05, 0.0, 0.16), knee + Vector3(-side * 0.22, 0.08, 0.0) - root, 0.035, materials["steel"], 0.035, 10)
	var tire := _add_cylinder(gear, "Tyre", wheel_radius, 0.16, wheel - root, materials["rubber"], "x", 32)
	tire.material_override = materials["rubber"]
	_add_cylinder(gear, "Hub cap outer", wheel_radius * 0.45, 0.18, wheel - root, materials["steel"], "x", 28)
	_add_cylinder(gear, "Hub cap inset", wheel_radius * 0.21, 0.19, wheel - root, materials["dark_steel"], "x", 20)
	for spoke_index in range(8):
		var spoke_angle: float = TAU * float(spoke_index) / 8.0
		var offset := Vector3(0.0, cos(spoke_angle) * wheel_radius * 0.29, sin(spoke_angle) * wheel_radius * 0.29)
		_add_cylinder(gear, "Hub bolt %02d" % spoke_index, 0.018, 0.19, wheel - root + offset, materials["steel"], "x", 8)
	return gear


func _add_main_gear_pair(root_y: float, root_x: float, z: float, wheel_radius: float, spread: float) -> void:
	landing_gear = _new_group(self, "Landing gear")
	for side in [-1.0, 1.0]:
		var root := Vector3(side * root_x, root_y, z)
		var wheel := Vector3(side * spread, float(spec.get("main_wheel_center_y_m",wheel_radius)), z + 0.13)
		_add_gear(side, root, wheel, wheel_radius, "Main gear left" if side < 0.0 else "Main gear right")
		var door_outline := PackedVector2Array([
			Vector2(side * (root_x - 0.25), z - 0.38), Vector2(side * (root_x + 0.27), z - 0.38),
			Vector2(side * (root_x + 0.31), z + 0.30), Vector2(side * (root_x - 0.20), z + 0.30)
		])
		var cover_name: String = "Main gear bay cover %s" % ("L" if side < 0.0 else "R")
		if flight_simplified and not damage_parts.is_empty():
			_add_closed_gear_cover(_wing_damage_parent(side),cover_name,door_outline)
		else:
			_add_horizontal_panel(self,cover_name,door_outline,root_y-0.13,materials["bottom"])


func _add_closed_gear_cover(host: Node3D, cover_name: String, outline: PackedVector2Array) -> void:
	# The old flat door hung below the wing and survived at the fuselage after
	# separation. Fit the closed flight cover to the actual lower airfoil and
	# keep it inside its wing's static batch. Legacy ground viewers are unchanged.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS: int = 6
	for row: int in range(STEPS+1):
		var v: float = float(row)/STEPS
		for column: int in range(STEPS+1):
			var u: float = float(column)/STEPS
			var leading: Vector2 = outline[0].lerp(outline[1],u)
			var trailing: Vector2 = outline[3].lerp(outline[2],u)
			var point: Vector2 = leading.lerp(trailing,v)
			var station: Vector4 = _sample_wing_profile(wing_profile,absf(point.x))
			var chord_t: float = clampf((point.y-station.z)/station.y,0,1)
			var thickness: float = _wing_thickness_ratio(wing_profile,absf(point.x))
			var lower_y: float = station.w+_airfoil_height(chord_t,station.y,thickness,false)
			if bool(spec.get("fit_gear_cover_triangles",false)):
				# F6F's forward wheel bay follows actual leading-edge triangles;
				# unmodified aircraft keep their admitted cover geometry.
				var segment: int = mini(AIRFOIL_STEPS-1,floori(chord_t*AIRFOIL_STEPS))
				var chord_a: float = float(segment)/AIRFOIL_STEPS
				var chord_b: float = float(segment+1)/AIRFOIL_STEPS
				lower_y = station.w+lerpf(_airfoil_height(chord_a,station.y,thickness,false),_airfoil_height(chord_b,station.y,thickness,false),chord_t*AIRFOIL_STEPS-segment)
			surface.add_vertex(Vector3(point.x,lower_y-0.004,point.y))
	for row: int in STEPS:
		for column: int in STEPS:
			var a: int = row*(STEPS+1)+column
			var indices: Array[int] = [a,a+STEPS+2,a+1,a,a+STEPS+1,a+STEPS+2]
			if outline[0].x < 0: indices.reverse()
			for index: int in indices: surface.add_index(index)
	surface.generate_normals()
	_part(host,cover_name,surface.commit(),materials["bottom"])


func _add_tailwheel(position: Vector3, wheel_radius: float, attachment_height: float, leg_radius: float = 0.043) -> void:
	var tail_gear := _new_group(landing_gear, "Tail wheel assembly", position)
	var leg_top := Vector3(0.0, attachment_height - position.y, -0.16)
	var leg_radius_end: float = 0.052 if is_equal_approx(leg_radius, 0.043) else leg_radius * 0.72
	_add_beam(tail_gear, "Tail leg and oleo sleeve", leg_top, Vector3(0.0, 0.025, 0.0), leg_radius, materials["steel"], leg_radius_end, 12)
	_add_beam(tail_gear, "Tailwheel fork", leg_top.lerp(Vector3.ZERO, 0.82), Vector3(0.0, 0.025, 0.055), 0.024, materials["dark_steel"], 0.022, 10)
	_add_cylinder(tail_gear, "Tail tyre", wheel_radius, 0.085, Vector3.ZERO, materials["rubber"], "x", 20)
	_add_cylinder(tail_gear, "Tail hub", wheel_radius * 0.42, 0.09, Vector3.ZERO, materials["steel"], "x", 16)


func _add_roundel_on_wing(side: float, center_x: float, center_z: float, radius: float, red_color: Material) -> void:
	var center_y: float = _wing_y(wing_profile, center_x, center_z) + 0.012
	_add_wing_disc("Wing roundel border", side, center_x, center_z, center_y, radius, materials["insignia_white"])
	_add_wing_disc("Wing roundel", side, center_x, center_z, center_y + 0.007, radius * 0.79, red_color)


func _add_wing_disc(name: String, side: float, center_x: float, center_z: float, center_y: float, radius: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center_index: int = 0
	var center_x_signed: float = side * center_x
	surface.add_vertex(Vector3(center_x_signed, center_y, center_z))
	var segments: int = 44
	for index in range(segments + 1):
		var angle: float = TAU * float(index) / float(segments)
		var x: float = center_x_signed + cos(angle) * radius
		var z: float = center_z + sin(angle) * radius
		var y: float = _wing_y(wing_profile, absf(x), z) + (center_y - _wing_y(wing_profile, center_x, center_z))
		surface.add_vertex(Vector3(x, y, z))
	for index in range(segments):
		var a: int = 1 + index
		var b: int = a + 1
		if side < 0.0:
			surface.add_index(center_index)
			surface.add_index(b)
			surface.add_index(a)
		else:
			surface.add_index(center_index)
			surface.add_index(a)
			surface.add_index(b)
	surface.generate_normals()
	_part(_wing_damage_parent(side), name, surface.commit(), material)


func _add_flat_patch(parent: Node3D, name: String, outline: PackedVector2Array, side_x: float, material: Material, underside: bool = false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2.ZERO
	for point in outline:
		center += point
	center /= float(outline.size())
	for index in range(outline.size()):
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		surface.add_vertex(Vector3(side_x, center.y, center.x))
		surface.add_vertex(Vector3(side_x, a.y, a.x))
		surface.add_vertex(Vector3(side_x, b.y, b.x))
	surface.generate_normals()
	_part(parent, name, surface.commit(), material)


func _add_horizontal_panel(parent: Node3D, name: String, outline: PackedVector2Array, y: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2.ZERO
	for point in outline:
		center += point
	center /= float(outline.size())
	surface.add_vertex(Vector3(center.x, y, center.y))
	for point in outline:
		surface.add_vertex(Vector3(point.x, y, point.y))
	for index in range(outline.size()):
		surface.add_index(0)
		surface.add_index(index + 1)
		surface.add_index((index + 1) % outline.size() + 1)
	surface.generate_normals()
	_part(parent, name, surface.commit(), material)


func _add_aircraft_roundel_on_fuselage(side: float, z: float, y: float, radius: float) -> void:
	if flight_simplified:
		var circle: PackedVector2Array = PackedVector2Array()
		for i: int in range(40):
			circle.append(Vector2(cos(TAU * i / 40.0), sin(TAU * i / 40.0)) * radius)
		_add_conformal_side_patch("Fuselage roundel white", side, z, y, circle, materials["insignia_white"], 0.009)
		var inner: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in circle:
			inner.append(point * 0.78)
		_add_conformal_side_patch("Fuselage Hinomaru", side, z, y, inner, materials["insignia_red"], 0.013)
		return
	var position := Vector3(side * float(spec.get("fuselage_mark_x", 0.49)), y, z)
	_add_cylinder(self, "Fuselage roundel white", radius, 0.014, position, materials["insignia_white"], "x", 48)
	_add_cylinder(self, "Fuselage Hinomaru", radius * 0.78, 0.024, position + Vector3(side * 0.012, 0.0, 0.0), materials["insignia_red"], "x", 48)


func _add_us_insignia_on_fuselage(side: float, z: float, y: float, radius: float) -> void:
	if flight_simplified:
		_add_conformal_side_patch("Fuselage insignia white star", side, z, y, _star_outline(radius), materials["insignia_white"], 0.009)
		for bar_side: float in [-1.0,1.0]:
			var outline: PackedVector2Array = PackedVector2Array([Vector2(bar_side*radius*0.60,-radius*0.22),Vector2(bar_side*radius*1.6,-radius*0.22),Vector2(bar_side*radius*1.6,radius*0.22),Vector2(bar_side*radius*0.60,radius*0.22)])
			_add_conformal_side_patch("Fuselage insignia bar", side, z, y, outline, materials["insignia_white"], 0.009)
		return
	var x: float = side * float(spec.get("fuselage_mark_x", 0.58))
	_add_cylinder(self, "Fuselage insignia red keyline", radius, 0.014, Vector3(x, y, z), materials["us_red"], "x", 48)
	_add_cylinder(self, "Fuselage insignia blue disk", radius * 0.88, 0.024, Vector3(x + side * 0.012, y, z), materials["us_blue"], "x", 48)
	_add_side_polygon(self, "Fuselage insignia white star", side, x + side * 0.026, z, y, _star_outline(radius * 0.58), materials["insignia_white"])
	for bar_side in [-1.0, 1.0]:
		var bar_outline := PackedVector2Array([
			Vector2(bar_side * radius * 0.61, -radius * 0.12),
			Vector2(bar_side * radius * 1.25, -radius * 0.12),
			Vector2(bar_side * radius * 1.25, radius * 0.12),
			Vector2(bar_side * radius * 0.61, radius * 0.12)
		])
		_add_side_polygon(self, "Fuselage insignia bar", side, x + side * 0.03, z, y, bar_outline, materials["insignia_white"])


func _body_surface_point(side: float, point: Vector2, offset: float) -> Vector3:
	var station: Vector4 = _sample_station(fuselage_stations, point.x)
	var dy: float = point.y - station.x
	var rise: float = _dorsal_rise(point.x)
	var q: float = dy / station.z
	if dy > 0.0 and rise > 0.0001:
		q = (-station.z + sqrt(station.z * station.z + 4.0 * rise * dy)) / (2.0 * rise)
	return Vector3(side * (station.y * sqrt(maxf(0.0, 1.0 - q*q)) + offset), point.y, point.x)


func _add_conformal_side_patch(label: String, side: float, z: float, y: float, outline: PackedVector2Array, material: Material, offset: float) -> void:
	# Small subdivided decal follows the actual fuselage instead of cutting into it.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in outline:
		center += point
	center /= outline.size()
	var divisions: int = 6
	for sector: int in range(outline.size()):
		var a: Vector2 = outline[sector] - center
		var b: Vector2 = outline[(sector+1) % outline.size()] - center
		for row: int in range(divisions):
			for column: int in range(row+1):
				var p0: Vector2 = center + (a*(row-column)+b*column)/divisions
				var p1: Vector2 = center + (a*(row+1-column)+b*column)/divisions
				var p2: Vector2 = center + (a*(row-column)+b*(column+1))/divisions
				for point: Vector2 in [p0,p1,p2]:
					surface.add_vertex(_body_surface_point(side,point+Vector2(z,y),offset))
				if column < row:
					var p3: Vector2 = center + (a*(row-column-1)+b*(column+1))/divisions
					for point: Vector2 in [p0,p2,p3]:
						surface.add_vertex(_body_surface_point(side,point+Vector2(z,y),offset))
	surface.generate_normals()
	_part(self,label,surface.commit(),material)


func _add_side_polygon(parent: Node3D, name: String, side: float, x: float, center_z: float, center_y: float, outline: PackedVector2Array, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2.ZERO
	for point in outline:
		center += point
	center /= float(outline.size())
	surface.add_vertex(Vector3(x, center_y + center.y, center_z + center.x))
	for point in outline:
		surface.add_vertex(Vector3(x, center_y + point.y, center_z + point.x))
	for index in range(outline.size()):
		var b: int = index + 1
		var c: int = (index + 1) % outline.size() + 1
		if side < 0.0:
			surface.add_index(0)
			surface.add_index(c)
			surface.add_index(b)
		else:
			surface.add_index(0)
			surface.add_index(b)
			surface.add_index(c)
	surface.generate_normals()
	_part(parent, name, surface.commit(), material)


func _star_outline(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(10):
		var r: float = radius if index % 2 == 0 else radius * 0.44
		var angle: float = -PI_F * 0.5 + TAU * float(index) / 10.0
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	return points


func _add_us_insignia_on_wing(side: float, center_x: float, center_z: float) -> void:
	var width: float = 1.34
	var height: float = 0.63
	var center_y: float = _wing_y(wing_profile, center_x, center_z) + 0.014
	var outer := PackedVector2Array([
		Vector2(center_z - height * 0.5, -side * (center_x + width * 0.5)),
		Vector2(center_z - height * 0.5, -side * (center_x - width * 0.5)),
		Vector2(center_z + height * 0.5, -side * (center_x - width * 0.5)),
		Vector2(center_z + height * 0.5, -side * (center_x + width * 0.5))
	])
	_add_wing_surface_patch("Insignia red outline", outer, side, 0.014, materials["us_red"], center_x, center_z)
	var inner := PackedVector2Array([
		Vector2(center_z - height * 0.43, -side * (center_x + width * 0.465)),
		Vector2(center_z - height * 0.43, -side * (center_x - width * 0.465)),
		Vector2(center_z + height * 0.43, -side * (center_x - width * 0.465)),
		Vector2(center_z + height * 0.43, -side * (center_x + width * 0.465))
	])
	_add_wing_surface_patch("Insignia blue field", inner, side, 0.019, materials["us_blue"], center_x, center_z)
	_add_wing_disc("Insignia blue roundel", side, center_x, center_z, center_y + 0.008, 0.31, materials["us_blue"])
	_add_star_on_wing(side, center_x, center_z, 0.027, 0.255)
	var bar_width: float = 0.24
	for bar_side in [-1.0, 1.0]:
		var bar_center_x: float = center_x + bar_side * 0.49
		var bar := PackedVector2Array([
			Vector2(center_z - bar_width * 0.36, -side * (bar_center_x + 0.16)),
			Vector2(center_z - bar_width * 0.36, -side * (bar_center_x - 0.16)),
			Vector2(center_z + bar_width * 0.36, -side * (bar_center_x - 0.16)),
			Vector2(center_z + bar_width * 0.36, -side * (bar_center_x + 0.16))
		])
		_add_wing_surface_patch("Insignia white bar", bar, side, 0.034, materials["insignia_white"], center_x, center_z)


func _add_wing_surface_patch(name: String, outline: PackedVector2Array, side: float, y_offset: float, material: Material, center_x: float, center_z: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cx: float = 0.0
	var cz: float = 0.0
	for p in outline:
		cz += p.x
		cx += -p.y / side
	cx /= float(outline.size())
	cz /= float(outline.size())
	surface.add_vertex(Vector3(side * cx, _wing_y(wing_profile, cx, cz) + y_offset, cz))
	for p in outline:
		var x: float = -p.y / side
		surface.add_vertex(Vector3(-p.y, _wing_y(wing_profile, x, p.x) + y_offset, p.x))
	for index in range(outline.size()):
		var a: int = 0
		var b: int = index + 1
		var c: int = (index + 1) % outline.size() + 1
		if side < 0.0:
			surface.add_index(a)
			surface.add_index(c)
			surface.add_index(b)
		else:
			surface.add_index(a)
			surface.add_index(b)
			surface.add_index(c)
	surface.generate_normals()
	_part(_wing_damage_parent(side), name, surface.commit(), material)


func _add_wing_surface_rect(name: String, side: float, span_start: float, span_end: float, chord_start: float, chord_end: float, material: Material, offset: float = 0.014) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span_segments: int = 24
	var chord_segments: int = 3
	var vertex_index: int = 0
	for span_index in range(span_segments):
		var span_a: float = lerpf(span_start, span_end, float(span_index) / float(span_segments))
		var span_b: float = lerpf(span_start, span_end, float(span_index + 1) / float(span_segments))
		for chord_index in range(chord_segments):
			var chord_a: float = lerpf(chord_start, chord_end, float(chord_index) / float(chord_segments))
			var chord_b: float = lerpf(chord_start, chord_end, float(chord_index + 1) / float(chord_segments))
			var vertices: Array[Vector3] = [
				_wing_surface_point(side, span_a, chord_a, offset),
				_wing_surface_point(side, span_b, chord_a, offset),
				_wing_surface_point(side, span_b, chord_b, offset),
				_wing_surface_point(side, span_a, chord_b, offset)
			]
			var base_index: int = vertex_index
			for vertex in vertices:
				surface.add_vertex(vertex)
			vertex_index += 4
			var quad_indices: Array = [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
			for index in quad_indices:
				surface.add_index(base_index + index)
	surface.generate_normals()
	_part(_wing_damage_parent(side), name, surface.commit(), material)


func _wing_surface_point(side: float, span: float, chord_fraction: float, offset: float) -> Vector3:
	var wing := _sample_wing_profile(wing_profile, span)
	var point_z: float = wing.z + wing.y * chord_fraction
	var point_y: float = wing.w + _airfoil_height(chord_fraction, wing.y, _wing_thickness_ratio(wing_profile, span), true) + offset
	return Vector3(side * span, point_y, point_z)


func _add_star_on_wing(side: float, center_x: float, center_z: float, y_offset: float, outer_radius: float) -> void:
	var points := PackedVector2Array()
	for index in range(10):
		var radius: float = outer_radius if index % 2 == 0 else outer_radius * 0.43
		var angle: float = -PI_F * 0.5 + TAU * float(index) / 10.0
		points.append(Vector2(center_z + cos(angle) * radius, -side * (center_x + sin(angle) * radius)))
	_add_wing_surface_patch("Insignia white star", points, side, y_offset, materials["insignia_white"], center_x, center_z)


func _add_canopy(stations: Array[Vector4], name: String, frame_color: Material, panels: int = 5) -> void:
	if flight_simplified:
		panels = 3
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var longitudinal: int = 32
	var transverse: int = 22
	var ring_size: int = transverse + 1
	for zi in range(longitudinal + 1):
		var z: float = lerpf(stations[0].w, stations[stations.size() - 1].w, float(zi) / float(longitudinal))
		var section := _sample_station(stations, z)
		for ti in range(ring_size):
			var angle: float = PI_F * float(ti) / float(transverse)
			var x: float = cos(angle) * section.y
			var y: float = section.x + sin(angle) * section.z
			var sweep: float = float(spec.get("canopy_windscreen_sweep_m",0.0)) if flight_simplified else 0.0
			var shifted_z: float = z + sin(angle) * sweep * clampf(1.0-(z-stations[0].w)/0.72,0.0,1.0)
			surface.add_vertex(Vector3(x, y, shifted_z))
	for zi in range(longitudinal):
		for ti in range(transverse):
			var a: int = zi * ring_size + ti
			var b: int = (zi + 1) * ring_size + ti
			var c: int = (zi + 1) * ring_size + ti + 1
			var d: int = zi * ring_size + ti + 1
			surface.add_index(a)
			surface.add_index(d)
			surface.add_index(c)
			surface.add_index(a)
			surface.add_index(c)
			surface.add_index(b)
	surface.generate_normals()
	var canopy := _part(self, name, surface.commit(), materials["glass"])
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame_group := _new_group(self, "%s frames" % name)
	if flight_simplified:
		var front: Vector4 = stations[0]
		var sweep: float = float(spec.get("canopy_windscreen_sweep_m",0.0))
		var cap: SurfaceTool = SurfaceTool.new()
		cap.begin(Mesh.PRIMITIVE_TRIANGLES)
		var bow: PackedVector3Array = PackedVector3Array()
		for index: int in range(9):
			var angle: float = PI * index / 8.0
			bow.append(Vector3(cos(angle)*front.y,front.x+sin(angle)*front.z,front.w+sin(angle)*sweep))
		for index: int in range(8):
			cap.add_vertex(Vector3(0,front.x,front.w))
			cap.add_vertex(bow[index])
			cap.add_vertex(bow[index+1])
		cap.generate_normals()
		_part(self,"Sloped planar windscreen",cap.commit(),materials["glass"])
		_add_tube_line(frame_group,"Windscreen edge",bow,0.018,frame_color)
	for panel_index in range(1, panels):
		var z: float = lerpf(stations[0].w + 0.12, stations[stations.size() - 1].w - 0.12, float(panel_index) / float(panels))
		var section := _sample_station(stations, z)
		var bow_points := PackedVector3Array()
		for point_index in range(9):
			var angle: float = PI_F * float(point_index) / 8.0
			bow_points.append(Vector3(cos(angle) * section.y, section.x + sin(angle) * section.z, z))
		_add_tube_line(frame_group, "Transverse bow %02d" % panel_index, bow_points, 0.027, frame_color)
	for side in [-1.0, 1.0]:
		var points := PackedVector3Array()
		for zi in range(13):
			var z: float = lerpf(stations[0].w, stations[stations.size() - 1].w, float(zi) / 12.0)
			var section := _sample_station(stations, z)
			points.append(Vector3(side * section.y, section.x + 0.01, z))
		_add_tube_line(frame_group, "Side rail L" if side < 0.0 else "Side rail R", points, 0.022, frame_color)
	var front_section := _sample_station(stations, stations[0].w + 0.08)
	_add_beam(frame_group, "Windscreen lower frame", Vector3(-front_section.y, front_section.x, stations[0].w + 0.08), Vector3(front_section.y, front_section.x, stations[0].w + 0.08), 0.036, frame_color, 0.036, 10)


func _sample_station_for_canopy(stations: Array[Vector4], z: float) -> Vector4:
	return _sample_station(stations, z)


func _add_tube_line(parent: Node3D, name: String, points: PackedVector3Array, radius: float, material: Material) -> void:
	for index in range(points.size() - 1):
		_add_beam(parent, "%s %02d" % [name, index], points[index], points[index + 1], radius, material, radius, 8)


func _add_hinged_wing_control(control_name: String, profile: Array[Vector4], side: float, span_start: float, span_end: float, chord_start: float, chord_end: float, material: Material) -> Node3D:
	var center_span: float = (span_start + span_end) * 0.5
	var wing := _sample_wing_profile(profile, center_span)
	var pivot := Vector3(side * center_span, wing.w, wing.z + wing.y * chord_start)
	var host: Node3D = control_surfaces
	if not damage_parts.is_empty():
		host = _wing_damage_parent(side) if profile == wing_profile else _damage_parent_id("tail")
	var control := _new_group(host, control_name, pivot)
	animated_surfaces.append(control)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span_sections: int = 16
	var chord_sections: int = 10
	var stride: int = chord_sections + 1
	for span_index in range(span_sections + 1):
		var distance: float = lerpf(span_start, span_end, float(span_index) / float(span_sections))
		var section := _sample_wing_profile(profile, distance)
		for chord_index in range(chord_sections + 1):
			var t: float = lerpf(chord_start, chord_end, float(chord_index) / float(chord_sections))
			var thickness_ratio: float = _wing_thickness_ratio(profile, distance)
			var point := Vector3(side * distance, section.w + _airfoil_height(t, section.y, thickness_ratio, true), section.z + section.y * t)
			var lower := Vector3(point.x, section.w + _airfoil_height(t, section.y, thickness_ratio, false), point.z)
			surface.set_color(spec.get("top_color", Color("64734e")))
			surface.add_vertex(point - pivot)
			surface.set_color(spec.get("bottom_color", spec.get("top_color", Color("64734e"))))
			surface.add_vertex(lower - pivot)
	var vertex_per_station: int = stride * 2
	for span_index in range(span_sections):
		for chord_index in range(chord_sections):
			var upper_a: int = span_index * vertex_per_station + chord_index * 2
			var upper_b: int = upper_a + 2
			var upper_c: int = upper_b + vertex_per_station
			var upper_d: int = upper_a + vertex_per_station
			var lower_a: int = upper_a + 1
			var lower_b: int = upper_b + 1
			var lower_c: int = upper_c + 1
			var lower_d: int = upper_d + 1
			var winding: Array[int] = [upper_a, upper_b, upper_c, upper_a, upper_c, upper_d, lower_a, lower_c, lower_b, lower_a, lower_d, lower_c]
			if side < 0.0:
				winding = [upper_a, upper_c, upper_b, upper_a, upper_d, upper_c, lower_a, lower_b, lower_c, lower_a, lower_c, lower_d]
			for index in winding:
				surface.add_index(index)
	surface.generate_normals()
	_part(control, "Movable skin", surface.commit(), materials["airframe"])
	control.set_meta("surface_kind", control_name)
	return control


func _add_hinged_fin_rudder(name: String, outline: PackedVector2Array, hinge_z: float, hinge_y: float, material: Material, thickness: float = 0.11) -> Node3D:
	var rudder := _new_group(_damage_parent_id("tail") if not damage_parts.is_empty() else control_surfaces, name, Vector3(0.0, hinge_y, hinge_z))
	animated_surfaces.append(rudder)
	var local_outline := PackedVector2Array()
	for point in outline:
		local_outline.append(Vector2(point.x - hinge_z, point.y - hinge_y))
	_add_extruded_side_shape(rudder, "Rudder panel", local_outline, thickness, material)
	return rudder


func _add_cockpit_interior(position: Vector3, cockpit_width: float, canopy_height: float, seat_material: Material) -> void:
	var cockpit := _new_group(self, "Cockpit interior", position)
	var seat := _add_cylinder(cockpit, "Seat pan", 0.22, 0.12, Vector3(0.0, -0.16, 0.06), seat_material, "z", 18)
	seat.scale.x = cockpit_width * 1.4
	_add_flat_patch(cockpit, "Armored seat back", PackedVector2Array([
		Vector2(0.08, -0.28), Vector2(0.54, -0.28), Vector2(0.63, -0.06), Vector2(0.12, -0.06)
	]), -0.19, materials["dark_steel"], false)
	_add_flat_patch(cockpit, "Seat back right", PackedVector2Array([
		Vector2(0.08, -0.28), Vector2(0.54, -0.28), Vector2(0.63, -0.06), Vector2(0.12, -0.06)
	]), 0.19, materials["dark_steel"], false)
	_add_beam(cockpit, "Control stick", Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.27, -0.27), 0.025, materials["dark_steel"], 0.018, 8)
	_add_beam(cockpit, "Stick grip", Vector3(0.0, 0.27, -0.27), Vector3(0.08, 0.30, -0.27), 0.022, materials["black"], 0.022, 8)
	_add_beam(cockpit, "Instrument panel", Vector3(-cockpit_width * 0.72, 0.18, -0.47), Vector3(cockpit_width * 0.72, 0.18, -0.47), 0.07, materials["dark_steel"], 0.07, 12)
	for dial in range(7):
		var x: float = lerpf(-cockpit_width * 0.55, cockpit_width * 0.55, float(dial) / 6.0)
		_add_cylinder(cockpit, "Instrument %02d" % dial, 0.035, 0.018, Vector3(x, 0.20, -0.405), materials["black"], "z", 12)
	_add_beam(cockpit, "Left rudder pedal", Vector3(-0.17, -0.13, -0.48), Vector3(-0.17, -0.08, -0.38), 0.022, materials["steel"], 0.022, 8)
	_add_beam(cockpit, "Right rudder pedal", Vector3(0.17, -0.13, -0.48), Vector3(0.17, -0.08, -0.38), 0.022, materials["steel"], 0.022, 8)


func _add_light(parent: Node3D, name: String, position: Vector3, material: Material) -> void:
	_add_sphere(parent, name, 0.065, position, material, Vector3(1.0, 0.64, 0.58))


func _add_hinomaru_leading_stripes(profile: Array[Vector4]) -> void:
	for side in [-1.0, 1.0]:
		_add_wing_surface_rect("Yellow wing identification band", side, 0.48, 2.12, 0.025, 0.135, materials["yellow"], 0.018)


func _add_surface_seam(parent: Node3D, name: String, from: Vector3, to: Vector3, radius: float = 0.008, material: Material = null) -> void:
	_add_beam(parent, name, from, to, radius, materials["seam"] if material == null else material, radius, 6)



func _register_gun_muzzle(id: String, point: Vector3, host_id: String) -> void:
	var marker: Marker3D = Marker3D.new()
	marker.name = "Muzzle_" + id
	marker.position = point
	marker.set_meta("mount_id", id)
	marker.set_meta("host_id", host_id)
	var host: Node3D = self
	if host_id == "port_wing": host = _wing_damage_parent(-1.0)
	elif host_id == "starboard_wing": host = _wing_damage_parent(1.0)
	host.add_child(marker)
