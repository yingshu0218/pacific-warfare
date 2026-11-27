extends "res://aircraft/visual_study/airframe_geometry.gd"
## Static game silhouette, 1944 reference class. Meters; nose toward -Z.
## No combat registration, payloads, flight behavior or engineering geometry.

const BODY_LENGTH_M: float = 12.50
const HALF_SPAN_M: float = 8.255

var _blue: StandardMaterial3D
var _navy: StandardMaterial3D
var _canopy: StandardMaterial3D
var _prop: StandardMaterial3D


func _ready() -> void:
	_blue = _paint(Color("49667a"), true)
	_navy = _paint(Color("324a61"))
	_canopy = _paint(Color("263944"))
	_canopy.roughness = 0.30
	_prop = _paint(Color("222a30"))
	_body()
	_wing()
	_tail()
	_cockpit()
	_nose()


func _body() -> void:
	# z, vertical center, horizontal radius, vertical radius; visual estimates
	# from July 1943 arrangement and 1944 photographs, not structure stations.
	var outline: Array[Vector4] = [
		Vector4(-5.92, 0.15, 0.71, 0.74), Vector4(-5.76, 0.15, 0.83, 0.84),
		Vector4(-5.38, 0.15, 0.88, 0.91), Vector4(-4.76, 0.13, 0.91, 1.02),
		Vector4(-3.90, 0.09, 0.95, 1.15), Vector4(-2.95, 0.05, 0.96, 1.24),
		Vector4(-1.80, 0.00, 0.96, 1.29), Vector4(-0.65, -0.01, 0.94, 1.28),
		Vector4(0.65, -0.02, 0.87, 1.17), Vector4(1.75, 0.03, 0.75, 1.01),
		Vector4(3.00, 0.13, 0.60, 0.79), Vector4(4.22, 0.25, 0.40, 0.55),
		Vector4(5.37, 0.39, 0.25, 0.37), Vector4(6.08, 0.48, 0.12, 0.19),
	]
	_loft("Fuselage", _body_rings(outline), _blue)


func _cockpit() -> void:
	# Long stepped, framed canopy. The rounded rear blister is bare glazing.
	var glass: Array[Vector4] = [
		Vector4(-3.66, 0.97, 0.32, 0.12), Vector4(-3.43, 1.07, 0.50, 0.40),
		Vector4(-3.10, 1.10, 0.57, 0.63), Vector4(-2.62, 1.10, 0.61, 0.68),
		Vector4(-1.65, 1.10, 0.61, 0.66), Vector4(-0.62, 1.08, 0.59, 0.65),
		Vector4(-0.04, 1.05, 0.55, 0.59), Vector4(0.18, 1.02, 0.47, 0.40),
	]
	var rings: Array[PackedVector3Array] = _body_rings(glass)
	_loft("Canopy glazing", rings, _canopy)
	for index: int in [1, 2, 3, 4, 5, 6]:
		var station: Vector4 = glass[index]
		var a := Vector4(station.x - 0.023, station.y, station.z + 0.014, station.w + 0.018)
		var b := Vector4(station.x + 0.023, station.y, station.z + 0.014, station.w + 0.018)
		var strip: Array[Vector4] = [a, b]
		_loft("Canopy bow %d" % index, _body_rings(strip), _navy, false)
	var blister := SphereMesh.new()
	blister.radial_segments = 24
	blister.rings = 12
	blister.radius = 0.56
	blister.height = 1.12
	var bubble := _mesh("Rear glazed blister", blister, _canopy)
	bubble.position = Vector3(0.0, 1.26, 0.54)
	bubble.scale = Vector3(1.07, 0.88, 1.12)


func _wing() -> void:
	# x, leading z, trailing z, half thickness; broad inboard panels and tapered outer wings.
	var outline: Array[Vector4] = [
		Vector4(0.48, -3.38, 0.54, 0.24), Vector4(1.28, -3.38, 0.54, 0.26),
		Vector4(2.34, -3.32, 0.53, 0.23), Vector4(4.75, -2.95, -0.08, 0.16),
		Vector4(7.67, -2.51, -0.73, 0.095), Vector4(8.08, -2.45, -0.83, 0.061),
		Vector4(HALF_SPAN_M, -2.23, -1.02, 0.029),
	]
	for side: float in [-1.0, 1.0]:
		_loft("Wing L" if side < 0.0 else "Wing R", _span_rings(outline, side, -0.29, 0.085), _blue)


func _tail() -> void:
	var outline: Array[Vector4] = [
		Vector4(0.11, 4.15, 5.94, 0.107), Vector4(1.53, 4.43, 5.83, 0.081),
		Vector4(2.63, 4.63, 5.65, 0.060), Vector4(3.10, 4.88, 5.44, 0.030),
		Vector4(3.17, 5.00, 5.31, 0.018),
	]
	for side: float in [-1.0, 1.0]:
		_loft("Stabilizer L" if side < 0.0 else "Stabilizer R", _span_rings(outline, side, 0.61, 0.045), _blue)
	var fin: Array[Vector4] = [
		Vector4(0.57, 3.63, BODY_LENGTH_M - 6.25, 0.168), Vector4(1.11, 4.18, 6.23, 0.145),
		Vector4(1.67, 4.55, 6.11, 0.105), Vector4(2.21, 4.82, 5.95, 0.080),
		Vector4(2.54, 5.03, 5.78, 0.048), Vector4(2.62, 5.18, 5.59, 0.023),
	]
	var rings: Array[PackedVector3Array] = []
	for station: Vector4 in fin:
		var rim := PackedVector3Array()
		for index: int in range(SECTION_POINTS):
			var a: float = TAU * float(index) / SECTION_POINTS
			rim.append(Vector3(station.w * sin(a), station.x, lerpf(station.y, station.z, (1.0 + cos(a)) * 0.5)))
		rings.append(rim)
	_loft("Vertical fin", rings, _blue)


func _nose() -> void:
	var dark_face := CylinderMesh.new()
	dark_face.top_radius = 0.68
	dark_face.bottom_radius = 0.70
	dark_face.height = 0.09
	dark_face.radial_segments = 36
	var cover := _mesh("Dark cowling face", dark_face, _prop)
	cover.rotation.x = PI * 0.5
	cover.position = Vector3(0.0, 0.15, -5.92)
	var cap := SphereMesh.new()
	cap.radius = 0.18
	cap.height = 0.36
	cap.radial_segments = 24
	cap.rings = 12
	var hub := _mesh("Propeller hub", cap, _navy)
	hub.position = Vector3(0.0, 0.15, -6.07)
	for index: int in range(3):
		var pivot := Node3D.new()
		pivot.position = Vector3(0.0, 0.15, -6.03)
		pivot.rotation.z = TAU * float(index) / 3.0 + 0.36
		add_child(pivot)
		var blades: Array[Vector4] = [
			Vector4(0.12, -0.038, 0.040, 0.034),
			Vector4(0.52, -0.128, 0.117, 0.043),
			Vector4(1.54, -0.166, 0.131, 0.028),
			Vector4(1.99, -0.041, 0.042, 0.013),
		]
		var rings: Array[PackedVector3Array] = []
		for blade: Vector4 in blades:
			var rim := PackedVector3Array()
			for step: int in range(SECTION_POINTS):
				var angle: float = TAU * float(step) / SECTION_POINTS
				rim.append(Vector3(lerpf(blade.y, blade.z, (1.0 + cos(angle)) * 0.5), blade.x, blade.w * sin(angle)))
			rings.append(rim)
		var blade_mesh := _loft("Propeller blade", rings, _prop)
		blade_mesh.reparent(pivot, false)
