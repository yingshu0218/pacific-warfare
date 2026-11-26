class_name AircraftAdapter
extends Node3D

## Snapshot consumer only. Flight and debris integration belong to the simulation.
const ZERO: Script = preload("res://aircraft/models/a6m5_52ko.gd")
const HELLCAT: Script = preload("res://aircraft/models/f6f5.gd")
const GLOBAL_FRAGMENT_CAP: int = 48
static var live_fragment_nodes: int = 0
@export_enum("jp_a6m5a_1944", "us_f6f5_1944") var model_id: String = "jp_a6m5a_1944"
var model_root: PacificAircraftBuilder
var mount_visuals: Dictionary = {}
var _sockets: Array[Dictionary] = []
var _fragments: Dictionary = {}
var _disabled_mounts: Array = []
var _suppressed_fragments: Array[String] = []

func _ready() -> void:
	model_root = (HELLCAT if model_id == "us_f6f5_1944" else ZERO).new() as PacificAircraftBuilder
	model_root.flight_simplified = true
	model_root.position.y = -2.30 if model_id == "us_f6f5_1944" else -1.60
	add_child(model_root)
	_apply_carrier_configuration({})
	StaticModelBatch.apply(model_root, model_id)
	for child: Node in model_root.find_children("*", "Marker3D", true, false):
		if child.has_meta("mount_id"):
			var id: String = child.get_meta("mount_id")
			mount_visuals[id] = child
			_sockets.append({"id": id, "host_id": child.get_meta("host_id"), "position_m": (global_transform.affine_inverse() * (child as Marker3D).global_transform).origin, "barrel_count": 1})

func mount_sockets() -> Array[Dictionary]:
	return _sockets.duplicate(true)

func installation_sockets() -> Array[Dictionary]:
	return _sockets.duplicate(true)

func apply_state(state: Dictionary) -> void:
	position = _vec3(state.get("position_m", Vector3.ZERO))
	rotation = _vec3(state.get("rotation_rad", Vector3.ZERO))
	var data: Dictionary = state.get("module_data", {})
	var damage: Dictionary = data.get("damage", {})
	visible = bool(state.get("active", true)) or str(damage.get("phase", "operational")) in ["crashing", "wreck"]
	_disabled_mounts = damage.get("disabled_mounts", [])
	var flight: Dictionary = data.get("aircraft_motion", {})
	model_root.propeller.rotation.z = float(flight.get("propeller_phase_rad", 0.0))
	_apply_carrier_configuration(data.get("carrier_ops",{}))
	for surface: Node3D in model_root.animated_surfaces:
		var label: String = str(surface.name).to_lower()
		if "aileron" in label:
			surface.rotation.z = float(flight.get("aileron_rad", 0.0)) * (-1.0 if "port" in label else 1.0)
		elif "elevator" in label:
			surface.rotation.x = float(flight.get("elevator_rad", 0.0))
	_apply_fragments(damage.get("aircraft", {}))

func _apply_carrier_configuration(operations: Dictionary) -> void:
	if model_id == "us_f6f5_1944" and model_root.has_method("apply_carrier_usage_state"):
		model_root.call("apply_carrier_usage_state",operations)
	else:
		model_root.landing_gear.visible = false

func carrier_usage_local(support_normal_local: Vector3 = Vector3.UP) -> Dictionary:
	if not model_root.has_method("carrier_usage_model"): return {}
	var usage: Dictionary = model_root.call("carrier_usage_model",model_root.basis.inverse()*support_normal_local)
	if usage.is_empty(): return {}
	for contact: Dictionary in usage.wheel_contacts.values():
		contact.position_m = model_root.transform*(contact.position_m as Vector3)
		contact.centre_m = model_root.transform*(contact.centre_m as Vector3)
	usage.hook_tip_m = model_root.transform*(usage.hook_tip_m as Vector3)
	usage.hook_pivot_m = model_root.transform*(usage.hook_pivot_m as Vector3)
	usage["coordinate_space"] = "aircraft_local"
	return usage

func _apply_fragments(aircraft: Dictionary) -> void:
	var detached: Array = aircraft.get("detached_parts", [])
	if detached.is_empty(): _suppressed_fragments.clear()
	for part_id: String in model_root.damage_parts:
		(model_root.damage_parts[part_id] as Node3D).visible = part_id not in detached
	var live: Array[String] = []
	for piece: Dictionary in aircraft.get("fragments", []):
		var part_id: String = str(piece.part_id)
		if live.size() >= AircraftDamageMotion.FRAGMENT_LIMIT or not model_root.damage_parts.has(part_id): continue
		live.append(part_id)
		if not _fragments.has(part_id):
			if part_id in _suppressed_fragments: continue
			if live_fragment_nodes >= GLOBAL_FRAGMENT_CAP:
				_suppressed_fragments.append(part_id)
				continue
			var fragment: Node3D = (model_root.damage_parts[part_id] as Node3D).duplicate(0) as Node3D
			fragment.name = "Debris_" + part_id
			add_child(fragment)
			fragment.top_level = true
			fragment.visible = true
			_fragments[part_id] = fragment
			live_fragment_nodes += 1
		(_fragments[part_id] as Node3D).global_transform = Transform3D(Basis.from_euler(_vec3(piece.rotation_rad)), _vec3(piece.position_m))
	for part_id: String in _fragments.keys():
		if part_id not in live:
			(_fragments[part_id] as Node3D).free()
			_fragments.erase(part_id)
			live_fragment_nodes = maxi(0,live_fragment_nodes-1)

func damage_statistics() -> Dictionary:
	return {"fragment_nodes": _fragments.size(), "fragment_cap": AircraftDamageMotion.FRAGMENT_LIMIT,
		"global_fragment_nodes":live_fragment_nodes, "global_fragment_cap":GLOBAL_FRAGMENT_CAP, "suppressed_fragments":_suppressed_fragments.size(),
		"detachable_groups": model_root.damage_parts.size(), "mesh_nodes": find_children("*", "MeshInstance3D", true, false).size()}

func _exit_tree() -> void:
	live_fragment_nodes = maxi(0,live_fragment_nodes-_fragments.size())
	_fragments.clear() # SceneTree owns/frees child nodes; no retained node references.

func apply_weapon_state(station_id: String, _state: Dictionary) -> bool:
	return mount_visuals.has(station_id) and station_id not in _disabled_mounts

func muzzle_transform_local(station_id: String, barrel_index: int) -> Transform3D:
	if not mount_visuals.has(station_id) or station_id in _disabled_mounts or barrel_index != 0:
		return Transform3D.IDENTITY
	return global_transform.affine_inverse() * (mount_visuals[station_id] as Marker3D).global_transform

func muzzle_transform_global(station_id: String, barrel_index: int) -> Transform3D:
	return global_transform * muzzle_transform_local(station_id, barrel_index)

func _vec3(value: Variant) -> Vector3:
	return value if value is Vector3 else SimData.vec3(value)
