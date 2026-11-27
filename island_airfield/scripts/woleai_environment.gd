extends Node3D
class_name WoleaiEnvironment

const AIRFIELD_HEIGHT_M: float = 3.5
const ISLAND_RADIUS_X_M: float = 640.0
const ISLAND_RADIUS_Z_M: float = 1450.0
const TERRAIN_STEPS_X: int = 192
const TERRAIN_STEPS_Z: int = 264

var _sand_material: StandardMaterial3D
var _concrete_material: StandardMaterial3D
var _white_material: StandardMaterial3D
var _wood_material: StandardMaterial3D
var _roof_material: StandardMaterial3D
var _dark_material: StandardMaterial3D
var _sandbag_material: StandardMaterial3D
var _green_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _brass_material: StandardMaterial3D


func _ready() -> void:
	_create_materials()
	_build_ocean()
	_build_terrain()
	_build_vegetation()
	_build_runway_and_taxiways()
	_build_structures()
	_build_defences()
	_build_airfield_details()


func _create_materials() -> void:
	_sand_material = _material(Color("a99b79"), 0.96)
	_concrete_material = _material(Color("77766d"), 0.88)
	_white_material = _material(Color("e7e3d3"), 0.78)
	_wood_material = _material(Color("705a3d"), 0.93)
	_roof_material = _material(Color("4b514e"), 0.72, 0.12)
	_dark_material = _material(Color("282d2b"), 0.62, 0.18)
	_sandbag_material = _material(Color("9d8b6c"), 1.0)
	_green_material = _material(Color("506348"), 1.0)
	_glass_material = _material(Color("6b8384"), 0.28, 0.12)
	_brass_material = _material(Color("aa8248"), 0.72, 0.48)


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	return result


func _build_ocean() -> void:
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(14000.0, 14000.0)
	ocean_mesh.subdivide_width = 1
	ocean_mesh.subdivide_depth = 1
	var ocean := MeshInstance3D.new()
	ocean.name = "Pacific Ocean · calm water"
	ocean.mesh = ocean_mesh
	ocean.position.y = 0.0
	var water_shader := Shader.new()
	water_shader.code = """
	shader_type spatial;
	render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

	varying vec3 world_position;

	void vertex() {
		world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}

	void fragment() {
		float island_distance = length(vec2(world_position.x / 640.0, world_position.z / 1450.0));
		float shallows = 1.0 - smoothstep(1.01, 1.24, island_distance);
		float wave_a = sin(world_position.x * 0.012 + world_position.z * 0.004 + TIME * 0.8);
		float wave_b = cos(world_position.z * 0.016 - world_position.x * 0.006 - TIME * 0.56);
		vec3 deep_color = vec3(0.025, 0.14, 0.20);
		vec3 reef_color = vec3(0.12, 0.40, 0.40);
		ALBEDO = mix(deep_color, reef_color, shallows * 0.92);
		ALBEDO += vec3(0.012, 0.019, 0.02) * (wave_a * 0.5 + wave_b * 0.5);
		ROUGHNESS = mix(0.28, 0.42, shallows);
		METALLIC = 0.08;
		SPECULAR = 0.52;
	}
	"""
	var water_material := ShaderMaterial.new()
	water_material.shader = water_shader
	ocean.material_override = water_material
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)


func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width_m: float = 2400.0
	var length_m: float = 3400.0
	var vertex_count_x: int = TERRAIN_STEPS_X + 1
	for row in range(TERRAIN_STEPS_Z + 1):
		var z: float = lerpf(-length_m * 0.5, length_m * 0.5, float(row) / TERRAIN_STEPS_Z)
		for column in range(TERRAIN_STEPS_X + 1):
			var x: float = lerpf(-width_m * 0.5, width_m * 0.5, float(column) / TERRAIN_STEPS_X)
			var height: float = _terrain_height(x, z)
			surface.set_color(_terrain_color(x, z, height))
			surface.add_vertex(Vector3(x, height, z))
	for row in range(TERRAIN_STEPS_Z):
		for column in range(TERRAIN_STEPS_X):
			var a: int = row * vertex_count_x + column
			var b: int = a + 1
			var c: int = a + vertex_count_x + 1
			var d: int = a + vertex_count_x
			surface.add_index(a)
			surface.add_index(d)
			surface.add_index(c)
			surface.add_index(a)
			surface.add_index(c)
			surface.add_index(b)
	surface.generate_normals()
	var terrain_mesh := surface.commit()
	var terrain_material := _material(Color.WHITE, 1.0)
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var land := MeshInstance3D.new()
	land.name = "Falalap · coral island terrain"
	land.mesh = terrain_mesh
	land.material_override = terrain_material
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)


func _terrain_height(x: float, z: float) -> float:
	if _is_flat_airfield_surface(x, z):
		return AIRFIELD_HEIGHT_M
	var radius: float = _island_radius(x, z)
	var shoreline: float = 1.0 + 0.018 * sin(z * 0.012) + 0.012 * cos(x * 0.021 + z * 0.008)
	var normalized_radius: float = radius / shoreline
	if normalized_radius >= 1.0:
		return -12.0
	if normalized_radius > 0.965:
		var beach_t: float = smoothstep(0.965, 1.0, normalized_radius)
		return lerpf(2.1, -0.12, beach_t)
	var low_terrain: float = 3.25 + 0.34 * sin(x * 0.017 + z * 0.006) + 0.24 * cos(z * 0.018 - x * 0.009)
	var ridge: float = maxf(0.0, 1.0 - absf(x + 0.12 * z) / 240.0)
	low_terrain += ridge * 0.56 * sin(z * 0.006)
	return low_terrain


func _is_flat_airfield_surface(x: float, z: float) -> bool:
	if absf(x) < 68.0 and absf(z) < 510.0:
		return true
	if absf(x + 104.0) < 18.0 and absf(z) < 325.0:
		return true
	if absf(z + 270.0) < 15.0 and absf(x + 57.0) < 54.0:
		return true
	if absf(z - 260.0) < 15.0 and absf(x + 57.0) < 54.0:
		return true
	if absf(x + 273.0) < 150.0 and absf(z - 82.0) < 132.0:
		return true
	# Keep the connector and dispersal stands clear of adjacent terrain
	# vertices too: the triangulated ground has 12.5–12.9 m spacing.
	if absf(x + 397.75) < 34.0 and absf(z - 82.0) < 42.0:
		return true
	if absf(x - 175.0) < 51.0 and absf(absf(z) - 130.0) < 46.0:
		return true
	if absf(x + 430.0) < 35.0 and absf(z) < 220.0:
		return true
	if absf(x + 207.0) < 24.0 and absf(z + 182.0) < 24.0:
		return true
	return false


func _island_radius(x: float, z: float) -> float:
	var shifted_x: float = x + 24.0 * sin(z * 0.004)
	return sqrt(pow(shifted_x / ISLAND_RADIUS_X_M, 2.0) + pow(z / ISLAND_RADIUS_Z_M, 2.0))


func _terrain_color(x: float, z: float, height: float) -> Color:
	var radius: float = _island_radius(x, z)
	if height < 0.0:
		return Color("293e38")
	if radius > 0.975 or height < 0.8:
		return Color("d0c09b").lerp(Color("aa9b72"), clampf(radius - 0.975, 0.0, 0.025) * 24.0)
	if height < 2.1:
		return Color("8c8963")
	var variation: float = 0.06 * sin(x * 0.026) * cos(z * 0.019)
	return Color("40523b").lightened(variation + clampf((height - 3.0) * 0.025, 0.0, 0.06))


func _build_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1944
	var transforms: Array[Transform3D] = []
	var attempts: int = 18000
	for _index in range(attempts):
		if transforms.size() >= 4200:
			break
		var x: float = rng.randf_range(-610.0, 610.0)
		var z: float = rng.randf_range(-1390.0, 1390.0)
		if _island_radius(x, z) > 0.89 or _inside_airfield_clearance(x, z):
			continue
		var scale: float = rng.randf_range(0.62, 1.08)
		var yaw: float = rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
		transforms.append(Transform3D(basis, Vector3(x, _terrain_height(x, z) + 0.02, z)))
	_add_multimesh("Coconut palms · windward belt", _palm_mesh(), transforms)

	var shrub_transforms: Array[Transform3D] = []
	for _index in range(8200):
		var x: float = rng.randf_range(-620.0, 620.0)
		var z: float = rng.randf_range(-1420.0, 1420.0)
		if _island_radius(x, z) > 0.91 or _inside_airfield_clearance(x, z):
			continue
		var scale: float = rng.randf_range(0.65, 1.45)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale * rng.randf_range(0.65, 1.0), scale))
		shrub_transforms.append(Transform3D(basis, Vector3(x, _terrain_height(x, z) + 0.6 * scale, z)))
	_add_multimesh("Low tropical scrub", _shrub_mesh(), shrub_transforms)


func _inside_airfield_clearance(x: float, z: float) -> bool:
	if absf(x - 175.0) < 44.0 and absf(absf(z) - 130.0) < 40.0:
		return true
	if absf(x) < 83.0 and absf(z) < 535.0:
		return true
	if absf(x + 103.0) < 38.0 and absf(z) < 355.0:
		return true
	if absf(x + 260.0) < 190.0 and absf(z - 80.0) < 175.0:
		return true
	if absf(x + 420.0) < 110.0 and absf(z) < 280.0:
		return true
	return false


func _palm_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var trunk := SurfaceTool.new()
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	trunk.set_material(_material(Color("574a32"), 1.0))
	var trunk_segments: int = 6
	for segment in range(trunk_segments):
		var a0: float = TAU * float(segment) / trunk_segments
		var a1: float = TAU * float(segment + 1) / trunk_segments
		var bend: Vector2 = Vector2(0.45, 0.0)
		var p0 := Vector3(cos(a0) * 0.25, 0.0, sin(a0) * 0.25)
		var p1 := Vector3(cos(a1) * 0.25, 0.0, sin(a1) * 0.25)
		var p2 := Vector3(bend.x + cos(a1) * 0.095, 5.4, bend.y + sin(a1) * 0.095)
		var p3 := Vector3(bend.x + cos(a0) * 0.095, 5.4, bend.y + sin(a0) * 0.095)
		_add_triangle(trunk, p0, p1, p2)
		_add_triangle(trunk, p0, p2, p3)
	trunk.generate_normals()
	trunk.commit(mesh)

	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.set_material(_material(Color("465a3b"), 0.94))
	var crown := Vector3(0.45, 5.45, 0.0)
	for frond in range(7):
		var angle: float = TAU * float(frond) / 7.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-direction.z, 0.0, direction.x)
		var previous_center: Vector3 = crown
		for section in range(1, 5):
			var t: float = float(section) / 4.0
			var center: Vector3 = crown + direction * (3.8 * t) + Vector3(0.0, -1.55 * t * t, 0.0)
			var half_width: float = sin(t * PI) * 0.36
			var previous_t: float = float(section - 1) / 4.0
			var previous_width: float = sin(previous_t * PI) * 0.36
			var left_previous: Vector3 = previous_center + side * previous_width
			var right_previous: Vector3 = previous_center - side * previous_width
			var left_current: Vector3 = center + side * half_width
			var right_current: Vector3 = center - side * half_width
			_add_double_triangle(leaves, left_previous, right_previous, right_current)
			_add_double_triangle(leaves, left_previous, right_current, left_current)
			previous_center = center
	leaves.generate_normals()
	leaves.commit(mesh)
	return mesh


func _shrub_mesh() -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.7
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = _material(Color("536247"), 1.0)
	return sphere


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], parent: Node3D = null) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent == null:
		add_child(instance)
	else:
		parent.add_child(instance)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _add_double_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	_add_triangle(surface, a, b, c)
	_add_triangle(surface, c, b, a)


func _build_runway_and_taxiways() -> void:
	var field_y: float = AIRFIELD_HEIGHT_M
	_add_box("Runway clearing · compacted coral envelope", Vector3(100.0, 0.28, 1000.0), Vector3(0.0, field_y - 0.06, 0.0), _sand_material)
	_add_box("Runway · hard-packed coral", Vector3(58.0, 0.14, 1000.0), Vector3(0.0, field_y + 0.15, 0.0), _concrete_material)
	_add_box("Runway edge · west", Vector3(0.55, 0.045, 982.0), Vector3(-28.2, field_y + 0.245, 0.0), _white_material)
	_add_box("Runway edge · east", Vector3(0.55, 0.045, 982.0), Vector3(28.2, field_y + 0.245, 0.0), _white_material)

	var center_dashes: Array[Transform3D] = []
	for index in range(25):
		var z: float = -462.0 + float(index) * 38.5
		center_dashes.append(Transform3D(Basis.IDENTITY, Vector3(0.0, field_y + 0.255, z)))
	_add_box_multimesh("Runway centerline dashes", Vector3(0.72, 0.04, 18.0), _white_material, center_dashes)

	var threshold_bars: Array[Transform3D] = []
	for end_sign in [-1.0, 1.0]:
		for index in range(8):
			var x: float = -24.5 + float(index) * 7.0
			var z: float = end_sign * 451.0
			threshold_bars.append(Transform3D(Basis.IDENTITY, Vector3(x, field_y + 0.255, z)))
	_add_box_multimesh("Runway threshold bars", Vector3(2.8, 0.04, 27.0), _white_material, threshold_bars)

	_add_box("Taxiway · 625 m cleared length envelope", Vector3(50.0, 0.12, 625.0), Vector3(-104.0, field_y + 0.12, 0.0), _sand_material)
	_add_box("Taxiway surface", Vector3(16.0, 0.14, 625.0), Vector3(-104.0, field_y + 0.15, 0.0), _concrete_material)
	# Share the paved edges at x=-96 and x=-29 rather than drawing two
	# overlapping tops. Keep the same usable footprint and y=3.72 grade.
	var connector_width_m: float = 67.0
	var connector_x_m: float = -62.5
	# The shoulder starts at the outer taxiway-clearance edge (x=-79).
	var shoulder_width_m: float = 50.0
	var shoulder_x_m: float = -54.0
	_add_box("Taxiway connector north", Vector3(shoulder_width_m, 0.12, 18.0), Vector3(shoulder_x_m, field_y + 0.12, -270.0), _sand_material)
	_add_box("Taxiway connector north surface", Vector3(connector_width_m, 0.14, 14.0), Vector3(connector_x_m, field_y + 0.15, -270.0), _concrete_material)
	_add_box("Taxiway connector south", Vector3(shoulder_width_m, 0.12, 18.0), Vector3(shoulder_x_m, field_y + 0.12, 260.0), _sand_material)
	_add_box("Taxiway connector south surface", Vector3(connector_width_m, 0.14, 14.0), Vector3(connector_x_m, field_y + 0.15, 260.0), _concrete_material)
	_add_box("Aircraft dispersal apron · coral", Vector3(270.0, 0.2, 235.0), Vector3(-273.0, field_y - 0.02, 82.0), _sand_material)
	_add_box("Aircraft dispersal apron · central hardstand", Vector3(210.0, 0.12, 176.0), Vector3(-273.0, field_y + 0.14, 82.0), _concrete_material)
	_add_box("Hangar apron connector", Vector3(39.5, 0.12, 55.0), Vector3(-397.75, field_y + 0.14, 82.0), _concrete_material)

	var stand_material := _material(Color("777667"), 0.92)
	_add_box("North dispersal stand", Vector3(74.0, 0.12, 65.0), Vector3(175.0, field_y + 0.03, -130.0), stand_material)
	_add_box("South dispersal stand", Vector3(74.0, 0.12, 65.0), Vector3(175.0, field_y + 0.03, 130.0), stand_material)


func _build_structures() -> void:
	_add_hangar(Vector3(-430.0, AIRFIELD_HEIGHT_M, 177.0), "Timber-framed aircraft shed · north")
	_add_hangar(Vector3(-430.0, AIRFIELD_HEIGHT_M, -177.0), "Timber-framed aircraft shed · south")
	_add_operations_tower(Vector3(-207.0, AIRFIELD_HEIGHT_M, -182.0))
	_add_utility_shed(Vector3(-284.0, AIRFIELD_HEIGHT_M, -210.0))


func _add_hangar(center: Vector3, hangar_name: String) -> void:
	var pad_y: float = center.y + 0.18
	_add_box(hangar_name + " · concrete pad", Vector3(64.0, 0.35, 67.0), center + Vector3(0.0, -0.02, 0.0), _concrete_material)
	var eave_y: float = center.y + 7.8
	var ridge_y: float = center.y + 12.0
	_add_box(hangar_name + " · back wall", Vector3(0.8, 7.8, 60.0), Vector3(center.x - 21.0, center.y + 4.1, center.z), _wood_material)
	_add_box(hangar_name + " · north side wall", Vector3(41.0, 7.8, 0.8), Vector3(center.x - 0.5, center.y + 4.1, center.z - 29.5), _wood_material)
	_add_box(hangar_name + " · south side wall", Vector3(41.0, 7.8, 0.8), Vector3(center.x - 0.5, center.y + 4.1, center.z + 29.5), _wood_material)
	_add_box(hangar_name + " · front jamb north", Vector3(0.8, 7.8, 13.5), Vector3(center.x + 20.0, center.y + 4.1, center.z - 23.25), _wood_material)
	_add_box(hangar_name + " · front jamb south", Vector3(0.8, 7.8, 13.5), Vector3(center.x + 20.0, center.y + 4.1, center.z + 23.25), _wood_material)
	_add_box(hangar_name + " · sliding door leaf north", Vector3(0.48, 6.7, 10.0), Vector3(center.x + 20.9, center.y + 3.55, center.z - 16.5), _material(Color("897652"), 0.92))
	_add_box(hangar_name + " · sliding door leaf south", Vector3(0.48, 6.7, 10.0), Vector3(center.x + 20.9, center.y + 3.55, center.z + 16.5), _material(Color("897652"), 0.92))
	_add_box(hangar_name + " · door header", Vector3(0.85, 0.55, 35.0), Vector3(center.x + 20.0, center.y + 7.75, center.z), _wood_material)

	var gable_mesh := SurfaceTool.new()
	gable_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	gable_mesh.set_material(_wood_material)
	for x_sign in [-1.0, 1.0]:
		var x: float = center.x + x_sign * 20.5
		var left := Vector3(x, eave_y, center.z - 29.0)
		var right := Vector3(x, eave_y, center.z + 29.0)
		var peak := Vector3(x, ridge_y, center.z)
		_add_double_triangle(gable_mesh, left, peak, right)
	var gable := MeshInstance3D.new()
	gable.name = hangar_name + " · end gables"
	gable.mesh = gable_mesh.commit()
	add_child(gable)

	var roof_angle: float = atan2(ridge_y - eave_y, 21.8)
	_add_box(hangar_name + " · west roof plane", Vector3(23.5, 0.34, 63.0), Vector3(center.x - 10.9, center.y + 9.9, center.z), _roof_material, null, Vector3(0.0, 0.0, roof_angle))
	_add_box(hangar_name + " · east roof plane", Vector3(23.5, 0.34, 63.0), Vector3(center.x + 10.9, center.y + 9.9, center.z), _roof_material, null, Vector3(0.0, 0.0, -roof_angle))
	_add_box(hangar_name + " · ridge cap", Vector3(1.2, 0.6, 64.0), Vector3(center.x, ridge_y - 0.25, center.z), _roof_material)

	var posts: Array[Transform3D] = []
	for z_offset in [-27.0, -18.0, -9.0, 0.0, 9.0, 18.0, 27.0]:
		for x_offset in [-19.5, -10.0, 0.0, 10.0, 19.5]:
			posts.append(Transform3D(Basis.IDENTITY, Vector3(center.x + x_offset, center.y + 4.05, center.z + z_offset)))
	_add_box_multimesh(hangar_name + " · visible timber bents", Vector3(0.34, 7.9, 0.34), _wood_material, posts)

	var corrugation_mesh := BoxMesh.new()
	corrugation_mesh.size = Vector3(23.4, 0.055, 0.11)
	corrugation_mesh.material = _material(Color("68706b"), 0.62, 0.2)
	var corrugation: Array[Transform3D] = []
	for z_offset in range(-29, 30, 3):
		corrugation.append(Transform3D(Basis(Vector3.FORWARD, roof_angle), Vector3(center.x - 10.9, center.y + 9.95, center.z + float(z_offset))))
		corrugation.append(Transform3D(Basis(Vector3.FORWARD, -roof_angle), Vector3(center.x + 10.9, center.y + 9.95, center.z + float(z_offset))))
	_add_multimesh(hangar_name + " · corrugated roof seams", corrugation_mesh, corrugation)

	_add_box(hangar_name + " · shadowed interior", Vector3(0.1, 5.2, 25.0), Vector3(center.x + 20.35, pad_y + 2.7, center.z), _dark_material)


func _add_operations_tower(base: Vector3) -> void:
	var tower := Node3D.new()
	tower.name = "Airfield operations tower"
	add_child(tower)
	var leg_material := _material(Color("63543d"), 0.96)
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var foot := Vector3(base.x + x_sign * 3.0, base.y + 0.05, base.z + z_sign * 3.0)
			var top := Vector3(base.x + x_sign * 2.4, base.y + 6.2, base.z + z_sign * 2.4)
			_add_beam(tower, "Timber stilts", foot, top, 0.16, leg_material)
		_add_beam(tower, "Tower diagonal brace", Vector3(base.x - 3.0, base.y + 1.6, base.z - 3.0), Vector3(base.x + 2.4, base.y + 4.1, base.z + 2.4), 0.1, leg_material)
		_add_beam(tower, "Tower diagonal brace", Vector3(base.x + 3.0, base.y + 1.6, base.z - 3.0), Vector3(base.x - 2.4, base.y + 4.1, base.z + 2.4), 0.1, leg_material)
	_add_box("Operations room · raised floor", Vector3(8.4, 0.38, 8.4), Vector3(base.x, base.y + 6.15, base.z), leg_material)
	_add_box("Operations room · timber wall", Vector3(8.0, 4.4, 8.0), Vector3(base.x, base.y + 8.55, base.z), _wood_material)
	_add_box("Operations room · runway-facing window", Vector3(8.1, 1.45, 0.16), Vector3(base.x + 0.05, base.y + 9.25, base.z + 4.05), _glass_material)
	_add_box("Operations room · side windows", Vector3(0.16, 1.35, 5.8), Vector3(base.x + 4.05, base.y + 9.25, base.z), _glass_material)
	_add_box("Operations room · roof", Vector3(10.2, 0.42, 10.2), Vector3(base.x, base.y + 10.95, base.z), _roof_material)
	_add_cylinder(tower, "Tower aerial mast", 0.055, 3.4, Vector3(base.x, base.y + 12.8, base.z - 3.5), _dark_material, 8)


func _add_utility_shed(base: Vector3) -> void:
	_add_box("Workshop shed · coral pad", Vector3(25.0, 0.22, 19.0), base + Vector3(0.0, 0.04, 0.0), _concrete_material)
	_add_box("Workshop shed · timber walls", Vector3(22.0, 4.5, 16.0), base + Vector3(0.0, 2.45, 0.0), _wood_material)
	_add_box("Workshop shed · open service bay", Vector3(7.0, 3.4, 0.3), base + Vector3(0.0, 1.85, 8.1), _dark_material)
	_add_box("Workshop shed · roof", Vector3(25.0, 0.42, 19.0), base + Vector3(0.0, 4.85, 0.0), _roof_material)


func _build_airfield_details() -> void:
	_add_windsock(Vector3(78.0, AIRFIELD_HEIGHT_M, -325.0))
	_add_light_poles()
	_add_dispersal_revetments()
	_add_storage_props()


func _build_defences() -> void:
	_add_type96_twin_battery(Vector3(-485.0, _terrain_height(-485.0, -690.0), -690.0), -0.8, "Type 96 twin 25 mm AA position · northwest")
	_add_type96_twin_battery(Vector3(476.0, _terrain_height(476.0, 675.0), 675.0), 2.4, "Type 96 twin 25 mm AA position · southeast")
	_add_type92_hmg_position(Vector3(-552.0, _terrain_height(-552.0, 325.0), 325.0), -1.2, "Type 92 heavy machine-gun pit · west")
	_add_type92_hmg_position(Vector3(520.0, _terrain_height(520.0, -395.0), -395.0), 2.1, "Type 92 heavy machine-gun pit · east")
	_add_type92_hmg_position(Vector3(80.0, _terrain_height(80.0, 1050.0), 1050.0), 0.5, "Type 92 heavy machine-gun pit · southern shore")
	var comparison_y: float = _terrain_height(0.0, 1350.0)
	_add_type92_hmg_position(Vector3(-5.0, comparison_y, 1350.0), 0.0, "Type 92 HMG · scale comparison")
	_add_type96_twin_battery(Vector3(5.0, comparison_y, 1350.0), 0.0, "Type 96 twin AA · scale comparison")


func _add_type96_twin_battery(position: Vector3, yaw: float, battery_name: String) -> void:
	var emplacement := Node3D.new()
	emplacement.name = battery_name
	emplacement.position = position
	emplacement.rotation.y = yaw
	add_child(emplacement)
	_add_bag_ring(emplacement, Vector3.ZERO, 3.55, 24, 3, PI * 0.5, TAU * 0.86, Vector3(0.92, 0.32, 0.38))
	_add_cylinder(emplacement, "Raised coral gun platform", 2.65, 0.3, Vector3(0.0, 0.16, 0.0), _sand_material, 24)
	_add_box("Buried iron foundation cap", Vector3(1.55, 0.16, 1.55), Vector3(0.0, 0.42, 0.0), _dark_material, emplacement)
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			_add_cylinder(emplacement, "Pedestal anchor bolt", 0.075, 0.11, Vector3(x_sign * 0.58, 0.55, z_sign * 0.58), _roof_material, 8)
	_add_cylinder(emplacement, "Fixed pedestal base", 0.68, 0.36, Vector3(0.0, 0.68, 0.0), _dark_material, 20)
	_add_cylinder(emplacement, "Pedestal column", 0.22, 0.86, Vector3(0.0, 1.28, 0.0), _dark_material, 16)
	_add_cylinder(emplacement, "Traversing gear race", 0.62, 0.16, Vector3(0.0, 1.78, 0.0), _roof_material, 20)
	_add_cylinder(emplacement, "Rotating gun platform", 0.78, 0.18, Vector3(0.0, 1.94, 0.0), _dark_material, 20)
	_add_box("Turntable frame", Vector3(1.85, 0.18, 1.5), Vector3(0.0, 2.08, -0.06), _dark_material, emplacement)
	_add_box("Gunner foot platform left", Vector3(0.62, 0.09, 0.88), Vector3(-0.62, 2.02, 0.22), _roof_material, emplacement)
	_add_box("Gunner foot platform right", Vector3(0.62, 0.09, 0.88), Vector3(0.62, 2.02, 0.22), _roof_material, emplacement)
	for side in [-1.0, 1.0]:
		_add_box("Elevation yoke cheek", Vector3(0.18, 0.82, 1.12), Vector3(side * 0.68, 2.47, -0.16), _dark_material, emplacement)
		var trunnion := _add_cylinder(emplacement, "Elevation trunnion bearing", 0.17, 0.3, Vector3(side * 0.72, 2.48, -0.16), _roof_material, 16)
		trunnion.rotation.z = PI * 0.5
		_add_cylinder(emplacement, "Layer seat column", 0.06, 0.24, Vector3(side * 0.87, 2.24, 0.67), _dark_material, 10)
		_add_box("Layer bucket seat", Vector3(0.42, 0.12, 0.4), Vector3(side * 0.87, 2.4, 0.67), _roof_material, emplacement)
		_add_box("Layer seat back", Vector3(0.42, 0.42, 0.1), Vector3(side * 0.87, 2.64, 0.86), _dark_material, emplacement)
	_add_box("Elevation yoke crossbar", Vector3(1.35, 0.16, 0.3), Vector3(0.0, 2.42, 0.3), _dark_material, emplacement)
	_add_handwheel(emplacement, "Elevation handwheel", Vector3(-0.98, 2.5, 0.1), 0.3, true)
	_add_handwheel(emplacement, "Traverse handwheel", Vector3(0.82, 1.48, 0.08), 0.27, false)
	_add_box("Magazine rack frame", Vector3(0.82, 0.08, 0.52), Vector3(1.2, 0.55, 0.58), _dark_material, emplacement)
	for index in range(3):
		var magazine_x: float = 0.9 + float(index) * 0.28
		_add_box("Spare 15-round magazine", Vector3(0.22, 0.32, 0.28), Vector3(magazine_x, 0.76, 0.58), _roof_material, emplacement)
		_add_box("Magazine identification band", Vector3(0.24, 0.045, 0.29), Vector3(magazine_x, 0.82, 0.58), _sand_material, emplacement)

	var gun_group := Node3D.new()
	gun_group.name = "Twin Type 96 barrels"
	gun_group.position = Vector3(0.0, 2.48, -0.16)
	gun_group.rotation.x = -deg_to_rad(39.0)
	emplacement.add_child(gun_group)
	for side in [-1.0, 1.0]:
		var barrel_x: float = side * 0.22
		_add_box("Type 96 receiver casing", Vector3(0.34, 0.58, 0.42), Vector3(barrel_x, -0.18, 0.02), _dark_material, gun_group)
		_add_box("Receiver back plate", Vector3(0.36, 0.12, 0.42), Vector3(barrel_x, -0.48, 0.02), _roof_material, gun_group)
		_add_box("Upper feed throat", Vector3(0.22, 0.16, 0.18), Vector3(barrel_x, 0.05, 0.3), _dark_material, gun_group)
		_add_box("15-round box magazine", Vector3(0.25, 0.34, 0.3), Vector3(barrel_x, -0.02, 0.52), _roof_material, gun_group)
		_add_box("Magazine top cover", Vector3(0.27, 0.07, 0.32), Vector3(barrel_x, -0.02, 0.7), _dark_material, gun_group)
		_add_box("Magazine latch", Vector3(0.08, 0.1, 0.08), Vector3(barrel_x + side * 0.16, -0.02, 0.48), _sand_material, gun_group)
		_add_cylinder(gun_group, "25 mm L/60 barrel", 0.05, 1.49, Vector3(barrel_x, 1.02, 0.0), _dark_material, 16, 0.05)
		_add_cylinder(gun_group, "Barrel jacket", 0.068, 0.48, Vector3(barrel_x, 0.65, 0.0), _roof_material, 16, 0.068)
		for rib in range(5):
			var rib_y: float = 0.48 + float(rib) * 0.085
			_add_cylinder(gun_group, "Cooling jacket rib", 0.078, 0.025, Vector3(barrel_x, rib_y, 0.0), _dark_material, 16, 0.078)
		_add_cylinder(gun_group, "Muzzle collar", 0.079, 0.085, Vector3(barrel_x, 1.78, 0.0), _roof_material, 16, 0.06)
		_add_cylinder(gun_group, "Muzzle bore", 0.043, 0.012, Vector3(barrel_x, 1.828, 0.0), _dark_material, 12, 0.043)
		_add_cylinder(gun_group, "Hydro-spring recoil cylinder", 0.055, 0.82, Vector3(barrel_x, 0.12, -0.3), _dark_material, 12, 0.055)
		_add_box("Recoil guide bracket", Vector3(0.12, 0.18, 0.5), Vector3(barrel_x, -0.24, -0.28), _roof_material, gun_group)

	_add_box("Calculating sight support", Vector3(0.14, 0.3, 0.14), Vector3(0.0, -0.26, 0.52), _dark_material, gun_group)
	_add_box("Calculating sight housing", Vector3(0.26, 0.2, 0.22), Vector3(0.0, -0.25, 0.72), _roof_material, gun_group)
	_add_cylinder(gun_group, "Sight hood", 0.055, 0.18, Vector3(0.0, -0.18, 0.86), _dark_material, 10, 0.045)
	_add_box("Ammunition ready box", Vector3(0.56, 0.42, 0.46), Vector3(1.35, 0.36, 0.92), _wood_material, emplacement)


func _add_type92_hmg_position(position: Vector3, yaw: float, position_name: String) -> void:
	var emplacement := Node3D.new()
	emplacement.name = position_name
	emplacement.position = position
	emplacement.rotation.y = yaw
	add_child(emplacement)
	_add_bag_ring(emplacement, Vector3.ZERO, 2.65, 22, 2, PI * 0.5, TAU * 0.72)
	_add_cylinder(emplacement, "Packed coral firing step", 1.45, 0.28, Vector3(0.0, 0.12, 0.0), _sand_material, 16)
	var gun := Node3D.new()
	gun.name = "Type 92 tripod-mounted HMG · 7.7 mm"
	gun.position = Vector3(0.0, 0.25, 0.0)
	emplacement.add_child(gun)
	var mount_height: float = 0.94
	var barrel_y: float = mount_height + 0.15
	var head := Vector3(0.0, mount_height, 0.08)
	var feet: Array[Vector3] = [
		Vector3(-0.64, 0.05, -0.67),
		Vector3(0.64, 0.05, -0.67),
		Vector3(0.0, 0.05, 0.86)
	]
	for foot in feet:
		_add_beam(gun, "Tripod leg", foot, head, 0.022, _dark_material)
		var shoe := _add_box("Tripod foot plate", Vector3(0.2, 0.04, 0.13), foot + Vector3(0.0, -0.005, 0.0), _roof_material, gun)
		shoe.rotation.y = atan2(foot.x, foot.z)
	_add_beam(gun, "Tripod forward brace", Vector3(-0.42, 0.42, -0.43), Vector3(0.42, 0.42, -0.43), 0.009, _roof_material)
	_add_beam(gun, "Tripod left brace", Vector3(-0.34, 0.4, -0.28), Vector3(0.0, 0.4, 0.48), 0.008, _roof_material)
	_add_beam(gun, "Tripod right brace", Vector3(0.34, 0.4, -0.28), Vector3(0.0, 0.4, 0.48), 0.008, _roof_material)
	_add_cylinder(gun, "Tripod traverse head", 0.08, 0.28, head, _roof_material, 12)
	_add_box("Elevation cradle", Vector3(0.32, 0.08, 0.24), head + Vector3(0.0, 0.15, 0.02), _dark_material, gun)
	_add_cylinder(gun, "Elevation pivot", 0.042, 0.42, head + Vector3(0.0, 0.2, 0.02), _roof_material, 12).rotation.z = PI * 0.5
	_add_box("Type 92 receiver · 7.7 mm", Vector3(0.38, 0.34, 0.48), Vector3(0.0, barrel_y, 0.1), _dark_material, gun)
	_add_box("Receiver top cover", Vector3(0.4, 0.1, 0.4), Vector3(0.0, barrel_y + 0.22, 0.12), _roof_material, gun)
	_add_box("Feed cover hinge", Vector3(0.3, 0.045, 0.055), Vector3(-0.04, barrel_y + 0.28, 0.3), _dark_material, gun)
	_add_box("Receiver left plate", Vector3(0.035, 0.22, 0.28), Vector3(-0.205, barrel_y - 0.015, 0.12), _roof_material, gun)
	_add_box("Receiver right plate", Vector3(0.035, 0.22, 0.28), Vector3(0.205, barrel_y - 0.015, 0.12), _roof_material, gun)
	for side in [-1.0, 1.0]:
		for fastener in range(3):
			_add_cylinder(gun, "Receiver cover fastener", 0.018, 0.015, Vector3(side * 0.229, barrel_y + 0.015, -0.02 + float(fastener) * 0.12), _dark_material, 8).rotation.z = PI * 0.5
	_add_beam(gun, "Gas cylinder below barrel", Vector3(0.0, barrel_y - 0.15, -0.08), Vector3(0.0, barrel_y - 0.15, -0.57), 0.012, _roof_material)
	_add_beam(gun, "Barrel · 28.4 in", Vector3(0.0, barrel_y, -0.1), Vector3(0.0, barrel_y, -0.81), 0.013, _dark_material)
	_add_beam(gun, "Barrel jacket", Vector3(0.0, barrel_y, -0.14), Vector3(0.0, barrel_y, -0.48), 0.022, _roof_material)
	for rib in range(7):
		var z: float = -0.18 - float(rib) * 0.045
		var jacket_fin := _add_cylinder(gun, "Broad barrel-jacket cooling fin", 0.034, 0.023, Vector3(0.0, barrel_y, z), _roof_material, 12)
		jacket_fin.rotation.x = PI * 0.5
	for rib in range(8):
		var z: float = -0.51 - float(rib) * 0.041
		var muzzle_fin := _add_cylinder(gun, "Machined barrel cooling fin", 0.025, 0.018, Vector3(0.0, barrel_y, z), _dark_material, 12)
		muzzle_fin.rotation.x = PI * 0.5
	var barrel_lock := TorusMesh.new()
	barrel_lock.inner_radius = 0.012
	barrel_lock.outer_radius = 0.04
	barrel_lock.rings = 16
	barrel_lock.ring_segments = 8
	barrel_lock.material = _roof_material
	var lock_instance := MeshInstance3D.new()
	lock_instance.name = "Left-side barrel lock nut"
	lock_instance.mesh = barrel_lock
	lock_instance.position = Vector3(0.0, barrel_y, -0.13)
	lock_instance.rotation.x = PI * 0.5
	gun.add_child(lock_instance)
	var flash_hider := _add_cylinder(gun, "Cone flash hider", 0.04, 0.12, Vector3(0.0, barrel_y, -0.86), _roof_material, 14, 0.019)
	flash_hider.rotation.x = PI * 0.5
	var flash_hider_tip := _add_cylinder(gun, "Flash-hider end ring", 0.021, 0.018, Vector3(0.0, barrel_y, -0.925), _dark_material, 14)
	flash_hider_tip.rotation.x = PI * 0.5
	_add_box("Muzzle sight base", Vector3(0.11, 0.05, 0.08), Vector3(0.0, barrel_y + 0.11, -0.7), _roof_material, gun)
	_add_box("Front blade sight", Vector3(0.022, 0.11, 0.025), Vector3(0.0, barrel_y + 0.18, -0.7), _dark_material, gun)
	_add_box("Rear sight base", Vector3(0.12, 0.06, 0.12), Vector3(0.0, barrel_y + 0.19, 0.27), _roof_material, gun)
	_add_box("Rear sight leaf", Vector3(0.025, 0.13, 0.035), Vector3(0.0, barrel_y + 0.28, 0.27), _dark_material, gun)
	_add_box("Rear peep aperture", Vector3(0.12, 0.035, 0.025), Vector3(0.0, barrel_y + 0.33, 0.27), _dark_material, gun)
	_add_box("Right-side cocking handle", Vector3(0.16, 0.055, 0.07), Vector3(0.31, barrel_y + 0.04, 0.08), _roof_material, gun)
	_add_cylinder(gun, "Cocking handle knob", 0.043, 0.08, Vector3(0.39, barrel_y + 0.04, 0.08), _dark_material, 10).rotation.z = PI * 0.5
	_add_beam(gun, "Backplate grip bar", Vector3(-0.24, barrel_y - 0.12, 0.31), Vector3(0.24, barrel_y - 0.12, 0.31), 0.035, _dark_material)
	for side in [-1.0, 1.0]:
		_add_box("Wooden downward-hinged traverse grip", Vector3(0.105, 0.24, 0.105), Vector3(side * 0.19, barrel_y - 0.31, 0.34), _wood_material, gun, Vector3(0.16, 0.0, side * -0.12))
	_add_handwheel(gun, "Tripod elevation handwheel", Vector3(0.43, 0.76, 0.3), 0.19, true)
	_add_beam(gun, "Elevation screw", Vector3(0.0, 0.56, 0.32), Vector3(0.0, 0.94, 0.32), 0.025, _dark_material)
	_add_box("Metal ammunition feed tray", Vector3(0.19, 0.035, 0.34), Vector3(-0.3, barrel_y + 0.035, 0.06), _roof_material, gun)
	var strip_length: float = 0.43
	var strip_center_x: float = -0.49
	var cartridge_y: float = barrel_y + 0.06
	for rail_side in [-1.0, 1.0]:
		_add_box("30-round strip · steel rail", Vector3(strip_length, 0.012, 0.012), Vector3(strip_center_x, cartridge_y - 0.02, 0.06 + rail_side * 0.034), _roof_material, gun)
	var case_mesh := CylinderMesh.new()
	case_mesh.top_radius = 0.006
	case_mesh.bottom_radius = 0.0067
	case_mesh.height = 0.047
	case_mesh.radial_segments = 8
	case_mesh.material = _brass_material
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.006
	tip_mesh.height = 0.02
	tip_mesh.radial_segments = 8
	tip_mesh.material = _material(Color("665b42"), 0.6, 0.45)
	var cartridge_basis := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	var case_transforms: Array[Transform3D] = []
	var tip_transforms: Array[Transform3D] = []
	for round_index in range(30):
		var cartridge_x: float = -0.27 - float(round_index) * 0.014
		case_transforms.append(Transform3D(cartridge_basis, Vector3(cartridge_x, cartridge_y, 0.06)))
		tip_transforms.append(Transform3D(cartridge_basis, Vector3(cartridge_x, cartridge_y, 0.026)))
	_add_multimesh("30 brass cartridges in metal strip", case_mesh, case_transforms, gun)
	_add_multimesh("30 pointed cartridge tips", tip_mesh, tip_transforms, gun)


func _add_bag_ring(parent: Node3D, center: Vector3, radius: float, count: int, layers: int, arc_center: float, arc_width: float, bag_size: Vector3 = Vector3(1.38, 0.42, 0.52)) -> void:
	var transforms: Array[Transform3D] = []
	var first_angle: float = arc_center - arc_width * 0.5
	for layer in range(layers):
		var layer_count: int = count if layer % 2 == 0 else count - 1
		for index in range(layer_count):
			var t: float = (float(index) + (0.5 if layer % 2 == 1 else 0.0)) / float(layer_count - 1)
			var angle: float = first_angle + arc_width * t
			var bag_position := center + Vector3(cos(angle) * radius, 0.25 + float(layer) * 0.34, sin(angle) * radius)
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			var tangent := Vector3(-sin(angle), 0.0, cos(angle))
			var bag_basis := Basis(Vector3.UP, tangent, radial)
			transforms.append(Transform3D(bag_basis, bag_position))
	var bag_mesh := CapsuleMesh.new()
	bag_mesh.radius = minf(bag_size.y, bag_size.z) * 0.5
	bag_mesh.height = bag_size.x
	bag_mesh.radial_segments = 8
	bag_mesh.rings = 4
	bag_mesh.material = _sandbag_material
	_add_multimesh(parent.name + " · sandbag revetment", bag_mesh, transforms, parent)


func _add_handwheel(parent: Node3D, wheel_name: String, center: Vector3, radius: float, axle_along_x: bool) -> void:
	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.026
	wheel_mesh.outer_radius = radius
	wheel_mesh.rings = 24
	wheel_mesh.ring_segments = 8
	wheel_mesh.material = _roof_material
	var wheel := MeshInstance3D.new()
	wheel.name = wheel_name
	wheel.mesh = wheel_mesh
	wheel.position = center
	if axle_along_x:
		wheel.rotation.z = -PI * 0.5
	else:
		wheel.rotation.x = PI * 0.5
	parent.add_child(wheel)
	for spoke_index in range(4):
		var angle: float = TAU * float(spoke_index) / 4.0
		var radial := Vector3(0.0, cos(angle), sin(angle)) if axle_along_x else Vector3(cos(angle), sin(angle), 0.0)
		_add_beam(parent, wheel_name + " spoke", center + radial * radius * 0.12, center + radial * radius * 0.88, 0.025, _dark_material)
	var hub := _add_cylinder(parent, wheel_name + " hub", 0.085, 0.14, center, _dark_material, 12)
	if axle_along_x:
		hub.rotation.z = PI * 0.5
	else:
		hub.rotation.x = PI * 0.5


func _add_dispersal_revetments() -> void:
	_add_bag_ring(self, Vector3(175.0, AIRFIELD_HEIGHT_M + 0.05, -130.0), 13.0, 30, 3, PI * 0.5, TAU * 0.67)
	_add_bag_ring(self, Vector3(175.0, AIRFIELD_HEIGHT_M + 0.05, 130.0), 13.0, 30, 3, PI * 0.5, TAU * 0.67)


func _add_storage_props() -> void:
	var barrel_material := _material(Color("554b3a"), 0.82, 0.2)
	for index in range(7):
		var x: float = -340.0 + float(index % 4) * 4.0
		var z: float = 165.0 + float(index / 4) * 5.0
		_add_cylinder(self, "Fuel drum", 0.58, 0.95, Vector3(x, AIRFIELD_HEIGHT_M + 0.48, z), barrel_material, 14)
		_add_cylinder(self, "Fuel drum top rim", 0.6, 0.07, Vector3(x, AIRFIELD_HEIGHT_M + 0.94, z), _dark_material, 14)
	_add_box("Spare parts crate", Vector3(2.1, 1.8, 1.6), Vector3(-347.0, AIRFIELD_HEIGHT_M + 0.9, 188.0), _wood_material)
	_add_box("Ammunition crate", Vector3(1.4, 1.1, 0.9), Vector3(-343.0, AIRFIELD_HEIGHT_M + 0.55, 190.0), _wood_material)


func _add_windsock(base: Vector3) -> void:
	_add_cylinder(self, "Windsock pole", 0.07, 11.5, base + Vector3(0.0, 5.75, 0.0), _dark_material, 10)
	var sock_mesh := CylinderMesh.new()
	sock_mesh.top_radius = 0.045
	sock_mesh.bottom_radius = 0.3
	sock_mesh.height = 3.2
	sock_mesh.radial_segments = 10
	sock_mesh.material = _material(Color("be6b36"), 0.9)
	var sock := MeshInstance3D.new()
	sock.name = "Orange windsock"
	sock.mesh = sock_mesh
	sock.position = base + Vector3(1.7, 10.8, 0.0)
	sock.rotation.z = -PI * 0.5
	add_child(sock)
	_add_cylinder(self, "Windsock hoop", 0.33, 0.06, base + Vector3(0.05, 10.8, 0.0), _roof_material, 16)


func _add_light_poles() -> void:
	for end_z in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var marker_pos := Vector3(side * 66.0, AIRFIELD_HEIGHT_M + 1.3, end_z * 490.0)
			_add_cylinder(self, "Runway end marker post", 0.12, 2.6, marker_pos, _white_material, 8)
			_add_box("Runway end marker board", Vector3(2.5, 0.55, 0.16), marker_pos + Vector3(0.0, 0.2, 0.0), _dark_material)


func _add_box(node_name: String, size: Vector3, position: Vector3, material: Material, parent: Node3D = null, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = box
	instance.position = position
	instance.rotation = rotation
	if parent == null:
		add_child(instance)
	else:
		parent.add_child(instance)
	return instance


func _add_box_multimesh(node_name: String, size: Vector3, material: Material, transforms: Array[Transform3D], parent: Node3D = null) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	_add_multimesh(node_name, mesh, transforms, parent)


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material, radial_segments: int = 20, top_radius: float = -1.0) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius if top_radius < 0.0 else top_radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = radial_segments
	cylinder.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = cylinder
	instance.position = position
	parent.add_child(instance)
	return instance


func _add_beam(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var delta: Vector3 = finish - start
	var beam := _add_cylinder(parent, node_name, radius, delta.length(), (start + finish) * 0.5, material, 10)
	var direction: Vector3 = delta.normalized()
	beam.basis = Basis(Quaternion(Vector3.UP, direction))

