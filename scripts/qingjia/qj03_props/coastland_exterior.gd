extends Node3D
## Photo-inspired static exhibit on fictional scenery. All silhouette ends are solid.
## No moving assemblies, collision, weapon data, or in-game weapon behaviors.

@export_enum("Open plinth", "Shielded housing", "Cliff façade")
var variant: int = 0

const PALETTE: Dictionary = {
	"ground": Color("44463b"),
	"rock": Color("555952"),
	"rock_lite": Color("656861"),
	"cement": Color("8b8a79"),
	"edge": Color("a8a38c"),
	"dark_cement": Color("6a6a5f"),
	"metal": Color("4f5f51"),
	"metal_lite": Color("737f69"),
	"black": Color("363b38"),
	"rust": Color("84654e"),
	"wood": Color("695b46"),
	"linen": Color("958266"),
	"linen_lite": Color("ad9775"),
	"stain": Color("73766c"),
	"grass": Color("656c46"),
}

var _surfaces: Dictionary = {}

func _ready() -> void:
	match variant:
		0: _open_plinth()
		1: _shielded_housing()
		2: _cliff_facade()
	for key: String in _surfaces:
		var batch: MeshInstance3D = MeshInstance3D.new()
		batch.name = "Matte_" + key
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = PALETTE[key]
		material.roughness = 0.91
		var surface: SurfaceTool = _surfaces[key]
		batch.mesh = surface.commit()
		batch.material_override = material
		add_child(batch)
	_surfaces.clear()

func _open_plinth() -> void:
	_cylinder(Vector3(0, 0.15, 0), 5.2, 5.3, 0.3, "ground", 14)
	_cylinder(Vector3(0, 0.4, 0), 4.6, 4.8, 0.55, "dark_cement", 12)
	_cylinder(Vector3(0, 0.76, 0), 4.35, 4.58, 0.21, "cement", 12)
	_cylinder(Vector3(0, 1.03, 0.15), 1.18, 1.59, 0.42, "dark_cement", 12)
	_cylinder(Vector3(0, 1.31, 0.15), 1.03, 1.15, 0.20, "metal_lite", 12)
	_piti_silhouette(Vector3(0, 1.45, 0.1))
	for i: int in range(8):
		var angle: float = (i * 30 + 15) * PI / 180.0
		var point: Vector3 = Vector3(cos(angle) * 4.05, 0.96, sin(angle) * 4.05)
		_bag(point, angle + PI / 2, i)
		_bag(point + Vector3(0, 0.25, 0) + Vector3(cos(angle), 0, sin(angle)) * -0.13, angle + PI / 2 + 0.11, i + 3)
	_step(Vector3(2.64, 0, 3.4), 0.42)
	_crate(Vector3(-2.72, 0.85, 0.60), -0.57)
	_crate(Vector3(-2.68, 1.26, 0.68), -0.45)
	_stains(3.32, 0.868, 0.4, 10)

func _shielded_housing() -> void:
	_box(Vector3(0, 0.19, 0), Vector3(9.6, 0.38, 8.1), "ground")
	_box(Vector3(0, 0.38, 0), Vector3(8.6, 0.38, 7.1), "dark_cement")
	_box(Vector3(0, 0.64, 0), Vector3(8.45, 0.16, 7.05), "cement")
	for side: int in [-1, 1]:
		_box(Vector3(side * 3.95, 0.95, -0.5), Vector3(0.57, 0.53, 4.7), "cement")
		_box(Vector3(side * 3.95, 1.25, -0.5), Vector3(0.63, 0.09, 4.83), "edge")
		for j: int in range(3):
			_bag(Vector3(side * 3.97, 1.41, j * 1.02 - 0.9), PI / 2, j + side * 2)
		_crate(Vector3(side * 3.1, 0.72, 1.96), side * 0.12)
	_cylinder(Vector3(0, 0.92, -0.16), 1.23, 1.73, 0.5, "dark_cement", 12)
	_cylinder(Vector3(0, 1.2, -0.16), 1.20, 1.29, 0.15, "metal_lite", 12)
	_six_inch_silhouette(Vector3(0, 1.24, 0.14))
	_box(Vector3(0, 2.13, -0.13), Vector3(2.4, 1.35, 1.33), "metal", Vector3(-0.14, 0, 0))
	_box(Vector3(0, 2.79, -0.28), Vector3(2.37, 0.12, 1.07), "metal_lite", Vector3(-0.14, 0, 0))
	for side: int in [-1, 1]:
		_box(Vector3(side * 1.21, 2.1, 0.53), Vector3(0.19, 1.29, 1.64), "metal", Vector3(0, side * -0.25, side * 0.17))
		_box(Vector3(side * 0.89, 2.44, -0.8), Vector3(0.18, 0.14, 0.031), "metal_lite")
	_box(Vector3(0, 1.88, -0.84), Vector3(0.64, 0.43, 0.06), "black")
	for i: int in range(4):
		_box(Vector3(-3.1 + 2.07 * i, 0.725, 3.13), Vector3(0.74, 0.022, 0.077), "edge")
	_step(Vector3(0.6, 0, 3.8), 0.38)
	_stains(2.9, 0.723, 0.35, 11)

func _cliff_facade() -> void:
	_box(Vector3(0, 0.18, 0), Vector3(12, 0.36, 10.0), "ground")
	_box(Vector3(0, 0.44, -0.26), Vector3(10.9, 0.51, 8.45), "dark_cement")
	_box(Vector3(0, 0.72, -0.33), Vector3(10.64, 0.16, 8.25), "cement")
	_rock(Vector3(0.19, 2.7, 2.5), Vector3(10.3, 3.7, 6.0), -0.21, "rock")
	_rock(Vector3(-3.88, 1.8, 0.78), Vector3(3.04, 2.5, 3.0), 0.49, "rock")
	_rock(Vector3(3.84, 1.9, 0.66), Vector3(3.3, 2.65, 3.5), -0.78, "rock_lite")
	for i: int in range(7):
		var x: float = (i - 3.1) * 1.39
		_rock(Vector3(x, 3.17 + abs(sin(i * 1.67)) * 0.65, 2.20 + abs(cos(i)) * 1.71),
			Vector3(2.0, 1.37, 2.12), 0.88 + i * 0.37, "rock_lite" if i % 3 == 0 else "rock")
	_box(Vector3(0, 2.07, -0.58), Vector3(6.05, 2.65, 2.10), "cement")
	_box(Vector3(0, 3.46, -0.65), Vector3(6.38, 0.34, 2.36), "edge")
	_box(Vector3(0, 2.37, -1.642), Vector3(4.35, 0.79, 0.04), "black")
	_box(Vector3(0, 1.91, -1.63), Vector3(6.01, 0.46, 0.18), "dark_cement")
	_box(Vector3(0, 2.92, -1.69), Vector3(5.9, 0.18, 0.175), "dark_cement")
	_box(Vector3(0, 2.34, -1.691), Vector3(1.72, 0.62, 0.1), "metal")
	_six_inch_silhouette(Vector3(0, 1.68, -0.86))
	for side: int in [-1, 1]:
		_box(Vector3(side * 2.64, 2.42, -1.74), Vector3(0.52, 1.29, 0.24), "cement")
		_box(Vector3(side * 3.12, 1.08, -1.23), Vector3(0.91, 0.45, 3.04), "dark_cement", Vector3(0, side * -0.26, 0))
		for i: int in range(3):
			_bag(Vector3(side * (3.27 + i * 0.28), 1.15, -2.76 + i * 0.91), PI / 2 + side * -0.26, i + side)
		_crate(Vector3(side * 2.9, 0.8, -3.38), side * 0.18)
	for i: int in range(7):
		var x: float = (i - 3) * 0.69
		_box(Vector3(x, 3.18, -1.714), Vector3(0.15 + 0.09 * (i % 2), 0.28 + 0.1 * (i % 3), 0.035), "stain", Vector3(0, 0, (i % 3 - 1) * 0.11))
	_step(Vector3(1.85, 0, -4.86), 0.42)

func _body(p: Vector3, size: Vector3) -> void:
	_box(p, size, "metal")
	_box(p + Vector3(0, size.y / 2.0 + 0.041, 0), Vector3(size.x * 0.91, 0.081, size.z * 0.9), "metal_lite")
	for side: int in [-1, 1]:
		_box(p + Vector3(side * size.x * 0.48, 0.061, 0.24), Vector3(0.14, size.y * 0.93, size.z * 0.67), "black")

func _piti_silhouette(p: Vector3) -> void:
	# Long quiet line, dark broad collar and angular exterior cheeks visible in the Piti image.
	_body(p + Vector3(0, 0.32, 0.20), Vector3(1.43, 0.56, 1.28))
	for side: int in [-1, 1]:
		_box(p + Vector3(side * 0.65, 0.40, 0.01), Vector3(0.16, 0.74, 1.23), "metal")
		_box(p + Vector3(side * 0.65, 0.63, 0.44), Vector3(0.16, 0.63, 0.78), "metal",
			Vector3(0.35, 0, 0))
		_cylinder(p + Vector3(side * 0.63, 0.86, 0.41), 0.19, 0.19, 0.14, "metal_lite", 8)
	_solid_boom(p + Vector3(0, 0.49, -0.43), p + Vector3(0, 0.91, -3.79), 0.31)

func _six_inch_silhouette(p: Vector3) -> void:
	# Profile cues only: heavy, unobstructed barrel and a low metal mass beneath it.
	_body(p + Vector3(0, 0.31, 0.18), Vector3(1.47, 0.61, 1.57))
	_solid_boom(p + Vector3(0, 0.65, -0.45), p + Vector3(0, 1.07, -3.49), 0.30)

func _solid_boom(a: Vector3, b: Vector3, radius: float) -> void:
	var v: Vector3 = b - a
	var orient: Basis = Basis(Quaternion(Vector3.UP, v.normalized()))
	_add(_cyl_mesh(radius * 0.64, radius, v.length(), 10), Transform3D(orient, a.lerp(b, 0.5)), "metal")
	_add(_cyl_mesh(radius * 0.83, radius * 0.74, 0.23, 10), Transform3D(orient, b - v.normalized() * 0.12), "black")
	_add(_cyl_mesh(radius * 0.76, radius * 0.76, 0.055, 10), Transform3D(orient, b), "rust")

func _step(p: Vector3, h: float) -> void:
	for i: int in range(3):
		var height: float = (i + 1) * h / 3
		_box(p + Vector3(0, height / 2.0, i * -0.22), Vector3(1.29, height, 0.45), "cement")

func _crate(p: Vector3, yaw: float) -> void:
	var vr: Vector3 = Vector3(0, yaw, 0)
	var basis: Basis = Basis.from_euler(vr)
	_box(p + Vector3(0, 0.23, 0), Vector3(0.82, 0.45, 0.70), "wood", vr)
	for i: int in [-1, 1]:
		_box(p + basis * Vector3(i * 0.26, 0.471, 0), Vector3(0.093, 0.043, 0.69), "linen", vr)

func _bag(p: Vector3, yaw: float, id: int) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.radius = 0.5
	mesh.height = 1.0
	_add(mesh, Transform3D(Basis.from_euler(Vector3(0, yaw, 0.06 * sin(id))).scaled_local(Vector3(0.98, 0.36, 0.46)), p),
		"linen_lite" if id % 3 == 0 else "linen")

func _rock(p: Vector3, size: Vector3, yaw: float, key: String) -> void:
	_add(_cyl_mesh(0.32, 0.58, 1.0, 6), Transform3D(Basis.from_euler(Vector3(0.09, yaw, 0.12)).scaled_local(size), p), key)

func _stains(radius: float, height: float, phase: float, count: int) -> void:
	for i: int in range(count):
		var a: float = i * TAU / count + phase
		var p: Vector3 = Vector3(cos(a) * radius, height, sin(a) * radius)
		_box(p, Vector3(0.27 + abs(sin(i)) * 0.49, 0.022, 0.12 + abs(cos(i)) * 0.17), "stain", Vector3(0, a + 0.42, 0))
		if i % 3 == 0:
			_box(p + Vector3(0.1, 0.027, 0.05), Vector3(0.20, 0.035, 0.21), "grass", Vector3(0, a, 0))

func _box(p: Vector3, size: Vector3, key: String, r: Vector3 = Vector3.ZERO) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_add(mesh, Transform3D(Basis.from_euler(r), p), key)

func _cylinder(p: Vector3, top: float, bottom: float, height: float, key: String, segments: int) -> void:
	_add(_cyl_mesh(top, bottom, height, segments), Transform3D(Basis.IDENTITY, p), key)

func _cyl_mesh(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	return mesh

func _add(mesh: PrimitiveMesh, xform: Transform3D, key: String) -> void:
	var surface: SurfaceTool
	if not _surfaces.has(key):
		surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = surface
	else:
		surface = _surfaces[key]
	surface.append_from(mesh, 0, xform)
