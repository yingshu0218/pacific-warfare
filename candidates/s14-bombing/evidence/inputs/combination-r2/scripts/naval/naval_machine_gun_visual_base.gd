@tool
extends Node3D
class_name NavalMachineGunVisualBase

var _materials: Dictionary = {}


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var previous: Node = get_node_or_null("Generated")
	if previous != null:
		remove_child(previous)
		previous.free()

	_materials = _create_materials()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	generated.owner = owner

	_add_mount_interface(generated)
	var weapon := Node3D.new()
	weapon.name = "WeaponBody"
	generated.add_child(weapon)
	_build_weapon(weapon)


func _build_weapon(_weapon: Node3D) -> void:
	pass


func _add_mount_interface(parent: Node3D) -> void:
	var interface := Node3D.new()
	interface.name = "MountInterface"
	parent.add_child(interface)
	var axis := Marker3D.new()
	axis.name = "ElevationAxis"
	interface.add_child(axis)
	for side: float in [-1.0, 1.0]:
		var trunnion := Marker3D.new()
		trunnion.name = "%sTrunnionCenter" % _side_name(side)
		trunnion.position = Vector3(side * 0.105, 0.0, 0.0)
		interface.add_child(trunnion)
	var muzzle_axis := Marker3D.new()
	muzzle_axis.name = "BoreAxisReference"
	muzzle_axis.position = Vector3(0.0, 0.0, -0.8)
	interface.add_child(muzzle_axis)


func _create_materials() -> Dictionary:
	return {
		"receiver": _material(Color(0.38, 0.40, 0.42), 0.25, 0.62),
		"receiver_light": _material(Color(0.49, 0.51, 0.52), 0.32, 0.54),
		"steel": _material(Color(0.25, 0.27, 0.29), 0.42, 0.48),
		"steel_edge": _material(Color(0.63, 0.65, 0.66), 0.48, 0.38),
		"jacket": _material(Color(0.45, 0.47, 0.48), 0.28, 0.56),
		"dark": _material(Color(0.035, 0.042, 0.045), 0.1, 0.48),
		"rubber": _material(Color(0.055, 0.06, 0.058), 0.0, 0.88),
		"wood": _material(Color(0.37, 0.25, 0.15), 0.04, 0.78),
		"brass": _material(Color(0.48, 0.34, 0.13), 0.65, 0.43),
	}


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


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


func _add_cylinder_y(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _add_cylinder_z(parent: Node3D, node_name: String, radius: float, length: float, at: Vector3, material_key: String, end_radius: float = -1.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if end_radius < 0.0 else end_radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 24
	instance.mesh = mesh
	instance.position = at
	instance.rotation.x = PI * 0.5
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _add_cylinder_x(parent: Node3D, node_name: String, radius: float, length: float, at: Vector3, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 20
	instance.mesh = mesh
	instance.position = at
	instance.rotation.z = PI * 0.5
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _add_ring_z(parent: Node3D, node_name: String, radius: float, tube_radius: float, at: Vector3, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube_radius
	mesh.outer_radius = radius + tube_radius
	mesh.rings = 32
	mesh.ring_segments = 8
	instance.mesh = mesh
	instance.position = at
	instance.rotation.x = PI * 0.5
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, radius: float, at: Vector3, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _side_name(side: float) -> String:
	return "Port" if side < 0.0 else "Starboard"
