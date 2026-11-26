@tool
extends Node3D
class_name USNBofors40mmQuadMark2Mod5

const MAX_DEPRESSION_DEG: float = -5.0
const MAX_ELEVATION_DEG: float = 90.0
const GUNNER_STATIONS_X: Array[float] = [-1.12, -0.39, 0.39, 1.12]
const BARREL_CALIBER_M: float = 0.04
const BARREL_RIFLED_LENGTH_M: float = 2.24
const SHIELD_THICKNESS_M: float = 0.009525
const MOUNT_BOLT_DIAMETER_M: float = 0.0254
const BOLT_COUNT: int = 18

@export_range(-5.0, 90.0, 0.5) var elevation_degrees: float = 15.0:
	set(value):
		elevation_degrees = clampf(value, MAX_DEPRESSION_DEG, MAX_ELEVATION_DEG)
		_apply_elevation()

@export_range(0.0, 360.0, 0.5) var train_degrees: float = 0.0:
	set(value):
		train_degrees = fposmod(value, 360.0)
		_apply_train()

@export var shielded: bool = true:
	set(value):
		shielded = value
		if is_inside_tree():
			_rebuild()

var _generated_root: Node3D
var _train_pivot: Node3D
var _elevation_pivot: Node3D
var _materials: Dictionary = {}


func _ready() -> void:
	_rebuild()


func set_train_angle(degrees: float) -> void:
	train_degrees = degrees


func set_elevation(degrees: float) -> void:
	elevation_degrees = degrees


func _apply_train() -> void:
	if is_instance_valid(_train_pivot):
		_train_pivot.rotation.y = deg_to_rad(train_degrees)


func _apply_elevation() -> void:
	if is_instance_valid(_elevation_pivot):
		_elevation_pivot.rotation.x = deg_to_rad(elevation_degrees)


func _rebuild() -> void:
	var previous: Node = get_node_or_null("Generated")
	if previous != null:
		remove_child(previous)
		previous.free()

	_materials = _create_materials()
	_generated_root = Node3D.new()
	_generated_root.name = "Generated"
	add_child(_generated_root)
	_generated_root.owner = owner

	_build_foundation()
	_build_rotating_carriage()
	_apply_train()
	_apply_elevation()


func _create_materials() -> Dictionary:
	return {
		"paint": _material(Color(0.37, 0.41, 0.43), 0.25, 0.0),
		"paint_light": _material(Color(0.48, 0.52, 0.53), 0.22, 0.0),
		"steel": _material(Color(0.26, 0.29, 0.31), 0.52, 0.0),
		"steel_edge": _material(Color(0.56, 0.59, 0.59), 0.65, 0.0),
		"rubber": _material(Color(0.07, 0.08, 0.08), 0.0, 0.0),
		"brass": _material(Color(0.57, 0.39, 0.15), 0.68, 0.0),
		"glass": _material(Color(0.14, 0.27, 0.29), 0.18, 0.5),
		"shield": _material(Color(0.42, 0.46, 0.47), 0.28, 0.0, true),
	}


func _material(color: Color, metallic: float, roughness: float, double_sided: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if double_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_foundation() -> void:
	var foundation := Node3D.new()
	foundation.name = "MountFoundation"
	_generated_root.add_child(foundation)

	_add_cylinder(foundation, "DeckContactFlange", 0.91, 0.12, Vector3(0.0, 0.06, 0.0), "steel")
	_add_torus(foundation, "OuterSeatRace", 0.81, 0.045, Vector3(0.0, 0.15, 0.0), "steel_edge")
	_add_cylinder(foundation, "StandDrum", 0.61, 0.49, Vector3(0.0, 0.405, 0.0), "paint")
	_add_cylinder(foundation, "UpperBearingFlange", 0.84, 0.11, Vector3(0.0, 0.69, 0.0), "steel")
	_add_torus(foundation, "UpperSeatRace", 0.73, 0.035, Vector3(0.0, 0.755, 0.0), "steel_edge")

	var bolt_radius: float = 0.76
	for bolt_index: int in range(BOLT_COUNT):
		var angle: float = TAU * float(bolt_index) / float(BOLT_COUNT)
		var bolt_position := Vector3(cos(angle) * bolt_radius, 0.145, sin(angle) * bolt_radius)
		_add_cylinder(foundation, "DeckBolt_%02d" % bolt_index, MOUNT_BOLT_DIAMETER_M * 0.5, 0.035, bolt_position, "steel_edge")

	var seat := Marker3D.new()
	seat.name = "WeaponSeat"
	seat.position = Vector3(0.0, 0.78, 0.0)
	foundation.add_child(seat)

	var contact := Marker3D.new()
	contact.name = "DeckContact"
	contact.position = Vector3.ZERO
	foundation.add_child(contact)

	_train_pivot = Node3D.new()
	_train_pivot.name = "TrainPivot"
	_train_pivot.position = seat.position
	_generated_root.add_child(_train_pivot)


func _build_rotating_carriage() -> void:
	_add_torus(_train_pivot, "TrainingCircle", 0.76, 0.04, Vector3(0.0, -0.005, 0.0), "steel_edge")
	_add_cylinder(_train_pivot, "CarriageHub", 0.56, 0.18, Vector3(0.0, 0.09, 0.0), "steel")

	# This is the mount's own operator floor and carriage, not a ship deck or sponson.
	_add_box(_train_pivot, "CarriageDeck", Vector3(3.62, 0.11, 2.38), Vector3(0.0, 0.32, 0.18), "paint_light")
	# Keep the estimated underframe flush with the operator deck so it reads as a beam flange, not as four separate feet.
	_add_box(_train_pivot, "CarriageUnderbeam_Fore", Vector3(3.32, 0.06, 0.08), Vector3(0.0, 0.235, -0.91), "steel")
	_add_box(_train_pivot, "CarriageUnderbeam_Aft", Vector3(3.32, 0.06, 0.08), Vector3(0.0, 0.235, 1.27), "steel")
	_add_box(_train_pivot, "CarriageUnderbeam_Port", Vector3(0.08, 0.06, 2.15), Vector3(-1.56, 0.235, 0.18), "steel")
	_add_box(_train_pivot, "CarriageUnderbeam_Starboard", Vector3(0.08, 0.06, 2.15), Vector3(1.56, 0.235, 0.18), "steel")
	_add_box(_train_pivot, "Footplate_Fore", Vector3(3.32, 0.04, 0.15), Vector3(0.0, 0.405, -0.94), "steel_edge")
	_add_box(_train_pivot, "Footplate_Aft", Vector3(3.32, 0.04, 0.15), Vector3(0.0, 0.405, 1.30), "steel_edge")

	for side: float in [-1.0, 1.0]:
		_add_box(_train_pivot, "TrainGearHousing_%s" % _side_name(side), Vector3(0.43, 0.32, 0.55), Vector3(side * 1.4, 0.55, 0.62), "paint")
		_add_handwheel(_train_pivot, "TrainHandwheel_%s" % _side_name(side), Vector3(side * 1.34, 0.73, 0.75), "steel_edge")
		_add_operator_seat(side)

	if shielded:
		_build_shield()

	_elevation_pivot = Node3D.new()
	_elevation_pivot.name = "ElevationPivot"
	_elevation_pivot.position = Vector3(0.0, 0.72, -0.02)
	_train_pivot.add_child(_elevation_pivot)

	_add_elevation_mechanism()
	for gun_index: int in range(GUNNER_STATIONS_X.size()):
		_add_gun(gun_index, GUNNER_STATIONS_X[gun_index])

	_add_aiming_sight()


func _build_shield() -> void:
	var shield_root := Node3D.new()
	shield_root.name = "ShieldFixedToCarriage"
	_train_pivot.add_child(shield_root)
	var segment_count: int = 15
	var radius: float = 1.37
	var panel_height: float = 0.79
	for index: int in range(segment_count):
		var angle: float = deg_to_rad(4.0 + float(index) * 172.0 / float(segment_count - 1))
		var position := Vector3(cos(angle) * radius, 0.84, sin(angle) * radius + 0.34)
		var tangent_width: float = 0.37
		var panel := _add_box(shield_root, "ShieldPanel_%02d" % index, Vector3(tangent_width, panel_height, SHIELD_THICKNESS_M), position, "shield")
		panel.rotation.y = -angle - PI * 0.5


func _add_elevation_mechanism() -> void:
	_add_box(_elevation_pivot, "CradleCrossbeam", Vector3(3.2, 0.18, 0.22), Vector3(0.0, -0.32, 0.15), "steel")
	_add_box(_elevation_pivot, "CradleLongBeam_Port", Vector3(0.18, 0.15, 1.42), Vector3(-0.77, -0.27, -0.43), "steel")
	_add_box(_elevation_pivot, "CradleLongBeam_Starboard", Vector3(0.18, 0.15, 1.42), Vector3(0.77, -0.27, -0.43), "steel")

	for side: float in [-1.0, 1.0]:
		var cheek := _add_box(_elevation_pivot, "ElevatingCheek_%s" % _side_name(side), Vector3(0.18, 0.79, 0.19), Vector3(side * 1.42, 0.05, 0.18), "paint")
		cheek.rotation.z = deg_to_rad(-12.0 * side)
		_add_cylinder_x(_elevation_pivot, "TrunnionPin_%s" % _side_name(side), 0.09, 0.48, Vector3(side * 1.45, 0.0, 0.16), "steel_edge")
		_add_cylinder_x(_elevation_pivot, "ElevationSector_%s" % _side_name(side), 0.28, 0.11, Vector3(side * 1.35, -0.19, 0.36), "steel")


func _add_gun(gun_index: int, gun_x: float) -> void:
	var side_name: String = "Port" if gun_x < 0.0 else "Starboard"
	var gun_root := Node3D.new()
	gun_root.name = "Gun_%02d_%s" % [gun_index + 1, side_name]
	gun_root.position = Vector3(gun_x, 0.0, 0.0)
	_elevation_pivot.add_child(gun_root)

	_add_box(gun_root, "BreechHousing", Vector3(0.48, 0.48, 0.66), Vector3(0.0, 0.0, 0.30), "steel")
	_add_box(gun_root, "BreechCover", Vector3(0.40, 0.13, 0.52), Vector3(0.0, 0.29, 0.31), "paint_light")
	_add_box(gun_root, "FeedTray", Vector3(0.32, 0.11, 0.34), Vector3(0.0, 0.36, -0.03), "steel")
	_add_box(gun_root, "TrayGuides", Vector3(0.035, 0.12, 0.38), Vector3(-0.13, 0.44, -0.03), "steel_edge")
	_add_box(gun_root, "TrayGuides_R", Vector3(0.035, 0.12, 0.38), Vector3(0.13, 0.44, -0.03), "steel_edge")

	# Navy service ammunition was supplied in four-round clips; this partial clip makes the top feed visible.
	var clip_root := Node3D.new()
	clip_root.name = "FourRoundClip"
	clip_root.position = Vector3(0.0, 0.44, -0.02)
	gun_root.add_child(clip_root)
	_add_box(clip_root, "ClipRail_L", Vector3(0.018, 0.28, 0.31), Vector3(-0.12, 0.13, 0.0), "steel_edge")
	_add_box(clip_root, "ClipRail_R", Vector3(0.018, 0.28, 0.31), Vector3(0.12, 0.13, 0.0), "steel_edge")
	for round_index: int in range(4):
		var round_y: float = 0.035 + float(round_index) * 0.065
		_add_cylinder_z(clip_root, "Cartridge_%d" % round_index, 0.018, 0.25, Vector3(0.0, round_y, -0.01), "brass")
		_add_cylinder_z(clip_root, "Projectile_%d" % round_index, 0.018, 0.07, Vector3(0.0, round_y, -0.17), "steel_edge")

	_add_box(gun_root, "ReceiverSideCover", Vector3(0.13, 0.27, 0.34), Vector3(0.25, -0.02, 0.34), "paint_light")
	_add_box(gun_root, "ChargingHandle", Vector3(0.04, 0.19, 0.1), Vector3(0.28, -0.05, 0.15), "steel_edge")
	_add_box(gun_root, "TriggerHousing", Vector3(0.12, 0.16, 0.2), Vector3(0.0, -0.29, 0.54), "steel")

	var barrel_length: float = 2.47
	var barrel_center: float = -1.23
	_add_cylinder_z(gun_root, "WaterJacket", 0.068, barrel_length - 0.28, Vector3(0.0, 0.0, barrel_center + 0.14), "paint_light", 0.064, 0.074)
	_add_cylinder_z(gun_root, "MuzzleNeck", 0.043, 0.48, Vector3(0.0, 0.0, -2.43), "steel")
	_add_cylinder_z(gun_root, "MuzzleCollar", 0.061, 0.08, Vector3(0.0, 0.0, -2.65), "steel_edge")
	_add_cylinder_z(gun_root, "BoreShadow", 0.021, 0.012, Vector3(0.0, 0.0, -2.694), "rubber")
	_add_cylinder_z(gun_root, "WaterJacketBand_Fore", 0.078, 0.045, Vector3(0.0, 0.0, -2.16), "steel_edge")
	_add_cylinder_z(gun_root, "WaterJacketBand_Aft", 0.078, 0.045, Vector3(0.0, 0.0, -0.16), "steel_edge")

	for buffer_side: float in [-1.0, 1.0]:
		_add_cylinder_z(gun_root, "RecoilBuffer_%s" % _side_name(buffer_side), 0.055, 1.18, Vector3(buffer_side * 0.19, 0.22, -0.54), "steel")
		_add_cylinder_z(gun_root, "RecoilRod_%s" % _side_name(buffer_side), 0.018, 0.78, Vector3(buffer_side * 0.19, 0.23, -0.68), "steel_edge")

	_add_box(gun_root, "WaterValve", Vector3(0.1, 0.1, 0.13), Vector3(-0.27, 0.08, -0.1), "steel_edge")
	_add_cylinder(gun_root, "WaterPipeStub", 0.018, 0.29, Vector3(-0.27, 0.14, -0.16), "steel_edge")

	var trunnion := _add_cylinder_x(gun_root, "GunTrunnion", 0.085, 0.62, Vector3.ZERO, "steel_edge")
	trunnion.rotation.z = deg_to_rad(90.0)


func _add_aiming_sight() -> void:
	var sight_root := Node3D.new()
	sight_root.name = "Mark4StyleQuadSightStudy"
	sight_root.position = Vector3(0.0, 0.34, 0.62)
	_elevation_pivot.add_child(sight_root)
	_add_box(sight_root, "SightHousing", Vector3(0.25, 0.25, 0.34), Vector3(0.0, 0.14, 0.0), "paint")
	_add_box(sight_root, "SightFoot", Vector3(0.32, 0.08, 0.24), Vector3(0.0, -0.04, 0.04), "steel")
	var lens := _add_cylinder_z(sight_root, "SightLens", 0.067, 0.025, Vector3(0.0, 0.16, -0.17), "glass")
	lens.rotation.x = deg_to_rad(90.0)
	_add_box(sight_root, "SightEyepiece", Vector3(0.11, 0.12, 0.18), Vector3(0.0, 0.15, 0.23), "steel")
	_add_handwheel(sight_root, "SightAdjustmentWheel", Vector3(0.21, 0.03, 0.12), "steel_edge")


func _add_operator_seat(side: float) -> void:
	var seat_root := Node3D.new()
	seat_root.name = "OperatorSeat_%s" % _side_name(side)
	seat_root.position = Vector3(side * 0.84, 0.0, 1.0)
	_train_pivot.add_child(seat_root)
	_add_cylinder(seat_root, "SeatPedestal", 0.055, 0.39, Vector3(0.0, 0.61, 0.0), "steel")
	_add_box(seat_root, "SeatPan", Vector3(0.42, 0.08, 0.38), Vector3(0.0, 0.83, 0.0), "paint")
	_add_box(seat_root, "SeatBack", Vector3(0.42, 0.48, 0.08), Vector3(0.0, 1.09, 0.17), "paint")
	_add_box(seat_root, "FootRest", Vector3(0.46, 0.05, 0.29), Vector3(-side * 0.08, 0.5, -0.35), "steel_edge")


func _add_handwheel(parent: Node3D, wheel_name: String, at: Vector3, material_key: String) -> void:
	var wheel := MeshInstance3D.new()
	wheel.name = wheel_name
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.185
	torus.rings = 24
	torus.ring_segments = 8
	wheel.mesh = torus
	wheel.position = at
	wheel.rotation.z = PI * 0.5
	wheel.material_override = _materials[material_key]
	parent.add_child(wheel)
	_add_cylinder_x(parent, wheel_name + "Hub", 0.05, 0.09, at, material_key)


func _add_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material_key: String) -> MeshInstance3D:
	return _add_cylinder_mesh(parent, node_name, radius, height, at, material_key, Vector3.ZERO, radius)


func _add_cylinder_x(parent: Node3D, node_name: String, radius: float, length: float, at: Vector3, material_key: String) -> MeshInstance3D:
	return _add_cylinder_mesh(parent, node_name, radius, length, at, material_key, Vector3(0.0, 0.0, PI * 0.5), radius)


func _add_cylinder_z(parent: Node3D, node_name: String, radius: float, length: float, at: Vector3, material_key: String, top_radius: float = -1.0, bottom_radius: float = -1.0) -> MeshInstance3D:
	var upper: float = radius if top_radius < 0.0 else top_radius
	var lower: float = radius if bottom_radius < 0.0 else bottom_radius
	return _add_cylinder_mesh(parent, node_name, upper, length, at, material_key, Vector3(PI * 0.5, 0.0, 0.0), lower)


func _add_cylinder_mesh(parent: Node3D, node_name: String, top_radius: float, height: float, at: Vector3, material_key: String, rotation_value: Vector3, bottom_radius: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	instance.mesh = mesh
	instance.position = at
	instance.rotation = rotation_value
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _add_torus(parent: Node3D, node_name: String, radius: float, tube_radius: float, at: Vector3, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube_radius
	mesh.outer_radius = radius + tube_radius
	mesh.rings = 48
	mesh.ring_segments = 10
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _side_name(side: float) -> String:
	return "Port" if side < 0.0 else "Starboard"
