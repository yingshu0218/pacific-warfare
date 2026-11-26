class_name MountSocket
extends RefCounted

var id: String
var host_id: String
var weapon_definition_id: String
var role: String
var position_m: Vector3
var base_yaw_rad: float
var elevation_pivot_m: Vector3
## Muzzles relative to elevation pivot at zero train/elevation, pointing -Z.
var muzzle_positions_m: Array[Vector3] = []
var source: Dictionary

static func from_data(data: Dictionary) -> MountSocket:
	var result: MountSocket = MountSocket.new()
	result.id = data.id
	result.host_id = data.host_id
	result.weapon_definition_id = data.weapon_definition_id
	result.role = data.role
	result.position_m = SimData.vec3(data.position_m)
	result.base_yaw_rad = deg_to_rad(float(data.base_yaw_deg))
	result.elevation_pivot_m = SimData.vec3(data.elevation_pivot_m)
	for value: Array in data.muzzle_positions_m:
		result.muzzle_positions_m.append(SimData.vec3(value))
	result.source = data.source.duplicate(true)
	return result

func local_muzzle_transform(barrel_index: int, train_rad: float, elevation_rad: float) -> Transform3D:
	var train: Transform3D = Transform3D(Basis(Vector3.UP, base_yaw_rad + train_rad), position_m)
	var elevation: Transform3D = Transform3D(Basis(Vector3.RIGHT, elevation_rad), elevation_pivot_m)
	return train * elevation * Transform3D(Basis.IDENTITY, muzzle_positions_m[barrel_index])
