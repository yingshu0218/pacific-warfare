extends Node3D
## Pure unit visual. No process callback, clock, targeting, ammunition or firing logic.
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
@export_file("*.json") var assembly_path: String
var configuration: Dictionary
var unit_record: Dictionary
var mount_visuals: Dictionary = {}
var _sockets: Array[Dictionary] = []
var _materials: Array[ShaderMaterial] = []
var equipment: Node3D

func _ready() -> void:
	configuration = JSON.parse_string(FileAccess.get_file_as_string(assembly_path))
	unit_record = JSON.parse_string(FileAccess.get_file_as_string(configuration.unit_definition))
	for entry: Dictionary in configuration.module_scenes:
		var packed: PackedScene = load(entry.scene) as PackedScene
		var instance: Node3D = packed.instantiate() as Node3D
		instance.name = entry.id
		add_child(instance)
		equipment = instance if entry.id == "Equipment" else equipment
	var foundations: Node3D = Node3D.new()
	foundations.name = "MountFoundations"
	add_child(foundations)
	for socket: Dictionary in unit_record.mounts:
		var placement: Dictionary = configuration.installations[socket.id]
		var host: Node3D = _find_host(self, socket.host_id)
		assert(host != null, "Missing real host " + str(socket.host_id))
		var surface: Marker3D = host.get_node(placement.surface_id) as Marker3D
		var attachment: Marker3D = Marker3D.new()
		attachment.name = "Socket_" + str(socket.id)
		surface.add_child(attachment)
		attachment.position = G.vector(placement.surface_offset_m)
		attachment.set_meta("station_id", socket.id)
		attachment.set_meta("interface_id", placement.interface_id)
		var foundation: Node3D = Node3D.new()
		foundation.name = "Foundation_" + str(socket.id)
		foundation.set_meta("host_id", socket.host_id)
		foundation.set_meta("attachment_path", attachment.get_path())
		foundations.add_child(foundation)
		foundation.transform = global_transform.affine_inverse() * attachment.global_transform
		var height: float = float(placement.foundation_height_m)
		var radius: float = float(placement.foundation_radius_m)
		var p: Dictionary = G.palette(configuration.country_id == "us")
		G.cylinder(foundation, "FixedFoundation", radius, height, Vector3(0,height * 0.5,0), p.gray)
		var seat: Marker3D = Marker3D.new()
		seat.name = "WeaponSeat"
		seat.position.y = height
		foundation.add_child(seat)
		var weapon_scene: PackedScene = load(placement.weapon_scene) as PackedScene
		var weapon: Node3D = weapon_scene.instantiate() as Node3D
		weapon.name = "WeaponInstance"
		seat.add_child(weapon)
		var definition: Dictionary = _weapon_definition(socket.weapon_definition_id)
		mount_visuals[socket.id] = {"weapon":weapon, "foundation":foundation, "host":host,
			"attachment":attachment, "seat":seat, "socket":socket.duplicate(true),
			"base_yaw_rad":deg_to_rad(float(socket.base_yaw_deg)),
			"train_limits_rad":Vector2(definition.train_limits_deg[0],definition.train_limits_deg[1]) * PI / 180.0,
			"elevation_limits_rad":Vector2(definition.elevation_limits_deg[0],definition.elevation_limits_deg[1]) * PI / 180.0}
		_sockets.append(socket.duplicate(true))
		apply_weapon_state(socket.id,{"train_rad":0.0,"elevation_rad":0.0})
	_collect_materials(self)
	_update_material_coordinates()

func _find_host(node: Node, host_id: String) -> Node3D:
	if node is Node3D and str(node.get_meta("host_id", "")) == host_id:
		return node as Node3D
	for child: Node in node.get_children():
		var result: Node3D = _find_host(child,host_id)
		if result != null:
			return result
	return null

func _weapon_definition(id: String) -> Dictionary:
	for record: Dictionary in unit_record.weapon_definitions:
		if record.id == id:
			return record
	return {}

func mount_sockets() -> Array[Dictionary]:
	return _sockets.duplicate(true)

func apply_state(state: Dictionary) -> void:
	var new_position: Vector3 = G.vector(state.get("position_m", position))
	var new_rotation: Vector3 = G.vector(state.get("rotation_rad", rotation))
	if not new_position.is_finite() or not new_rotation.is_finite():
		return
	position = new_position
	rotation = new_rotation
	visible = bool(state.get("active",true))
	for station_id: String in state.get("weapons",{}):
		apply_weapon_state(station_id,state.weapons[station_id])
	_update_material_coordinates()

func apply_weapon_state(station_id: String, state: Dictionary) -> bool:
	if not mount_visuals.has(station_id):
		return false
	var train: float = float(state.get("train_rad",0.0))
	var elevation: float = float(state.get("elevation_rad",0.0))
	var individual: Array = state.get("gun_elevations_rad",[])
	if not is_finite(train) or not is_finite(elevation):
		return false
	for value: Variant in individual:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	var r: Dictionary = mount_visuals[station_id]
	var weapon: Node3D = r.weapon
	weapon.train_axis.rotation.y = r.base_yaw_rad + clampf(train,r.train_limits_rad.x,r.train_limits_rad.y)
	for index: int in range(weapon.elevation_axes.size()):
		var angle: float = elevation if index >= individual.size() else float(individual[index])
		(weapon.elevation_axes[index] as Node3D).rotation.x = clampf(angle,r.elevation_limits_rad.x,r.elevation_limits_rad.y)
	return true

func apply_equipment_state(equipment_id: String, state: Dictionary) -> bool:
	# Optional visual-only torpedo training; there is deliberately no launch method.
	if equipment == null or not equipment.torpedo_axes.has(equipment_id):
		return false
	var train: float = float(state.get("train_rad",0.0))
	if not is_finite(train):
		return false
	(equipment.torpedo_axes[equipment_id] as Node3D).rotation.y = clampf(train,-PI,PI)
	return true

func muzzle_transform_local(station_id: String, barrel_index: int) -> Transform3D:
	if not mount_visuals.has(station_id):
		return Transform3D.IDENTITY
	var weapon: Node3D = mount_visuals[station_id].weapon
	if barrel_index < 0 or barrel_index >= weapon.muzzle_markers.size():
		return Transform3D.IDENTITY
	return global_transform.affine_inverse() * (weapon.muzzle_markers[barrel_index] as Marker3D).global_transform

func muzzle_transform_global(station_id: String, barrel_index: int) -> Transform3D:
	return global_transform * muzzle_transform_local(station_id,barrel_index)

func _collect_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = (node as MeshInstance3D).material_override
		if mat is ShaderMaterial and not _materials.has(mat):
			_materials.append(mat as ShaderMaterial)
	for child: Node in node.get_children():
		_collect_materials(child)

func _update_material_coordinates() -> void:
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter("ship_inverse",global_transform.affine_inverse())
