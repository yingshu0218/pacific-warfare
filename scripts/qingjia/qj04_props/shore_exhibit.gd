extends "res://scripts/qingjia/qj03_props/coastland_exterior.gd"
## QJ04 static scenery only. The maritime heritage profile is intentionally
## solid, with no collision, actor, moving parts, or actual weapon geometry.

func _ready() -> void:
	super._ready()
	if variant == 1:
		var gray: Dictionary = {
			"cement": Color("878a89"),
			"edge": Color("9fa2a1"),
			"dark_cement": Color("687071"),
			"ground": Color("494e4c"),
			"stain": Color("737a76"),
		}
		for mesh: MeshInstance3D in get_children():
			var key: String = mesh.name.trim_prefix("Matte_")
			if gray.has(key):
				var finish: StandardMaterial3D = mesh.material_override
				finish.albedo_color = gray[key]
				finish.roughness = 0.96

func _open_plinth() -> void:
	# Three staggered, shaded rows make a single legible circle from above.
	_cylinder(Vector3(0, .15, 0), 5.15, 5.32, .30, "ground", 24)
	_cylinder(Vector3(0, .29, 0), 4.52, 4.75, .20, "dark_cement", 22)
	_cylinder(Vector3(0, .43, 0), 4.03, 4.40, .15, "cement", 22)
	for row: int in range(3):
		for slot: int in range(24):
			var angle: float = (slot + .5 * (row % 2)) * TAU / 24.0
			var radius: float = 4.51 - row * .13
			var p: Vector3 = Vector3(cos(angle) * radius, .48 + row * .27, sin(angle) * radius)
			_ring_bag(p, -angle + PI * .5, 24 * row + slot)
	_cylinder(Vector3(0, .66, .13), 1.15, 1.55, .31, "dark_cement", 12)
	_cylinder(Vector3(0, .86, .13), 1.06, 1.24, .13, "metal_lite", 12)
	_piti_silhouette(Vector3(0, .94, .11))
	_stains(3.31, .515, .41, 13)
	_crate(Vector3(-2.47, .51, 1.39), -.23)
	_crate(Vector3(-2.71, .51, 2.15), .11)

func _shielded_housing() -> void:
	# A sculpted, blocked-in shell with a matte shadow band instead of an interior.
	_box(Vector3(0, .15, 0), Vector3(10.35, .3, 8.94), "ground")
	_box(Vector3(0, .32, .04), Vector3(9.72, .28, 8.27), "dark_cement")
	_box(Vector3(0, .48, .08), Vector3(9.24, .16, 7.92), "cement")
	_box(Vector3(0, 1.93, .92), Vector3(7.91, 2.9, 4.93), "cement")
	_box(Vector3(0, 3.48, .90), Vector3(8.33, .50, 5.27), "edge")
	_box(Vector3(0, 3.76, .93), Vector3(7.86, .14, 4.96), "cement")
	_box(Vector3(0, 2.14, -1.552), Vector3(5.47, .86, .036), "black")
	_box(Vector3(0, 1.68, -1.56), Vector3(6.95, .24, .25), "dark_cement")
	_box(Vector3(0, 2.66, -1.66), Vector3(6.99, .20, .37), "dark_cement")
	for side: int in [-1, 1]:
		_box(Vector3(side * 3.58, 1.98, -1.68), Vector3(.86, 2.50, .50), "cement")
		_box(Vector3(side * 3.91, .97, -.77), Vector3(.62, 1.0, 2.24), "dark_cement", Vector3(0, side * -.08, 0))
		_box(Vector3(side * 4.00, .59, -1.87), Vector3(.60, .19, .71), "edge")
		_crate(Vector3(side * 3.57, .56, -2.85), side * .23)
	_six_inch_silhouette(Vector3(0, 1.34, -.99))
	_weathering()
	_stains(2.78, .568, .97, 11)

func _ring_bag(p: Vector3, yaw: float, idx: int) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radial_segments = 9
	mesh.rings = 4
	mesh.radius = .5
	mesh.height = 1.0
	var length: float = 1.28 + .06 * cos(float(idx) * 1.42)
	var tilt: float = .075 * sin(float(idx) * 1.81)
	var basis: Basis = Basis.from_euler(Vector3(.03, yaw + tilt, tilt)).scaled_local(Vector3(length, .35, .66))
	_add(mesh, Transform3D(basis, p), "linen_lite" if idx % 5 < 2 else "linen")

func _weathering() -> void:
	# Tiny colored flakes are painted visual variation; no openings or joints.
	for i: int in range(22):
		var x: float = lerpf(-3.65, 3.65, float(i) / 21.0)
		var height: float = .06 + .24 * abs(sin(i * 1.39))
		_box(Vector3(x, 2.92 - .09 * cos(i), -1.560), Vector3(.04 + .1 * abs(sin(i)), height, .021),
			"stain", Vector3(0, 0, .09 * sin(i)))
	for i: int in range(26):
		var x: float = 3.68 * sin(i * 2.394)
		var z: float = .85 + 2.23 * cos(i * 1.674)
		_box(Vector3(x, 3.837, z), Vector3(.08 + abs(sin(i)) * .20, .016, .06 + abs(cos(i * 1.39)) * .14),
			"stain" if i % 3 == 0 else "dark_cement", Vector3(0, i * .78, 0))
	for side: int in [-1, 1]:
		for i: int in range(14):
			var z: float = -.99 + float(i) * .30
			var y: float = .87 + abs(sin(i * 1.64)) * 2.13
			_box(Vector3(side * 3.963, y, z), Vector3(.024, .06 + abs(cos(i)) * .25, .08 + abs(sin(i)) * .07),
				"stain", Vector3(side * sin(i) * .07, 0, 0))
