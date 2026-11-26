class_name CapitalShipAdapter
extends Node3D

## Pure presentation. Only apply_state / apply_weapon_state change poses; no local AI or clock.
const YAMATO_BUILDER: Script = preload("res://scripts/ship_geometry.gd")
const IOWA_SCENE: PackedScene = preload("res://assets/naval/models/us_iowa_1944/scenes/iowa_bb61.tscn")

@export_enum("jp_yamato_1944_04", "us_iowa_bb61_1944_12_28") var model_id: String = "jp_yamato_1944_04"

var model_root: Node3D
var mount_visuals: Dictionary = {}
var _builder: Node3D
var _sockets: Array[Dictionary] = []
var _camo_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	if model_id == "us_iowa_bb61_1944_12_28":
		_build_iowa()
	else:
		_build_yamato()
	for record: Dictionary in mount_visuals.values():
		apply_weapon_state(record.station_id, {"train_rad":0.0, "elevation_rad":0.0})

func _build_yamato() -> void:
	_builder = YAMATO_BUILDER.new() as Node3D
	_builder.name = "YamatoModelBuilder"
	add_child(_builder)
	model_root = _builder.build_ship() as Node3D
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/yamato_1944_mounts.json"))
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_profiles.json"))
	for entry: Dictionary in _builder.weapons:
		var mount: WeaponMount = entry.pivot as WeaponMount
		mount.moving = false
		mount.set_process(false)
		var id: String = str(entry.station_id)
		var source: Dictionary = {}
		for candidate: Dictionary in layout.mounts:
			if str(candidate.id) == id:
				source = candidate
				break
		var profile: Dictionary = profiles[source.profile]
		var definition_id: String = {"main":"jp_type94_460mm_triple", "secondary":"jp_type3_155mm_triple", "heavy_aa":"jp_type89_127mm_twin", "light_aa":"jp_type96_25mm_triple", "single_aa":"jp_type96_25mm_single", "bridge_mg":"jp_type93_13mm_twin"}[source.profile]
		var role: String = str(source.profile) if source.profile in ["main", "secondary"] else "dedicated_aa"
		var socket: Dictionary = _socket_record(id, str(source.attachment.host), definition_id, role, model_root.to_local(mount.global_position), mount.base_heading, mount.elevation_axis.position, _muzzles(mount.elevation_axis), str(source.placement_status))
		_register_mount(socket, mount, [mount.elevation_axis], _marker_nodes(mount.elevation_axis), mount.train_limits, mount.elevation_limits)

func _build_iowa() -> void:
	model_root = IOWA_SCENE.instantiate() as Node3D
	model_root.viewer_motion_enabled = false
	add_child(model_root)
	for mount: IowaWeaponMount in model_root.get_weapon_mounts():
		mount.moving = false
		mount.automatic_demo = false
		var points: Array[Vector3] = []
		var nodes: Array[Marker3D] = []
		var shared_pivot: Vector3 = mount.elevation_axis.position
		# Main guns have independent pivots. MountSocket v1 expresses their common pose
		# using a central pivot; each marker retains its actual independent parent.
		if mount.elevation_axes.size() > 1:
			shared_pivot.x = 0.0
		for axis: Node3D in mount.elevation_axes:
			for marker: Marker3D in _marker_nodes(axis):
				nodes.append(marker)
				points.append(axis.position - shared_pivot + marker.position)
		var definition_id: String = {"main_16in":"us_16in50_mk7_triple", "secondary_5in":"us_5in38_mk28_twin", "bofors_40mm":"us_bofors_40mm_quad", "oerlikon_20mm":"us_oerlikon_20mm_single"}[mount.mount_type]
		var role: String = "main" if mount.mount_type == "main_16in" else ("secondary" if mount.mount_type == "secondary_5in" else "dedicated_aa")
		var socket: Dictionary = _socket_record(mount.mount_id, mount.support_surface, definition_id, role, model_root.to_local(mount.global_position), mount.base_heading, shared_pivot, points, str(mount.station_marker.get_meta("source_status")))
		_register_mount(socket, mount.train_axis, mount.elevation_axes, nodes, mount.train_limits, mount.elevation_limits)
	for value: Variant in model_root.palette.values():
		if value is ShaderMaterial and not _camo_materials.has(value):
			_camo_materials.append(value as ShaderMaterial)

func _socket_record(id: String, host: String, definition: String, role: String, position_value: Vector3, base_yaw: float, elevation_pivot: Vector3, muzzles: Array[Vector3], source: String) -> Dictionary:
	var muzzle_arrays: Array = []
	for point: Vector3 in muzzles:
		muzzle_arrays.append([point.x,point.y,point.z])
	return {"id":id, "host_id":host, "weapon_definition_id":definition, "role":role,
		"position_m":[position_value.x,position_value.y,position_value.z], "base_yaw_deg":rad_to_deg(base_yaw),
		"elevation_pivot_m":[elevation_pivot.x,elevation_pivot.y,elevation_pivot.z], "muzzle_positions_m":muzzle_arrays,
		"source":{"status":"provisional", "basis":"source_matched_image_proportions", "note":source}}

func _register_mount(socket: Dictionary, train: Node3D, axes: Array, muzzles: Array[Marker3D], train_limits: Vector2, elevation_limits: Vector2) -> void:
	_sockets.append(socket)
	mount_visuals[socket.id] = {"station_id":socket.id, "train_axis":train, "elevation_axes":axes,
		"muzzles":muzzles, "base_yaw_rad":deg_to_rad(float(socket.base_yaw_deg)),
		"train_limits_rad":train_limits * PI / 180.0, "elevation_limits_rad":elevation_limits * PI / 180.0}

func _marker_nodes(axis: Node3D) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for child: Node in axis.get_children():
		if child is Marker3D and str(child.name).begins_with("Muzzle_"):
			result.append(child as Marker3D)
	result.sort_custom(func(a: Marker3D,b: Marker3D) -> bool: return a.position.x < b.position.x)
	return result

func _muzzles(axis: Node3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for marker: Marker3D in _marker_nodes(axis):
		result.append(marker.position)
	return result

func mount_sockets() -> Array[Dictionary]:
	return _sockets.duplicate(true)

func apply_state(state: Dictionary) -> void:
	position = _vec3(state.get("position_m",Vector3.ZERO))
	rotation = _vec3(state.get("rotation_rad",Vector3.ZERO))
	visible = bool(state.get("active",true))
	for id: String in state.get("weapons",{}):
		apply_weapon_state(id,state.weapons[id])
	for material: ShaderMaterial in _camo_materials:
		material.set_shader_parameter("world_to_ship",model_root.global_transform.affine_inverse())

func apply_weapon_state(station_id: String, state: Dictionary) -> bool:
	if not mount_visuals.has(station_id):
		return false
	var train: float = float(state.get("train_rad",0.0))
	var elevation: float = float(state.get("elevation_rad",0.0))
	if not is_finite(train) or not is_finite(elevation):
		return false
	var record: Dictionary = mount_visuals[station_id]
	# The simulation owns rate limits and obstruction decisions. Display a validated pose.
	(record.train_axis as Node3D).rotation.y = float(record.base_yaw_rad) + clampf(train,record.train_limits_rad.x,record.train_limits_rad.y)
	var gun_angles: Array = state.get("gun_elevations_rad",[])
	for index: int in range(record.elevation_axes.size()):
		var gun_elevation: float = elevation if index >= gun_angles.size() else float(gun_angles[index])
		if not is_finite(gun_elevation):
			return false
		(record.elevation_axes[index] as Node3D).rotation.x = clampf(gun_elevation,record.elevation_limits_rad.x,record.elevation_limits_rad.y)
	return true

func muzzle_transform_local(station_id: String, barrel_index: int) -> Transform3D:
	if not mount_visuals.has(station_id):
		return Transform3D.IDENTITY
	var markers: Array = mount_visuals[station_id].muzzles
	if barrel_index < 0 or barrel_index >= markers.size():
		return Transform3D.IDENTITY
	return global_transform.affine_inverse() * (markers[barrel_index] as Marker3D).global_transform

func muzzle_transform_global(station_id: String, barrel_index: int) -> Transform3D:
	return global_transform * muzzle_transform_local(station_id,barrel_index)

func _vec3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]),float(value[1]),float(value[2]))
	return Vector3.ZERO
