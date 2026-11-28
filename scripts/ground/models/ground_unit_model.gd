class_name GroundUnitModel
extends Node3D
## Passive visual adapter. Geometry and model-space muzzles share one MountSocket.
@export var model_id: String = "us_5in51_mk13mod4_1945"
var spec: Dictionary = {}
var parts: Dictionary = {}
var mount_visuals: Dictionary = {}

func _ready() -> void:
	var all_specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ground/models.json"))
	spec = all_specs[model_id].duplicate(true)
	var builder: Script = load(spec.builder)
	parts = builder.build(self,spec)
	var id: String = str(spec.mount.id)
	mount_visuals[id] = {"station_id":id,"train_axis":parts.train,"elevation_axes":[parts.elevation],
		"recoil_axes":[parts.recoil],"recoil_stroke_m":spec.recoil_stroke_m,"muzzles":parts.get("muzzles",[parts.muzzle])}
	StaticModelBatch.apply(self,model_id)

func mount_sockets() -> Array[Dictionary]:
	return [spec.mount.duplicate(true)]

func apply_state(state: Dictionary) -> void:
	position = SimData.vec3(state.position_m) if state.position_m is Array else state.position_m
	rotation = SimData.vec3(state.rotation_rad) if state.rotation_rad is Array else state.rotation_rad
	var phase: String = str(state.get("module_data",{}).get("damage",{}).get("phase","operational"))
	visible = phase != "removed"
	for id: String in state.get("weapons",{}): apply_weapon_state(id,state.weapons[id])

func apply_weapon_state(id: String, state: Dictionary) -> bool:
	if not mount_visuals.has(id): return false
	var train: float = float(state.get("train_rad",0.0))
	var elevation: float = float(state.get("elevation_rad",0.0))
	if not is_finite(train) or not is_finite(elevation): return false
	(parts.train as Node3D).rotation.y = clampf(train,deg_to_rad(float(spec.train_limits_deg[0])),deg_to_rad(float(spec.train_limits_deg[1])))
	(parts.elevation as Node3D).rotation.x = clampf(elevation,deg_to_rad(float(spec.elevation_limits_deg[0])),deg_to_rad(float(spec.elevation_limits_deg[1])))
	return true

func muzzle_transform_local(id: String, barrel: int) -> Transform3D:
	if not mount_visuals.has(id): return Transform3D.IDENTITY
	var muzzles: Array = mount_visuals[id].muzzles
	if barrel < 0 or barrel >= muzzles.size(): return Transform3D.IDENTITY
	return global_transform.affine_inverse() * (muzzles[barrel] as Marker3D).global_transform

func muzzle_transform_global(id: String, barrel: int) -> Transform3D:
	return global_transform * muzzle_transform_local(id,barrel)
