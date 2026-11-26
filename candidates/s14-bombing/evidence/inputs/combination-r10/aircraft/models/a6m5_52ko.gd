extends "res://aircraft/scripts/aircraft_builder.gd"


func _configure() -> void:
	spec = {
		"id": "a6m5_52ko",
		"name": "Mitsubishi A6M5a Model 52 Ko",
		"short_name": "A6M5a • 五二甲型",
		"nation": "Japan",
		"service_year": "1944",
		"length_m": 9.121,
		"span_m": 11.0,
		"height_m": 3.509,
		"top_color": Color("42563c"),
		"bottom_color": Color("b2b6a7"),
		"frame_color": Color("3b4738"),
		"seam_color": Color("303b30"),
		"prop_y": 1.84,
		"fuselage_mark_x": 0.39,
		"vertex_paint_wings": true,
		"engine": "Nakajima Sakae 21, 14-cylinder radial",
		"armament": "2 × 7.7 mm Type 97; 2 × 20 mm Type 99-2 Model 4, belt-fed (125 rounds each)",
		"profile_note": "52 Ko / A6M5a: belt-fed wing cannon, no drum fairing; 0.2 mm thicker wing skin"
	}
	wing_profile = [
		Vector4(0.25, 2.66, -1.88, 1.47), Vector4(1.20, 2.38, -1.82, 1.48),
		Vector4(2.42, 2.07, -1.72, 1.52), Vector4(3.48, 1.81, -1.64, 1.60),
		Vector4(4.38, 1.59, -1.58, 1.69), Vector4(4.80, 1.47, -1.55, 1.74),
		Vector4(5.10, 1.24, -1.45, 1.77), Vector4(5.30, 0.96, -1.34, 1.80),
		Vector4(5.43, 0.62, -1.19, 1.82), Vector4(5.48, 0.32, -1.06, 1.83),
		Vector4(5.50, 0.20, -1.00, 1.83)
	]
	wing_thickness_profile = [
		Vector2(0.25, 0.150), Vector2(1.20, 0.145), Vector2(2.42, 0.130),
		Vector2(4.38, 0.105), Vector2(5.50, 0.090)
	]
	tail_profile = [
		Vector4(0.12, 1.16, 3.18, 1.97), Vector4(0.78, 1.00, 3.27, 1.99),
		Vector4(1.30, 0.72, 3.42, 2.02), Vector4(1.62, 0.35, 3.57, 2.06),
		Vector4(1.68, 0.08, 3.70, 2.07)
	]


func _build_model() -> void:
	var fuselage: Array[Vector4] = [
		Vector4(1.94, 0.035, 0.055, -4.20), Vector4(1.87, 0.20, 0.22, -4.10),
		Vector4(1.79, 0.43, 0.46, -3.98), Vector4(1.72, 0.57, 0.58, -3.55),
		Vector4(1.66, 0.56, 0.58, -3.05), Vector4(1.62, 0.53, 0.56, -2.35),
		Vector4(1.60, 0.51, 0.53, -1.55), Vector4(1.59, 0.49, 0.49, -0.55),
		Vector4(1.63, 0.44, 0.46, 0.55), Vector4(1.69, 0.36, 0.39, 1.72),
		Vector4(1.75, 0.26, 0.29, 2.82), Vector4(1.80, 0.16, 0.19, 3.76),
		Vector4(1.84, 0.035, 0.055, 4.56)
	]
	_build_fuselage(fuselage)
	_build_wing(wing_profile, -1.0, self, materials["top"], "Port mainplane")
	_build_wing(wing_profile, 1.0, self, materials["top"], "Starboard mainplane")
	_build_wing(tail_profile, -1.0, self, materials["top"], "Port tailplane", 22)
	_build_wing(tail_profile, 1.0, self, materials["top"], "Starboard tailplane", 22)
	_add_extruded_side_shape(_damage_parent_id("tail"), "Vertical fin", PackedVector2Array([
		Vector2(3.10, 1.79), Vector2(4.35, 1.80), Vector2(4.44, 1.94), Vector2(4.36, 2.35),
		Vector2(4.20, 3.18), Vector2(4.06, 3.43), Vector2(3.95, 3.509), Vector2(3.79, 3.44), Vector2(3.62, 2.63)
	]), 0.17, materials["top"])
	control_surfaces = _new_group(self, "Control surfaces")
	var left_aileron := _add_hinged_wing_control("Port aileron", wing_profile, -1.0, 3.28, 5.22, 0.75, 0.99, materials["control"])
	var right_aileron := _add_hinged_wing_control("Starboard aileron", wing_profile, 1.0, 3.28, 5.22, 0.75, 0.99, materials["control"])
	var left_flap := _add_hinged_wing_control("Port split flap", wing_profile, -1.0, 0.62, 2.48, 0.67, 0.98, materials["control"])
	var right_flap := _add_hinged_wing_control("Starboard split flap", wing_profile, 1.0, 0.62, 2.48, 0.67, 0.98, materials["control"])
	_add_hinged_wing_control("Port elevator", tail_profile, -1.0, 0.42, 1.56, 0.70, 0.99, materials["control"])
	_add_hinged_wing_control("Starboard elevator", tail_profile, 1.0, 0.42, 1.56, 0.70, 0.99, materials["control"])
	var rudder_outline := PackedVector2Array([
		Vector2(4.29, 2.00), Vector2(4.42, 2.03), Vector2(4.38, 2.34),
		Vector2(4.21, 3.19), Vector2(4.08, 3.43), Vector2(4.00, 3.39), Vector2(4.12, 2.44)
	])
	_add_hinged_fin_rudder("Movable rudder", rudder_outline, 4.16, 2.07, materials["control"])
	var cowl: Material = _material(Color("17191b"), 0.0, 0.72)
	_add_cowling(-4.18, -3.46, 1.84, 0.60, 0.59, cowl, "Sakae engine cowling")
	if not flight_simplified:
		_add_radial_engine("Nakajima Sakae 21", 14, 0.43, 0.54, -4.18)
	if not flight_simplified:
		_add_engine_cooling_flaps(-3.52, 1.84, 0.56, 12)
	_add_zero_exhausts()
	_add_zero_scoop()
	_add_zero_guns()
	_add_propeller(3, 3.05, Vector3(0.0, float(spec["prop_y"]), -4.13), materials["dark_steel"])
	_add_zero_canopy()
	if not flight_simplified:
		_add_cockpit_interior(Vector3(0.0, 2.12, -1.42), 0.40, 0.55, materials["frame"])
	_add_main_gear_pair(1.46, 1.22, -0.52, 0.31, 1.52)
	_add_tailwheel(Vector3(0.0, 0.13, 3.63), 0.13, 1.60)
	if not flight_simplified:
		_add_zero_drop_tank()
	_add_zero_marks()
	_add_hinomaru_leading_stripes(wing_profile)
	if not flight_simplified:
		_add_zero_panel_detail()


func _add_engine_cooling_flaps(z: float, center_y: float, radius: float, count: int) -> void:
	for index in range(count):
		var angle: float = TAU * float(index) / float(count)
		var start := Vector3(cos(angle) * radius * 0.93, center_y + sin(angle) * radius * 0.93, z)
		var finish := Vector3(cos(angle) * radius * 1.01, center_y + sin(angle) * radius * 1.01, z + 0.19)
		_add_beam(self, "Cowling exit flap %02d" % index, start, finish, 0.025, materials["dark_steel"], 0.023, 8)


func _add_zero_exhausts() -> void:
	for side in [-1.0, 1.0]:
		var exhaust_count: int = 5 if side < 0.0 else 6
		for index in range(exhaust_count):
			var z: float = -3.59 + float(index) * 0.13
			var station_y: float = 1.73 - float(index) * 0.015
			var root := Vector3(side * 0.53, station_y, z)
			var tip := Vector3(side * 0.67, station_y - 0.025, z - 0.15)
			_add_beam(self, "Individual thrust exhaust %s %02d" % ["L" if side < 0.0 else "R", index], root, tip, 0.052, materials["exhaust"], 0.047, 10)
			_add_cylinder(self, "Exhaust mouth %s %02d" % ["L" if side < 0.0 else "R", index], 0.035, 0.014, tip, materials["black"], "z", 10)


func _add_zero_scoop() -> void:
	var intake := _add_sphere(self, "Carburettor intake fairing", 0.31, Vector3(0.0, 1.29, -3.92), materials["top"], Vector3(0.72, 0.38, 1.03))
	intake.rotation.x = -0.1
	_add_cylinder(self, "Carburettor intake throat", 0.145, 0.045, Vector3(0.0, 1.21, -4.08), materials["black"], "z", 24)
	for side in [-1.0, 1.0]:
		_add_sphere(self, "Oil cooler opening", 0.10, Vector3(side * 0.44, 1.38, -3.78), materials["dark_steel"], Vector3(0.5, 0.63, 1.0))


func _add_zero_guns() -> void:
	for side in [-1.0, 1.0]:
		_add_cylinder(self, "Type 97 synchronized 7.7 mm", 0.028, 0.64, Vector3(side * 0.16, 2.16, -3.62), materials["dark_steel"], "z", 10)
		_add_cylinder(self, "Type 97 gun port", 0.043, 0.022, Vector3(side * 0.16, 2.16, -3.94), materials["black"], "z", 12)
		var cannon_x: float = side * 2.28
		var cannon_leading_edge: float = _sample_profile(wing_profile, absf(cannon_x)).z
		_add_cylinder(_wing_damage_parent(side), "Type 99-2 Model 4 cannon barrel", 0.047, 0.88, Vector3(cannon_x, 1.64, cannon_leading_edge + 0.26), materials["dark_steel"], "z", 12)
		_add_cylinder(_wing_damage_parent(side), "20 mm muzzle", 0.057, 0.028, Vector3(cannon_x, 1.64, cannon_leading_edge - 0.18), materials["black"], "z", 14)
		var side_id: String = "port" if side < 0.0 else "starboard"
		_register_gun_muzzle("cowl_" + side_id + "_01", Vector3(side * 0.16, 2.16, -3.94), "upper_engine_cowl")
		_register_gun_muzzle("wing_" + side_id + "_01", Vector3(cannon_x, 1.64, cannon_leading_edge - 0.18), side_id + "_wing")
		var casing_port := PackedVector2Array([
			Vector2(-0.12, 1.42), Vector2(-0.02, 1.42), Vector2(0.06, 1.48), Vector2(-0.10, 1.49)
		])
		_add_flat_patch(_wing_damage_parent(side), "Spent-case port", casing_port, side * 2.31, materials["dark_steel"])
	var pitot_root := Vector3(-1.31, 1.52, -1.68)
	_add_beam(_wing_damage_parent(1.0), "Starboard pitot tube", Vector3(1.31, 1.52, -1.68), Vector3(1.31, 1.48, -2.18), 0.018, materials["steel"], 0.012, 8)


func _add_zero_canopy() -> void:
	var canopy: Array[Vector4] = [
		Vector4(2.02, 0.08, 0.15, -2.48), Vector4(2.03, 0.32, 0.34, -2.20),
		Vector4(2.02, 0.47, 0.57, -1.78), Vector4(2.02, 0.51, 0.62, -1.12),
		Vector4(2.02, 0.49, 0.59, -0.55), Vector4(2.04, 0.41, 0.46, 0.05),
		Vector4(2.09, 0.20, 0.22, 0.45)
	]
	if flight_simplified:
		spec["canopy_windscreen_sweep_m"] = 0.45
		canopy = [Vector4(2.02,0.38,0.53,-2.48),Vector4(2.02,0.47,0.60,-1.80),Vector4(2.02,0.51,0.62,-1.12),Vector4(2.04,0.49,0.57,-0.55),Vector4(2.05,0.40,0.39,0.10),Vector4(2.08,0.26,0.20,0.65),Vector4(2.08,0.07,0.055,1.02)]
	_add_canopy(canopy, "Three-section framed canopy", materials["frame"], 6)
	if not flight_simplified:
		_add_beam(self, "Flat armored windscreen", Vector3(-0.40, 2.10, -2.32), Vector3(0.0, 2.51, -2.16), 0.028, materials["glass"], 0.028, 10)
	if not flight_simplified:
		_add_beam(self, "Windscreen center frame", Vector3(0.0, 2.10, -2.32), Vector3(0.0, 2.50, -2.16), 0.018, materials["frame"], 0.018, 8)
	_add_beam(self, "Radio aerial mast", Vector3(0.0, 2.40, 0.12), Vector3(0.0, 2.89, 0.18), 0.035, materials["frame"], 0.027, 10)
	_add_beam(self, "Radio aerial wire", Vector3(0.0, 2.87, 0.18), Vector3(0.0, 2.22, 3.42), 0.006, materials["dark_steel"], 0.006, 6)


func _add_zero_drop_tank() -> void:
	var tank := _add_sphere(self, "330 litre centreline drop tank", 1.0, Vector3(0.0, 0.87, 0.60), materials["bottom"], Vector3(0.22, 0.22, 0.77))
	tank.rotation.x = -0.04
	_add_beam(self, "Drop tank forward lug", Vector3(0.0, 1.07, 0.10), Vector3(0.0, 1.23, 0.12), 0.045, materials["dark_steel"], 0.04, 10)
	_add_beam(self, "Drop tank aft lug", Vector3(0.0, 1.08, 1.02), Vector3(0.0, 1.22, 1.00), 0.042, materials["dark_steel"], 0.04, 10)
	_add_extruded_side_shape(self, "Drop tank tail fin port", PackedVector2Array([Vector2(1.10, 0.87), Vector2(1.42, 0.88), Vector2(1.23, 1.03)]), 0.02, materials["bottom"])
	_add_extruded_side_shape(self, "Drop tank tail fin starboard", PackedVector2Array([Vector2(1.10, 0.87), Vector2(1.42, 0.88), Vector2(1.23, 1.03)]), 0.02, materials["bottom"])


func _add_zero_marks() -> void:
	for side in [-1.0, 1.0]:
		_add_roundel_on_wing(side, 3.14, -0.70, 0.44, materials["insignia_red"])
		_add_aircraft_roundel_on_fuselage(side, 1.10, 1.70, 0.32)
		_add_light(_wing_damage_parent(side), "Navigation lamp", Vector3(side * 5.38, 1.86, -1.20), materials["lamp_red"] if side < 0.0 else materials["lamp_green"])


func _add_zero_panel_detail() -> void:
	for side in [-1.0, 1.0]:
		for span in [1.23, 2.95, 4.28, 5.08]:
			var wing := _sample_profile(wing_profile, span)
			var p1 := Vector3(side * span, _wing_y(wing_profile, span, wing.z + wing.y * 0.12) + 0.008, wing.z + wing.y * 0.12)
			var p2 := Vector3(side * span, _wing_y(wing_profile, span, wing.z + wing.y * 0.88) + 0.008, wing.z + wing.y * 0.88)
			_add_surface_seam(self, "Wing rib panel line", p1, p2, 0.006)
		var flap_span := 2.52
		var flap := _sample_profile(wing_profile, flap_span)
		_add_surface_seam(self, "Flap outer hinge line", Vector3(side * flap_span, flap.w + 0.01, flap.z + flap.y * 0.66), Vector3(side * flap_span, flap.w + 0.01, flap.z + flap.y * 0.99), 0.012)
	var tail_points := PackedVector3Array([Vector3(0.0, 2.28, 3.34), Vector3(0.0, 2.55, 3.48), Vector3(0.0, 2.87, 3.72)])
	_add_tube_line(self, "Antenna rigging", tail_points, 0.004, materials["dark_steel"])
