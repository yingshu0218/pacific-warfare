extends Node3D

## Model-specific geometry and actual muzzle transforms remain in CV01/CV02.
## Only normalize the already public recoil interface; never aim autonomously.
@export var model_scene: String = "res://naval/essex_cv9_1944_04_15/essex.tscn"
var visual: Node3D
var mount_visuals: Dictionary = {}

func _ready() -> void:
	visual = (load(model_scene) as PackedScene).instantiate() as Node3D
	add_child(visual)
	for id: String in visual.mount_visuals:
		var row: Dictionary = visual.mount_visuals[id]
		mount_visuals[id] = {"recoil_axes":row.axes,"recoil_stroke_m":.28 if str(id).begins_with("dp_") else .05}

func apply_state(state: Dictionary) -> void:
	var at: Variant = state.get("position_m",Vector3.ZERO)
	var angles: Variant = state.get("rotation_rad",Vector3.ZERO)
	position = at if at is Vector3 else SimData.vec3(at)
	rotation = angles if angles is Vector3 else SimData.vec3(angles)
	visual.apply_state({"weapons":state.get("weapons",{}),"active":state.get("active",true),"equipment":state.get("equipment",{})})

func mount_sockets() -> Array[Dictionary]: return visual.mount_sockets()
func muzzle_transform_local(id: String, barrel: int) -> Transform3D:
	return global_transform.affine_inverse()*visual.muzzle_transform_global(id,barrel)
func muzzle_transform_global(id: String, barrel: int) -> Transform3D:
	return visual.muzzle_transform_global(id,barrel)
