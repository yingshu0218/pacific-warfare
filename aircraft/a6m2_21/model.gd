extends "res://aircraft/scripts/aircraft_builder.gd"
## Independent, non-simulated exterior of an early Model 21, in model-space metres.

const PAINT := Color("bebda8")
const GEAR := preload("res://aircraft/visual_study/gear_pose.gd")
var gear_pivots: Array[Node3D] = []

func _configure() -> void:
	spec = {
		"id": "a6m2_21",
		"name": "Mitsubishi A6M2 Model 21",
		"length_m": 9.06,
		"span_m": 12.0,
		"height_m": 3.51,
		"top_color": PAINT,
		"bottom_color": PAINT,
		"frame_color": Color("aaa990"),
		"seam_color": Color("858472"),
		"vertex_paint_wings": true,
		"piecewise_wing_profile": true,
	}
	# Separate outer-panel break and gradual elliptic terminal cap.
	wing_profile = [
		Vector4(0.24, 2.67, -1.86, 1.44), Vector4(1.14, 2.43, -1.79, 1.46),
		Vector4(2.25, 2.13, -1.70, 1.52), Vector4(3.32, 1.87, -1.59, 1.62),
		Vector4(4.30, 1.63, -1.49, 1.72), Vector4(4.88, 1.44, -1.42, 1.78),
		Vector4(5.50, 1.24, -1.33, 1.84), Vector4(5.68, 1.11, -1.27, 1.86),
		Vector4(5.81, 0.93, -1.19, 1.876), Vector4(5.91, 0.70, -1.10, 1.886),
		Vector4(5.965, 0.49, -1.00, 1.892), Vector4(5.99, 0.28, -0.89, 1.896),
		Vector4(6.0, 0.07, -0.77, 1.898)
	]
	wing_thickness_profile = [
		Vector2(0.24, 0.145), Vector2(1.46, 0.140), Vector2(2.32, 0.127),
		Vector2(4.31, 0.100), Vector2(5.50, 0.090), Vector2(6.0, 0.085)
	]
	tail_profile = [
		Vector4(0.09, 1.24, 3.16, 1.94), Vector4(0.65, 1.12, 3.23, 1.985),
		Vector4(1.14, 0.91, 3.33, 2.027), Vector4(1.44, 0.63, 3.48, 2.057),
		Vector4(1.64, 0.30, 3.62, 2.077), Vector4(1.67, 0.06, 3.74, 2.08)
	]

func _build_model() -> void:
	_build_fuselage([
		Vector4(1.79, .28, .31, -4.02), Vector4(1.74, .51, .55, -3.81),
		Vector4(1.67, .552, .593, -3.17), Vector4(1.635, .526, .559, -2.41),
		Vector4(1.61, .514, .548, -1.69), Vector4(1.605, .497, .515, -.60),
		Vector4(1.635, .449, .478, .48), Vector4(1.69, .362, .373, 1.55),
		Vector4(1.748, .27, .284, 2.57), Vector4(1.793, .180, .189, 3.47),
		Vector4(1.826, .108, .118, 4.05), Vector4(1.835, .024, .036, 4.515)
	])
	control_surfaces = _new_group(self, "Control surfaces")
	for side: float in [-1.0, 1.0]:
		var label := "Port" if side < 0.0 else "Starboard"
		_build_wing(wing_profile, side, self, materials["top"], label + " mainplane", 80)
		_build_wing(tail_profile, side, self, materials["top"], label + " tailplane", 26)
		_add_hinged_wing_control(label + " aileron", wing_profile, side, 2.84, 5.49, .764, .995, materials["control"])
		_add_hinged_wing_control(label + " elevator", tail_profile, side, .36, 1.53, .69, .994, materials["control"])
		_add_panel_line(side, 5.49, .02, .98, "Folding tip joint", .0075)
		_add_panel_line(side, 2.79, .71, .98, "Outboard flap seam")
		_add_panel_line(side, 1.16, .10, .59, "Inner skin joint")
		_add_panel_line(side, 3.52, .09, .71, "Outer skin joint")
		_add_panel_line(side, 4.68, .15, .71, "Outer panel joint")
		_add_wing_disc("Upper wing hinomaru", side, 3.71, -.625, _wing_y(wing_profile, 3.71, -.625) + .012, .503, materials["insignia_red"])
		_add_lower_roundel(side, 3.71, -.625, .503)
		_add_conformal_side_patch("Fuselage hinomaru", side, 1.18, 1.722, _circle(.345, 48), materials["insignia_red"], .013)
		_add_light(self, label + " tip lens", Vector3(side * 5.891, 1.891, -1.013), materials["lamp_red"] if side < 0 else materials["lamp_green"])

	_add_extruded_side_shape(self, "Fin", PackedVector2Array([
		Vector2(3.04, 1.80), Vector2(3.42, 2.13), Vector2(3.62, 2.51),
		Vector2(3.79, 3.16), Vector2(3.89, 3.43), Vector2(4.02, 3.51),
		Vector2(4.13, 3.46), Vector2(4.20, 3.28), Vector2(4.37, 2.47),
		Vector2(4.50, 1.86)
	]), .139, materials["top"])
	_add_hinged_fin_rudder("Fabric rudder", PackedVector2Array([
		Vector2(4.02, 3.473), Vector2(4.12, 3.453), Vector2(4.21, 3.26),
		Vector2(4.36, 2.49), Vector2(4.49, 1.89), Vector2(4.34, 1.91),
		Vector2(4.19, 2.49), Vector2(4.08, 3.16)
	]), 4.17, 2.45, materials["control"], .143)
	_add_nose()
	_add_early_canopy()
	_add_main_gear_pair(1.44, 1.17, -.66, .294, 1.54)
	_add_gear_door_faces()
	_add_tailwheel(Vector3(0.0, 1.275, 3.64), .128, 1.634)
	gear_pivots = [
		landing_gear.get_node("Main gear left"),
		landing_gear.get_node("Main gear right"),
		GEAR.move_about_attachment(landing_gear.get_node("Tail wheel assembly"), Vector3(0., .359, -.16)),
	]
	_add_beam(self, "Radio mast", Vector3(0, 2.40, -.09), Vector3(0, 2.91, -.013), .030, materials["frame"], .019, 10)
	_add_beam(self, "Aerial wire", Vector3(0, 2.91, -.013), Vector3(0, 3.46, 4.055), .0045, materials["dark_steel"], .0045, 6)

func _add_nose() -> void:
	var cowl := _material(Color("272c2e"), .06, .48)
	_add_cowling(-4.13, -3.40, 1.82, .574, .564, cowl, "Early black cowling")
	_add_annulus(self, "Recessed intake lip", .487, .361, 1.82, -4.134, cowl)
	_add_cylinder(self, "Shadow behind intake", .477, .020, Vector3(0, 1.82, -3.98), materials["black"], "z", 48)
	var blades := _material(Color("96958e"), .33, .44)
	_add_propeller(3, 2.90, Vector3(0, 1.82, -4.105), blades)
	for side: float in [-1.0, 1.0]:
		var cover := _add_sphere(self, "Collector outlet fairing", .12, Vector3(side * .41, 1.44, -3.31), cowl, Vector3(1.08, .67, 1.37))
		cover.rotation.y = side * .23
		_add_cylinder(self, "Recessed collector opening", .062, .018, Vector3(side * .46, 1.428, -3.215), materials["black"], "z", 20)
	var intake := _add_sphere(self, "Lower intake fairing", .216, Vector3(0, 1.304, -3.873), cowl, Vector3(.80, .54, 1.5))
	intake.rotation.x = -.08
	_add_cylinder(self, "Lower intake shadow", .095, .018, Vector3(0, 1.294, -4.085), materials["black"], "z", 24)

func _add_early_canopy() -> void:
	var glazing: Array[Vector4] = [
		Vector4(2.05, .265, .051, -2.31), Vector4(2.07, .33, .280, -2.13),
		Vector4(2.075, .407, .475, -1.84), Vector4(2.077, .442, .499, -1.51),
		Vector4(2.08, .435, .491, -1.02), Vector4(2.091, .415, .433, -.58),
		Vector4(2.105, .376, .345, -.20), Vector4(2.104, .295, .215, .29),
		Vector4(2.100, .203, .082, .57), Vector4(2.077, .075, .013, .725)
	]
	_add_canopy(glazing, "Framed Model 21 glazing", materials["frame"], 8)
	_add_cockpit_interior(Vector3(0, 2.038, -1.19), .34, .43, _material(Color("535d45"), .0, .75))
	for side: float in [-1.0, 1.0]:
		var rail: PackedVector3Array
		for i in range(32):
			var f := i / 31.0
			var station := _sample_station(glazing, lerpf(-2.19, .61, f))
			rail.append(Vector3(side * station.y * .886, station.x + station.z * .464 + .007, station.w))
		_add_tube_line(self, "Longitudinal canopy frame", rail, .013, materials["frame"])

func _add_panel_line(side: float, span: float, start: float, finish: float, label: String, radius: float = .003) -> void:
	var points: PackedVector3Array
	for i in range(12):
		points.append(_wing_surface_point(side, span, lerpf(start, finish, i / 11.0), .005))
	_add_tube_line(self, label, points, radius, materials["seam"])

func _circle(radius: float, count: int) -> PackedVector2Array:
	var points: PackedVector2Array
	for i in range(count):
		var theta := TAU * i / count
		points.append(Vector2(cos(theta), sin(theta)) * radius)
	return points

func _add_lower_roundel(side: float, span: float, z: float, radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := _paint_under_point(side * span, z)
	var ring := _circle(radius, 48)
	for i in range(ring.size()):
		st.add_vertex(center)
		st.add_vertex(_paint_under_point(side * span + ring[i].x, z + ring[i].y))
		st.add_vertex(_paint_under_point(side * span + ring[(i + 1) % ring.size()].x, z + ring[(i + 1) % ring.size()].y))
	st.generate_normals()
	_part(self, "Lower wing hinomaru", st.commit(), materials["insignia_red"])

func _paint_under_point(x: float, z: float) -> Vector3:
	var section := _sample_wing_profile(wing_profile, absf(x))
	var frac := clampf((z - section.z) / section.y, .001, .999)
	var y := section.w + _airfoil_height(frac, section.y, _wing_thickness_ratio(wing_profile, absf(x)), false)
	return Vector3(x, y - .012, z)


func _add_gear_door_faces() -> void:
	for side: float in [-1.0, 1.0]:
		var root := Vector3(side * 1.17, 1.43, -.66)
		var end := Vector3(side * 1.57, .43, -.53)
		var outline := PackedVector3Array([
			root + Vector3(side * .063, .0, -.215),
			root + Vector3(side * .063, .0, .234),
			end + Vector3(side * .055, -.036, .152),
			end + Vector3(side * .055, -.18, -.06),
			end + Vector3(side * .055, -.016, -.225),
		])
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1, outline.size() - 1):
			for j: int in [0, i, i + 1]:
				st.add_vertex(outline[j])
		st.generate_normals()
		var door := _part(self, "Main strut door outer skin", st.commit(), materials["bottom"])
		door.reparent(landing_gear.get_node("Main gear left" if side < 0.0 else "Main gear right"), true)


func set_landing_gear_fraction(value: float) -> void:
	if gear_pivots.size() != 3:
		return
	GEAR.pose(gear_pivots[0], Vector3(0, 0, PI * .49), value)
	GEAR.pose(gear_pivots[1], Vector3(0, 0, -PI * .49), value)
	GEAR.pose(gear_pivots[2], Vector3(-PI * .51, 0, 0), value)
