extends "res://aircraft/scripts/aircraft_builder.gd"


func _configure() -> void:
	spec = {
		"id": "f6f5",
		"name": "Grumman F6F-5 Hellcat",
		"short_name": "F6F-5 Hellcat",
		"nation": "United States",
		"service_year": "1944–1945",
		"length_m": 10.236,
		"span_m": 13.056,
		"height_m": 3.99,
		"top_color": Color("273d56"),
		"bottom_color": Color("273d56"),
		"frame_color": Color("1e3248"),
		"seam_color": Color("172c43"),
		"prop_y": 2.52,
		"fuselage_mark_x": 0.69,
		"vertex_paint_wings": true,
		"piecewise_wing_profile": true,
		"wing_fold_station_m": 3.52,
		"wing_fold_lower_sweep_m": 0.36,
		"engine": "Pratt & Whitney R-2800-10W, 18-cylinder radial, water injection",
		"armament": "6 × .50 in Browning M2 machine guns, 400 rounds per gun",
		"profile_note": "Gloss Sea Blue finish, bullet-resistant flat windscreen, hydraulic Sto-Wing panels"
	}
	wing_profile = [
		Vector4(0.32, 3.85, -1.90, 2.12), Vector4(0.90, 3.45, -1.88, 2.12),
		Vector4(1.48, 3.05, -1.84, 2.12), Vector4(2.80, 2.60, -1.71, 2.12),
		Vector4(3.52, 2.36, -1.64, 2.12), Vector4(4.22, 2.18, -1.56, 2.21),
		Vector4(5.35, 1.90, -1.45, 2.36), Vector4(5.95, 1.72, -1.36, 2.44),
		Vector4(6.20, 1.50, -1.24, 2.47), Vector4(6.36, 1.20, -1.08, 2.49),
		Vector4(6.46, 0.90, -0.95, 2.50), Vector4(6.52, 0.40, -0.68, 2.51),
		Vector4(6.528, 0.02, -0.49, 2.51)
	]
	wing_thickness_profile = [
		Vector2(0.32, 0.156), Vector2(1.48, 0.150), Vector2(3.52, 0.125),
		Vector2(5.35, 0.102), Vector2(6.528, 0.090)
	]
	tail_profile = [
		Vector4(0.16, 1.46, 3.66, 2.44), Vector4(0.92, 1.38, 3.72, 2.46),
		Vector4(1.70, 0.95, 3.93, 2.52), Vector4(2.18, 0.44, 4.20, 2.58),
		Vector4(2.30, 0.08, 4.38, 2.59)
	]


func _build_model() -> void:
	if flight_simplified:
		materials["us_red"] = materials["top"] # late-war blue/white markings
		dorsal_profile = [Vector2(-4.62,0),Vector2(-2,0),Vector2(-0.8,0.04),Vector2(0.4,0.20),Vector2(1.0,0.30),Vector2(1.6,0.27),Vector2(2.6,0.20),Vector2(3.7,0.08),Vector2(4.8,0),Vector2(5.12,0)]
	var fuselage: Array[Vector4] = [
		Vector4(2.51, 0.035, 0.055, -4.62), Vector4(2.48, 0.27, 0.33, -4.50),
		Vector4(2.45, 0.69, 0.70, -4.28), Vector4(2.40, 0.86, 0.82, -3.82),
		Vector4(2.36, 0.83, 0.81, -3.10), Vector4(2.31, 0.79, 0.79, -2.20),
		Vector4(2.30, 0.75, 0.76, -1.12), Vector4(2.32, 0.72, 0.72, 0.15),
		Vector4(2.39, 0.62, 0.64, 1.44), Vector4(2.47, 0.47, 0.49, 2.63),
		Vector4(2.53, 0.32, 0.35, 3.70), Vector4(2.57, 0.17, 0.20, 4.58),
		Vector4(2.59, 0.035, 0.055, 5.12)
	]
	_build_fuselage(fuselage, "Wide Grumman fuselage")
	_build_wing(wing_profile, -1.0, self, materials["top"], "Port folding wing")
	_build_wing(wing_profile, 1.0, self, materials["top"], "Starboard folding wing")
	_build_wing(tail_profile, -1.0, self, materials["top"], "Port horizontal stabilizer", 26)
	_build_wing(tail_profile, 1.0, self, materials["top"], "Starboard horizontal stabilizer", 26)
	_add_extruded_side_shape(_damage_parent_id("tail"), "Vertical stabilizer", PackedVector2Array([
		Vector2(3.50, 2.47), Vector2(4.91, 2.44), Vector2(5.05, 2.55), Vector2(5.00, 2.94),
		Vector2(4.77, 3.57), Vector2(4.57, 3.91), Vector2(4.40, 3.99), Vector2(4.14, 3.80), Vector2(3.83, 3.16)
	]), 0.20, materials["top"])
	control_surfaces = _new_group(self, "Control surfaces")
	_add_hinged_wing_control("Port aileron", wing_profile, -1.0, 3.52, 6.34, 0.76, 0.99, materials["control"])
	_add_hinged_wing_control("Starboard aileron", wing_profile, 1.0, 3.52, 6.34, 0.76, 0.99, materials["control"])
	_add_hinged_wing_control("Port inboard flap", wing_profile, -1.0, 0.46, 2.30, 0.62, 0.99, materials["control"])
	_add_hinged_wing_control("Starboard inboard flap", wing_profile, 1.0, 0.46, 2.30, 0.62, 0.99, materials["control"])
	_add_hinged_wing_control("Port outboard flap", wing_profile, -1.0, 2.30, 3.35, 0.69, 0.98, materials["control"])
	_add_hinged_wing_control("Starboard outboard flap", wing_profile, 1.0, 2.30, 3.35, 0.69, 0.98, materials["control"])
	_add_hinged_wing_control("Port elevator", tail_profile, -1.0, 0.42, 2.17, 0.71, 0.99, materials["control"])
	_add_hinged_wing_control("Starboard elevator", tail_profile, 1.0, 0.42, 2.17, 0.71, 0.99, materials["control"])
	var rudder_outline := PackedVector2Array([
		Vector2(4.85, 2.58), Vector2(5.02, 2.63), Vector2(4.99, 2.96),
		Vector2(4.76, 3.59), Vector2(4.58, 3.88), Vector2(4.45, 3.87), Vector2(4.61, 3.02)
	])
	_add_hinged_fin_rudder("Movable rudder", rudder_outline, 4.66, 2.63, materials["control"])
	_add_cowling(-4.63, -3.65, 2.54, 0.93, 0.88, materials["top"], "R-2800 cowling")
	if not flight_simplified:
		_add_radial_engine("Pratt & Whitney R-2800-10W", 18, 0.66, 0.66, -4.63)
	if not flight_simplified:
		_add_hellcat_cowl_flaps()
	_add_hellcat_exhausts()
	_add_hellcat_air_intake()
	_add_hellcat_guns()
	_add_propeller(3, 3.99, Vector3(0.0, float(spec["prop_y"]), -4.68), materials["dark_steel"])
	_add_hellcat_canopy()
	if not flight_simplified:
		_add_cockpit_interior(Vector3(0.0, 3.00, -1.36), 0.54, 0.62, materials["dark_steel"])
	_add_main_gear_pair(2.12, 1.58, -0.22, 0.43, 1.93)
	_add_tailwheel(Vector3(0.0, 0.15, 4.52), 0.15, 2.37)
	_add_hellcat_marks()
	if not flight_simplified:
		_add_hellcat_panel_detail()


func _add_hellcat_cowl_flaps() -> void:
	for index in range(16):
		var angle: float = TAU * float(index) / 16.0
		var root := Vector3(cos(angle) * 0.82, 2.54 + sin(angle) * 0.78, -3.66)
		var tip := Vector3(cos(angle) * 0.87, 2.54 + sin(angle) * 0.83, -3.39)
		_add_beam(self, "Adjustable cowl flap %02d" % index, root, tip, 0.034, materials["dark_steel"], 0.031, 8)


func _add_hellcat_exhausts() -> void:
	for side in [-1.0, 1.0]:
		for index in range(6):
			var z: float = -3.92 + float(index) * 0.17
			var y: float = 2.25 - float(index) * 0.035
			var root := Vector3(side * 0.79, y, z)
			var end := Vector3(side * 0.92, y - 0.05, z - 0.18)
			_add_beam(self, "R-2800 exhaust stack %s %02d" % ["L" if side < 0.0 else "R", index], root, end, 0.064, materials["exhaust"], 0.058, 10)
			_add_cylinder(self, "Exhaust opening", 0.043, 0.016, end, materials["black"], "z", 12)


func _add_hellcat_air_intake() -> void:
	var scoop := _add_sphere(self, "Under-cowl carburettor scoop", 1.0, Vector3(0.0, 1.62, -4.19), materials["top"], Vector3(0.50, 0.34, 0.46))
	scoop.rotation.x = -0.05
	_add_cylinder(self, "Chin intake mouth", 0.235, 0.045, Vector3(0.0, 1.56, -4.46), materials["black"], "z", 28)
	_add_cylinder(self, "Oil cooler intake port L", 0.12, 0.040, Vector3(-0.62, 1.97, -4.37), materials["black"], "z", 20)
	_add_cylinder(self, "Oil cooler intake port R", 0.12, 0.040, Vector3(0.62, 1.97, -4.37), materials["black"], "z", 20)


func _add_hellcat_guns() -> void:
	for side in [-1.0, 1.0]:
		for gun_index in range(3):
			var x: float = 2.35 + float(gun_index) * 0.38
			var wing := _sample_wing_profile(wing_profile, x)
			var z: float = wing.z + 0.10
			var y: float = wing.w + 0.025
			_add_cylinder(_wing_damage_parent(side), "Browning M2 barrel %s %02d" % ["L" if side < 0.0 else "R", gun_index + 1], 0.033, 0.66, Vector3(side * x, y, wing.z + 0.15), materials["dark_steel"], "z", 10)
			_add_cylinder(_wing_damage_parent(side), "Browning muzzle %s %02d" % ["L" if side < 0.0 else "R", gun_index + 1], 0.044, 0.025, Vector3(side * x, y, wing.z - 0.18), materials["black"], "z", 12)
			_register_gun_muzzle("wing_%s_%02d" % ["port" if side < 0.0 else "starboard", gun_index + 1], Vector3(side * x, y, wing.z - 0.18), "port_wing" if side < 0.0 else "starboard_wing")
			var vent := PackedVector2Array([Vector2(z + 0.23, y - 0.02), Vector2(z + 0.36, y - 0.02), Vector2(z + 0.40, y + 0.01), Vector2(z + 0.22, y + 0.01)])
			_add_flat_patch(_wing_damage_parent(side), "Spent-case port", vent, side * x, materials["dark_steel"])
		if flight_simplified:
			continue
		var inboard_x: float = 2.02
		var inboard := _sample_wing_profile(wing_profile, inboard_x)
		var inboard_z: float = inboard.z + inboard.y * 0.53
		var inboard_bottom: float = inboard.w + _airfoil_height(0.53, inboard.y, 0.10, false)
		_add_box(self, "Inboard HVAR rail shoe", Vector3(0.14, 0.22, 0.52), Vector3(side * inboard_x, inboard_bottom - 0.11, inboard_z), materials["top"])
		var outboard_x: float = 5.10
		var outboard := _sample_wing_profile(wing_profile, outboard_x)
		var outboard_z: float = outboard.z + outboard.y * 0.53
		var outboard_bottom: float = outboard.w + _airfoil_height(0.53, outboard.y, 0.095, false)
		_add_box(self, "Outboard HVAR rail shoe", Vector3(0.14, 0.19, 0.40), Vector3(side * outboard_x, outboard_bottom - 0.095, outboard_z), materials["top"])


func _add_hellcat_canopy() -> void:
	var canopy: Array[Vector4] = [
		Vector4(3.02, 0.10, 0.16, -1.70), Vector4(3.02, 0.34, 0.42, -1.45),
		Vector4(3.02, 0.51, 0.58, -1.05), Vector4(3.02, 0.57, 0.61, -0.40),
		Vector4(3.02, 0.55, 0.58, 0.22), Vector4(3.03, 0.44, 0.46, 0.62),
		Vector4(3.05, 0.15, 0.18, 0.83)
	]
	if flight_simplified:
		spec["canopy_windscreen_sweep_m"] = 0.53
		canopy = [Vector4(3.03,0.43,0.57,-1.86),Vector4(3.10,0.51,0.57,-1.15),Vector4(3.12,0.56,0.54,-0.40),Vector4(3.18,0.53,0.46,0.20),Vector4(3.23,0.44,0.27,0.65),Vector4(3.28,0.28,0.11,0.98),Vector4(3.30,0.04,0.02,1.15)]
	_add_canopy(canopy, "Clear-view sliding canopy", materials["frame"], 6)
	if flight_simplified:
		_add_beam(self, "Radio mast", Vector3(0.0, 3.25, 0.72), Vector3(0.0, 3.83, 0.81), 0.036, materials["frame"], 0.029, 10)
		_add_beam(self, "Radio aerial wire", Vector3(0.0, 3.81, 0.81), Vector3(0.0, 3.70, 4.55), 0.006, materials["dark_steel"], 0.006, 6)
		return
	var front_glass := SurfaceTool.new()
	front_glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [
		Vector3(-0.55, 2.94, -1.72), Vector3(0.0, 2.94, -1.72), Vector3(0.0, 3.36, -1.43),
		Vector3(-0.55, 2.94, -1.72), Vector3(0.0, 3.36, -1.43), Vector3(-0.50, 3.36, -1.43),
		Vector3(0.0, 2.94, -1.72), Vector3(0.55, 2.94, -1.72), Vector3(0.50, 3.36, -1.43),
		Vector3(0.0, 2.94, -1.72), Vector3(0.50, 3.36, -1.43), Vector3(0.0, 3.36, -1.43)
	]
	for point in corners:
		front_glass.add_vertex(point)
	front_glass.generate_normals()
	var windshield := _part(self, "F6F-5 flat armored windscreen", front_glass.commit(), materials["glass"])
	windshield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_beam(self, "Windscreen top crossbar", Vector3(-0.50, 3.36, -1.43), Vector3(0.50, 3.36, -1.43), 0.025, materials["frame"], 0.025, 10)
	_add_beam(self, "Windscreen lower frame", Vector3(-0.56, 2.94, -1.72), Vector3(0.56, 2.94, -1.72), 0.035, materials["frame"], 0.035, 10)
	_add_beam(self, "Windscreen centre post", Vector3(0.0, 2.94, -1.72), Vector3(0.0, 3.36, -1.43), 0.023, materials["frame"], 0.023, 10)
	_add_beam(self, "Radio mast", Vector3(0.0, 3.25, 0.72), Vector3(0.0, 3.83, 0.81), 0.036, materials["frame"], 0.029, 10)
	_add_beam(self, "Radio aerial wire", Vector3(0.0, 3.81, 0.81), Vector3(0.0, 3.70, 4.55), 0.006, materials["dark_steel"], 0.006, 6)


func _add_hellcat_marks() -> void:
	for side in [-1.0, 1.0]:
		_add_us_insignia_on_wing(side, 4.55, 0.00)
		_add_us_insignia_on_fuselage(side, 1.95 if flight_simplified else 0.42, 2.52 if flight_simplified else 2.38, 0.36)
		_add_light(_wing_damage_parent(side), "Navigation lamp", Vector3(side * 6.39, _wing_y(wing_profile, 6.39, -0.36) + 0.035, -0.36), materials["lamp_red"] if side < 0.0 else materials["lamp_green"])


func _add_hellcat_panel_detail() -> void:
	for side in [-1.0, 1.0]:
		for span in [1.48, 2.80, 4.22, 5.35, 6.20]:
			var wing := _sample_wing_profile(wing_profile, span)
			var start_z: float = wing.z + wing.y * 0.08
			var end_z: float = wing.z + wing.y * 0.92
			var p1 := Vector3(side * span, _wing_y(wing_profile, span, start_z) + 0.009, start_z)
			var p2 := Vector3(side * span, _wing_y(wing_profile, span, end_z) + 0.009, end_z)
			_add_surface_seam(self, "Wing access rib", p1, p2, 0.006)
		var fold_station: float = float(spec["wing_fold_station_m"])
		var lower_sweep: float = float(spec["wing_fold_lower_sweep_m"])
		var upper_fold_line := PackedVector3Array()
		var lower_fold_line := PackedVector3Array()
		for line_index in range(25):
			var chord_t: float = lerpf(0.02, 0.98, float(line_index) / 24.0)
			var upper_wing := _sample_wing_profile(wing_profile, fold_station)
			var upper_z: float = upper_wing.z + upper_wing.y * chord_t
			var upper_y: float = upper_wing.w + _airfoil_height(chord_t, upper_wing.y, 0.095, true) + 0.010
			upper_fold_line.append(Vector3(side * fold_station, upper_y, upper_z))
			var lower_span: float = fold_station + (chord_t - 0.5) * lower_sweep
			var lower_wing := _sample_wing_profile(wing_profile, lower_span)
			var lower_z: float = lower_wing.z + lower_wing.y * chord_t
			var lower_y: float = lower_wing.w + _airfoil_height(chord_t, lower_wing.y, 0.095, false) - 0.010
			lower_fold_line.append(Vector3(side * lower_span, lower_y, lower_z))
		_add_tube_line(self, "Sto-Wing straight upper joint", upper_fold_line, 0.010, materials["dark_steel"])
		_add_tube_line(self, "Sto-Wing swept lower joint", lower_fold_line, 0.010, materials["dark_steel"])
	var nav_light := Vector3(0.0, 2.74, 4.90)
	_add_sphere(self, "Tail navigation light", 0.07, nav_light, materials["lamp_red"])
