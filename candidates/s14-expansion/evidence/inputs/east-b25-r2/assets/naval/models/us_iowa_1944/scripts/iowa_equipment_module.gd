class_name IowaEquipmentModule
extends Node3D

const GEOMETRY = preload("iowa_geometry.gd")

var equipment_type: String = ""
var materials: Dictionary = {}
var equipment_profile: Dictionary = {}
var train_axis: Node3D
var boom_elevation_axis: Node3D

func build_module_template(module_type: String, palette: Dictionary, profile: Dictionary = {}) -> void:
	equipment_type = module_type
	materials = palette
	equipment_profile = profile
	name = "EquipmentModule"
	match equipment_type:
		"aircraft_crane":
			_build_aircraft_crane()
		"aircraft_catapult":
			_build_aircraft_catapult()
		_:
			push_error("Unknown equipment module type: %s" % equipment_type)

func _build_aircraft_catapult() -> void:
	var estimates: Dictionary = equipment_profile.get("geometry_estimates", {})
	var pedestal_radius: float = float(estimates.get("pedestal_radius_m", 1.45))
	var pedestal_height: float = float(estimates.get("pedestal_height_m", 0.62))
	var track_length: float = float(estimates.get("track_length_m", 18.3))
	var track_width: float = float(estimates.get("track_width_m", 2.2))
	var truss_depth: float = float(estimates.get("truss_depth_m", 0.95))
	var truss_bays: int = maxi(6, int(estimates.get("truss_bays", 8)))
	var shuttle_position: float = float(estimates.get("shuttle_position_m", 5.0))
	GEOMETRY.add_cylinder(self, "CatapultDeckSocket", Vector3(0.0, pedestal_height * 0.5, 0.0), pedestal_radius, pedestal_height, materials.foundation, 24)
	GEOMETRY.add_annulus(self, "CatapultSlewBearing", Vector3(0.0, pedestal_height, 0.0), pedestal_radius * 1.10, pedestal_radius * 0.78, 0.18, materials.steel, 32, PI * 0.5)
	train_axis = Node3D.new()
	train_axis.name = "TrainPivot"
	train_axis.position.y = pedestal_height + 0.19
	add_child(train_axis)
	GEOMETRY.add_cylinder(train_axis, "RotatingCatapultTable", Vector3(0.0, 0.16, 0.0), pedestal_radius * 0.82, 0.32, materials.deck_detail, 24)
	_build_catapult_bed(train_axis, track_length, track_width, truss_depth, truss_bays, shuttle_position)

func _build_catapult_bed(parent: Node3D, track_length: float, track_width: float, truss_depth: float, bay_count: int, shuttle_position: float) -> void:
	var half_width: float = track_width * 0.5
	var lower_y: float = 0.34
	var upper_y: float = lower_y + truss_depth
	var rail_y: float = upper_y + 0.25
	var start_z: float = 0.45
	var end_z: float = track_length - 0.25
	for side: float in [-1.0, 1.0]:
		var side_x: float = side * half_width * 0.5
		GEOMETRY.add_beam(parent, "CatapultLowerLongitudinalGirder", Vector3(side_x, lower_y, start_z), Vector3(side_x, lower_y, end_z), 0.38, materials.frame, 10)
		GEOMETRY.add_beam(parent, "CatapultUpperLongitudinalGirder", Vector3(side_x, upper_y, start_z), Vector3(side_x, upper_y, end_z), 0.32, materials.steel, 10)
		for bay_index: int in range(bay_count + 1):
			var amount: float = float(bay_index) / float(bay_count)
			var z_value: float = lerpf(start_z, end_z, amount)
			GEOMETRY.add_beam(parent, "CatapultTrussPost", Vector3(side_x, lower_y, z_value), Vector3(side_x, upper_y, z_value), 0.20, materials.steel, 8)
			if bay_index < bay_count:
				var next_z: float = lerpf(start_z, end_z, float(bay_index + 1) / float(bay_count))
				var lower_point: Vector3 = Vector3(side_x, lower_y, z_value)
				var upper_next_point: Vector3 = Vector3(side_x, upper_y, next_z)
				var upper_point: Vector3 = Vector3(side_x, upper_y, z_value)
				var lower_next_point: Vector3 = Vector3(side_x, lower_y, next_z)
				if (bay_index + int(side)) % 2 == 0:
					GEOMETRY.add_beam(parent, "CatapultTrussDiagonal", lower_point, upper_next_point, 0.16, materials.frame, 8)
				else:
					GEOMETRY.add_beam(parent, "CatapultTrussDiagonal", upper_point, lower_next_point, 0.16, materials.frame, 8)
		GEOMETRY.add_box(parent, "CatapultLaunchRail", Vector3(side_x, rail_y, (start_z + end_z) * 0.5), Vector3(0.30, 0.24, end_z - start_z), materials.gunmetal)
	for bay_index: int in range(bay_count + 1):
		var amount: float = float(bay_index) / float(bay_count)
		var z_value: float = lerpf(start_z, end_z, amount)
		GEOMETRY.add_beam(parent, "CatapultCrossTie", Vector3(-half_width * 0.5, lower_y, z_value), Vector3(half_width * 0.5, lower_y, z_value), 0.18, materials.steel, 8)
		GEOMETRY.add_beam(parent, "CatapultRailCrosshead", Vector3(-half_width * 0.5, rail_y - 0.12, z_value), Vector3(half_width * 0.5, rail_y - 0.12, z_value), 0.18, materials.steel, 8)
	GEOMETRY.add_beam(parent, "CatapultLaunchCylinder", Vector3(0.0, lower_y + 0.10, start_z + 0.40), Vector3(0.0, lower_y + 0.10, end_z - 1.0), 0.46, materials.superstructure_dark, 12)
	GEOMETRY.add_beam(parent, "CatapultRootStay_Port", Vector3(-pedestal_root_offset(track_width), 0.35, 0.15), Vector3(-half_width * 0.5, upper_y, 3.8), 0.26, materials.frame, 10)
	GEOMETRY.add_beam(parent, "CatapultRootStay_Starboard", Vector3(pedestal_root_offset(track_width), 0.35, 0.15), Vector3(half_width * 0.5, upper_y, 3.8), 0.26, materials.frame, 10)
	GEOMETRY.add_box(parent, "CatapultLaunchCarriage", Vector3(0.0, rail_y - 0.16, shuttle_position), Vector3(track_width * 0.82, 0.30, 1.5), materials.deck_detail)
	for side: float in [-1.0, 1.0]:
		var roller: MeshInstance3D = GEOMETRY.add_cylinder(parent, "CatapultCarriageRoller", Vector3(side * half_width * 0.35, rail_y - 0.31, shuttle_position), 0.16, 0.18, materials.steel, 12)
		roller.rotation.z = PI * 0.5
	GEOMETRY.add_box(parent, "CatapultEndStop", Vector3(0.0, rail_y + 0.20, end_z - 0.15), Vector3(track_width * 0.9, 0.25, 0.32), materials.gunmetal)

func pedestal_root_offset(track_width: float) -> float:
	return maxf(0.82, track_width * 0.42)

func _build_aircraft_crane() -> void:
	var estimates: Dictionary = equipment_profile.get("geometry_estimates", {})
	var pedestal_radius: float = float(estimates.get("pedestal_radius_m", 1.25))
	var tower_height: float = float(estimates.get("tower_height_m", 5.8))
	var tower_base_half_width: float = float(estimates.get("tower_base_half_width_m", 0.92))
	var tower_top_half_width: float = float(estimates.get("tower_top_half_width_m", 0.55))
	var boom_length: float = float(estimates.get("boom_length_m", 12.0))
	var boom_base_depth: float = float(estimates.get("boom_base_depth_m", 1.45))
	var boom_tip_depth: float = float(estimates.get("boom_tip_depth_m", 0.72))
	var boom_side_spacing: float = float(estimates.get("boom_side_spacing_m", 0.92))
	var boom_bays: int = maxi(4, int(estimates.get("boom_bays", 6)))
	var headframe_extension: float = float(estimates.get("headframe_extension_m", 0.78))
	var headframe_aft_offset: float = float(estimates.get("headframe_aft_offset_m", -0.36))
	var hook_drop: float = float(estimates.get("hook_drop_m", 3.5))
	GEOMETRY.add_cylinder(self, "CraneDeckSocket", Vector3(0.0, 0.30, 0.0), pedestal_radius, 0.60, materials.foundation, 24)
	GEOMETRY.add_annulus(self, "CraneSlewBearing", Vector3(0.0, 0.60, 0.0), pedestal_radius * 1.08, pedestal_radius * 0.82, 0.18, materials.steel, 32, PI * 0.5)
	train_axis = Node3D.new()
	train_axis.name = "TrainPivot"
	train_axis.position.y = 0.68
	add_child(train_axis)
	GEOMETRY.add_cylinder(train_axis, "RotatingTurntable", Vector3(0.0, 0.16, 0.0), pedestal_radius * 0.84, 0.32, materials.deck_detail, 24)
	_build_crane_tower(train_axis, tower_height, tower_base_half_width, tower_top_half_width, headframe_extension, headframe_aft_offset)
	boom_elevation_axis = Node3D.new()
	boom_elevation_axis.name = "BoomElevationPivot"
	boom_elevation_axis.position.y = tower_height
	boom_elevation_axis.rotation.z = float(estimates.get("initial_boom_elevation_rad", 0.035))
	train_axis.add_child(boom_elevation_axis)
	_build_crane_boom(boom_elevation_axis, boom_length, boom_base_depth, boom_tip_depth, boom_side_spacing, boom_bays)
	_build_crane_hoist(train_axis, boom_elevation_axis, tower_height, boom_length, boom_base_depth, boom_tip_depth, headframe_extension, headframe_aft_offset, hook_drop)

func _build_crane_tower(parent: Node3D, tower_height: float, base_half_width: float, top_half_width: float, headframe_extension: float, headframe_aft_offset: float) -> void:
	var lower_y: float = 0.28
	var upper_y: float = tower_height - 0.18
	for x_side: float in [-1.0, 1.0]:
		for z_side: float in [-1.0, 1.0]:
			GEOMETRY.add_beam(parent, "TowerLeg", Vector3(x_side * base_half_width, lower_y, z_side * base_half_width * 0.82), Vector3(x_side * top_half_width, upper_y, z_side * top_half_width * 0.82), 0.30, materials.frame, 10)
	for level_index: int in range(4):
		var amount: float = float(level_index) / 3.0
		var y_value: float = lerpf(lower_y + 0.45, upper_y - 0.35, amount)
		var half_width: float = lerpf(base_half_width, top_half_width, (y_value - lower_y) / (upper_y - lower_y))
		for side: float in [-1.0, 1.0]:
			GEOMETRY.add_beam(parent, "TowerCrossbeam_X", Vector3(-half_width, y_value, side * half_width * 0.82), Vector3(half_width, y_value, side * half_width * 0.82), 0.16, materials.steel, 8)
			GEOMETRY.add_beam(parent, "TowerCrossbeam_Z", Vector3(side * half_width, y_value, -half_width * 0.82), Vector3(side * half_width, y_value, half_width * 0.82), 0.16, materials.steel, 8)
	for bay_index: int in range(3):
		var bay_amount_a: float = float(bay_index) / 3.0
		var bay_amount_b: float = float(bay_index + 1) / 3.0
		var y_a: float = lerpf(lower_y, upper_y, bay_amount_a)
		var y_b: float = lerpf(lower_y, upper_y, bay_amount_b)
		var half_a: float = lerpf(base_half_width, top_half_width, bay_amount_a)
		var half_b: float = lerpf(base_half_width, top_half_width, bay_amount_b)
		for z_side: float in [-1.0, 1.0]:
			GEOMETRY.add_beam(parent, "TowerDiagonal_XZ", Vector3(-half_a, y_a, z_side * half_a * 0.82), Vector3(half_b, y_b, z_side * half_b * 0.82), 0.13, materials.frame, 8)
			GEOMETRY.add_beam(parent, "TowerDiagonal_XZ", Vector3(half_a, y_a, z_side * half_a * 0.82), Vector3(-half_b, y_b, z_side * half_b * 0.82), 0.13, materials.frame, 8)
		for x_side: float in [-1.0, 1.0]:
			GEOMETRY.add_beam(parent, "TowerDiagonal_YZ", Vector3(x_side * half_a, y_a, -half_a * 0.82), Vector3(x_side * half_b, y_b, half_b * 0.82), 0.13, materials.frame, 8)
			GEOMETRY.add_beam(parent, "TowerDiagonal_YZ", Vector3(x_side * half_a, y_a, half_a * 0.82), Vector3(x_side * half_b, y_b, -half_b * 0.82), 0.13, materials.frame, 8)
	GEOMETRY.add_box(parent, "CraneMachineryDeck", Vector3(0.0, upper_y, 0.0), Vector3(top_half_width * 2.8, 0.42, top_half_width * 2.5), materials.deck_detail)
	GEOMETRY.add_box(parent, "CraneWinchHousing", Vector3(-0.42, upper_y + 0.40, 0.0), Vector3(1.55, 0.72, 1.18), materials.superstructure_dark)
	GEOMETRY.add_cylinder(parent, "CraneWinchDrum", Vector3(0.42, upper_y + 0.43, 0.0), 0.34, 1.18, materials.gunmetal, 18)
	var winch_axis: MeshInstance3D = parent.get_node("CraneWinchDrum") as MeshInstance3D
	winch_axis.rotation.z = PI * 0.5
	var headframe_base: Vector3 = Vector3(headframe_aft_offset, upper_y - 0.10, 0.0)
	var headframe_top: Vector3 = Vector3(headframe_aft_offset, upper_y + headframe_extension, 0.0)
	GEOMETRY.add_beam(parent, "CraneToppingLiftMast", headframe_base, headframe_top, 0.24, materials.frame, 10)
	for x_side: float in [-1.0, 1.0]:
		for z_side: float in [-1.0, 1.0]:
			var brace_root: Vector3 = Vector3(x_side * top_half_width, upper_y - 0.12, z_side * top_half_width * 0.82)
			GEOMETRY.add_beam(parent, "CraneToppingLiftMastBrace", brace_root, headframe_top, 0.12, materials.steel, 8)
	GEOMETRY.add_cylinder(parent, "CraneHeadSheave", Vector3(0.0, upper_y + 0.32, 0.0), 0.52, 0.32, materials.gunmetal, 24)
	var head_sheave: MeshInstance3D = parent.get_node("CraneHeadSheave") as MeshInstance3D
	head_sheave.rotation.x = PI * 0.5
	GEOMETRY.add_box(parent, "CraneSheaveGuard_Port", Vector3(0.0, upper_y + 0.32, -0.25), Vector3(0.92, 0.96, 0.10), materials.frame)
	GEOMETRY.add_box(parent, "CraneSheaveGuard_Starboard", Vector3(0.0, upper_y + 0.32, 0.25), Vector3(0.92, 0.96, 0.10), materials.frame)

func _build_crane_boom(parent: Node3D, length: float, base_depth: float, tip_depth: float, side_spacing: float, bay_count: int) -> void:
	var base_upper_y: float = base_depth * 0.70
	var tip_lower_y: float = base_depth * 0.12
	var tip_upper_y: float = tip_lower_y + tip_depth * 0.70
	for z_side: float in [-1.0, 1.0]:
		var side_z: float = z_side * side_spacing * 0.5
		GEOMETRY.add_beam(parent, "BoomLowerChord", Vector3(0.0, 0.0, side_z), Vector3(length, tip_lower_y, side_z), 0.22, materials.frame, 10)
		GEOMETRY.add_beam(parent, "BoomUpperChord", Vector3(0.0, base_upper_y, side_z), Vector3(length, tip_upper_y, side_z), 0.22, materials.frame, 10)
		for bay_index: int in range(bay_count + 1):
			var amount: float = float(bay_index) / float(bay_count)
			var x_value: float = length * amount
			var lower_y: float = lerpf(0.0, tip_lower_y, amount)
			var upper_y: float = lerpf(base_upper_y, tip_upper_y, amount)
			GEOMETRY.add_beam(parent, "BoomPost", Vector3(x_value, lower_y, side_z), Vector3(x_value, upper_y, side_z), 0.14, materials.steel, 8)
			if bay_index < bay_count:
				var next_amount: float = float(bay_index + 1) / float(bay_count)
				var next_x: float = length * next_amount
				var next_lower_y: float = lerpf(0.0, tip_lower_y, next_amount)
				var next_upper_y: float = lerpf(base_upper_y, tip_upper_y, next_amount)
				if bay_index % 2 == 0:
					GEOMETRY.add_beam(parent, "BoomDiagonal", Vector3(x_value, lower_y, side_z), Vector3(next_x, next_upper_y, side_z), 0.13, materials.frame, 8)
				else:
					GEOMETRY.add_beam(parent, "BoomDiagonal", Vector3(x_value, upper_y, side_z), Vector3(next_x, next_lower_y, side_z), 0.13, materials.frame, 8)
	for bay_index: int in range(bay_count + 1):
		var amount: float = float(bay_index) / float(bay_count)
		var x_value: float = length * amount
		var lower_y: float = lerpf(0.0, tip_lower_y, amount)
		var upper_y: float = lerpf(base_upper_y, tip_upper_y, amount)
		GEOMETRY.add_beam(parent, "BoomCrossTie_Lower", Vector3(x_value, lower_y, -side_spacing * 0.5), Vector3(x_value, lower_y, side_spacing * 0.5), 0.12, materials.steel, 8)
		GEOMETRY.add_beam(parent, "BoomCrossTie_Upper", Vector3(x_value, upper_y, -side_spacing * 0.5), Vector3(x_value, upper_y, side_spacing * 0.5), 0.12, materials.steel, 8)
	GEOMETRY.add_beam(parent, "BoomToppingLift_Port", Vector3(0.0, base_upper_y, -side_spacing * 0.5), Vector3(length, tip_upper_y, -side_spacing * 0.5), 0.07, materials.steel, 8)
	GEOMETRY.add_beam(parent, "BoomToppingLift_Starboard", Vector3(0.0, base_upper_y, side_spacing * 0.5), Vector3(length, tip_upper_y, side_spacing * 0.5), 0.07, materials.steel, 8)
	GEOMETRY.add_cylinder(parent, "BoomTipSheave", Vector3(length, tip_lower_y + tip_depth * 0.40, 0.0), 0.48, 0.30, materials.gunmetal, 24)
	var tip_sheave: MeshInstance3D = parent.get_node("BoomTipSheave") as MeshInstance3D
	tip_sheave.rotation.x = PI * 0.5

func _build_crane_hoist(parent: Node3D, boom_axis: Node3D, tower_height: float, boom_length: float, boom_base_depth: float, boom_tip_depth: float, headframe_extension: float, headframe_aft_offset: float, hook_drop: float) -> void:
	var tip_lower_y: float = boom_base_depth * 0.12
	var tip_upper_y: float = tip_lower_y + boom_tip_depth * 0.70
	var sheave_y: float = tip_lower_y + boom_tip_depth * 0.40
	var tip_upper_position: Vector3 = boom_axis.transform * Vector3(boom_length, tip_upper_y, 0.0)
	var sheave_position: Vector3 = boom_axis.transform * Vector3(boom_length, sheave_y, 0.0)
	var head_lift_position: Vector3 = Vector3(headframe_aft_offset, tower_height - 0.18 + headframe_extension, 0.0)
	var cable_end: Vector3 = sheave_position + Vector3(0.0, -hook_drop, 0.0)
	GEOMETRY.add_beam(parent, "CraneToppingLift", head_lift_position, tip_upper_position, 0.06, materials.gunmetal, 8)
	GEOMETRY.add_beam(parent, "AircraftHoistCable", sheave_position, cable_end, 0.055, materials.gunmetal, 8)
	GEOMETRY.add_beam(parent, "CraneCargoHookStem", cable_end + Vector3(0.0, 0.05, 0.0), cable_end + Vector3(0.0, -0.50, 0.0), 0.12, materials.steel, 8)
	GEOMETRY.add_beam(parent, "CraneCargoHookArm", cable_end + Vector3(0.0, -0.50, 0.0), cable_end + Vector3(-0.28, -0.73, 0.0), 0.09, materials.steel, 8)
