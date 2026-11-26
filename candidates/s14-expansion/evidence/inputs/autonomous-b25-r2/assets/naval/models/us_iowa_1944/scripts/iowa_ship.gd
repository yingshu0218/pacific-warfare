class_name IowaShip
extends Node3D

const GEOMETRY = preload("iowa_geometry.gd")
const FOUNDATION_SCRIPT = preload("iowa_mount_foundation.gd")
const MAIN_TURRET_SCENE: PackedScene = preload("../scenes/weapons/main_16in_three_gun.tscn")
const SECONDARY_TWIN_SCENE: PackedScene = preload("../scenes/weapons/secondary_5in38_twin.tscn")
const BOFORS_QUAD_SCENE: PackedScene = preload("../scenes/weapons/bofors_40mm_quad.tscn")
const OERLIKON_SINGLE_SCENE: PackedScene = preload("../scenes/weapons/oerlikon_20mm_single.tscn")
const AIRCRAFT_CATAPULT_SCENE: PackedScene = preload("../scenes/equipment/aircraft_catapult_turntable.tscn")
const AIRCRAFT_CRANE_SCENE: PackedScene = preload("../scenes/equipment/aircraft_crane_lattice.tscn")
const MEASURE_32_SHADER: Shader = preload("../shaders/iowa_measure32_1b.gdshader")
const CAMOUFLAGE_MASK: Script = preload("iowa_camouflage_mask.gd")
const SIMULATION_SCRIPT = preload("iowa_simulation.gd")

@export var viewer_motion_enabled: bool = true
@export var batch_static_parts: bool = true

var geometry_parent: Node3D
var hull_root: Node3D
var superstructure_root: Node3D
var bridge_root: Node3D
var platforms_root: Node3D
var mast_root: Node3D
var funnel_root: Node3D
var aft_tower_root: Node3D
var mount_foundations_root: Node3D
var equipment_root: Node3D
var simulation: IowaSimulation
var weapon_mounts: Array[IowaWeaponMount] = []
var mount_index: Dictionary = {}
var configuration: Dictionary = {}
var palette: Dictionary = {}
var hull_stations: Array[Dictionary] = []
var main_mounts: Dictionary = {}
var platform_hosts: Dictionary = {}
var battery_deck_root: Node3D

func _ready() -> void:
	configuration = _load_configuration()
	_make_palette()
	_create_module_hierarchy()
	geometry_parent = hull_root
	_build_hull()
	_build_superstructure()
	geometry_parent = equipment_root
	_build_deck_equipment()
	_build_mounts()
	if batch_static_parts:
		_batch_static_tree(self)
	if viewer_motion_enabled:
		simulation = SIMULATION_SCRIPT.new() as IowaSimulation
		simulation.name = "IowaFixedStepSimulation"
		add_child(simulation)
		simulation.configure(self, weapon_mounts)

func _create_module_hierarchy() -> void:
	hull_root = _add_module(self, "Hull")
	superstructure_root = _add_module(self, "Superstructure")
	bridge_root = _add_module(superstructure_root, "Bridge")
	platforms_root = _add_module(superstructure_root, "Platforms")
	mast_root = _add_module(superstructure_root, "Mast")
	funnel_root = _add_module(superstructure_root, "Funnel")
	aft_tower_root = _add_module(superstructure_root, "AfterTower")
	mount_foundations_root = _add_module(self, "MountFoundations")
	equipment_root = _add_module(self, "Equipment")

func _add_module(parent: Node3D, module_name: String) -> Node3D:
	var module: Node3D = Node3D.new()
	module.name = module_name
	parent.add_child(module)
	return module

func _load_configuration() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("../data/december_1944.json")))
	if parsed is Dictionary:
		return parsed
	push_error("Could not read Iowa configuration data")
	return {}

func _make_palette() -> void:
	var camouflage: Dictionary = configuration.get("camouflage", {})
	var camouflage_colors: Dictionary = camouflage.get("colors", {})
	var hull_camo: ShaderMaterial = _create_camouflage_material(camouflage_colors, Color.WHITE, true)
	var superstructure_camo: ShaderMaterial = _create_camouflage_material(camouflage_colors, Color.WHITE, false)
	var dark_superstructure_camo: ShaderMaterial = _create_camouflage_material(camouflage_colors, Color("c5cbd0"), false)
	palette = {
		"hull": hull_camo,
		"hull_below": GEOMETRY.material(Color("574f4b"), 0.8),
		"hull_edge": GEOMETRY.material(Color("454f57"), 0.72),
		"deck": GEOMETRY.material(Color(str(camouflage_colors.get("deck_blue_20_b", "35434d"))), 0.9),
		"deck_detail": GEOMETRY.material(Color("46535c"), 0.82),
		"superstructure": superstructure_camo,
		"superstructure_dark": dark_superstructure_camo,
		"mount_camo": _create_camouflage_material(camouflage_colors, Color.WHITE, false),
		"turret": GEOMETRY.material(Color("707a7f"), 0.78),
		"turret_roof": GEOMETRY.material(Color("8b9294"), 0.78),
		"barbettes": GEOMETRY.material(Color("59636a"), 0.78),
		"gunmetal": GEOMETRY.material(Color("414a50"), 0.68, 0.18),
		"steel": GEOMETRY.material(Color("a0a6a7"), 0.68, 0.12),
		"railings": GEOMETRY.material(Color("9aa2a3"), 0.74, 0.08),
		"dark_glass": GEOMETRY.material(Color("202d34"), 0.32, 0.16),
		"port_buckler": GEOMETRY.material(Color("343d42"), 0.96),
		"seat": GEOMETRY.material(Color("465056"), 0.86),
		"mast": GEOMETRY.material(Color("788287"), 0.78),
		"waterline": GEOMETRY.material(Color("313a40"), 0.72)
	}

func _create_camouflage_material(colors: Dictionary, tint: Color, paint_underwater: bool) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = MEASURE_32_SHADER
	material.set_shader_parameter("camouflage_mask", CAMOUFLAGE_MASK.texture())
	material.set_shader_parameter("navy_blue", Color(str(colors.get("navy_blue_5_n", "40515b"))))
	material.set_shader_parameter("light_gray", Color(str(colors.get("light_gray_5_l", "a5acad"))))
	material.set_shader_parameter("deck_blue", Color(str(colors.get("deck_blue_20_b", "35434d"))))
	material.set_shader_parameter("anti_fouling_red", Color(str(colors.get("anti_fouling_red", "70463d"))))
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("paint_underwater", paint_underwater)
	material.set_shader_parameter("paint_decks", true)
	return material

func _make_hull_stations() -> void:
	hull_stations.clear()
	var raw: Array[Array] = [
		[-135.2, 0.18, 8.5, -8.5], [-130.0, 1.5, 8.2, -10.0], [-120.0, 3.0, 7.8, -11.3],
		[-105.0, 5.5, 7.0, -11.3], [-88.0, 8.2, 6.2, -11.3], [-72.0, 10.7, 5.7, -11.3],
		[-58.8, 12.0, 5.5, -11.3], [-40.0, 14.1, 5.4, -11.3], [-23.0, 15.5, 5.35, -11.3],
		[-5.0, 16.5, 5.3, -11.3], [15.0, 16.5, 5.3, -11.3], [35.0, 16.3, 5.25, -11.3],
		[55.0, 15.7, 5.2, -11.3], [75.0, 14.0, 5.2, -11.3], [95.0, 11.2, 5.2, -11.3],
		[113.0, 8.3, 5.2, -10.9], [125.0, 6.0, 5.2, -9.6], [132.0, 4.0, 5.2, -7.6], [135.2, 0.3, 5.2, -6.0]
	]
	for row: Array in raw:
		hull_stations.append({"z": float(row[0]), "breadth": float(row[1]), "deck_y": float(row[2]), "keel_y": float(row[3])})
	var control_stations: Array[Dictionary] = []
	for station: Dictionary in hull_stations:
		control_stations.append(station)
	hull_stations = _interpolate_hull_stations(control_stations, 4)

func _interpolate_hull_stations(control_stations: Array[Dictionary], subdivisions: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if control_stations.size() < 2:
		return control_stations.duplicate()
	for section_index: int in range(control_stations.size() - 1):
		var first: Dictionary = control_stations[section_index]
		var second: Dictionary = control_stations[section_index + 1]
		for subdivision: int in range(subdivisions):
			var amount: float = float(subdivision) / float(subdivisions)
			var sample: Dictionary = {
				"z": lerpf(float(first["z"]), float(second["z"]), amount),
				"breadth": _interpolate_hull_value(control_stations, section_index, amount, "breadth"),
				"deck_y": _interpolate_hull_value(control_stations, section_index, amount, "deck_y"),
				"keel_y": _interpolate_hull_value(control_stations, section_index, amount, "keel_y")
			}
			result.append(sample)
	result.append(control_stations.back().duplicate())
	return result

func _interpolate_hull_value(stations: Array[Dictionary], section_index: int, amount: float, component: String) -> float:
	var first: Dictionary = stations[section_index]
	var second: Dictionary = stations[section_index + 1]
	var previous: Dictionary = stations[maxi(0, section_index - 1)]
	var following: Dictionary = stations[mini(stations.size() - 1, section_index + 2)]
	var z0: float = float(first["z"])
	var z1: float = float(second["z"])
	var interval: float = z1 - z0
	var v0: float = float(first[component])
	var v1: float = float(second[component])
	var slope0: float = (v1 - v0) / interval
	var slope1: float = slope0
	if section_index > 0:
		slope0 = (v1 - float(previous[component])) / (z1 - float(previous["z"]))
	if section_index + 2 < stations.size():
		slope1 = (float(following[component]) - v0) / (float(following["z"]) - z0)
	var amount_squared: float = amount * amount
	var amount_cubed: float = amount_squared * amount
	var value: float = (2.0 * amount_cubed - 3.0 * amount_squared + 1.0) * v0
	value += (amount_cubed - 2.0 * amount_squared + amount) * slope0 * interval
	value += (-2.0 * amount_cubed + 3.0 * amount_squared) * v1
	value += (amount_cubed - amount_squared) * slope1 * interval
	return clampf(value, minf(v0, v1), maxf(v0, v1))

func _deck_height_at(z_value: float) -> float:
	if hull_stations.is_empty():
		_make_hull_stations()
	if z_value <= float(hull_stations[0]["z"]):
		return float(hull_stations[0]["deck_y"])
	for index: int in range(hull_stations.size() - 1):
		var first: Dictionary = hull_stations[index]
		var second: Dictionary = hull_stations[index + 1]
		if z_value <= float(second["z"]):
			var amount: float = inverse_lerp(float(first["z"]), float(second["z"]), z_value)
			return lerpf(float(first["deck_y"]), float(second["deck_y"]), amount)
	return float(hull_stations.back()["deck_y"])

func _half_breadth_at(z_value: float) -> float:
	for index: int in range(hull_stations.size() - 1):
		var first: Dictionary = hull_stations[index]
		var second: Dictionary = hull_stations[index + 1]
		if z_value <= float(second["z"]):
			var amount: float = inverse_lerp(float(first["z"]), float(second["z"]), z_value)
			return lerpf(float(first["breadth"]), float(second["breadth"]), amount)
	return float(hull_stations.back()["breadth"])

func _build_hull() -> void:
	_make_hull_stations()
	GEOMETRY.add_lofted_hull(geometry_parent, hull_stations, palette.hull)
	GEOMETRY.add_weather_deck(geometry_parent, hull_stations, palette.deck)
	_build_waterline_details()
	_build_propulsion_and_rudder()
	_build_hull_bulwarks()

func _build_waterline_details() -> void:
	GEOMETRY.add_beam(geometry_parent, "CenterlineKeel", Vector3(0.0, -10.9, -89.0), Vector3(0.0, -10.9, 112.0), 0.6, palette.hull_edge, 10)
	for side: float in [-1.0, 1.0]:
		GEOMETRY.add_beam(geometry_parent, "BilgeKeel", Vector3(side * 11.0, -6.3, -50.0), Vector3(side * 12.1, -6.3, 68.0), 0.42, palette.hull_edge, 8)

func _build_hull_bulwarks() -> void:
	for side: float in [-1.0, 1.0]:
		for index: int in range(2, hull_stations.size() - 2):
			var first: Dictionary = hull_stations[index]
			var second: Dictionary = hull_stations[index + 1]
			var first_point: Vector3 = Vector3(side * (float(first["breadth"]) - 0.08), float(first["deck_y"]) + 0.3, float(first["z"]))
			var second_point: Vector3 = Vector3(side * (float(second["breadth"]) - 0.08), float(second["deck_y"]) + 0.3, float(second["z"]))
			GEOMETRY.add_beam(geometry_parent, "DeckEdgeBulwark", first_point, second_point, 0.2, palette.superstructure_dark, 6)

func _build_propulsion_and_rudder() -> void:
	for shaft_index: int in range(4):
		var side: float = -1.0 if shaft_index < 2 else 1.0
		var inner: bool = shaft_index % 2 == 0
		var x_value: float = side * (5.3 if inner else 11.0)
		var prop_z: float = 124.2 if inner else 121.5
		var hull_y: float = -8.1 if inner else -7.8
		GEOMETRY.add_beam(geometry_parent, "PropellerShaft_%02d" % shaft_index, Vector3(x_value * 0.62, hull_y + 1.0, 103.0), Vector3(x_value, hull_y, prop_z), 0.52 if inner else 0.4, palette.hull_edge, 12)
		GEOMETRY.add_beam(geometry_parent, "ShaftStrut_%02d" % shaft_index, Vector3(x_value * 0.82, hull_y + 0.8, 112.0), Vector3(x_value, hull_y - 1.4, prop_z), 0.34, palette.hull_edge, 10)
		GEOMETRY.add_beam(geometry_parent, "PropellerHub_%02d" % shaft_index, Vector3(x_value, hull_y, prop_z - 0.5), Vector3(x_value, hull_y, prop_z + 0.5), 0.84, palette.steel, 16)
		for blade_index: int in range(4):
			var angle: float = TAU * float(blade_index) / 4.0 + float(shaft_index) * 0.27
			var blade_center: Vector3 = Vector3(x_value + cos(angle) * 1.05, hull_y + sin(angle) * 1.05, prop_z)
			GEOMETRY.add_box(geometry_parent, "PropellerBlade", blade_center, Vector3(0.48, 1.9, 0.16), palette.steel, Vector3(0.0, 0.0, -angle))
	for side: float in [-1.0, 1.0]:
		var rudder: MeshInstance3D = GEOMETRY.add_prism(geometry_parent, "Rudder", GEOMETRY.chamfered_outline(2.2, 7.0, 0.65, 131.0), -8.9, -0.5, palette.hull_edge)
		rudder.position.x = side * 3.2
		GEOMETRY.add_cylinder(geometry_parent, "RudderStock", Vector3(side * 3.2, -4.6, 127.2), 0.2, 8.7, palette.steel, 10)

func _add_deckhouse(part_name: String, center_z: float, width: float, length: float, bottom_y: float, top_y: float, mat: Material, chamfer: float = 1.7) -> void:
	GEOMETRY.add_prism(geometry_parent, part_name, GEOMETRY.chamfered_outline(width, length, chamfer, center_z), bottom_y, top_y, mat)

func _add_tapered_deckhouse(part_name: String, center_z: float, bottom_size: Vector2, top_size: Vector2, bottom_y: float, top_y: float, bottom_chamfer: float, top_chamfer: float, mat: Material, top_shift_z: float = 0.0) -> void:
	var bottom_outline: PackedVector2Array = GEOMETRY.chamfered_outline(bottom_size.x, bottom_size.y, bottom_chamfer, center_z)
	var top_outline: PackedVector2Array = GEOMETRY.chamfered_outline(top_size.x, top_size.y, top_chamfer, center_z + top_shift_z)
	GEOMETRY.add_tapered_prism(geometry_parent, part_name, bottom_outline, top_outline, bottom_y, top_y, mat)

func _build_superstructure() -> void:
	geometry_parent = platforms_root
	_build_battery_deck()
	geometry_parent = bridge_root
	_build_forward_bridge()
	geometry_parent = platforms_root
	_build_forward_bridge_wings()
	geometry_parent = mast_root
	_build_forward_mast()
	_build_after_mast()
	geometry_parent = funnel_root
	_build_funnel()
	geometry_parent = aft_tower_root
	_build_after_tower()
	geometry_parent = hull_root

func _build_forward_bridge() -> void:
	# Iowa's round armored conning tower and open navigation galleries in 1944.
	# The broad squared enclosed navigation bridge belongs to the 1945 refit.
	_add_rounded_house("ForwardBridgeBase", -12.0, Vector2(10.6, 27.0), Vector2(8.8, 24.0), 10.5, 14.1, 4.0, 3.5, palette.superstructure, 0.0)
	GEOMETRY.add_cylinder(geometry_parent, "ArmoredConningTower", Vector3(0.0, 15.6, -16.0), 3.2, 5.0, palette.superstructure_dark, 32)
	_add_rounded_deck("OpenNavigationDeck", -13.0, 18.4, 20.0, 17.5, 17.8, palette.deck_detail)
	_add_tapered_deckhouse("PilotHouse1944", -9.2, Vector2(8.0, 7.4), Vector2(7.6, 6.8), 17.8, 20.1, 1.7, 1.6, palette.superstructure, 0.0)
	# Slender director-support tower behind the open bridge; no stacked broad boxes.
	_add_rounded_house("DirectorSupportTower", -3.6, Vector2(7.6, 10.6), Vector2(6.0, 8.0), 14.1, 33.0, 1.3, 1.0, palette.superstructure_dark, 0.7)
	_add_rounded_deck("LowerDirectorGallery", -3.5, 10.8, 10.7, 23.0, 23.28, palette.deck_detail)
	_add_rounded_deck("UpperDirectorGallery", -3.1, 10.2, 9.2, 29.5, 29.8, palette.deck_detail)
	_add_tapered_deckhouse("ForwardMk38Director", -3.1, Vector2(6.6, 7.0), Vector2(5.6, 6.2), 33.0, 35.7, 1.0, 0.8, palette.superstructure, 0.0)
	GEOMETRY.add_box(geometry_parent, "Mk38OpticalRangefinder", Vector3(0.0, 34.8, -3.1), Vector3(9.1, 0.5, 0.65), palette.superstructure)
	for y_value: float in [19.1, 25.1, 30.9]:
		GEOMETRY.add_box(geometry_parent, "DirectorTowerWindowBand", Vector3(0.0, y_value, -8.1), Vector3(3.6, 0.36, 0.06), palette.dark_glass)
	# Forward Mk37 director stands forward of the main director tower.
	_add_tapered_deckhouse("ForwardMk37", -15.6, Vector2(4.0, 4.6), Vector2(3.6, 4.0), 20.0, 22.9, 0.7, 0.6, palette.superstructure, 0.0)
	GEOMETRY.add_box(geometry_parent, "ForwardMk37Rangefinder", Vector3(0.0, 22.0, -15.6), Vector3(4.6, 0.3, 0.35), palette.dark_glass)

func _build_forward_bridge_face_windows(deck_y: float) -> void:
	var window_y: float = 10.55
	var bottom_y: float = deck_y - 0.05
	var top_y: float = 14.2
	var bottom_front_z: float = -28.0 - 37.0 * 0.5
	var top_front_z: float = -28.0 + 1.0 - 33.5 * 0.5
	var amount: float = inverse_lerp(bottom_y, top_y, window_y)
	var face_z: float = lerpf(bottom_front_z, top_front_z, amount)
	var face_angle: float = atan((top_front_z - bottom_front_z) / (top_y - bottom_y))
	var face_normal: Vector3 = Vector3(0.0, sin(face_angle), -cos(face_angle))
	var window_count: int = 11
	var window_spacing: float = 0.93
	for index: int in range(window_count):
		var x_value: float = (float(index) - float(window_count - 1) * 0.5) * window_spacing
		var window_name: String = "%02d" % index
		var face_center: Vector3 = Vector3(x_value, window_y, face_z)
		GEOMETRY.add_box(geometry_parent, "BridgeForwardWindowFrame_" + window_name, face_center + face_normal * 0.085, Vector3(0.82, 0.58, 0.14), palette.superstructure_dark, Vector3(face_angle, 0.0, 0.0))
		GEOMETRY.add_box(geometry_parent, "BridgeForwardWindowGlass_" + window_name, face_center + face_normal * 0.145, Vector3(0.61, 0.36, 0.045), palette.dark_glass, Vector3(face_angle, 0.0, 0.0))
	var brow_center: Vector3 = Vector3(0.0, window_y + 0.39, face_z) + face_normal * 0.25
	GEOMETRY.add_box(geometry_parent, "BridgeForwardWindowBrow", brow_center, Vector3(10.5, 0.16, 0.46), palette.deck_detail, Vector3(face_angle, 0.0, 0.0))

func _build_forward_bridge_wings() -> void:
	# Galleries belong to the bridge, rather than invented pillars under weapons.
	for side: float in [-1.0, 1.0]:
		var side_name: String = "Port" if side < 0.0 else "Starboard"
		var wing: Node3D = _add_module(platforms_root, "OpenBridgeWing_" + side_name)
		wing.position = Vector3(side * 5.9, 17.8, -12.6)
		var outline: PackedVector2Array = GEOMETRY.chamfered_outline(5.7, 13.5, 1.0)
		GEOMETRY.add_prism(wing, "OpenWingParapetDeck", outline, -0.10, 0.12, palette.deck_detail)
		_add_platform_railings(wing, outline, 0.12, 0.82)
		platform_hosts["forward_bridge_wing_" + side_name.to_lower()] = wing
		platform_hosts["after_director_wing_" + side_name.to_lower()] = battery_deck_root
		platform_hosts["bridge_battery_sponson_" + side_name.to_lower()] = battery_deck_root

func _build_bridge_access_ladders() -> void:
	var segments: Array[Dictionary] = []
	var lower_y: float = 14.65
	var upper_y: float = 20.35
	var lower_x: float = 8.22
	var upper_x: float = 7.52
	var center_z: float = -25.3
	var half_width_z: float = 0.34
	var rung_count: int = 10
	for side: float in [-1.0, 1.0]:
		for rail_side: float in [-1.0, 1.0]:
			segments.append({
				"from": Vector3(side * lower_x, lower_y, center_z + rail_side * half_width_z),
				"to": Vector3(side * upper_x, upper_y, center_z + rail_side * half_width_z),
				"diameter": 0.09
			})
		for rung_index: int in range(rung_count):
			var amount: float = float(rung_index + 1) / float(rung_count + 1)
			var x_value: float = lerpf(lower_x, upper_x, amount)
			var y_value: float = lerpf(lower_y, upper_y, amount)
			segments.append({
				"from": Vector3(side * x_value, y_value, center_z - half_width_z),
				"to": Vector3(side * x_value, y_value, center_z + half_width_z),
				"diameter": 0.07
			})
	GEOMETRY.add_beam_batch(platforms_root, "BridgeExteriorAccessLadders", segments, palette.railings, 6)

func _add_platform_railings(parent: Node3D, outline: PackedVector2Array, deck_height: float, railing_height: float) -> void:
	var segments: Array[Dictionary] = []
	for point_index: int in range(outline.size()):
		var first: Vector2 = outline[point_index]
		var second: Vector2 = outline[(point_index + 1) % outline.size()]
		var edge_length: float = first.distance_to(second)
		var post_intervals: int = maxi(1, ceili(edge_length / 1.7))
		var first_point: Vector3 = Vector3(first.x, deck_height, first.y)
		var second_point: Vector3 = Vector3(second.x, deck_height, second.y)
		segments.append({
			"from": first_point + Vector3.UP * railing_height,
			"to": second_point + Vector3.UP * railing_height,
			"diameter": 0.07
		})
		segments.append({
			"from": first_point + Vector3.UP * railing_height * 0.5,
			"to": second_point + Vector3.UP * railing_height * 0.5,
			"diameter": 0.055
		})
		for post_index: int in range(post_intervals + 1):
			var amount: float = float(post_index) / float(post_intervals)
			var post_base: Vector3 = first_point.lerp(second_point, amount)
			segments.append({
				"from": post_base,
				"to": post_base + Vector3.UP * railing_height,
				"diameter": 0.065
			})
	GEOMETRY.add_beam_batch(parent, "ProvisionalPlatformRailings", segments, palette.railings, 6)

func _build_forward_mast() -> void:
	var mast: Node3D = _add_module(mast_root, "ForwardRadarMast")
	mast.position.z = -3.1
	GEOMETRY.add_beam(mast, "MastPole", Vector3(0.0, 34.9, 0.0), Vector3(0.0, 44.3, 0.0), 0.30, palette.mast, 10)
	GEOMETRY.add_box(mast, "MastYard", Vector3(0.0, 37.8, 0.0), Vector3(11.5, 0.23, 0.3), palette.mast)
	GEOMETRY.add_box(mast, "SKRadarFrame", Vector3(0.0, 41.0, 0.0), Vector3(5.4, 3.7, 0.20), palette.mast)
	GEOMETRY.add_box(mast, "SKRadarFace", Vector3(0.0, 41.0, -0.12), Vector3(5.0, 3.3, 0.06), palette.dark_glass)
	for x_value: float in [-1.6, 0.0, 1.6]:
		GEOMETRY.add_box(mast, "RadarGrid", Vector3(x_value, 41.0, -0.18), Vector3(0.05, 3.3, 0.04), palette.mast)

func _build_funnel() -> void:
	_build_single_funnel("ForwardFunnel", 4.8, 26.2, Vector2(9.5, 13.0), Vector2(8.3, 11.8), Vector2(7.8, 10.4), Vector2(7.0, 9.6), 15.0, 0.6)
	_build_single_funnel("AfterFunnel", 30.5, 28.0, Vector2(9.4, 13.4), Vector2(8.0, 11.8), Vector2(7.6, 10.9), Vector2(6.8, 9.8), 15.2, 0.7)

func _build_single_funnel(module_name: String, world_z: float, top_y: float, uptake_bottom_size: Vector2, uptake_top_size: Vector2, casing_bottom_size: Vector2, casing_top_size: Vector2, casing_bottom_y: float, upper_shift_z: float) -> void:
	var stack_root: Node3D = _add_module(funnel_root, module_name)
	stack_root.position.z = world_z
	geometry_parent = stack_root
	var deck_y: float = _deck_height_at(world_z)
	_add_tapered_deckhouse("UptakeTrunk", 0.0, uptake_bottom_size, uptake_top_size, deck_y - 0.04, casing_bottom_y + 0.25, 2.8, 2.25, palette.superstructure_dark, 0.55)
	_add_tapered_deckhouse("FunnelCasing", 0.5, casing_bottom_size, casing_top_size, casing_bottom_y, top_y - 0.8, 2.0, 1.6, palette.superstructure, upper_shift_z)
	_add_deckhouse("FunnelCrown", 0.5 + upper_shift_z, casing_top_size.x + 0.9, casing_top_size.y + 1.3, top_y - 1.05, top_y - 0.62, palette.turret_roof, 1.35)
	_add_deckhouse("OpenFunnelMouth", 0.5 + upper_shift_z, casing_top_size.x - 0.7, casing_top_size.y - 0.7, top_y - 0.65, top_y - 0.58, palette.dark_glass, 1.3)
	for side: float in [-1.0, 1.0]:
		GEOMETRY.add_beam(geometry_parent, "FunnelCasingRib", Vector3(side * (casing_bottom_size.x * 0.5 - 0.7), casing_bottom_y + 0.35, -4.2), Vector3(side * (casing_top_size.x * 0.5 - 0.55), top_y - 1.1, 0.5 + upper_shift_z), 0.22, palette.superstructure_dark, 8)

func _build_after_tower() -> void:
	var tower_z: float = 49.8
	_add_tapered_deckhouse("AfterDirectorSupport", tower_z, Vector2(7.6, 12.5), Vector2(5.2, 7.6), 10.5, 20.1, 1.4, 1.0, palette.superstructure, 0.0)
	_add_deckhouse("AfterDirectorGallery", tower_z, 10.6, 11.6, 18.0, 18.28, palette.deck_detail, 1.8)
	_add_tapered_deckhouse("AfterMk38Director", tower_z, Vector2(6.2, 6.8), Vector2(5.4, 6.0), 20.1, 22.7, 0.9, 0.8, palette.superstructure_dark, 0.0)
	GEOMETRY.add_box(geometry_parent, "AfterMk38Rangefinder", Vector3(0.0, 21.8, tower_z), Vector3(9.1, 0.45, 0.6), palette.superstructure)
	GEOMETRY.add_box(geometry_parent, "AfterDirectorRadar", Vector3(0.0, 23.1, tower_z), Vector3(3.0, 0.8, 0.16), palette.mast)
	for side: float in [-1.0, 1.0]:
		GEOMETRY.add_cylinder(geometry_parent, "WingDirectorTrunk", Vector3(side * 7.3, 12.9, 16.5), 1.35, 4.8, palette.superstructure, 16)
		var director: MeshInstance3D = GEOMETRY.add_cylinder(geometry_parent, "WingMk37Director", Vector3(side * 7.3, 16.8, 16.5), 1.5, 2.0, palette.superstructure, 16)
		director.set_meta("role", "5inch_fire_control")

func _build_after_tower_windows(tower_z: float) -> void:
	var windows: Array[Dictionary] = []
	_add_window_row(windows, 10.9, tower_z - 10.0, 7.1, 14, 1.0, Vector3(0.08, 0.36, 0.6))
	_add_window_row(windows, 10.9, tower_z + 1.2, 7.1, 12, 0.8, Vector3(0.08, 0.36, 0.6))
	_add_window_row(windows, 15.6, tower_z - 5.0, 5.2, 10, 0.78, Vector3(0.08, 0.34, 0.54))
	GEOMETRY.add_box_batch(geometry_parent, "AfterTowerWindows", windows, palette.dark_glass)

func _build_after_mast() -> void:
	var mast: Node3D = _add_module(mast_root, "AfterFunnelMast")
	mast.position.z = 30.3
	GEOMETRY.add_beam(mast, "AfterMastPole", Vector3(0.0, 25.0, 0.0), Vector3(0.0, 37.0, 0.0), 0.28, palette.mast, 10)
	GEOMETRY.add_box(mast, "AfterMastYard", Vector3(0.0, 31.5, 0.0), Vector3(10.4, 0.23, 0.28), palette.mast)
	GEOMETRY.add_box(mast, "AfterSearchRadar", Vector3(0.0, 35.4, 0.0), Vector3(4.5, 1.1, 0.18), palette.mast)

func _build_windows() -> void:
	var windows: Array[Dictionary] = []
	_add_window_row(windows, 10.55, -43.2, 8.35, 14, 0.95, Vector3(0.08, 0.38, 0.6))
	_add_window_row(windows, 10.55, -11.5, 8.35, 8, 0.86, Vector3(0.08, 0.38, 0.6))
	_add_window_row(windows, 16.15, -36.5, 6.8, 11, 0.76, Vector3(0.08, 0.34, 0.54))
	_add_window_row(windows, 16.15, -16.0, 6.8, 8, 0.68, Vector3(0.08, 0.34, 0.54))
	_add_window_row(windows, 22.15, -29.8, 5.15, 8, 0.62, Vector3(0.08, 0.3, 0.48))
	GEOMETRY.add_box_batch(geometry_parent, "BridgeWindows", windows, palette.dark_glass)

func _add_window_row(records: Array[Dictionary], y_value: float, z_start: float, x_side: float, count: int, step: float, size: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		for index: int in range(count):
			var z_value: float = z_start + float(index) * step
			records.append({"center": Vector3(side * x_side, y_value, z_value), "size": size})

func _build_small_superstructure_details() -> void:
	for level: int in range(3):
		var y_value: float = 12.3 + float(level) * 1.25
		var z_value: float = -28.0 - float(level) * 1.5
		GEOMETRY.add_box(geometry_parent, "BridgeForwardWindowBand", Vector3(0.0, y_value, z_value), Vector3(8.0 - float(level) * 0.7, 0.32, 0.12), palette.dark_glass)
	for side: float in [-1.0, 1.0]:
		GEOMETRY.add_cylinder(geometry_parent, "Searchlight", Vector3(side * 10.2, 17.3, -27.0), 0.42, 0.55, palette.steel, 16)
		GEOMETRY.add_box(geometry_parent, "SearchlightLens", Vector3(side * 10.2, 17.3, -26.71), Vector3(0.55, 0.35, 0.08), palette.dark_glass)
		GEOMETRY.add_cylinder(geometry_parent, "SignalLamp", Vector3(side * 4.5, 24.1, -24.0), 0.14, 0.18, palette.steel, 10)

func _build_deck_equipment() -> void:
	geometry_parent = _add_module(equipment_root, "AircraftCatapults")
	_build_aircraft_catapults()
	geometry_parent = _add_module(equipment_root, "AircraftCranes")
	_build_aircraft_cranes()
	geometry_parent = _add_module(equipment_root, "AnchorsAndDeckFittings")
	_build_anchors_and_deck_fittings()

func _build_aircraft_catapults() -> void:
	for record: Dictionary in configuration.get("aircraft_catapults", []):
		var catapult_x: float = float(record.get("x", 0.0))
		var catapult_z: float = float(record.get("z", 0.0))
		var side_name: String = "Port" if catapult_x < 0.0 else "Starboard"
		var catapult: IowaEquipmentModule = AIRCRAFT_CATAPULT_SCENE.instantiate() as IowaEquipmentModule
		catapult.name = "AircraftCatapult_%s" % side_name
		catapult.position = Vector3(catapult_x, _deck_height_at(catapult_z), catapult_z)
		catapult.set_meta("station_id", str(record.get("id", "aircraft_catapult_%s" % side_name.to_lower())))
		catapult.set_meta("host_module", "Hull")
		catapult.set_meta("surface", str(record.get("surface", "weather_deck")))
		catapult.set_meta("source_status", str(record.get("source_status", "provisional")))
		catapult.set_meta("confidence", str(record.get("confidence", "low")))
		var train_axis: Node3D = catapult.get_node("TrainPivot") as Node3D
		train_axis.rotation.y = deg_to_rad(float(record.get("initial_train_deg", 0.0)))
		geometry_parent.add_child(catapult)

func _build_aircraft_cranes() -> void:
	for record: Dictionary in configuration.get("aircraft_cranes", []):
		var crane_x: float = float(record.get("x", 0.0))
		var crane_z: float = float(record.get("z", 0.0))
		var side_name: String = "Port" if crane_x < 0.0 else "Starboard"
		var crane: IowaEquipmentModule = AIRCRAFT_CRANE_SCENE.instantiate() as IowaEquipmentModule
		crane.name = "AircraftCrane_%s" % side_name
		crane.position = Vector3(crane_x, _deck_height_at(crane_z), crane_z)
		crane.set_meta("station_id", str(record.get("id", "aircraft_crane_%s" % side_name.to_lower())))
		crane.set_meta("host_module", "Hull")
		crane.set_meta("surface", str(record.get("surface", "weather_deck")))
		crane.set_meta("source_status", str(record.get("source_status", "provisional")))
		crane.set_meta("confidence", str(record.get("confidence", "low")))
		var train_axis: Node3D = crane.get_node("TrainPivot") as Node3D
		train_axis.rotation.y = deg_to_rad(float(record.get("initial_train_deg", 0.0)))
		geometry_parent.add_child(crane)

func _build_anchors_and_deck_fittings() -> void:
	for side: float in [-1.0, 1.0]:
		GEOMETRY.add_beam(geometry_parent, "AnchorChain", Vector3(side * 4.8, 5.1, -117.5), Vector3(side * 6.4, 1.0, -126.0), 0.16, palette.gunmetal, 8)
		GEOMETRY.add_box(geometry_parent, "AnchorFluke", Vector3(side * 6.4, 0.35, -126.0), Vector3(1.3, 2.0, 0.42), palette.gunmetal, Vector3(0.0, 0.0, side * -0.28))
		for bollard_z: float in [-114.0, -97.0, -54.0, -6.0, 42.0, 75.0, 114.0]:
			var x_value: float = side * maxf(3.0, _half_breadth_at(bollard_z) - 1.2)
			GEOMETRY.add_cylinder(geometry_parent, "MooringBollard", Vector3(x_value, _deck_height_at(bollard_z) + 0.25, bollard_z), 0.26, 0.5, palette.gunmetal, 10)
		GEOMETRY.add_beam(geometry_parent, "ForedeckBreakwater", Vector3(side * 6.7, 10.15, -111.0), Vector3(side * 7.6, 9.05, -101.0), 0.45, palette.deck_detail, 8)
		GEOMETRY.add_box(geometry_parent, "HawsePipeRim", Vector3(side * 7.1, 5.3, -119.2), Vector3(0.5, 0.25, 1.1), palette.gunmetal)

func _build_mounts() -> void:
	var phase_index: int = 0
	for source_record: Dictionary in configuration.get("main_batteries", []):
		var record: Dictionary = source_record.duplicate(true)
		record["type"] = "main_16in"
		if str(record.id) == "main_03":
			record["initial_heading_deg"] = 180.0
		_new_main_mount(record, phase_index)
		phase_index += 1
	for source_record: Dictionary in configuration.get("secondary_batteries", []):
		var record: Dictionary = source_record.duplicate(true)
		record["type"] = "secondary_5in"
		record["name"] = "5-inch/38 Twin Mount " + str(record.id).replace("secondary_", "")
		record["initial_heading_deg"] = 90.0 if float(record.x) < 0.0 else -90.0
		_new_modular_mount(record, _create_deck_station_marker(record, "secondary_5in"), phase_index)
		phase_index += 1
	var bofors_count: int = 0
	for pair_record: Dictionary in configuration.get("bofors_40mm_pairs", []):
		for side: float in [-1.0, 1.0]:
			var record: Dictionary = {"id":"bofors_%02d" % (bofors_count + 1), "name":"40mm Quad Bofors %02d" % (bofors_count + 1), "type":"bofors_40mm", "x":side * float(pair_record.half_x), "z":float(pair_record.z), "surface":str(pair_record.get("surface", "weather_deck")), "initial_heading_deg":90.0 if side < 0.0 else -90.0}
			_new_modular_mount(record, _create_deck_station_marker(record, "bofors_40mm"), phase_index)
			phase_index += 1
			bofors_count += 1
	for source_record: Dictionary in configuration.get("bofors_40mm_singles", []):
		var record: Dictionary = source_record.duplicate(true)
		record["id"] = "bofors_%02d" % (bofors_count + 1)
		record["name"] = "40mm Quad Bofors %02d" % (bofors_count + 1)
		record["type"] = "bofors_40mm"
		_new_modular_mount(record, _create_deck_station_marker(record, "bofors_40mm"), phase_index)
		phase_index += 1
		bofors_count += 1
	for source_record: Dictionary in configuration.get("bofors_40mm_turret_roofs", []):
		var record: Dictionary = source_record.duplicate(true)
		record["name"] = "40mm Quad Bofors on " + str(record.turret_id)
		record["type"] = "bofors_40mm"
		record["initial_heading_deg"] = 0.0
		_new_modular_mount(record, _create_turret_roof_station_marker(record, "bofors_40mm"), phase_index)
		phase_index += 1
	var oerlikon_count: int = 0
	for pair_record: Dictionary in configuration.get("oerlikon_20mm_pairs", []):
		for side: float in [-1.0, 1.0]:
			var record: Dictionary = {"id":"oerlikon_%02d" % (oerlikon_count + 1), "name":"20mm Oerlikon Single", "type":"oerlikon_20mm", "x":side * float(pair_record.half_x), "z":float(pair_record.z), "surface":str(pair_record.surface), "initial_heading_deg":90.0 if side < 0.0 else -90.0}
			_new_modular_mount(record, _create_deck_station_marker(record, "oerlikon_20mm"), phase_index)
			phase_index += 1
			oerlikon_count += 1
	for source_record: Dictionary in configuration.get("oerlikon_20mm_singles", []):
		var record: Dictionary = source_record.duplicate(true)
		record["id"] = "oerlikon_%02d" % (oerlikon_count + 1)
		record["name"] = "20mm Oerlikon Single"
		record["type"] = "oerlikon_20mm"
		_new_modular_mount(record, _create_deck_station_marker(record, "oerlikon_20mm"), phase_index)
		phase_index += 1
		oerlikon_count += 1
	for source_record: Dictionary in configuration.get("oerlikon_20mm_turret_ii", []):
		var record: Dictionary = source_record.duplicate(true)
		record["id"] = "oerlikon_%02d" % (oerlikon_count + 1)
		record["name"] = "20mm Oerlikon on Turret II"
		record["type"] = "oerlikon_20mm"
		record["initial_heading_deg"] = 0.0
		_new_modular_mount(record, _create_turret_roof_station_marker(record, "oerlikon_20mm"), phase_index)
		phase_index += 1
		oerlikon_count += 1

	geometry_parent = hull_root

func _new_main_mount(record: Dictionary, phase_index: int) -> IowaWeaponMount:
	var marker: Marker3D = _create_deck_station_marker(record, "main_16in")
	var foundation: IowaMountFoundation = FOUNDATION_SCRIPT.new() as IowaMountFoundation
	foundation.configure(record, palette)
	mount_foundations_root.add_child(foundation)
	foundation.global_transform = marker.global_transform
	var mount: IowaWeaponMount = MAIN_TURRET_SCENE.instantiate() as IowaWeaponMount
	foundation.weapon_seat.add_child(mount)
	mount.configure(record, palette, float(phase_index) * 1.618, marker)
	mount.foundation_base_node = foundation
	main_mounts[str(record.id)] = mount
	_register_mount(mount)
	return mount

func _new_modular_mount(record: Dictionary, marker: Marker3D, phase_index: int) -> IowaWeaponMount:
	if marker == null:
		return null
	var mount_type: String = str(record.get("type", "oerlikon_20mm"))
	var weapon_scene: PackedScene = _weapon_scene_for_type(mount_type)
	if weapon_scene == null:
		push_error("No reusable weapon scene for mount type %s" % mount_type)
		return null
	var foundation_record: Dictionary = record.duplicate(true)
	var foundation_interfaces: Dictionary = configuration.get("foundation_interfaces", {})
	var interface_record: Dictionary = foundation_interfaces.get(mount_type, {})
	for key: Variant in interface_record.keys():
		foundation_record[str(key)] = interface_record[key]
	var foundation: IowaMountFoundation = FOUNDATION_SCRIPT.new() as IowaMountFoundation
	foundation.configure(foundation_record, palette)
	marker.add_child(foundation)
	if foundation.weapon_seat == null:
		push_error("Foundation for station %s has no WeaponSeat" % str(record.get("id", "unknown_station")))
		foundation.queue_free()
		return null
	var mount: IowaWeaponMount = weapon_scene.instantiate() as IowaWeaponMount
	foundation.weapon_seat.add_child(mount)
	mount.configure(record, palette, float(phase_index) * 1.618, marker)
	mount.foundation_base_node = foundation
	_register_mount(mount)
	return mount

func _weapon_scene_for_type(mount_type: String) -> PackedScene:
	match mount_type:
		"secondary_5in": return SECONDARY_TWIN_SCENE
		"bofors_40mm": return BOFORS_QUAD_SCENE
		"oerlikon_20mm": return OERLIKON_SINGLE_SCENE
		_: return null

func _register_mount(mount: IowaWeaponMount) -> void:
	weapon_mounts.append(mount)
	mount_index[str(mount.mount_id)] = mount

func _create_deck_station_marker(record: Dictionary, mount_type: String) -> Marker3D:
	var surface_name: String = str(record.get("surface", "weather_deck"))
	var side_name: String = "port" if float(record.get("x", 0.0)) < 0.0 else "starboard"
	var host: Node3D = hull_root
	var local_position: Vector3 = Vector3(float(record.get("x", 0.0)), _deck_height_at(float(record.get("z", 0.0))) + 0.015, float(record.get("z", 0.0)))
	match surface_name:
		"battery_deck":
			host = battery_deck_root
			local_position.y = 10.5
		"bridge_battery_sponson":
			host = platform_hosts.get("bridge_battery_sponson_" + side_name) as Node3D
			if host != null:
				local_position = Vector3(float(record.x) - host.position.x, 0.265, float(record.z) - host.position.z)
		"forward_bridge_wing":
			host = platform_hosts.get("forward_bridge_wing_" + side_name) as Node3D
			if host != null:
				local_position = Vector3(float(record.x) - host.position.x, 0.31, float(record.z) - host.position.z)
		"after_director_wing":
			host = platform_hosts.get("after_director_wing_" + side_name) as Node3D
			if host != null:
				local_position = Vector3(float(record.x) - host.position.x, 0.28, float(record.z) - host.position.z)
	if host == null:
		push_error("No host module for station %s on surface %s" % [str(record.get("id", "unknown")), surface_name])
		return null
	return _create_station_marker(record, mount_type, host, local_position)

func _create_turret_roof_station_marker(record: Dictionary, mount_type: String) -> Marker3D:
	var turret_id: String = str(record.get("turret_id", ""))
	var turret: IowaWeaponMount = main_mounts.get(turret_id) as IowaWeaponMount
	if turret == null or turret.station_marker == null:
		push_error("No turret host for roof station %s" % str(record.get("id", "unknown")))
		return null
	var host: Node3D = turret.get_node("TrainPivot/HousingAndControls/StationMountPoints") as Node3D
	var local_position: Vector3 = Vector3(float(record.get("x", 0.0)), 0.0, float(record.get("z", 0.0)) - turret.station_marker.position.z)
	return _create_station_marker(record, mount_type, host, local_position)

func _create_station_marker(record: Dictionary, mount_type: String, host: Node3D, local_position: Vector3) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	var station_id: String = str(record.get("station_id", record.get("id", "unknown_station")))
	marker.name = "Station_%s" % station_id
	marker.position = local_position
	var interface_data: Dictionary = _weapon_interface(mount_type)
	marker.set_meta("station_id", station_id)
	marker.set_meta("host_module", str(host.get_path()))
	marker.set_meta("host_module_name", str(host.name))
	marker.set_meta("local_position_m", local_position)
	marker.set_meta("compatible_interface", str(interface_data.get("name", "unknown")))
	marker.set_meta("interface_size_m", float(interface_data.get("diameter_m", 0.0)))
	marker.set_meta("source_status", str(record.get("placement_status", "game_aa_supported_station")))
	marker.set_meta("confidence", "low")
	host.add_child(marker)
	return marker

func _weapon_interface(mount_type: String) -> Dictionary:
	match mount_type:
		"main_16in": return {"name":"main_16in_turret_seat", "diameter_m":14.0}
		"secondary_5in": return {"name":"secondary_5in_twin_seat", "diameter_m":4.0}
		"bofors_40mm": return {"name":"bofors_40mm_quad_seat", "diameter_m":2.1}
		_: return {"name":"oerlikon_20mm_single_seat", "diameter_m":0.76}

func get_weapon_mounts() -> Array[IowaWeaponMount]:
	return weapon_mounts

func get_mount_by_id(mount_id: String) -> IowaWeaponMount:
	return mount_index.get(mount_id) as IowaWeaponMount

func expected_mount_support_height(mount: IowaWeaponMount) -> float:
	if not is_instance_valid(mount.station_marker):
		return NAN
	return mount.station_marker.global_position.y

func get_mount_audit_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for mount: IowaWeaponMount in weapon_mounts:
		records.append(mount.get_audit_record())
	return records

func get_weapon_counts() -> Dictionary:
	var result: Dictionary = {"main_16in":0,"secondary_5in":0,"bofors_40mm":0,"oerlikon_20mm":0}
	for mount: IowaWeaponMount in weapon_mounts:
		var mount_type: String = str(mount.mount_type)
		result[mount_type] = int(result.get(mount_type, 0)) + 1
	return result


func _build_battery_deck() -> void:
	battery_deck_root = _add_module(platforms_root, "ContinuousBatteryDeck")
	# Long continuous original deckhouse with the three inner upper 5-inch stations.
	# The two outer pairs remain on the weather deck; no generic per-station supports.
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-4.5, -26.5), Vector2(4.5, -26.5), Vector2(9.6, -15.0),
		Vector2(10.6, -6.0), Vector2(9.2, 1.0), Vector2(10.6, 12.5),
		Vector2(10.2, 19.0), Vector2(8.9, 29.7), Vector2(10.6, 39.6),
		Vector2(9.5, 46.0), Vector2(4.0, 54.0), Vector2(-4.0, 54.0),
		Vector2(-9.5, 46.0), Vector2(-10.6, 39.6), Vector2(-8.9, 29.7),
		Vector2(-10.2, 19.0), Vector2(-10.6, 12.5), Vector2(-9.2, 1.0),
		Vector2(-10.6, -6.0), Vector2(-9.6, -15.0)
	])
	_add_supported_deckhouse(battery_deck_root, "BatteryDeckHouse", outline, 5.20, 10.5, palette.superstructure)

func _add_supported_deckhouse(parent: Node3D, part_name: String, outline: PackedVector2Array, bottom_y: float, top_y: float, mat: Material) -> void:
	# Correct triangulation preserves the indented battery-deck perimeter.
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(0, triangles.size(), 3):
		for offset: int in [0, 2, 1]:
			var point: Vector2 = outline[triangles[index + offset]]
			surface.add_vertex(Vector3(point.x, top_y, point.y))
	for index: int in range(outline.size()):
		var first: Vector2 = outline[index]
		var second: Vector2 = outline[(index + 1) % outline.size()]
		for vertex: Vector3 in [Vector3(first.x,bottom_y,first.y), Vector3(second.x,bottom_y,second.y), Vector3(first.x,top_y,first.y), Vector3(second.x,bottom_y,second.y), Vector3(second.x,top_y,second.y), Vector3(first.x,top_y,first.y)]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = surface.commit()
	part.material_override = mat
	parent.add_child(part)

func _batch_static_tree(module: Node3D) -> void:
	# Merge only immediate static siblings. Pivots, sockets and module ownership survive.
	for child: Node in module.get_children():
		if child is Node3D and not child is MeshInstance3D:
			_batch_static_tree(child as Node3D)
	var groups: Dictionary = {}
	for child: Node in module.get_children():
		if not child is MeshInstance3D:
			continue
		var part: MeshInstance3D = child as MeshInstance3D
		if part.mesh == null or part.mesh.get_surface_count() != 1:
			continue
		var mat: Material = part.material_override if part.material_override != null else part.mesh.surface_get_material(0)
		if mat == null:
			continue
		var key: int = mat.get_instance_id()
		if not groups.has(key):
			groups[key] = {"material":mat, "parts":[]}
		groups[key].parts.append(part)
	for key: int in groups:
		var record: Dictionary = groups[key]
		if record.parts.size() < 2:
			continue
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in record.parts:
			var expanded: SurfaceTool = SurfaceTool.new()
			expanded.create_from(part.mesh, 0)
			expanded.deindex()
			surface.append_from(expanded.commit(), 0, part.transform)
		var batch: MeshInstance3D = MeshInstance3D.new()
		batch.name = "StaticBatch_%d" % key
		batch.mesh = surface.commit()
		batch.material_override = record.material
		module.add_child(batch)
		for part: MeshInstance3D in record.parts:
			module.remove_child(part)
			part.free()

func _rounded_outline(width: float, length: float, center_z: float) -> PackedVector2Array:
	var outline: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU*float(index)/24.0
		outline.append(Vector2(cos(angle)*width*0.5,center_z+sin(angle)*length*0.5))
	return outline

func _add_rounded_house(part_name: String, center_z: float, bottom_size: Vector2, top_size: Vector2, bottom_y: float, top_y: float, _bottom_chamfer: float, _top_chamfer: float, mat: Material, top_shift_z: float = 0.0) -> void:
	GEOMETRY.add_tapered_prism(geometry_parent,part_name,_rounded_outline(bottom_size.x,bottom_size.y,center_z),_rounded_outline(top_size.x,top_size.y,center_z+top_shift_z),bottom_y,top_y,mat)

func _add_rounded_deck(part_name: String, center_z: float, width: float, length: float, bottom_y: float, top_y: float, mat: Material) -> void:
	GEOMETRY.add_prism(geometry_parent,part_name,_rounded_outline(width,length,center_z),bottom_y,top_y,mat)
