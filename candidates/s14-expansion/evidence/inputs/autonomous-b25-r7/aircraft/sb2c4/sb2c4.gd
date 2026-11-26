extends "res://aircraft/scripts/aircraft_builder.gd"

const MODEL_LENGTH_M: float = 11.049
const MODEL_SPAN_M: float = 15.164
const MODEL_HEIGHT_M: float = 4.496
const ENGINE_NAME: String = "Wright R-2600-20 Twin Cyclone"
const COCKPIT_SILL_INSET_M: float = 0.17
const GUNNER_OPENING_START_M: float = 1.18
const GUNNER_OPENING_END_M: float = 2.02
const MAIN_WHEEL_CENTER_M: Vector3 = Vector3(2.10, 1.00, -0.58)
const MAIN_WHEEL_RADIUS_M: float = 0.44
const TAIL_WHEEL_CENTER_M: Vector3 = Vector3(0.0, 1.40, 3.90)
const TAIL_WHEEL_RADIUS_M: float = 0.15
const FLIGHT_REFERENCE_M: Vector3 = Vector3(0.0, 2.38, 0.0)

var fuselage_module: Node3D
var wing_module: Node3D
var empennage_module: Node3D
var cockpit_module: Node3D
var powerplant_module: Node3D
var dive_brakes_module: Node3D
var armament_module: Node3D
var external_stores_module: Node3D
var small_equipment_module: Node3D
var bay_open_group: Node3D
var bay_closed_group: Node3D
var fuselage_profile: Array[Vector4] = []
var folded_wing_surfaces: Array[MeshInstance3D] = []
var deployed_wing_surfaces: Array[MeshInstance3D] = []
var arrestor_hook: Node3D


func _configure() -> void:
	spec = {
		"id": "sb2c4",
		"name": "Curtiss SB2C-4 Helldiver",
		"short_name": "SB2C-4 • Helldiver",
		"nation": "United States",
		"service_year": "1944–1945",
		"length_m": MODEL_LENGTH_M,
		"span_m": MODEL_SPAN_M,
		"height_m": MODEL_HEIGHT_M,
		"top_color": Color("283543"),
		"bottom_color": Color("283543"),
		"frame_color": Color("182632"),
		"seam_color": Color("1b2732"),
		"prop_y": 2.38,
		"fuselage_mark_x": 0.69,
		"vertex_paint_wings": true,
		"piecewise_wing_profile": true,
		"piecewise_tail_profile": true,
		"engine": ENGINE_NAME + ", 14-cylinder air-cooled radial",
		"armament": "2 × 20 mm AN/M2 wing cannon; 2 × .30 in M1919 flexible aft guns; 8 × 5 in HVAR stations; internal bomb bay",
		"profile_note": "SB2C-4: split dive flaps shown as solid simplified panels; four-blade propeller"
	}
	wing_profile = [
		Vector4(0.22, 3.62, -1.90, 2.16), Vector4(0.85, 3.62, -1.90, 2.17),
		Vector4(3.35, 3.58, -1.88, 2.25), Vector4(4.18, 3.10, -1.64, 2.32),
		Vector4(5.25, 2.48, -1.31, 2.40), Vector4(6.45, 1.62, -0.80, 2.50),
		Vector4(6.90, 1.32, -0.58, 2.56), Vector4(7.20, 0.99, -0.40, 2.59),
		Vector4(7.42, 0.65, -0.23, 2.63), Vector4(7.54, 0.34, -0.075, 2.65),
		Vector4(7.582, 0.03, 0.08, 2.66)
	]
	wing_thickness_profile = [
		Vector2(0.22, 0.17), Vector2(1.70, 0.17), Vector2(4.05, 0.145),
		Vector2(6.25, 0.112), Vector2(7.582, 0.09)
	]
	tail_profile = [
		Vector4(0.14, 1.92, 3.34, 2.48), Vector4(1.30, 1.68, 3.48, 2.50),
		Vector4(2.18, 1.10, 3.80, 2.55), Vector4(2.72, 0.52, 4.14, 2.60),
		Vector4(2.93, 0.18, 4.34, 2.62)
	]


func _create_materials() -> void:
	super._create_materials()
	materials["glass"] = _material(Color("566d7a"), 0.02, 0.58)
	materials["dive_brake"] = _material(Color("903b36"), 0.24, 0.56)
	materials["dive_brake_frame"] = _material(Color("5a302e"), 0.45, 0.48)
	materials["interior"] = _material(Color("66734e"), 0.08, 0.72)
	materials["insignia_blue"] = _material(Color("1c3851"), 0.0, 0.62)
	materials["bomb"] = _material(Color("435344"), 0.32, 0.62)
	materials["rocket"] = _material(Color("56636a"), 0.52, 0.48)
	materials["bomb_bay_door"] = _material(Color("53616b"), 0.10, 0.64)
	materials["lamp_white"] = _material(Color("e8e4cf"), 0.12, 0.18, true)


func _build_model() -> void:
	fuselage_module = _new_group(self, "01 Fuselage module")
	fuselage_module.set_meta("module_id", "fuselage_module")
	wing_module = _new_group(self, "02 Main wing module")
	wing_module.set_meta("module_id", "wing_module")
	empennage_module = _new_group(self, "03 Empennage module")
	empennage_module.set_meta("module_id", "empennage_module")
	cockpit_module = _new_group(self, "04 Cockpit and glazing module")
	cockpit_module.set_meta("module_id", "cockpit_module")
	powerplant_module = _new_group(self, "05 Engine and propeller module")
	powerplant_module.set_meta("module_id", "powerplant_module")
	landing_gear = _new_group(self, "06 Landing gear module")
	landing_gear.set_meta("module_id", "landing_gear_module")
	dive_brakes_module = _new_group(self, "07 Split dive brake modules")
	dive_brakes_module.set_meta("module_id", "dive_brake_module")
	armament_module = _new_group(self, "08 Fixed and flexible armament module")
	armament_module.set_meta("module_id", "armament_module")
	external_stores_module = _new_group(self, "09 External stores modules")
	external_stores_module.set_meta("module_id", "external_stores_module")
	control_surfaces = _new_group(self, "10 Movable control surface modules")
	control_surfaces.set_meta("module_id", "control_surfaces_module")
	small_equipment_module = _new_group(self, "11 Small equipment module")
	small_equipment_module.set_meta("module_id", "small_equipment_module")

	_build_airframe()
	_build_control_surfaces()
	_build_engine()
	_build_cockpit()
	_build_gear_and_tail_hook()
	_build_dive_brakes()
	_build_armament_and_stores()
	_add_aircraft_markings()
	set_showcase_configuration(false)


func set_showcase_configuration(clean: bool) -> void:
	set_dive_brakes_deployed(not clean)
	set_external_stores_visible(not clean)
	set_bomb_bay_open(not clean)
	set_arrestor_hook_deployed(not clean)


func set_dive_brakes_deployed(deployed: bool) -> void:
	for surface: MeshInstance3D in deployed_wing_surfaces:
		surface.visible = deployed
	for surface: MeshInstance3D in folded_wing_surfaces:
		surface.visible = not deployed
	if dive_brakes_module != null:
		dive_brakes_module.visible = deployed


func set_external_stores_visible(show_stores: bool) -> void:
	if external_stores_module != null:
		external_stores_module.visible = show_stores


func set_bomb_bay_open(open: bool) -> void:
	if bay_open_group != null:
		bay_open_group.visible = open
	if bay_closed_group != null:
		bay_closed_group.visible = not open


func set_landing_gear_deployed(deployed: bool) -> void:
	if landing_gear != null:
		landing_gear.visible = deployed


func set_arrestor_hook_deployed(deployed: bool) -> void:
	if arrestor_hook != null:
		arrestor_hook.visible = deployed


func set_flight_configuration() -> void:
	set_showcase_configuration(true)
	set_landing_gear_deployed(false)


func get_parked_transform() -> Transform3D:
	# Display-only three-point stance. The pure model origin never moves.
	var delta_y: float = TAIL_WHEEL_CENTER_M.y - MAIN_WHEEL_CENTER_M.y
	var delta_z: float = TAIL_WHEEL_CENTER_M.z - MAIN_WHEEL_CENTER_M.z
	var radius_delta: float = MAIN_WHEEL_RADIUS_M - TAIL_WHEEL_RADIUS_M
	var pitch: float = atan2(delta_y, delta_z) + asin(radius_delta / Vector2(delta_y, delta_z).length())
	var parked_basis: Basis = Basis(Vector3.RIGHT, pitch)
	var main_center: Vector3 = parked_basis * MAIN_WHEEL_CENTER_M
	return Transform3D(parked_basis, Vector3(0.0, MAIN_WHEEL_RADIUS_M - main_center.y, 0.0))


func _build_sb2c_fuselage(stations: Array[Vector4]) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var canopy_stations: Array[Vector4] = _get_main_greenhouse_profile()
	var ring_size: int = RADIAL_SEGMENTS + 1
	for z_index in range(LOFT_SEGMENTS + 1):
		var z_fraction: float = float(z_index) / float(LOFT_SEGMENTS)
		var z: float = lerpf(stations[0].w, stations[stations.size() - 1].w, z_fraction)
		var station: Vector4 = _sample_station(stations, z)
		for ring_index in range(ring_size):
			var angle: float = TAU * float(ring_index) / float(RADIAL_SEGMENTS)
			var point := Vector3(sin(angle) * station.y, station.x + cos(angle) * station.z, z)
			surface.set_color(_fuselage_color(cos(angle)))
			surface.set_uv(Vector2(z_fraction, float(ring_index) / float(RADIAL_SEGMENTS)))
			surface.add_vertex(point)
	for z_index in range(LOFT_SEGMENTS):
		var z_a: float = lerpf(stations[0].w, stations[stations.size() - 1].w, float(z_index) / float(LOFT_SEGMENTS))
		var z_b: float = lerpf(stations[0].w, stations[stations.size() - 1].w, float(z_index + 1) / float(LOFT_SEGMENTS))
		var z_mid: float = (z_a + z_b) * 0.5
		var section_station: Vector4 = _sample_station(stations, z_mid)
		for ring_index in range(RADIAL_SEGMENTS):
			var angle_a: float = TAU * float(ring_index) / float(RADIAL_SEGMENTS)
			var angle_b: float = TAU * float(ring_index + 1) / float(RADIAL_SEGMENTS)
			var point_a := Vector3(sin(angle_a) * section_station.y, section_station.x + cos(angle_a) * section_station.z, z_mid)
			var point_b := Vector3(sin(angle_b) * section_station.y, section_station.x + cos(angle_b) * section_station.z, z_mid)
			var center_y: float = (point_a.y + point_b.y) * 0.5
			var center_x: float = (point_a.x + point_b.x) * 0.5
			var opens_bomb_bay: bool = z_mid >= -0.22 and z_mid <= 1.40 and absf(center_x) <= 0.37 and center_y <= section_station.x - section_station.z * 0.70
			var canopy_section: Vector4 = _sample_station(canopy_stations, z_mid)
			var cockpit_half_width: float = minf(maxf(canopy_section.y - COCKPIT_SILL_INSET_M, 0.06), section_station.y * 0.96)
			var opens_cockpit: bool = z_mid >= canopy_stations[0].w and z_mid <= canopy_stations[canopy_stations.size() - 1].w and absf(center_x) <= cockpit_half_width and center_y >= section_station.x + section_station.z * 0.70
			var gunner_half_width: float = minf(0.31, section_station.y * 0.88)
			var opens_gunner_position: bool = z_mid >= GUNNER_OPENING_START_M and z_mid <= GUNNER_OPENING_END_M and absf(center_x) <= gunner_half_width and center_y >= section_station.x + section_station.z * 0.70
			if opens_bomb_bay or opens_cockpit or opens_gunner_position:
				continue
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
	var nose_center_index: int = (LOFT_SEGMENTS + 1) * ring_size
	var nose_station: Vector4 = stations[0]
	surface.set_color(Color(spec["top_color"]))
	surface.add_vertex(Vector3(0.0, nose_station.x, nose_station.w))
	var tail_center_index: int = nose_center_index + 1
	var tail_station: Vector4 = stations[stations.size() - 1]
	surface.set_color(Color(spec["top_color"]))
	surface.add_vertex(Vector3(0.0, tail_station.x, tail_station.w))
	var tail_ring_start: int = LOFT_SEGMENTS * ring_size
	for ring_index in range(RADIAL_SEGMENTS):
		surface.add_index(nose_center_index)
		surface.add_index(ring_index)
		surface.add_index(ring_index + 1)
		var a: int = tail_ring_start + ring_index
		var b: int = tail_ring_start + ring_index + 1
		surface.add_index(tail_center_index)
		surface.add_index(b)
		surface.add_index(a)
	surface.generate_normals()
	_part(self, "Curtiss semi-monocoque fuselage with bomb-bay aperture", surface.commit(), materials["airframe"])


func _build_airframe() -> void:
	fuselage_profile = [
		Vector4(2.38, 0.045, 0.045, -5.15), Vector4(2.38, 0.62, 0.60, -5.02),
		Vector4(2.38, 0.80, 0.78, -4.82), Vector4(2.38, 0.84, 0.82, -4.52),
		Vector4(2.35, 0.82, 0.78, -3.82), Vector4(2.32, 0.75, 0.70, -3.40),
		Vector4(2.26, 0.73, 0.71, -2.73), Vector4(2.20, 0.68, 0.70, -1.54),
		Vector4(2.20, 0.65, 0.68, -0.28), Vector4(2.18, 0.60, 0.65, 0.98),
		Vector4(2.16, 0.58, 0.63, 2.07), Vector4(2.23, 0.47, 0.52, 3.10),
		Vector4(2.32, 0.34, 0.38, 4.08), Vector4(2.40, 0.18, 0.20, 4.94),
		Vector4(2.44, 0.015, 0.018, 5.55)
	]
	var first_child: int = get_child_count()
	_build_sb2c_fuselage(fuselage_profile)
	_move_new_children(fuselage_module, first_child)
	_add_marker(fuselage_module, "AIRCRAFT_FLIGHT_REFERENCE", FLIGHT_REFERENCE_M, "fuselage_module", "presentation reference, not measured center of gravity", 0.5)

	for side in [-1.0, 1.0]:
		deployed_wing_surfaces.append(_build_helldiver_wing(side, "%s wing skin with dive-brake bays" % ("Port" if side < 0.0 else "Starboard"), true))
		folded_wing_surfaces.append(_build_helldiver_wing(side, "%s wing skin with brakes folded" % ("Port" if side < 0.0 else "Starboard"), false))

	_build_wing(tail_profile, -1.0, empennage_module, materials["top"], "Port horizontal stabilizer", 40)
	_build_wing(tail_profile, 1.0, empennage_module, materials["top"], "Starboard horizontal stabilizer", 40)
	_add_extruded_side_shape(empennage_module, "Curtiss rounded vertical stabilizer", PackedVector2Array([
		Vector2(2.65, 2.60), Vector2(5.38, 2.44), Vector2(5.45, 2.82),
		Vector2(5.46, 3.28), Vector2(5.42, 3.68), Vector2(5.30, 3.98),
		Vector2(5.10, 4.23), Vector2(4.80, 4.42), Vector2(4.50, 4.46),
		Vector2(4.21, 4.35), Vector2(3.92, 4.12), Vector2(3.60, 3.80),
		Vector2(3.26, 3.36), Vector2(2.92, 2.93)
	]), 0.30, materials["top"])
	_add_marker(fuselage_module, "CONTROL_TAILPLANE_ROOT", Vector3(0.0, 2.48, 3.48), "fuselage_module", "tailplane structural attachment; photo-based estimate", 0.6)
	_add_marker(wing_module, "GEAR_MAIN_PORT", Vector3(-1.92, 2.00, -0.84), "wing_module", "main gear trunnion; photo-based estimate", 0.6)
	_add_marker(wing_module, "GEAR_MAIN_STARBOARD", Vector3(1.92, 2.00, -0.84), "wing_module", "main gear trunnion; photo-based estimate", 0.6)
	_add_marker(fuselage_module, "COCKPIT_PILOT_SEAT", Vector3(0.0, 2.22, -1.48), "fuselage_module", "front tandem cockpit station", 0.75)
	_add_marker(fuselage_module, "COCKPIT_REAR_SEAT", Vector3(0.0, 2.18, 0.76), "fuselage_module", "rear tandem cockpit station", 0.75)
	_add_marker(fuselage_module, "BOMB_BAY_CARRIER", Vector3(0.0, 1.72, 0.50), "fuselage_module", "internal bay carrier; model load is display fit", 0.55)


func _build_control_surfaces() -> void:
	for side in [-1.0, 1.0]:
		var side_name: String = "Port" if side < 0.0 else "Starboard"
		_add_hinged_wing_control("%s aileron" % side_name, wing_profile, side, 5.10, 7.25, 0.73, 0.98, materials["control"])
		var aileron_hinge: Vector3 = _wing_point(5.10, 0.73, true)
		aileron_hinge.x *= side
		_add_marker(wing_module, "CONTROL_AILERON_HINGE_%s" % side_name.to_upper(), aileron_hinge, "wing_module", "aileron hinge; photo-based estimate", 0.55)
		var aileron_hinge_tip: Vector3 = _wing_point(7.25, 0.73, true)
		aileron_hinge_tip.x *= side
		_add_surface_seam(wing_module, "%s aileron hinge seam" % side_name, aileron_hinge + Vector3(0.0, 0.006, 0.0), aileron_hinge_tip + Vector3(0.0, 0.006, 0.0), 0.006)
		_add_hinged_wing_control("%s elevator" % side_name, tail_profile, side, 0.22, 2.75, 0.70, 0.98, materials["control"])
		var tail_root: Vector4 = _sample_wing_profile(tail_profile, 0.22)
		var elevator_hinge := Vector3(side * 0.22, tail_root.w, tail_root.z + tail_root.y * 0.70)
		_add_marker(empennage_module, "CONTROL_ELEVATOR_HINGE_%s" % side_name.to_upper(), elevator_hinge, "empennage_module", "elevator hinge; photo-based estimate", 0.5)
	var rudder_outline := PackedVector2Array([
		Vector2(5.23, 2.53), Vector2(5.48, 2.53), Vector2(5.55, 2.82),
		Vector2(5.55, 3.34), Vector2(5.43, 3.68), Vector2(5.26, 3.95)
	])
	_add_hinged_fin_rudder("Movable rudder", rudder_outline, 5.23, 2.50, materials["control"], 0.12)
	_add_marker(empennage_module, "CONTROL_RUDDER_HINGE", Vector3(0.0, 2.50, 5.23), "fuselage_module", "rudder hinge; photo-based estimate", 0.5)


func _build_helldiver_wing(side: float, part_name: String, cut_for_brakes: bool) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span_start: float = wing_profile[0].x
	var span_end: float = wing_profile[wing_profile.size() - 1].x
	var span_positions: PackedFloat32Array = []
	var chord_positions: PackedFloat32Array = []
	for span_index in range(89):
		span_positions.append(lerpf(span_start, span_end, float(span_index) / 88.0))
	for span_boundary in [1.18, 4.78, 5.10, 7.25]:
		span_positions.append(span_boundary)
	span_positions.sort()
	var unique_span_positions: PackedFloat32Array = []
	for span_position in span_positions:
		if unique_span_positions.is_empty() or absf(span_position - unique_span_positions[-1]) > 0.0001:
			unique_span_positions.append(span_position)
	span_positions = unique_span_positions
	for chord_index in range(41):
		chord_positions.append(float(chord_index) / 40.0)
	for chord_boundary in [0.70, 0.73, 0.98]:
		chord_positions.append(chord_boundary)
	chord_positions.sort()
	var unique_chord_positions: PackedFloat32Array = []
	for chord_position in chord_positions:
		if unique_chord_positions.is_empty() or absf(chord_position - unique_chord_positions[-1]) > 0.0001:
			unique_chord_positions.append(chord_position)
	chord_positions = unique_chord_positions
	var chord_stride: int = chord_positions.size()
	var layer_vertex_count: int = span_positions.size() * chord_stride
	var layer_start: int = 0
	for upper in [true, false]:
		for span_index in range(span_positions.size()):
			var span: float = span_positions[span_index]
			for chord_index in range(chord_positions.size()):
				var chord_fraction: float = chord_positions[chord_index]
				var color: Color = spec["top_color"] if upper else spec["bottom_color"]
				surface.set_color(color)
				surface.set_uv(Vector2(chord_fraction, span / MODEL_SPAN_M * 2.0))
				surface.add_vertex(_helldiver_wing_point(side, span, chord_fraction, upper))
		for span_index in range(span_positions.size() - 1):
			var distance_a: float = span_positions[span_index]
			var distance_b: float = span_positions[span_index + 1]
			for chord_index in range(chord_positions.size() - 1):
				var chord_a: float = chord_positions[chord_index]
				var chord_b: float = chord_positions[chord_index + 1]
				var span_mid: float = (distance_a + distance_b) * 0.5
				var chord_mid: float = (chord_a + chord_b) * 0.5
				var in_dive_brake_bay: bool = cut_for_brakes and span_mid >= 1.18 and span_mid <= 4.78 and chord_mid >= 0.70
				var in_aileron_bay: bool = span_mid >= 5.10 and span_mid <= 7.25 and chord_mid >= 0.73 and chord_mid <= 0.98
				if in_dive_brake_bay or in_aileron_bay:
					continue
				var v00: int = layer_start + span_index * chord_stride + chord_index
				var v01: int = v00 + 1
				var v10: int = v00 + chord_stride
				var v11: int = v10 + 1
				var forward_winding: bool = (side > 0.0) == upper
				if forward_winding:
					surface.add_index(v00)
					surface.add_index(v01)
					surface.add_index(v11)
					surface.add_index(v00)
					surface.add_index(v11)
					surface.add_index(v10)
				else:
					surface.add_index(v00)
					surface.add_index(v11)
					surface.add_index(v01)
					surface.add_index(v00)
					surface.add_index(v10)
					surface.add_index(v11)
		layer_start += layer_vertex_count
	var lower_start: int = span_positions.size() * chord_stride
	for span_index in [0, span_positions.size() - 1]:
		for chord_index in range(chord_positions.size() - 1):
			var v00: int = span_index * chord_stride + chord_index
			var v01: int = v00 + 1
			var v10: int = lower_start + span_index * chord_stride + chord_index
			var v11: int = v10 + 1
			surface.add_index(v00)
			surface.add_index(v10)
			surface.add_index(v11)
			surface.add_index(v00)
			surface.add_index(v11)
			surface.add_index(v01)
	surface.generate_normals()
	return _part(wing_module, part_name, surface.commit(), materials["airframe"])


func _helldiver_wing_point(side: float, span: float, chord_fraction: float, upper: bool) -> Vector3:
	var section: Vector4 = _sample_wing_profile(wing_profile, span)
	var height: float = _airfoil_height(chord_fraction, section.y, _wing_thickness_ratio(wing_profile, span), upper)
	return Vector3(side * span, section.w + height, section.z + section.y * chord_fraction)


func _build_engine() -> void:
	# The rounded engine envelope is part of the continuous fuselage skin.
	var first_child: int = get_child_count()
	_add_propeller(4, 4.02, Vector3(0.0, 2.38, -5.12), materials["dark_steel"])
	_move_new_children(powerplant_module, first_child)
	var spinner: MeshInstance3D = propeller.get_node("Spinner") as MeshInstance3D
	spinner.material_override = materials["top"]


func _build_cockpit() -> void:
	var main_greenhouse: Array[Vector4] = _get_main_greenhouse_profile()
	var first_child: int = get_child_count()
	_add_canopy(main_greenhouse, "Continuous pilot and observer greenhouse", materials["frame"], 1)
	_move_new_children(cockpit_module, first_child)
	_add_windscreen_closed_pane(main_greenhouse)
	_build_cockpit_sills(main_greenhouse)
	for z: float in [-1.85, -0.35, 0.80]:
		_add_canopy_section_band(main_greenhouse, z)
	_add_box(cockpit_module, "Aft gunner footwell pan", Vector3(0.62, 0.05, 0.82), Vector3(0.0, 2.16, 1.63), materials["interior"])
	_build_gunner_ring()


func _add_canopy_section_band(stations: Array[Vector4], z: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections: int = 24
	for longitudinal: int in range(2):
		var band_z: float = z + (-0.009 if longitudinal == 0 else 0.009)
		var section: Vector4 = _sample_station(stations, band_z)
		for index: int in range(sections + 1):
			var angle: float = PI_F * float(index) / float(sections)
			surface.add_vertex(Vector3(cos(angle) * (section.y + 0.004), section.x + sin(angle) * (section.z + 0.004), band_z))
	for index: int in range(sections):
		var a: int = index
		var b: int = sections + 1 + index
		surface.add_index(a)
		surface.add_index(a + 1)
		surface.add_index(b + 1)
		surface.add_index(a)
		surface.add_index(b + 1)
		surface.add_index(b)
	surface.generate_normals()
	_part(cockpit_module, "Flat canopy division %.2f" % z, surface.commit(), materials["frame"])


func _get_main_greenhouse_profile() -> Array[Vector4]:
	return [
		Vector4(2.96, 0.22, 0.025, -2.55), Vector4(2.90, 0.37, 0.39, -2.18),
		Vector4(2.89, 0.43, 0.50, -2.02), Vector4(2.88, 0.45, 0.50, -1.60),
		Vector4(2.86, 0.44, 0.49, -1.00),
		Vector4(2.84, 0.39, 0.44, -0.43), Vector4(2.84, 0.39, 0.43, -0.18),
		Vector4(2.84, 0.40, 0.44, 0.08), Vector4(2.84, 0.41, 0.44, 0.53),
		Vector4(2.84, 0.40, 0.44, 0.88), Vector4(2.82, 0.38, 0.41, 1.18)
	]


func _build_cockpit_sills(canopy_stations: Array[Vector4]) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var longitudinal_sections: int = 64
	var vertex_count: int = 0
	for side in [-1.0, 1.0]:
		for section_index in range(longitudinal_sections):
			var z0: float = lerpf(canopy_stations[0].w, canopy_stations[canopy_stations.size() - 1].w, float(section_index) / float(longitudinal_sections))
			var z1: float = lerpf(canopy_stations[0].w, canopy_stations[canopy_stations.size() - 1].w, float(section_index + 1) / float(longitudinal_sections))
			var canopy0: Vector4 = _sample_station(canopy_stations, z0)
			var canopy1: Vector4 = _sample_station(canopy_stations, z1)
			var body0: Vector4 = _sample_station(fuselage_profile, z0)
			var body1: Vector4 = _sample_station(fuselage_profile, z1)
			var x0: float = minf(canopy0.y, body0.y * 0.98)
			var x1: float = minf(canopy1.y, body1.y * 0.98)
			var sill_bottom_x0: float = minf(maxf(canopy0.y - COCKPIT_SILL_INSET_M, 0.04), body0.y * 0.98)
			var sill_bottom_x1: float = minf(maxf(canopy1.y - COCKPIT_SILL_INSET_M, 0.04), body1.y * 0.98)
			var body_ratio0: float = clampf(sill_bottom_x0 / body0.y, 0.0, 0.98)
			var body_ratio1: float = clampf(sill_bottom_x1 / body1.y, 0.0, 0.98)
			var body_shell_y0: float = body0.x + body0.z * sqrt(1.0 - body_ratio0 * body_ratio0) + 0.008
			var body_shell_y1: float = body1.x + body1.z * sqrt(1.0 - body_ratio1 * body_ratio1) + 0.008
			var sill_bottom_y0: float = minf(body_shell_y0, canopy0.x - 0.04)
			var sill_bottom_y1: float = minf(body_shell_y1, canopy1.x - 0.04)
			var start: int = vertex_count
			surface.add_vertex(Vector3(side * sill_bottom_x0, sill_bottom_y0, z0))
			surface.add_vertex(Vector3(side * x0, canopy0.x, z0))
			surface.add_vertex(Vector3(side * x1, canopy1.x, z1))
			surface.add_vertex(Vector3(side * sill_bottom_x1, sill_bottom_y1, z1))
			if side > 0.0:
				surface.add_index(start)
				surface.add_index(start + 1)
				surface.add_index(start + 2)
				surface.add_index(start)
				surface.add_index(start + 2)
				surface.add_index(start + 3)
			else:
				surface.add_index(start)
				surface.add_index(start + 2)
				surface.add_index(start + 1)
				surface.add_index(start)
				surface.add_index(start + 3)
				surface.add_index(start + 2)
			vertex_count += 4
	surface.generate_normals()
	_part(cockpit_module, "Continuous cockpit sill walls fitted to fuselage", surface.commit(), materials["top"])


func _add_windscreen_side_frames(canopy_stations: Array[Vector4]) -> void:
	var forward: Vector4 = _sample_station(canopy_stations, -2.30)
	var aft: Vector4 = _sample_station(canopy_stations, -1.82)
	for side in [-1.0, 1.0]:
		_add_beam(cockpit_module, "Closed windscreen side pillar", Vector3(side * forward.y, forward.x, -2.30), Vector3(side * aft.y, aft.x, -1.82), 0.024, materials["frame"], 0.024, 10)
	_add_beam(cockpit_module, "Windscreen central brace", Vector3(0.0, forward.x + forward.z, -2.30), Vector3(0.0, aft.x + aft.z, -1.82), 0.015, materials["frame"], 0.015, 8)


func _add_windscreen_closed_pane(canopy_stations: Array[Vector4]) -> void:
	var section: Vector4 = _sample_station(canopy_stations, canopy_stations[0].w)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 18
	var center: Vector3 = Vector3(0.0, section.x + 0.012, section.w - 0.004)
	surface.add_vertex(center)
	for index in range(segments + 1):
		var angle: float = PI_F * float(index) / float(segments)
		var point := Vector3(cos(angle) * section.y, section.x + sin(angle) * section.z, section.w - 0.004)
		surface.add_vertex(point)
	for index in range(segments):
		surface.add_index(0)
		surface.add_index(index + 1)
		surface.add_index(index + 2)
	surface.generate_normals()
	var pane := _part(cockpit_module, "Closed curved forward windscreen pane", surface.commit(), materials["glass"])
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_gunner_ring() -> void:
	var mount_station: Vector3 = Vector3(0.0, 2.91, 1.62)
	var mount: Node3D = _new_group(armament_module, "Twin .30 in flexible gun ring mount", mount_station)
	_add_marker(fuselage_module, "GUN_MOUNT_AFT_FLEXIBLE", mount_station, "fuselage_module", "aft flexible gun ring; photo-based estimate", 0.6)
	var coaming := _new_group(cockpit_module, "Open aft gunner position coaming", Vector3(0.0, 2.72, 1.62))
	var coaming_points := PackedVector3Array()
	for index in range(33):
		var angle: float = TAU * float(index) / 32.0
		coaming_points.append(Vector3(cos(angle) * 0.34, 0.0, sin(angle) * 0.27))
	_add_tube_line(coaming, "Aft gunner coaming rim", coaming_points, 0.028, materials["frame"])
	var ring_points := PackedVector3Array()
	for index in range(33):
		var angle: float = TAU * float(index) / 32.0
		ring_points.append(Vector3(cos(angle) * 0.31, 0.0, sin(angle) * 0.30))
	_add_tube_line(mount, "Gunner ring rail", ring_points, 0.026, materials["steel"])
	_add_beam(mount, "Flexible mount crossbar", Vector3(-0.23, 0.11, 0.08), Vector3(0.23, 0.11, 0.08), 0.045, materials["dark_steel"], 0.045, 10)
	for side in [-1.0, 1.0]:
		_add_beam(mount, "Ring support strut", Vector3(side * 0.23, -0.04, -0.04), Vector3(side * 0.29, -0.18, 0.13), 0.026, materials["steel"], 0.022, 8)
	for side in [-1.0, 1.0]:
		var side_name: String = "port" if side < 0.0 else "starboard"
		var gun: Node3D = _new_group(mount, "M1919 flexible gun %s" % side_name, Vector3(side * 0.115, 0.13, 0.14))
		gun.rotation.x = deg_to_rad(-24.0)
		_add_box(gun, "M1919 receiver", Vector3(0.095, 0.13, 0.36), Vector3(0.0, 0.0, 0.10), materials["dark_steel"])
		_add_beam(gun, ".30 in barrel", Vector3(0.0, 0.015, 0.24), Vector3(0.0, 0.015, 0.92), 0.021, materials["steel"], 0.018, 10)
		_add_cylinder(gun, "Muzzle", 0.027, 0.024, Vector3(0.0, 0.015, 0.94), materials["black"], "z", 12)
		var muzzle: Marker3D = _add_marker(gun, "MUZZLE_AFT_M1919_%s" % side_name.to_upper(), Vector3(0.0, 0.015, 0.94), "armament_module", "presentation muzzle; aft/up displayed pose, no fire-control logic", 0.6)
		muzzle.rotation.y = PI_F
	_add_beam(mount, "Flexible mount pivot post", Vector3(0.0, -0.16, 0.0), Vector3(0.0, -0.015, 0.0), 0.048, materials["steel"], 0.048, 10)


func _add_seat_and_instruments(section_name: String, position: Vector3) -> void:
	var cockpit: Node3D = _new_group(cockpit_module, "%s cockpit station" % section_name, position)
	_add_box(cockpit, "Seat cushion", Vector3(0.38, 0.10, 0.42), Vector3(0.0, -0.08, 0.02), materials["interior"])
	_add_box(cockpit, "Armored seat back", Vector3(0.37, 0.52, 0.09), Vector3(0.0, 0.20, 0.22), materials["dark_steel"], Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	_add_beam(cockpit, "Control column", Vector3(0.0, -0.03, -0.30), Vector3(0.0, 0.30, -0.51), 0.023, materials["dark_steel"], 0.021, 8)
	_add_box(cockpit, "Instrument panel", Vector3(0.74, 0.20, 0.055), Vector3(0.0, 0.15, -0.61), materials["dark_steel"])
	for dial in range(7):
		var dial_x: float = lerpf(-0.28, 0.28, float(dial) / 6.0)
		_add_cylinder(cockpit, "Instrument dial %02d" % dial, 0.035, 0.012, Vector3(dial_x, 0.17, -0.575), materials["black"], "z", 12)
	_add_beam(cockpit, "Port lap belt", Vector3(-0.13, 0.08, -0.01), Vector3(0.02, 0.04, 0.14), 0.014, materials["interior"], 0.014, 8)
	_add_beam(cockpit, "Starboard lap belt", Vector3(0.13, 0.08, -0.01), Vector3(-0.02, 0.04, 0.14), 0.014, materials["interior"], 0.014, 8)


func _build_gear_and_tail_hook() -> void:
	for side: float in [-1.0, 1.0]:
		var side_name: String = "Port" if side < 0.0 else "Starboard"
		var root: Vector3 = Vector3(side * 1.92, 2.00, -0.84)
		var wheel: Vector3 = Vector3(side * MAIN_WHEEL_CENTER_M.x, MAIN_WHEEL_CENTER_M.y, MAIN_WHEEL_CENTER_M.z)
		var gear: Node3D = _new_group(landing_gear, "%s main oleo and wheel" % side_name, root)
		_add_beam(gear, "Simple main strut", Vector3.ZERO, wheel - root, 0.065, materials["steel"], 0.065, 12)
		_add_cylinder(gear, "Tyre", MAIN_WHEEL_RADIUS_M, 0.16, wheel - root, materials["rubber"], "x", 28)
		_add_cylinder(gear, "Hub cap", 0.18, 0.17, wheel - root, materials["steel"], "x", 18)
		var wheel_marker: Marker3D = _add_marker(landing_gear, "GEAR_WHEEL_%s" % side_name.to_upper(), wheel, "landing_gear_module", "deployed wheel center; photo-based estimate", 0.55)
		wheel_marker.set_meta("wheel_radius_m", MAIN_WHEEL_RADIUS_M)
	_add_sb2c_tailwheel(TAIL_WHEEL_CENTER_M)
	arrestor_hook = _new_group(small_equipment_module, "Retractable arrestor hook")
	_add_marker(small_equipment_module, "ARRESTOR_HOOK_PIVOT", Vector3(0.0, 1.72, 2.52), "fuselage_module", "simplified hook root; photo-based estimate", 0.55)
	_add_beam(arrestor_hook, "Hook pivot lug", Vector3(0.0, 1.72, 2.52), Vector3(0.0, 1.56, 2.83), 0.064, materials["dark_steel"], 0.050, 10)
	_add_beam(arrestor_hook, "Arrestor shank", Vector3(0.0, 1.57, 2.82), Vector3(0.0, 1.50, 4.50), 0.048, materials["steel"], 0.038, 10)
	_add_beam(arrestor_hook, "Hook terminal", Vector3(0.0, 1.50, 4.50), Vector3(0.0, 1.42, 4.72), 0.038, materials["steel"], 0.030, 10)
	_add_beam(arrestor_hook, "Hook beak", Vector3(0.0, 1.42, 4.72), Vector3(0.0, 1.50, 4.82), 0.030, materials["dark_steel"], 0.018, 8)
	var hook_tip: Marker3D = _add_marker(small_equipment_module, "ARRESTOR_HOOK_TIP_DEPLOYED", Vector3(0.0, 1.42, 4.72), "fuselage_module", "displayed deployed hook tip, not cable dynamics", 0.55)
	hook_tip.rotation.y = PI_F


func _add_sb2c_tailwheel(position: Vector3) -> void:
	var tail_gear: Node3D = _new_group(landing_gear, "Tail wheel assembly", position)
	var attachment: Vector3 = Vector3(0.0, 0.65, -0.12)
	var fork_root: Vector3 = Vector3(0.0, 0.14, 0.03)
	_add_beam(tail_gear, "Simple tailwheel strut", attachment, fork_root, 0.047, materials["steel"], 0.040, 10)
	for side: float in [-1.0, 1.0]:
		_add_beam(tail_gear, "Tailwheel fork cheek", Vector3(side * 0.065, fork_root.y, fork_root.z), Vector3(side * 0.065, 0.02, 0.03), 0.025, materials["steel"], 0.022, 8)
	_add_cylinder(tail_gear, "Tail tyre", TAIL_WHEEL_RADIUS_M, 0.11, Vector3.ZERO, materials["rubber"], "x", 24)
	_add_cylinder(tail_gear, "Tail hub", 0.068, 0.115, Vector3.ZERO, materials["steel"], "x", 16)
	var marker: Marker3D = _add_marker(landing_gear, "GEAR_WHEEL_TAIL", position, "landing_gear_module", "deployed wheel center; short support under aft shell", 0.55)
	marker.set_meta("wheel_radius_m", TAIL_WHEEL_RADIUS_M)
	_add_marker(fuselage_module, "GEAR_TAIL_ATTACHMENT", position + attachment, "fuselage_module", "tail gear root intersects aft belly", 0.55)


func _build_dive_brakes() -> void:
	for side in [-1.0, 1.0]:
		_add_split_dive_brake("%s upper split flap" % ("Port" if side < 0.0 else "Starboard"), side, true, deg_to_rad(34.0))
		_add_split_dive_brake("%s lower split flap" % ("Port" if side < 0.0 else "Starboard"), side, false, deg_to_rad(43.0))
		var upper_hinge: Vector3 = _wing_point(1.18, 0.72, true)
		var lower_hinge: Vector3 = _wing_point(1.18, 0.72, false)
		upper_hinge.x *= side
		lower_hinge.x *= side
		_add_marker(dive_brakes_module, "DIVE_BRAKE_HINGE_%s_UPPER" % ("PORT" if side < 0.0 else "STARBOARD"), upper_hinge, "wing_module", "upper split flap hinge; photo estimate", 0.7)
		_add_marker(dive_brakes_module, "DIVE_BRAKE_HINGE_%s_LOWER" % ("PORT" if side < 0.0 else "STARBOARD"), lower_hinge, "wing_module", "lower split flap hinge; photo estimate", 0.7)


func _add_split_dive_brake(part_name: String, side: float, upper: bool, opening_angle: float) -> void:
	var parent: Node3D = _new_group(dive_brakes_module, part_name)
	parent.set_meta("station_id", "DIVE_BRAKE_%s_%s" % ["PORT" if side < 0.0 else "STARBOARD", "UPPER" if upper else "LOWER"])
	parent.set_meta("host_module_id", "wing_module")
	var span_start: float = 1.18
	var span_end: float = 4.78
	var chord_start: float = 0.70
	var chord_end: float = 1.00
	var span_cells: int = 16
	var chord_cells: int = 3
	var chord_stride: int = chord_cells + 1
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for span_index in range(span_cells + 1):
		var span: float = lerpf(span_start, span_end, float(span_index) / float(span_cells))
		for chord_index in range(chord_cells + 1):
			var chord_fraction: float = lerpf(chord_start, chord_end, float(chord_index) / float(chord_cells))
			surface.add_vertex(_dive_brake_point(side, upper, opening_angle, span, chord_fraction))
	for span_index in range(span_cells):
		for chord_index in range(chord_cells):
			var a: int = span_index * chord_stride + chord_index
			var b: int = a + chord_stride
			var c: int = b + 1
			var d: int = a + 1
			if upper:
				surface.add_index(a)
				surface.add_index(d)
				surface.add_index(c)
				surface.add_index(a)
				surface.add_index(c)
				surface.add_index(b)
			else:
				surface.add_index(a)
				surface.add_index(b)
				surface.add_index(c)
				surface.add_index(a)
				surface.add_index(c)
				surface.add_index(d)
	surface.generate_normals()
	var panel_mesh: ArrayMesh = surface.commit()
	_part(parent, "Solid split flap skin", panel_mesh, materials["dive_brake"])
	var frame_path := PackedVector3Array()
	for point in [Vector2(span_start, chord_start), Vector2(span_end, chord_start), Vector2(span_end, chord_end), Vector2(span_start, chord_end), Vector2(span_start, chord_start)]:
		frame_path.append(_dive_brake_point(side, upper, opening_angle, point.x, point.y))
	_add_tube_line(parent, "Split flap perimeter", frame_path, 0.012, materials["dive_brake_frame"])
	var center_stiffener := PackedVector3Array()
	center_stiffener.append(_dive_brake_point(side, upper, opening_angle, (span_start + span_end) * 0.5, chord_start))
	center_stiffener.append(_dive_brake_point(side, upper, opening_angle, (span_start + span_end) * 0.5, chord_end))
	_add_tube_line(parent, "Single flap stiffener", center_stiffener, 0.012, materials["dive_brake_frame"])


func _dive_brake_point(side: float, upper: bool, opening_angle: float, span: float, chord_fraction: float) -> Vector3:
	var wing: Vector4 = _sample_wing_profile(wing_profile, span)
	var thickness_ratio: float = _wing_thickness_ratio(wing_profile, span)
	var hinge_fraction: float = 0.70
	var hinge_z: float = wing.z + wing.y * hinge_fraction
	var flap_distance: float = (chord_fraction - hinge_fraction) * wing.y
	var hinge_y: float = wing.w + _airfoil_height(hinge_fraction, wing.y, thickness_ratio, upper)
	var vertical: float = sin(opening_angle) * flap_distance * (1.0 if upper else -1.0)
	var rearward: float = cos(opening_angle) * flap_distance
	return Vector3(side * span, hinge_y + vertical, hinge_z + rearward)


func _build_armament_and_stores() -> void:
	_add_cannon(-1.0, "port")
	_add_cannon(1.0, "starboard")
	_add_internal_bomb_bay()
	var stations: Array[float] = [2.42, 3.25, 5.30, 6.33]
	var chord_positions: Array[float] = [0.58, 0.63, 0.56, 0.63]
	for side in [-1.0, 1.0]:
		for index in range(stations.size()):
			_add_hvar_station(side, index + 1, stations[index], chord_positions[index])


func _add_cannon(side: float, side_name: String) -> void:
	var span: float = 4.43
	var station: Vector4 = _sample_wing_profile(wing_profile, span)
	var z: float = station.z + station.y * 0.075
	var y: float = station.w + _airfoil_height(0.075, station.y, _wing_thickness_ratio(wing_profile, span), true) - 0.025
	var socket_position: Vector3 = Vector3(side * span, y, z)
	var gun: Node3D = _new_group(armament_module, "20 mm AN/M2 wing cannon %s" % side_name, socket_position)
	var station_id: String = "WEAPON_CANNON_ANM2_%s" % side_name.to_upper()
	gun.set_meta("station_id", station_id)
	gun.set_meta("host_module_id", "wing_module")
	_add_marker(wing_module, station_id, socket_position, "wing_module", "fixed wing cannon; location estimated from SB2C-3/-4 views", 0.65)
	_add_box(gun, "Cannon receiver", Vector3(0.10, 0.085, 0.74), Vector3(0.0, 0.02, 0.02), materials["dark_steel"])
	_add_cylinder(gun, "AN/M2 barrel", 0.034, 0.66, Vector3(0.0, 0.012, -0.27), materials["steel"], "z", 12)
	_add_cylinder(gun, "20 mm muzzle", 0.050, 0.035, Vector3(0.0, 0.012, -0.62), materials["black"], "z", 14)
	_add_marker(gun, "MUZZLE_CANNON_ANM2_%s" % side_name.to_upper(), Vector3(0.0, 0.012, -0.62), "wing_module", "presentation muzzle; fixed forward cannon", 0.65)
	_add_flat_patch(gun, "Spent case chute", PackedVector2Array([
		Vector2(-0.06, -0.10), Vector2(0.05, -0.10), Vector2(0.07, -0.03), Vector2(-0.05, -0.03)
	]), 0.01, materials["dark_steel"])


func _add_internal_bomb_bay() -> void:
	bay_open_group = _new_group(armament_module, "Bomb bay shown open")
	_add_box(bay_open_group, "Bomb bay dark inner liner", Vector3(0.68, 0.035, 1.62), Vector3(0.0, 2.15, 0.59), materials["black"])
	var port_door_mesh: ArrayMesh = _create_bomb_bay_door_mesh(-1.0)
	var starboard_door_mesh: ArrayMesh = _create_bomb_bay_door_mesh(1.0)
	_add_bomb_bay_door(bay_open_group, -1.0, port_door_mesh, true)
	_add_bomb_bay_door(bay_open_group, 1.0, starboard_door_mesh, true)
	_add_beam(bay_open_group, "Bomb cradle transverse carrier", Vector3(-0.19, 2.30, 0.22), Vector3(0.19, 2.30, 0.22), 0.040, materials["steel"], 0.040, 12)
	_add_beam(bay_open_group, "Bomb crutch port arm", Vector3(-0.19, 2.30, 0.22), Vector3(-0.12, 2.13, 0.49), 0.040, materials["dark_steel"], 0.032, 10)
	_add_beam(bay_open_group, "Bomb crutch starboard arm", Vector3(0.19, 2.30, 0.22), Vector3(0.12, 2.13, 0.49), 0.040, materials["dark_steel"], 0.032, 10)
	for side in [-1.0, 1.0]:
		_add_beam(bay_open_group, "Bomb bay door hinge rail", Vector3(side * 0.37, 1.86, -0.22), Vector3(side * 0.37, 1.86, 1.40), 0.022, materials["steel"], 0.022, 10)
	_add_marker(fuselage_module, "WEAPON_INTERNAL_BOMB_BAY", Vector3(0.0, 2.15, 0.59), "fuselage_module", "internal displacement gear / bomb carrier", 0.55)
	_add_marker(fuselage_module, "STORE_RELEASE_INTERNAL_BOMB", Vector3(0.0, 1.93, 0.59), "fuselage_module", "displayed store center; release motion owned by future bombing system", 0.55)
	_add_500lb_bomb(bay_open_group, Vector3(0.0, 1.93, 0.59))
	bay_closed_group = _new_group(armament_module, "Bomb bay doors shown closed")
	_add_bomb_bay_door(bay_closed_group, -1.0, port_door_mesh, false)
	_add_bomb_bay_door(bay_closed_group, 1.0, starboard_door_mesh, false)
	bay_closed_group.visible = false


func _add_bomb_bay_door(parent: Node3D, side: float, door_mesh: ArrayMesh, open: bool) -> void:
	var side_name: String = "Port" if side < 0.0 else "Starboard"
	var door := _new_group(parent, "%s bomb bay door pivot" % side_name, Vector3(side * 0.37, 1.86, 0.0))
	if open:
		door.rotation.z = side * deg_to_rad(60.0)
	var door_material: Material = materials["bomb_bay_door"] if open else materials["top"]
	_part(door, "%s curved bomb bay door" % side_name, door_mesh, door_material)
	if open:
		var inverse_basis: Basis = door.basis.inverse()
		for stay_index in range(3):
			var stay_z: float = [-0.05, 0.59, 1.22][stay_index]
			var frame_anchor := Vector3(side * 0.25, 2.08, stay_z)
			var door_anchor := Vector3(side * 0.26, 1.74, stay_z)
			var local_frame_anchor: Vector3 = inverse_basis * (frame_anchor - door.position)
			var local_door_anchor: Vector3 = inverse_basis * (door_anchor - door.position)
			_add_beam(door, "%s bomb bay opening stay %02d" % [side_name, stay_index + 1], local_frame_anchor, local_door_anchor, 0.024, materials["steel"], 0.024, 10)


func _create_bomb_bay_door_mesh(side: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var longitudinal_sections: int = 28
	var transverse_sections: int = 12
	var stride: int = transverse_sections + 1
	for z_index in range(longitudinal_sections + 1):
		var z: float = lerpf(-0.25, 1.43, float(z_index) / float(longitudinal_sections))
		var station: Vector4 = _sample_station(fuselage_profile, z)
		for x_index in range(transverse_sections + 1):
			var x: float = lerpf(0.0, side * 0.40, float(x_index) / float(transverse_sections))
			var radial_ratio: float = clampf(x / station.y, -0.98, 0.98)
			var y: float = station.x - station.z * sqrt(1.0 - radial_ratio * radial_ratio) - 0.006
			surface.add_vertex(Vector3(x - side * 0.37, y - 1.86, z))
	for z_index in range(longitudinal_sections):
		for x_index in range(transverse_sections):
			var a: int = z_index * stride + x_index
			var b: int = a + stride
			var c: int = b + 1
			var d: int = a + 1
			if side < 0.0:
				surface.add_index(a)
				surface.add_index(b)
				surface.add_index(c)
				surface.add_index(a)
				surface.add_index(c)
				surface.add_index(d)
			else:
				surface.add_index(a)
				surface.add_index(c)
				surface.add_index(b)
				surface.add_index(a)
				surface.add_index(d)
				surface.add_index(c)
	surface.generate_normals()
	return surface.commit()


func _add_500lb_bomb(parent: Node3D, position: Vector3) -> void:
	var bomb: Node3D = _new_group(parent, "One 500 lb general purpose bomb", position)
	_add_cylinder(bomb, "Bomb case", 0.175, 1.05, Vector3(0.0, 0.0, 0.02), materials["bomb"], "z", 24)
	_add_tapered_cylinder(bomb, "Bomb nose", 0.025, 0.175, 0.30, Vector3(0.0, 0.0, -0.64), materials["bomb"], "z")
	_add_tapered_cylinder(bomb, "Bomb tail taper", 0.175, 0.065, 0.26, Vector3(0.0, 0.0, 0.66), materials["bomb"], "z")
	_add_box(bomb, "Bomb tail fin vertical", Vector3(0.018, 0.28, 0.18), Vector3(0.0, 0.0, 0.74), materials["dark_steel"])
	_add_box(bomb, "Bomb tail fin horizontal", Vector3(0.28, 0.018, 0.18), Vector3(0.0, 0.0, 0.74), materials["dark_steel"])
	for side in [-1.0, 1.0]:
		_add_beam(bomb, "Bomb suspension lug %s" % ("port" if side < 0.0 else "starboard"), Vector3(side * 0.12, 0.16, -0.06), Vector3(side * 0.12, 0.23, -0.06), 0.026, materials["steel"], 0.026, 8)


func _add_hvar_station(side: float, index: int, span: float, chord_fraction: float) -> void:
	var wing: Vector4 = _sample_wing_profile(wing_profile, span)
	var z: float = wing.z + wing.y * chord_fraction
	var lower_y: float = wing.w + _airfoil_height(chord_fraction, wing.y, _wing_thickness_ratio(wing_profile, span), false)
	var station_id: String = "HVAR_%s_%02d" % ["PORT" if side < 0.0 else "STARBOARD", index]
	var socket_position: Vector3 = Vector3(side * span, lower_y - 0.005, z)
	_add_marker(wing_module, station_id, socket_position, "wing_module", "5 in HVAR launcher shoe; station estimated from model / store views", 0.55)
	var store: Node3D = _new_group(external_stores_module, "5 in HVAR rocket %s %02d" % ["port" if side < 0.0 else "starboard", index], socket_position)
	store.set_meta("station_id", station_id)
	store.set_meta("host_module_id", "wing_module")
	_add_beam(store, "Wing pylon and release lug", Vector3(0.0, -0.01, 0.0), Vector3(0.0, -0.11, 0.05), 0.035, materials["steel"], 0.032, 10)
	_add_box(store, "Rocket zero-length rail", Vector3(0.095, 0.035, 0.78), Vector3(0.0, -0.14, 0.07), materials["dark_steel"])
	_add_cylinder(store, "HVAR body", 0.0635, 0.96, Vector3(0.0, -0.19, 0.09), materials["rocket"], "z", 16)
	_add_tapered_cylinder(store, "HVAR warhead nose", 0.009, 0.0635, 0.26, Vector3(0.0, -0.19, -0.52), materials["rocket"], "z")
	_add_hvar_fins(store)


func _add_hvar_fins(parent: Node3D) -> void:
	var fin_root: Node3D = _new_group(parent, "Four stabilizer fins", Vector3(0.0, -0.19, 0.51))
	var fin_outline := PackedVector2Array([
		Vector2(0.045, -0.08), Vector2(0.052, 0.04), Vector2(0.25, 0.13),
		Vector2(0.37, 0.09), Vector2(0.20, -0.08)
	])
	for turn in range(4):
		var fin: Node3D = _new_group(fin_root, "Fin %02d" % turn)
		fin.rotation.z = TAU * float(turn) / 4.0
		_add_extruded_xy_shape(fin, "Tail fin plate", fin_outline, 0.012, materials["dark_steel"])


func _build_surface_details() -> void:
	_add_gear_doors_and_bay_edges()
	for side in [-1.0, 1.0]:
		for span in [0.85, 1.70, 2.80, 4.05, 5.30, 6.25, 7.42]:
			var wing: Vector4 = _sample_wing_profile(wing_profile, span)
			var start_z: float = wing.z + wing.y * 0.08
			var end_z: float = wing.z + wing.y * 0.91
			var start := Vector3(side * span, _wing_y(wing_profile, span, start_z) + 0.012, start_z)
			var finish := Vector3(side * span, _wing_y(wing_profile, span, end_z) + 0.012, end_z)
			_add_surface_seam(wing_module, "Wing rib and access line", start, finish, 0.0055)
		for span in [1.05, 2.20, 3.40]:
			var z: float = -3.60 + (span - 1.05) * 0.13
			_add_surface_seam(fuselage_module, "Fuselage side panel seam", Vector3(side * 0.67, 2.35, z), Vector3(side * 0.67, 2.73, z + 0.06), 0.007)
		var tip_light: Vector3 = _wing_point(7.47, 0.50, true)
		tip_light.x *= side
		_add_light(wing_module, "Port navigation light" if side < 0.0 else "Starboard navigation light", tip_light, materials["lamp_red"] if side < 0.0 else materials["lamp_green"])
	var pitot: Vector3 = _wing_point(6.53, 0.06, true)
	pitot.x *= -1.0
	_add_beam(wing_module, "Port wing pitot tube", pitot + Vector3(-0.02, -0.04, 0.02), pitot + Vector3(-0.02, -0.02, -0.72), 0.018, materials["steel"], 0.011, 8)
	_add_light(empennage_module, "Fin tip tail navigation lamp", Vector3(0.0, 4.43, 3.17), materials["lamp_white"])


func _add_gear_doors_and_bay_edges() -> void:
	for side in [-1.0, 1.0]:
		var door := PackedVector2Array([
			Vector2(side * 1.72, -1.34), Vector2(side * 2.17, -1.24),
			Vector2(side * 2.20, -0.36), Vector2(side * 1.76, -0.42)
		])
		_add_horizontal_panel(landing_gear, "Gear well lip %s" % ("port" if side < 0.0 else "starboard"), door, 1.78, materials["dark_steel"])


func _add_aircraft_markings() -> void:
	for side in [-1.0, 1.0]:
		_add_late_war_wing_insignia(side, 5.88, -0.32)
		_add_late_war_fuselage_insignia(side, 2.42, 2.14, 0.34)


func _add_late_war_wing_insignia(side: float, center_x: float, center_z: float) -> void:
	var first_child: int = get_child_count()
	_add_wing_disc("Dark blue national insignia field", side, center_x, center_z, _wing_y(wing_profile, center_x, center_z) + 0.013, 0.44, materials["insignia_blue"])
	var star_points := PackedVector2Array()
	for index in range(10):
		var radius: float = 0.265 if index % 2 == 0 else 0.118
		var angle: float = -PI_F * 0.5 + TAU * float(index) / 10.0
		star_points.append(Vector2(center_z + sin(angle) * radius, -side * (center_x + cos(angle) * radius)))
	_add_wing_surface_patch("White US star", star_points, side, 0.025, materials["insignia_white"], center_x, center_z)
	for bar_side in [-1.0, 1.0]:
		var bar_center: float = center_x + bar_side * 0.48
		var bar_outline := PackedVector2Array([
			Vector2(center_z - 0.12, -side * (bar_center - 0.17)),
			Vector2(center_z - 0.12, -side * (bar_center + 0.17)),
			Vector2(center_z + 0.12, -side * (bar_center + 0.17)),
			Vector2(center_z + 0.12, -side * (bar_center - 0.17))
		])
		_add_wing_surface_patch("White US insignia bar", bar_outline, side, 0.029, materials["insignia_white"], center_x, center_z)
	_move_new_children(wing_module, first_child)


func _add_late_war_fuselage_insignia(side: float, z: float, y: float, radius: float) -> void:
	var circle := PackedVector2Array()
	for index: int in range(32):
		var angle: float = PI_F * 0.5 + TAU * float(index) / 32.0
		circle.append(Vector2(cos(angle), sin(angle)) * radius)
	_add_fuselage_marking_patch("Fuselage insignia blue field", side, z, y, circle, 0.008, materials["insignia_blue"])
	var star := PackedVector2Array()
	for index: int in range(10):
		var star_radius: float = radius * (0.78 if index % 2 == 0 else 0.34)
		var angle: float = PI_F * 0.5 + TAU * float(index) / 10.0
		star.append(Vector2(cos(angle), sin(angle)) * star_radius)
	_add_fuselage_marking_patch("Fuselage white star", side, z, y, star, 0.014, materials["insignia_white"])
	for bar_side: float in [-1.0, 1.0]:
		var outline := PackedVector2Array([
			Vector2(-radius * 0.45, -radius * 0.18), Vector2(radius * 0.45, -radius * 0.18),
			Vector2(radius * 0.45, radius * 0.18), Vector2(-radius * 0.45, radius * 0.18)
		])
		_add_fuselage_marking_patch("Fuselage white insignia bar", side, z + bar_side * radius * 1.20, y, outline, 0.014, materials["insignia_white"])


func _add_fuselage_marking_patch(part_name: String, side: float, z: float, y: float, outline: PackedVector2Array, offset: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.add_vertex(_fuselage_marking_point(side, z, y, offset))
	for point: Vector2 in outline:
		surface.add_vertex(_fuselage_marking_point(side, z + point.x, y + point.y, offset))
	for index: int in range(outline.size()):
		var next: int = (index + 1) % outline.size()
		surface.add_index(0)
		surface.add_index(index + 1 if side < 0.0 else next + 1)
		surface.add_index(next + 1 if side < 0.0 else index + 1)
	surface.generate_normals()
	_part(fuselage_module, part_name, surface.commit(), material)


func _fuselage_marking_point(side: float, z: float, y: float, offset: float) -> Vector3:
	var station: Vector4 = _sample_station(fuselage_profile, z)
	var vertical: float = clampf((y - station.x) / station.z, -0.98, 0.98)
	var x: float = station.y * sqrt(1.0 - vertical * vertical)
	return Vector3(side * (x + offset), y, z)


func _wing_point(span: float, chord_fraction: float, upper: bool) -> Vector3:
	var wing: Vector4 = _sample_wing_profile(wing_profile, span)
	var vertical: float = _airfoil_height(chord_fraction, wing.y, _wing_thickness_ratio(wing_profile, span), upper)
	return Vector3(span, wing.w + vertical, wing.z + wing.y * chord_fraction)


func _add_marker(parent: Node3D, marker_name: String, position: Vector3, host_module: String, source_status: String, confidence: float) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = position
	marker.set_meta("station_id", marker_name)
	marker.set_meta("host_module", host_module)
	marker.set_meta("host_module_id", host_module)
	marker.set_meta("interface", "aircraft_station")
	marker.set_meta("source_status", source_status)
	marker.set_meta("confidence", confidence)
	parent.add_child(marker)
	return marker


func _move_new_children(target: Node3D, first_child: int) -> void:
	while get_child_count() > first_child:
		var child: Node = get_child(first_child)
		remove_child(child)
		target.add_child(child)


func _add_cowl_flaps() -> void:
	var flap_count: int = 16
	for index in range(flap_count):
		var angle: float = TAU * float(index) / float(flap_count)
		var start := Vector3(cos(angle) * 0.75, 2.38 + sin(angle) * 0.72, -3.74)
		var finish := Vector3(cos(angle) * 0.80, 2.38 + sin(angle) * 0.77, -3.48)
		_add_beam(powerplant_module, "Cowling cooling flap %02d" % index, start, finish, 0.025, materials["dark_steel"], 0.022, 8)


func _add_exhausts() -> void:
	for side in [-1.0, 1.0]:
		for index in range(5):
			var z: float = -3.53 + float(index) * 0.16
			var y: float = 2.30 - float(index) * 0.027
			var root: Vector3 = Vector3(side * 0.70, y, z)
			var tip: Vector3 = Vector3(side * 0.83, y - 0.025, z - 0.16)
			_add_beam(powerplant_module, "Individual exhaust stack %s %02d" % ["port" if side < 0.0 else "starboard", index], root, tip, 0.046, materials["exhaust"], 0.040, 8)
			_add_cylinder(powerplant_module, "Open exhaust mouth %s %02d" % ["port" if side < 0.0 else "starboard", index], 0.030, 0.018, tip, materials["black"], "z", 10)


func _add_lower_intake() -> void:
	var scoop: MeshInstance3D = _add_sphere(fuselage_module, "Under-cowling carburetor intake fairing", 1.0, Vector3(0.0, 1.61, -4.21), materials["top"], Vector3(0.35, 0.23, 0.41))
	scoop.rotation.x = -0.08
	_add_cylinder(fuselage_module, "Intake mouth shadow", 0.13, 0.035, Vector3(0.0, 1.53, -4.45), materials["black"], "z", 24)
	_add_beam(fuselage_module, "Lower oil cooler fairing", Vector3(-0.50, 1.77, -3.94), Vector3(-0.50, 1.72, -3.46), 0.09, materials["top"], 0.05, 10)
	_add_beam(fuselage_module, "Lower oil cooler fairing", Vector3(0.50, 1.77, -3.94), Vector3(0.50, 1.72, -3.46), 0.09, materials["top"], 0.05, 10)


func _add_tapered_cylinder(parent: Node3D, part_name: String, root_radius: float, tip_radius: float, length: float, position: Vector3, material: Material, axis: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = root_radius
	mesh.top_radius = tip_radius
	mesh.height = length
	mesh.radial_segments = 20
	var instance: MeshInstance3D = _part(parent, part_name, mesh, material, position)
	if axis == "z":
		instance.rotation.x = PI_F * 0.5
	return instance
