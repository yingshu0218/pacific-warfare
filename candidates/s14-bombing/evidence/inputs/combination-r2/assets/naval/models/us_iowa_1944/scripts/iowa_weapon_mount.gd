class_name IowaWeaponMount
extends Node3D

const GEOMETRY = preload("iowa_geometry.gd")

var mount_id: String = ""
var display_name: String = ""
var mount_type: String = ""
var support_surface: String = ""
var support_target_id: String = ""
var support_height: float = 0.0
var station_marker: Marker3D
var foundation_base_node: Node3D
var train_axis: Node3D
var housing_root: Node3D
var elevation_axes: Array[Node3D] = []
var elevation_axis: Node3D
var train_limits: Vector2 = Vector2(-180.0, 180.0)
var elevation_limits: Vector2 = Vector2(-10.0, 85.0)
var train_rate_deg_s: float = 18.0
var elevation_rate_deg_s: float = 12.0
var base_heading: float = 0.0
var phase: float = 0.0
var automatic_demo: bool = true
var moving: bool = true
var commanded_train_deg: float = 0.0
var commanded_elevations: PackedFloat64Array = PackedFloat64Array()
var materials: Dictionary = {}
var module_profile: Dictionary = {}
var independent_gun_elevation: bool = false

func build_module_template(module_type: String, palette: Dictionary, profile: Dictionary = {}) -> void:
	mount_type = module_type
	materials = palette
	module_profile = profile
	name = "WeaponInstance"
	_create_train_housing()
	match mount_type:
		"main_16in": _build_main_turret()
		"secondary_5in": _build_secondary_turret()
		"bofors_40mm": _build_bofors_mount()
		_: _build_oerlikon_mount()
	_bind_motion_nodes()

func configure(record: Dictionary, palette: Dictionary, phase_offset: float, marker: Marker3D = null) -> void:
	mount_id = str(record.get("id", "mount"))
	display_name = str(record.get("name", mount_id))
	mount_type = str(record.get("type", "oerlikon_20mm"))
	support_surface = str(record.get("surface", "weather_deck"))
	support_target_id = str(record.get("turret_id", ""))
	support_height = float(record.get("support_height", 0.0))
	station_marker = marker
	materials = palette
	phase = phase_offset
	position = Vector3.ZERO
	if is_instance_valid(station_marker):
		support_height = station_marker.global_position.y
	train_limits = _limits(record.get("train_limits", _default_train_limits()))
	elevation_limits = _limits(record.get("elevation_limits", _default_elevation_limits()))
	train_rate_deg_s = float(record.get("train_rate_deg_s", _default_train_rate()))
	elevation_rate_deg_s = float(record.get("elevation_rate_deg_s", _default_elevation_rate()))
	base_heading = deg_to_rad(float(record.get("initial_heading_deg", 0.0)))
	if get_node_or_null("TrainPivot") == null:
		build_module_template(mount_type, palette)
	else:
		_bind_motion_nodes()
	_ensure_muzzle_markers()
	independent_gun_elevation = elevation_axes.size() > 1
	name = "WeaponInstance"
	train_axis.rotation.y = base_heading
	commanded_train_deg = 0.0
	commanded_elevations.resize(elevation_axes.size())
	for index: int in range(commanded_elevations.size()):
		commanded_elevations[index] = 0.0
	_apply_turret_camouflage()

func _apply_turret_camouflage() -> void:
	if mount_type not in ["main_16in", "secondary_5in"] or not materials.has("mount_camo"):
		return
	var source_material: ShaderMaterial = materials.mount_camo as ShaderMaterial
	if source_material == null or housing_root == null:
		return
	var heading_transform: Transform3D = Transform3D(Basis.from_euler(Vector3(0.0, base_heading, 0.0)), Vector3.ZERO)
	var mount_pattern_transform: Transform3D = global_transform * heading_transform
	var part_material: ShaderMaterial = source_material.duplicate() as ShaderMaterial
	part_material.set_shader_parameter("use_pattern_transform", true)
	part_material.set_shader_parameter("pattern_transform", mount_pattern_transform)
	part_material.set_shader_parameter("pattern_center", mount_pattern_transform.origin)
	part_material.set_shader_parameter("mount_pattern_zoom", Vector2(8.0, 8.0))
	for child: Node in housing_root.get_children():
		if not child is MeshInstance3D:
			continue
		var shell_part: MeshInstance3D = child as MeshInstance3D
		if not _is_camouflaged_shell_part(shell_part.name):
			continue

		shell_part.material_override = part_material

func _is_camouflaged_shell_part(part_name: String) -> bool:
	return part_name in [
		"TurretArmor", "TurretRoof", "RearRangefinderHousing", "FrontSightHousing",
		"TwinGunShield", "ShieldRoof"
	] or part_name.begins_with("TurretFrontPlate_") or part_name.begins_with("TurretSideSightHood_") or part_name.begins_with("TurretPeriscopeHoodCover_") or part_name.begins_with("TwinGunFrontPlate_")

func _create_train_housing() -> void:
	train_axis = Node3D.new()
	train_axis.name = "TrainPivot"
	add_child(train_axis)
	housing_root = Node3D.new()
	housing_root.name = "HousingAndControls"
	train_axis.add_child(housing_root)
	elevation_axes.clear()
	elevation_axis = null

func _add_elevation_pivot(pivot_name: String, position_value: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = pivot_name
	pivot.position = position_value
	train_axis.add_child(pivot)
	var guns: Node3D = Node3D.new()
	guns.name = "GunsAndCradle"
	pivot.add_child(guns)
	elevation_axes.append(pivot)
	if elevation_axis == null:
		elevation_axis = pivot
	return pivot

func _bind_motion_nodes() -> void:
	train_axis = get_node_or_null("TrainPivot") as Node3D
	housing_root = get_node_or_null("TrainPivot/HousingAndControls") as Node3D
	elevation_axes.clear()
	elevation_axis = null
	if train_axis == null:
		return
	_collect_elevation_axes(train_axis)
	elevation_axes.sort_custom(func(first: Node3D, second: Node3D) -> bool: return str(first.name) < str(second.name))
	if not elevation_axes.is_empty():
		elevation_axis = elevation_axes[0]

func _collect_elevation_axes(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is Node3D and str(child.name).begins_with("ElevationPivot"):
			elevation_axes.append(child as Node3D)
		_collect_elevation_axes(child)

func _limits(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(-180.0, 180.0)

func _default_train_limits() -> Array[float]:
	match mount_type:
		"main_16in": return [-150.0, 150.0]
		"secondary_5in": return [-150.0, 150.0]
		_: return [-180.0, 180.0]

func _default_elevation_limits() -> Array[float]:
	match mount_type:
		"main_16in": return [-2.0, 45.0]
		"secondary_5in": return [-15.0, 85.0]
		"bofors_40mm": return [-15.0, 90.0]
		_: return [-5.0, 85.0]

func _default_train_rate() -> float:
	match mount_type:
		"main_16in": return 4.0
		"secondary_5in": return 25.0
		"bofors_40mm": return 24.0
		_: return 20.0

func _default_elevation_rate() -> float:
	match mount_type:
		"main_16in": return 12.0
		"secondary_5in": return 15.0
		"bofors_40mm": return 20.0
		_: return 15.0

func _build_main_turret() -> void:
	independent_gun_elevation = true
	var armor: Material = materials.turret
	var source_dimensions: Dictionary = module_profile.get("source_dimensions", {})
	var estimates: Dictionary = module_profile.get("geometry_estimates", {})
	var width: float = float(source_dimensions.get("gunhouse_width_m", 12.17676))
	var length: float = float(source_dimensions.get("gunhouse_length_m", 15.428976))
	var height: float = float(source_dimensions.get("shelf_plate_to_roof_m", 3.048))
	var side_inset: float = float(estimates.get("side_plate_top_inset_m", 0.32))
	var front_inset: float = float(estimates.get("front_plate_top_inset_m", 0.45))
	var corner_chamfer: float = float(estimates.get("front_corner_chamfer_m", 1.55))
	var outer_offset: float = float(source_dimensions.get("outer_bore_axis_offset_m", 3.0988))
	var bottom_outline: PackedVector2Array = GEOMETRY.chamfered_outline(width, length, corner_chamfer)
	var top_outline: PackedVector2Array = _make_turret_top_outline(bottom_outline, width, length, side_inset, front_inset, corner_chamfer)
	GEOMETRY.add_tapered_prism(housing_root, "TurretArmor", bottom_outline, top_outline, 0.0, height, armor, 0)
	_build_main_turret_front(armor, width, length, height, side_inset, front_inset, corner_chamfer, estimates, outer_offset)
	GEOMETRY.add_prism(housing_root, "TurretRoof", top_outline, height - 0.04, height + 0.18, materials.turret_roof)
	GEOMETRY.add_box(housing_root, "RearRangefinderHousing", Vector3(0.0, height + 0.38, length * 0.32), Vector3(4.3, 0.66, 2.7), armor)
	GEOMETRY.add_box(housing_root, "RearRangefinderGlass", Vector3(0.0, height + 0.39, length * 0.32 + 1.37), Vector3(3.4, 0.25, 0.08), materials.dark_glass)
	GEOMETRY.add_box(housing_root, "TurretRoofHatch", Vector3(0.0, height + 0.25, 1.6), Vector3(2.2, 0.16, 1.65), materials.deck_detail)
	GEOMETRY.add_box(housing_root, "FrontSightHousing", Vector3(0.0, height + 0.34, -length * 0.30), Vector3(7.6, 0.36, 1.0), armor)
	_build_main_turret_side_sights(width, height, side_inset)
	_build_main_turret_periscope_covers(height)
	var stations: Node3D = Node3D.new()
	stations.name = "StationMountPoints"
	stations.position.y = height + 0.24
	housing_root.add_child(stations)
	var gun_axis_y: float = float(estimates.get("gun_axis_above_shelf_plate_m", 2.25))
	var trunnion_forward: float = float(source_dimensions.get("trunnion_forward_offset_m", 3.3528))
	var overall_gun_length: float = float(source_dimensions.get("overall_gun_length_m", 20.7264))
	var breech_length: float = float(estimates.get("breech_length_m", 2.90))
	var barrel_start_z: float = float(estimates.get("barrel_breech_start_z_m", -2.10))
	var barrel_breech_end_z: float = float(estimates.get("barrel_breech_end_z_m", -4.80))
	var barrel_mid_end_z: float = float(estimates.get("barrel_mid_end_z_m", -12.0))
	var barrel_breech_diameter: float = float(estimates.get("barrel_breech_start_diameter_m", 1.08))
	var barrel_mid_start_diameter: float = float(estimates.get("barrel_breech_end_diameter_m", 0.98))
	var barrel_mid_end_diameter: float = float(estimates.get("barrel_mid_end_diameter_m", 0.72))
	var barrel_muzzle_diameter: float = float(estimates.get("barrel_muzzle_diameter_m", 0.56))
	var muzzle_band_diameter: float = float(estimates.get("muzzle_band_diameter_m", 0.70))
	var muzzle_band_length: float = float(estimates.get("muzzle_band_length_m", 0.27))
	var breech_rear_z: float = breech_length * 0.5
	var barrel_end_z: float = breech_rear_z - overall_gun_length
	for gun_index: int in range(3):
		var gun_x: float = float(gun_index - 1) * outer_offset
		var pivot: Node3D = _add_elevation_pivot("ElevationPivot_Gun%02d" % (gun_index + 1), Vector3(gun_x, gun_axis_y - 0.2, -trunnion_forward))
		var guns: Node3D = pivot.get_node("GunsAndCradle") as Node3D
		var gunmetal: Material = materials.gunmetal
		GEOMETRY.add_box(guns, "Gun%02d_Breech" % (gun_index + 1), Vector3.ZERO, Vector3(1.55, 1.28, breech_length), gunmetal)
		GEOMETRY.add_box(guns, "Gun%02d_RecoilSleeve" % (gun_index + 1), Vector3(0.0, 0.18, -1.4), Vector3(0.68, 0.72, 2.3), materials.steel)
		GEOMETRY.add_beam(guns, "Gun%02d_BarrelBreech" % (gun_index + 1), Vector3(0.0, 0.2, barrel_start_z), Vector3(0.0, 0.2, barrel_breech_end_z), barrel_breech_diameter, gunmetal, 20, barrel_mid_start_diameter)
		GEOMETRY.add_beam(guns, "Gun%02d_BarrelMid" % (gun_index + 1), Vector3(0.0, 0.2, barrel_breech_end_z), Vector3(0.0, 0.2, barrel_mid_end_z), barrel_mid_start_diameter, gunmetal, 20, barrel_mid_end_diameter)
		GEOMETRY.add_beam(guns, "Gun%02d_BarrelForward" % (gun_index + 1), Vector3(0.0, 0.2, barrel_mid_end_z), Vector3(0.0, 0.2, barrel_end_z + muzzle_band_length), barrel_mid_end_diameter, gunmetal, 20, barrel_muzzle_diameter)
		GEOMETRY.add_beam(guns, "Gun%02d_MuzzleBand" % (gun_index + 1), Vector3(0.0, 0.2, barrel_end_z + muzzle_band_length), Vector3(0.0, 0.2, barrel_end_z + 0.02), muzzle_band_diameter, materials.steel, 20)
		GEOMETRY.add_beam(guns, "Gun%02d_TrainingJack" % (gun_index + 1), Vector3(0.0, -0.52, -0.25), Vector3(0.0, -0.16, -2.1), 0.12, materials.steel, 8)

func _make_turret_top_outline(bottom_outline: PackedVector2Array, width: float, length: float, side_inset: float, front_inset: float, chamfer: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var side_scale: float = 1.0 - (2.0 * side_inset / width)
	var front_edge_z: float = -length * 0.5
	for point: Vector2 in bottom_outline:
		var front_distance: float = maxf(0.0, point.y - front_edge_z)
		var front_weight: float = clampf(1.0 - front_distance / chamfer, 0.0, 1.0)
		result.append(Vector2(point.x * side_scale, point.y + front_inset * front_weight))
	return result

func _turret_front_half_width(y: float, width: float, base_y: float, height: float, side_inset: float, chamfer: float) -> float:
	var side_scale: float = 1.0 - (2.0 * side_inset / width) * clampf((y - base_y) / height, 0.0, 1.0)
	return (width * 0.5 - chamfer) * side_scale

func _add_turret_front_panel(part_name: String, x_min: float, x_max: float, y_min: float, y_max: float, length: float, base_y: float, height: float, front_inset: float, plate_depth: float, material: Material) -> void:
	var panel_width: float = x_max - x_min
	var panel_height: float = y_max - y_min
	if panel_width <= 0.01 or panel_height <= 0.01:
		return
	var center_y: float = (y_min + y_max) * 0.5
	var front_z: float = -length * 0.5 + front_inset * (center_y - base_y) / height
	var front_angle: float = atan(front_inset / height)
	var panel: MeshInstance3D = GEOMETRY.add_box(housing_root, part_name, Vector3((x_min + x_max) * 0.5, center_y, front_z), Vector3(panel_width, panel_height, plate_depth), material, Vector3(front_angle, 0.0, 0.0))
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _build_main_turret_front(armor: Material, width: float, length: float, height: float, side_inset: float, front_inset: float, chamfer: float, estimates: Dictionary, outer_offset: float) -> void:
	var gun_axis_y: float = float(estimates.get("gun_axis_above_shelf_plate_m", 2.25))
	var plate_depth: float = float(estimates.get("front_plate_depth_m", 0.10))
	var port_outer_radius: float = float(estimates.get("gun_port_outer_radius_m", 0.72))
	var frame_inner_radius: float = float(estimates.get("gun_port_frame_inner_radius_m", 0.64))
	var buckler_inner_radius: float = float(estimates.get("gun_port_buckler_inner_radius_m", 0.56))
	var frame_depth: float = float(estimates.get("gun_port_frame_depth_m", 0.14))
	var buckler_depth: float = float(estimates.get("gun_port_buckler_depth_m", 0.12))
	var port_bottom_y: float = gun_axis_y - port_outer_radius
	var port_top_y: float = gun_axis_y + port_outer_radius
	var front_angle: float = atan(front_inset / height)
	var front_normal: Vector3 = Vector3(0.0, -sin(front_angle), cos(front_angle))
	var port_surface_z: float = -length * 0.5 + front_inset * gun_axis_y / height
	var gun_centers: Array[float] = [-outer_offset, 0.0, outer_offset]
	var bottom_half_width: float = _turret_front_half_width(gun_axis_y, width, 0.0, height, side_inset, chamfer)
	var lower_center_y: float = port_bottom_y * 0.5
	var lower_half_width: float = _turret_front_half_width(lower_center_y, width, 0.0, height, side_inset, chamfer)
	_add_turret_front_panel("TurretFrontPlate_Lower", -lower_half_width, lower_half_width, 0.0, port_bottom_y, length, 0.0, height, front_inset, plate_depth, armor)
	var upper_center_y: float = (port_top_y + height) * 0.5
	var upper_half_width: float = _turret_front_half_width(upper_center_y, width, 0.0, height, side_inset, chamfer)
	_add_turret_front_panel("TurretFrontPlate_Upper", -upper_half_width, upper_half_width, port_top_y, height, length, 0.0, height, front_inset, plate_depth, armor)
	var previous_right: float = -bottom_half_width
	for gun_index: int in range(gun_centers.size()):
		var gun_x: float = gun_centers[gun_index]
		var left_edge: float = gun_x - port_outer_radius
		if left_edge > previous_right:
			_add_turret_front_panel("TurretFrontPlate_Between%02d" % gun_index, previous_right, left_edge, port_bottom_y, port_top_y, length, 0.0, height, front_inset, plate_depth, armor)
		previous_right = gun_x + port_outer_radius
	if bottom_half_width > previous_right:
		_add_turret_front_panel("TurretFrontPlate_Right", previous_right, bottom_half_width, port_bottom_y, port_top_y, length, 0.0, height, front_inset, plate_depth, armor)
	for gun_index: int in range(gun_centers.size()):
		var gun_x: float = gun_centers[gun_index]
		var port_center: Vector3 = Vector3(gun_x, gun_axis_y, port_surface_z)
		var collar_center: Vector3 = port_center - front_normal * (frame_depth * 0.35)
		GEOMETRY.add_annulus(housing_root, "GunPortFrame_%02d" % (gun_index + 1), collar_center, port_outer_radius, frame_inner_radius, frame_depth, materials.turret_roof, 32, front_angle)
		GEOMETRY.add_annulus(housing_root, "GunPortBuckler_%02d" % (gun_index + 1), port_center + front_normal * 0.015, frame_inner_radius, buckler_inner_radius, buckler_depth, materials.port_buckler, 32, front_angle)
		var recess: MeshInstance3D = GEOMETRY.add_cylinder(housing_root, "GunPortRecess_%02d" % (gun_index + 1), port_center + front_normal * 0.18, buckler_inner_radius, 0.10, materials.gunmetal, 32)
		recess.rotation.x = PI * 0.5 + front_angle

func _build_main_turret_side_sights(width: float, height: float, side_inset: float) -> void:
	var sight_height: float = 1.72
	var armor_side_x: float = width * 0.5 - side_inset * sight_height / height
	var sight_positions: Array[float] = [-2.15, 1.65]
	for side: float in [-1.0, 1.0]:
		var side_name: String = "Port" if side < 0.0 else "Starboard"
		for index: int in range(sight_positions.size()):
			var sight_z: float = sight_positions[index]
			var part_name: String = "TurretSideSightHood_%s_%02d" % [side_name, index + 1]
			GEOMETRY.add_box(housing_root, part_name, Vector3(side * (armor_side_x + 0.16), sight_height, sight_z), Vector3(0.40, 0.56, 0.98), materials.turret)
			GEOMETRY.add_box(housing_root, "TurretSideSightOptic_%s_%02d" % [side_name, index + 1], Vector3(side * (armor_side_x + 0.37), sight_height, sight_z), Vector3(0.035, 0.22, 0.72), materials.dark_glass)
			GEOMETRY.add_box(housing_root, "TurretSideSightShutter_%s_%02d" % [side_name, index + 1], Vector3(side * (armor_side_x + 0.39), sight_height - 0.20, sight_z), Vector3(0.055, 0.10, 0.82), materials.turret_roof)

func _build_main_turret_periscope_covers(height: float) -> void:
	for side: float in [-1.0, 1.0]:
		var side_name: String = "Port" if side < 0.0 else "Starboard"
		var cover_center: Vector3 = Vector3(side * 2.35, height + 0.31, -2.65)
		GEOMETRY.add_box(housing_root, "TurretPeriscopeHoodCover_%s" % side_name, cover_center, Vector3(0.78, 0.20, 0.66), materials.turret_roof, Vector3(0.0, side * -0.10, 0.0))
		GEOMETRY.add_box(housing_root, "TurretPeriscopeOptic_%s" % side_name, cover_center + Vector3(0.0, 0.11, -0.17), Vector3(0.48, 0.025, 0.08), materials.dark_glass)

func _build_secondary_turret() -> void:
	var gunmetal: Material = materials.gunmetal
	var source_dimensions: Dictionary = module_profile.get("source_dimensions", {})
	var estimates: Dictionary = module_profile.get("geometry_estimates", {})
	var width: float = float(estimates.get("shield_width_m", 4.7))
	var length: float = float(estimates.get("shield_length_m", 5.0))
	var bottom_y: float = float(estimates.get("shield_bottom_y_m", 0.25))
	var top_y: float = float(estimates.get("shield_top_y_m", 3.05))
	var shield_height: float = top_y - bottom_y
	var side_inset: float = float(estimates.get("side_plate_top_inset_m", 0.14))
	var front_inset: float = float(estimates.get("front_plate_top_inset_m", 0.18))
	var chamfer: float = float(estimates.get("front_corner_chamfer_m", 0.65))
	var bottom_outline: PackedVector2Array = GEOMETRY.chamfered_outline(width, length, chamfer)
	var top_outline: PackedVector2Array = _make_turret_top_outline(bottom_outline, width, length, side_inset, front_inset, chamfer)
	GEOMETRY.add_cylinder(housing_root, "Turntable", Vector3(0.0, 0.16, 0.0), 1.92, 0.28, materials.steel, 24)
	GEOMETRY.add_tapered_prism(housing_root, "TwinGunShield", bottom_outline, top_outline, bottom_y, top_y, materials.turret, 0)
	GEOMETRY.add_prism(housing_root, "ShieldRoof", top_outline, top_y - 0.04, top_y + 0.16, materials.turret_roof)
	GEOMETRY.add_box(housing_root, "RangefinderBand", Vector3(0.0, top_y - 0.28, length * 0.39), Vector3(3.55, 0.28, 0.10), materials.dark_glass)
	GEOMETRY.add_box(housing_root, "GunCaptainSight", Vector3(1.55, top_y + 0.18, -length * 0.32), Vector3(0.34, 0.2, 0.42), materials.steel)
	var gun_axis_y: float = float(estimates.get("gun_axis_y_m", 1.45))
	var gun_spacing_half: float = float(estimates.get("gun_axis_spacing_half_m", 0.63))
	var bore_length: float = float(source_dimensions.get("bore_length_m", 4.826))
	var barrel_breech_face_z: float = -0.5
	var barrel_end_z: float = barrel_breech_face_z - bore_length
	var pivot: Node3D = _add_elevation_pivot("ElevationPivot", Vector3(0.0, gun_axis_y - 0.1, -1.68))
	var guns: Node3D = pivot.get_node("GunsAndCradle") as Node3D
	for gun_index: int in range(2):
		var gun_x: float = -gun_spacing_half if gun_index == 0 else gun_spacing_half
		GEOMETRY.add_box(guns, "Gun%02d_Breech" % (gun_index + 1), Vector3(gun_x, 0.1, 0.15), Vector3(0.68, 0.72, 1.3), gunmetal)
		GEOMETRY.add_box(guns, "Gun%02d_RecoilCradle" % (gun_index + 1), Vector3(gun_x, -0.24, -0.62), Vector3(0.34, 0.42, 1.65), materials.steel)
		GEOMETRY.add_beam(guns, "Gun%02d_Barrel" % (gun_index + 1), Vector3(gun_x, 0.1, barrel_breech_face_z), Vector3(gun_x, 0.1, barrel_end_z), 0.20, gunmetal, 16, 0.15)
		GEOMETRY.add_beam(guns, "Gun%02d_MuzzleRing" % (gun_index + 1), Vector3(gun_x, 0.1, barrel_end_z + 0.20), Vector3(gun_x, 0.1, barrel_end_z + 0.03), 0.22, materials.steel, 16)
	var port_outer_radius: float = float(estimates.get("gun_port_outer_radius_m", 0.32))
	var frame_inner_radius: float = float(estimates.get("gun_port_frame_inner_radius_m", 0.25))
	var buckler_inner_radius: float = float(estimates.get("gun_port_buckler_inner_radius_m", 0.19))
	var frame_depth: float = float(estimates.get("gun_port_frame_depth_m", 0.12))
	var buckler_depth: float = float(estimates.get("gun_port_buckler_depth_m", 0.10))
	var plate_depth: float = float(estimates.get("front_plate_depth_m", 0.10))
	var front_angle: float = atan(front_inset / shield_height)
	var front_normal: Vector3 = Vector3(0.0, -sin(front_angle), cos(front_angle))
	var port_bottom_y: float = gun_axis_y - port_outer_radius
	var port_top_y: float = gun_axis_y + port_outer_radius
	var front_half_width: float = _turret_front_half_width(gun_axis_y, width, bottom_y, shield_height, side_inset, chamfer)
	var lower_center_y: float = (bottom_y + port_bottom_y) * 0.5
	var lower_half_width: float = _turret_front_half_width(lower_center_y, width, bottom_y, shield_height, side_inset, chamfer)
	_add_turret_front_panel("TwinGunFrontPlate_Lower", -lower_half_width, lower_half_width, bottom_y, port_bottom_y, length, bottom_y, shield_height, front_inset, plate_depth, materials.turret)
	var upper_center_y: float = (port_top_y + top_y) * 0.5
	var upper_half_width: float = _turret_front_half_width(upper_center_y, width, bottom_y, shield_height, side_inset, chamfer)
	_add_turret_front_panel("TwinGunFrontPlate_Upper", -upper_half_width, upper_half_width, port_top_y, top_y, length, bottom_y, shield_height, front_inset, plate_depth, materials.turret)
	var previous_right: float = -front_half_width
	var gun_centers: Array[float] = [-gun_spacing_half, gun_spacing_half]
	for gun_index: int in range(gun_centers.size()):
		var gun_x: float = gun_centers[gun_index]
		var left_edge: float = gun_x - port_outer_radius
		if left_edge > previous_right:
			_add_turret_front_panel("TwinGunFrontPlate_Between%02d" % gun_index, previous_right, left_edge, port_bottom_y, port_top_y, length, bottom_y, shield_height, front_inset, plate_depth, materials.turret)
		previous_right = gun_x + port_outer_radius
	if front_half_width > previous_right:
		_add_turret_front_panel("TwinGunFrontPlate_Right", previous_right, front_half_width, port_bottom_y, port_top_y, length, bottom_y, shield_height, front_inset, plate_depth, materials.turret)
	var port_surface_z: float = -length * 0.5 + front_inset * (gun_axis_y - bottom_y) / shield_height
	for gun_index: int in range(gun_centers.size()):
		var gun_x: float = gun_centers[gun_index]
		var port_center: Vector3 = Vector3(gun_x, gun_axis_y, port_surface_z)
		var collar_center: Vector3 = port_center - front_normal * (frame_depth * 0.35)
		GEOMETRY.add_annulus(housing_root, "TwinGunPortFrame_%02d" % (gun_index + 1), collar_center, port_outer_radius, frame_inner_radius, frame_depth, materials.turret_roof, 28, front_angle)
		GEOMETRY.add_annulus(housing_root, "TwinGunPortBuckler_%02d" % (gun_index + 1), port_center + front_normal * 0.015, frame_inner_radius, buckler_inner_radius, buckler_depth, materials.port_buckler, 28, front_angle)
		var recess: MeshInstance3D = GEOMETRY.add_cylinder(housing_root, "TwinGunPortRecess_%02d" % (gun_index + 1), port_center + front_normal * 0.16, buckler_inner_radius, 0.08, materials.gunmetal, 28)
		recess.rotation.x = PI * 0.5 + front_angle

func _build_bofors_mount() -> void:
	GEOMETRY.add_cylinder(housing_root, "TurntablePedestal", Vector3(0.0, 0.34, 0.0), 0.32, 0.68, materials.steel, 16)
	GEOMETRY.add_cylinder(housing_root, "CrewPlatform", Vector3(0.0, 0.64, 0.0), 1.05, 0.2, materials.deck_detail, 20)
	GEOMETRY.add_box(housing_root, "Shield_Front", Vector3(0.0, 1.34, -0.78), Vector3(2.05, 1.18, 0.16), materials.turret)
	GEOMETRY.add_box(housing_root, "Shield_PortCheek", Vector3(-1.0, 1.25, -0.05), Vector3(0.16, 1.0, 1.38), materials.turret)
	GEOMETRY.add_box(housing_root, "Shield_StarboardCheek", Vector3(1.0, 1.25, -0.05), Vector3(0.16, 1.0, 1.38), materials.turret)
	GEOMETRY.add_box(housing_root, "AmmunitionTray_Port", Vector3(-0.78, 1.62, 0.28), Vector3(0.36, 0.35, 1.16), materials.steel)
	GEOMETRY.add_box(housing_root, "AmmunitionTray_Starboard", Vector3(0.78, 1.62, 0.28), Vector3(0.36, 0.35, 1.16), materials.steel)
	GEOMETRY.add_box(housing_root, "SightAndControlBody", Vector3(0.0, 1.84, 0.15), Vector3(0.62, 0.52, 0.68), materials.gunmetal)
	GEOMETRY.add_box(housing_root, "GunnerSeat", Vector3(0.0, 1.0, 0.92), Vector3(0.72, 0.18, 0.48), materials.seat)
	GEOMETRY.add_box(housing_root, "DirectorSight", Vector3(0.0, 2.02, 0.76), Vector3(0.58, 0.28, 0.42), materials.steel)
	GEOMETRY.add_cylinder(housing_root, "SightLens", Vector3(0.0, 2.03, 0.96), 0.09, 0.08, materials.dark_glass, 12)
	GEOMETRY.add_beam(housing_root, "HandwheelSupport_Port", Vector3(-0.88, 0.9, 0.7), Vector3(-0.88, 1.72, 0.7), 0.07, materials.steel, 8)
	GEOMETRY.add_beam(housing_root, "HandwheelSupport_Starboard", Vector3(0.88, 0.9, 0.7), Vector3(0.88, 1.72, 0.7), 0.07, materials.steel, 8)
	var pivot: Node3D = _add_elevation_pivot("ElevationPivot", Vector3(0.0, 1.42, -0.18))
	var guns: Node3D = pivot.get_node("GunsAndCradle") as Node3D
	for gun_x: float in [-0.63, -0.21, 0.21, 0.63]:
		GEOMETRY.add_box(guns, "Bofors_Receiver_%0.2f" % gun_x, Vector3(gun_x, 0.18, 0.2), Vector3(0.28, 0.38, 0.84), materials.gunmetal)
		GEOMETRY.add_box(guns, "Bofors_Breech_%0.2f" % gun_x, Vector3(gun_x, 0.16, 0.57), Vector3(0.38, 0.34, 0.42), materials.steel)
		GEOMETRY.add_beam(guns, "Bofors_Barrel_%0.2f" % gun_x, Vector3(gun_x, 0.2, -0.18), Vector3(gun_x, 0.2, -2.35), 0.082, materials.gunmetal, 12)
		GEOMETRY.add_beam(guns, "Bofors_MuzzleCollar_%0.2f" % gun_x, Vector3(gun_x, 0.2, -2.2), Vector3(gun_x, 0.2, -2.36), 0.108, materials.steel, 12)

func _build_oerlikon_mount() -> void:
	GEOMETRY.add_cylinder(housing_root, "OerlikonColumn", Vector3(0.0, 0.32, 0.0), 0.16, 0.64, materials.steel, 12)
	GEOMETRY.add_box(housing_root, "OerlikonSeat", Vector3(0.46, 0.52, 0.54), Vector3(0.7, 0.16, 0.62), materials.seat)
	GEOMETRY.add_box(housing_root, "OerlikonSeatBack", Vector3(0.46, 0.84, 0.82), Vector3(0.7, 0.5, 0.13), materials.seat)
	GEOMETRY.add_box(housing_root, "ShoulderRest", Vector3(0.0, 1.12, 0.72), Vector3(0.82, 0.16, 0.18), materials.steel)
	var pivot: Node3D = _add_elevation_pivot("ElevationPivot", Vector3(0.0, 0.98, 0.0))
	var guns: Node3D = pivot.get_node("GunsAndCradle") as Node3D
	GEOMETRY.add_box(guns, "OerlikonReceiver", Vector3(0.0, 0.14, -0.36), Vector3(0.34, 0.42, 0.8), materials.gunmetal)
	GEOMETRY.add_cylinder(guns, "OerlikonBreech", Vector3(0.0, 0.14, 0.09), 0.21, 0.36, materials.steel, 14)
	GEOMETRY.add_cylinder(guns, "OerlikonDrumMagazine", Vector3(0.0, -0.18, -0.27), 0.3, 0.22, materials.steel, 16)
	GEOMETRY.add_beam(guns, "OerlikonBarrel", Vector3(0.0, 0.16, -0.72), Vector3(0.0, 0.16, -1.95), 0.09, materials.gunmetal, 12)
	GEOMETRY.add_beam(guns, "OerlikonMuzzleRing", Vector3(0.0, 0.16, -1.83), Vector3(0.0, 0.16, -1.98), 0.13, materials.steel, 12)
	GEOMETRY.add_box(guns, "OerlikonSights", Vector3(0.0, 0.47, -0.52), Vector3(0.46, 0.12, 0.12), materials.steel)
	GEOMETRY.add_beam(housing_root, "ElevationYoke_Port", Vector3(-0.3, 0.9, 0.0), Vector3(-0.3, 1.35, 0.0), 0.06, materials.steel, 8)
	GEOMETRY.add_beam(housing_root, "ElevationYoke_Starboard", Vector3(0.3, 0.9, 0.0), Vector3(0.3, 1.35, 0.0), 0.06, materials.steel, 8)

func advance(delta: float, simulation_time: float) -> void:
	if not moving:
		return
	var train_target: float
	if automatic_demo:
		train_target = lerpf(train_limits.x, train_limits.y, (sin(simulation_time * 0.13 + phase) + 1.0) * 0.5)
	else:
		train_target = commanded_train_deg
	var train_degrees: float = rad_to_deg(wrapf(train_axis.rotation.y - base_heading, -PI, PI))
	train_degrees = move_toward(train_degrees, train_target, train_rate_deg_s * delta)
	train_axis.rotation.y = base_heading + deg_to_rad(clampf(train_degrees, train_limits.x, train_limits.y))
	for index: int in range(elevation_axes.size()):
		var elevation_target: float
		if automatic_demo:
			var elevation_phase: float = phase + float(index) * 0.74
			elevation_target = lerpf(elevation_limits.x, elevation_limits.y, (sin(simulation_time * 0.19 + elevation_phase) + 1.0) * 0.5)
		else:
			elevation_target = float(commanded_elevations[index])
		var elevation_degrees: float = rad_to_deg(elevation_axes[index].rotation.x)
		elevation_degrees = move_toward(elevation_degrees, elevation_target, elevation_rate_deg_s * delta)
		elevation_axes[index].rotation.x = deg_to_rad(clampf(elevation_degrees, elevation_limits.x, elevation_limits.y))

func aim_at_angles(train_degrees: float, elevation_degrees: float) -> void:
	if not is_finite(train_degrees) or not is_finite(elevation_degrees):
		return
	commanded_train_deg = clampf(train_degrees, train_limits.x, train_limits.y)
	for index: int in range(commanded_elevations.size()):
		commanded_elevations[index] = clampf(elevation_degrees, elevation_limits.x, elevation_limits.y)
	automatic_demo = false
	moving = true

func aim_at_train_angle(train_degrees: float) -> void:
	if not is_finite(train_degrees):
		return
	_capture_current_targets_if_demo()
	commanded_train_deg = clampf(train_degrees, train_limits.x, train_limits.y)
	automatic_demo = false
	moving = true

func aim_at_gun_elevation(gun_index: int, elevation_degrees: float) -> void:
	if not is_finite(elevation_degrees) or gun_index < 0 or gun_index >= elevation_axes.size():
		return
	_capture_current_targets_if_demo()
	commanded_elevations[gun_index] = clampf(elevation_degrees, elevation_limits.x, elevation_limits.y)
	automatic_demo = false
	moving = true

func _capture_current_targets_if_demo() -> void:
	if not automatic_demo:
		return
	commanded_train_deg = get_angle_state().x
	for index: int in range(elevation_axes.size()):
		commanded_elevations[index] = rad_to_deg(elevation_axes[index].rotation.x)

func resume_demo() -> void:
	automatic_demo = true
	moving = true

func get_angle_state() -> Vector2:
	var elevation_degrees: float = 0.0
	if not elevation_axes.is_empty():
		elevation_degrees = rad_to_deg(elevation_axes[0].rotation.x)
	return Vector2(rad_to_deg(wrapf(train_axis.rotation.y - base_heading, -PI, PI)), elevation_degrees)

func get_gun_elevation_states() -> PackedFloat64Array:
	var result: PackedFloat64Array = PackedFloat64Array()
	for axis: Node3D in elevation_axes:
		result.append(rad_to_deg(axis.rotation.x))
	return result

func get_audit_record() -> Dictionary:
	var anchor_position: Vector3 = Vector3.ZERO
	var host_module: String = ""
	var compatible_interface: String = ""
	var source_status: String = "unrecorded"
	var foundation_base_error: float = 0.0
	if is_instance_valid(station_marker):
		anchor_position = station_marker.global_position
		host_module = str(station_marker.get_meta("host_module", ""))
		compatible_interface = str(station_marker.get_meta("compatible_interface", ""))
		source_status = str(station_marker.get_meta("source_status", "unrecorded"))
		if is_instance_valid(foundation_base_node):
			foundation_base_error = foundation_base_node.global_position.distance_to(anchor_position)
	var installation_node: Node3D = get_parent() as Node3D
	var installation_position: Vector3 = installation_node.global_position if is_instance_valid(installation_node) else global_position
	return {
		"id": mount_id,
		"type": mount_type,
		"station_id": str(station_marker.get_meta("station_id", mount_id)) if is_instance_valid(station_marker) else mount_id,
		"host_module": host_module,
		"compatible_interface": compatible_interface,
		"source_status": source_status,
		"support_surface": support_surface,
		"support_target_id": support_target_id,
		"support_contact_position": anchor_position,
		"foundation_base_contact_position": foundation_base_node.global_position if is_instance_valid(foundation_base_node) else anchor_position,
		"installation_interface_position": installation_position,
		"mount_global_position": global_position,
		"station_global_position": anchor_position,
		"foundation_base_error_m": foundation_base_error,
		"station_contact_error_m": global_position.distance_to(installation_position),
		"train_axis": train_axis.name,
		"elevation_axes": elevation_axes.map(func(axis: Node3D) -> String: return axis.name),
		"independent_gun_elevation": independent_gun_elevation,
		"train_limits_deg": [train_limits.x, train_limits.y],
		"elevation_limits_deg": [elevation_limits.x, elevation_limits.y],
		"train_rate_deg_s": train_rate_deg_s,
		"elevation_rate_deg_s": elevation_rate_deg_s
	}

func _ensure_muzzle_markers() -> void:
	# Read the actual barrel-tip primitive before static batching; preserve its pivot.
	for axis: Node3D in elevation_axes:
		if not axis.find_children("Muzzle_*", "Marker3D", false, false).is_empty():
			continue
		var tips: Array[MeshInstance3D] = []
		for child: Node in axis.find_children("*Muzzle*", "MeshInstance3D", true, false):
			var part: MeshInstance3D = child as MeshInstance3D
			if part.mesh is CylinderMesh:
				tips.append(part)
		tips.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool: return a.position.x < b.position.x)
		for index: int in range(tips.size()):
			var part: MeshInstance3D = tips[index]
			var cylinder: CylinderMesh = part.mesh as CylinderMesh
			var tip: Vector3 = part.to_global(Vector3(0.0,cylinder.height*0.5,0.0))
			var marker: Marker3D = Marker3D.new()
			marker.name = "Muzzle_%02d" % (index+1)
			axis.add_child(marker)
			marker.position = axis.to_local(tip)
			marker.set_meta("source_barrel_part",str(part.name))
