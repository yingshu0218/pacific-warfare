extends "res://aircraft/visual_study/airframe_geometry.gd"
## Simplified B6N2 Model 12 exterior for the game model viewer, -Z forward.

const HALF_SPAN_M: float = 7.45
const HALF_LENGTH_M: float = 5.4325

var _skin: StandardMaterial3D
var _trim: StandardMaterial3D
var _glass: StandardMaterial3D
var _dark: StandardMaterial3D


func _ready() -> void:
	_skin = _paint(Color("738074"), true)
	_trim = _paint(Color("344a3d"))
	_glass = _paint(Color("334953"))
	_glass.roughness = 0.28
	_dark = _paint(Color("272f2d"))
	_build_fuselage()
	_build_wings()
	_build_tail()
	_build_canopy()
	_build_nose()


func _build_fuselage() -> void:
	# Exterior visual contours sampled coarsely from the silhouette, not airframe stations.
	var outline: Array[Vector4] = [
		Vector4(-4.39, 0.02, 0.768, 0.73), Vector4(-3.74, 0.02, 0.77, 0.75),
		Vector4(-2.94, 0.03, 0.77, 0.79), Vector4(-1.98, 0.02, 0.77, 0.81),
		Vector4(-0.72, 0.03, 0.75, 0.80), Vector4(0.48, 0.05, 0.70, 0.77),
		Vector4(1.40, 0.12, 0.60, 0.69), Vector4(2.47, 0.18, 0.49, 0.58),
		Vector4(3.47, 0.26, 0.36, 0.47), Vector4(4.23, 0.30, 0.26, 0.35),
		Vector4(5.03, 0.32, 0.15, 0.25), Vector4(5.39, 0.32, 0.045, 0.12),
	]
	_loft("Fuselage", _body_rings(outline), _skin)


func _build_wings() -> void:
	var plan: Array[Vector4] = [
		Vector4(0.40, -2.93, 0.59, 0.235), Vector4(0.78, -2.90, 0.51, 0.22),
		Vector4(2.0, -2.81, 0.28, 0.19), Vector4(3.57, -2.69, -0.10, 0.165),
		Vector4(5.10, -2.56, -0.41, 0.125), Vector4(6.26, -2.46, -0.66, 0.090),
		Vector4(7.00, -2.34, -0.98, 0.060), Vector4(7.27, -2.20, -1.23, 0.041),
		Vector4(7.40, -2.02, -1.48, 0.027), Vector4(HALF_SPAN_M, -1.83, -1.71, 0.012),
	]
	for side: float in [-1.0, 1.0]:
		_loft("Wing L" if side < 0.0 else "Wing R", _span_rings(plan, side, -0.38, 0.102), _skin)


func _build_tail() -> void:
	var plan: Array[Vector4] = [
		Vector4(0.07, 3.78, 5.38, 0.085), Vector4(0.60, 3.82, 5.36, 0.075),
		Vector4(1.73, 4.10, 5.21, 0.061), Vector4(2.49, 4.28, 5.08, 0.040),
		Vector4(2.76, 4.43, 4.95, 0.025), Vector4(2.85, 4.58, 4.76, 0.010),
	]
	for side: float in [-1.0, 1.0]:
		_loft("Stabilizer L" if side < 0.0 else "Stabilizer R", _span_rings(plan, side, 0.42, 0.015), _skin)
	# Rounded top and visibly forward-raked trailing profile.
	var fin: Array[Vector4] = [
		Vector4(0.33, 3.23, HALF_LENGTH_M, 0.115), Vector4(0.66, 3.72, 5.39, 0.108),
		Vector4(1.00, 3.91, 5.31, 0.09), Vector4(1.59, 4.13, 5.17, 0.071),
		Vector4(1.94, 4.31, 5.00, 0.049), Vector4(2.10, 4.52, 4.78, 0.022),
	]
	var rings: Array[PackedVector3Array] = []
	for row: Vector4 in fin:
		var rim := PackedVector3Array()
		for step: int in range(SECTION_POINTS):
			var a: float = TAU * float(step) / SECTION_POINTS
			rim.append(Vector3(row.w * sin(a), row.x, lerpf(row.y, row.z, (1.0 + cos(a)) * 0.5)))
		rings.append(rim)
	_loft("Vertical fin", rings, _skin)


func _build_canopy() -> void:
	# One continuous low canopy with no aft spherical blister.
	var glass: Array[Vector4] = [
		Vector4(-2.63, 0.78, 0.29, 0.12), Vector4(-2.18, 0.85, 0.43, 0.31),
		Vector4(-1.89, 0.86, 0.45, 0.35), Vector4(-1.11, 0.83, 0.45, 0.35),
		Vector4(-0.29, 0.82, 0.43, 0.35), Vector4(0.41, 0.81, 0.41, 0.33),
		Vector4(0.96, 0.79, 0.38, 0.30), Vector4(1.24, 0.76, 0.33, 0.24),
		Vector4(1.46, 0.75, 0.18, 0.12), Vector4(1.54, 0.75, 0.07, 0.04),
	]
	_loft("Canopy glazing", _body_rings(glass), _glass)
	for index: int in [1, 2, 3, 4, 5, 6, 7]:
		var s: Vector4 = glass[index]
		var ribs: Array[Vector4] = [
			Vector4(s.x - 0.020, s.y, s.z + 0.012, s.w + 0.015),
			Vector4(s.x + 0.020, s.y, s.z + 0.012, s.w + 0.015),
		]
		_loft("Canopy bow %d" % index, _body_rings(ribs), _trim, false)


func _build_nose() -> void:
	var cowling: Array[Vector4] = [
		Vector4(-4.92, 0.02, 0.54, 0.51), Vector4(-4.87, 0.02, 0.61, 0.58),
		Vector4(-4.77, 0.02, 0.70, 0.65), Vector4(-4.60, 0.02, 0.75, 0.71),
		Vector4(-4.39, 0.02, 0.768, 0.73),
	]
	_loft("Dark cowling", _body_rings(cowling), _dark)
	var spinner: Array[Vector4] = [
		Vector4(-HALF_LENGTH_M, 0.02, 0.018, 0.018), Vector4(-5.35, 0.02, 0.095, 0.095),
		Vector4(-5.22, 0.02, 0.17, 0.17), Vector4(-5.04, 0.02, 0.225, 0.225),
		Vector4(-4.88, 0.02, 0.243, 0.243),
	]
	_loft("Spinner", _body_rings(spinner), _trim)
	for index: int in range(4):
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.02, -5.06)
		pivot.rotation.z = 0.32 + float(index) * TAU / 4.0
		add_child(pivot)
		var shape: Array[Vector4] = [
			Vector4(0.15, -0.03, 0.05, 0.03), Vector4(0.51, -0.105, 0.09, 0.031),
			Vector4(1.24, -0.13, 0.11, 0.023), Vector4(1.54, -0.085, 0.085, 0.017),
			Vector4(1.68, -0.032, 0.044, 0.009),
		]
		var rings: Array[PackedVector3Array] = []
		for blade: Vector4 in shape:
			var rim := PackedVector3Array()
			for step: int in range(SECTION_POINTS):
				var a: float = TAU * float(step) / SECTION_POINTS
				rim.append(Vector3(lerpf(blade.y, blade.z, (1.0 + cos(a)) * 0.5), blade.x, blade.w * sin(a)))
			rings.append(rim)
		var piece := _loft("Propeller blade", rings, _dark)
		piece.reparent(pivot, false)


func _vertex(surface: SurfaceTool, point: Vector3) -> void:
	var u: float = smoothstep(-0.58, -0.22, point.y)
	surface.set_color(Color("e4e7e4").lerp(Color("7e9d83"), u))
	surface.add_vertex(point)
