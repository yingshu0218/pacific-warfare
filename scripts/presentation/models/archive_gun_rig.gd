extends Node3D
## Visual-only Godot articulation for archive models. Angles and reach are
## invented gallery controls, not a reconstruction of a real mounting.
const PROFILES := {
	"main": {"reach": 9.0, "train": 65.0, "lower": -4.0, "upper": 29.0},
	"secondary": {"reach": 6.0, "train": 53.0, "lower": -6.0, "upper": 48.0},
	"dedicated_aa": {"reach": 4.0, "train": 49.0, "lower": 0.0, "upper": 67.0},
}
const GROUP := &"archive_articulated_gun"

var mount_id: String
var role: String
var game_reach: float
var yaw_limit_rad: float
var pitch_min_rad: float
var pitch_max_rad: float
var train: Node3D
var pitch: Node3D
var neutral_yaw_rad: float
var neutral_train_to_pitch: Vector3

static func attach(ship: Node3D, id: String, requested_role: String, train_at: Vector3,
		elevation_at: Vector3, forward: Vector3, train_parts: Array, elevation_parts: Array) -> Node3D:
	if elevation_parts.is_empty():
		return null
	var frame := ship.get_node_or_null("ArchiveGunPivots") as Node3D
	if frame == null:
		frame = Node3D.new()
		frame.name = "ArchiveGunPivots"
		ship.add_child(frame)
	if frame.has_node(NodePath(id)):
		push_error("Duplicate archive gun id " + id + " on " + ship.name)
		return null
	var rig: Node3D = load("res://scripts/presentation/models/archive_gun_rig.gd").new()
	rig.name = id
	rig.mount_id = id
	rig.role = requested_role if PROFILES.has(requested_role) else "secondary"
	frame.add_child(rig)
	rig._setup(train_at, elevation_at, forward)
	for body in train_parts:
		if body is Node3D and is_instance_valid(body) and body not in elevation_parts:
			body.reparent(rig.train, true)
	for barrel in elevation_parts:
		if barrel is Node3D and is_instance_valid(barrel):
			barrel.reparent(rig.pitch, true)
	rig.add_to_group(GROUP)
	return rig

func _setup(center: Vector3, elev_at: Vector3, forward: Vector3) -> void:
	var preset: Dictionary = PROFILES[role]
	game_reach = preset.reach
	yaw_limit_rad = deg_to_rad(preset.train)
	pitch_min_rad = deg_to_rad(preset.lower)
	pitch_max_rad = deg_to_rad(preset.upper)
	position = center
	neutral_yaw_rad = atan2(-forward.x, -forward.z) if Vector2(forward.x, forward.z).length_squared() > 0.01 else 0.0
	train = Node3D.new()
	train.name = "Traverse"
	add_child(train)
	train.rotation.y = neutral_yaw_rad
	neutral_train_to_pitch = train.basis.inverse() * (elev_at-center)
	pitch = Node3D.new()
	pitch.name = "Elevation"
	train.add_child(pitch)
	pitch.position = neutral_train_to_pitch

func set_game_profile(reach: float, max_train_deg: float, min_pitch_deg: float, max_pitch_deg: float) -> bool:
	if not is_finite(reach) or not is_finite(max_train_deg) or not is_finite(min_pitch_deg) or not is_finite(max_pitch_deg):
		return false
	if reach <= 0.0 or max_train_deg < 0.0 or max_train_deg > 180.0 or min_pitch_deg > max_pitch_deg or min_pitch_deg < -89.0 or max_pitch_deg > 89.0:
		return false
	game_reach = reach
	yaw_limit_rad = deg_to_rad(max_train_deg)
	pitch_min_rad = deg_to_rad(min_pitch_deg)
	pitch_max_rad = deg_to_rad(max_pitch_deg)
	return true

func pose(train_rad: float, pitch_rad: float) -> bool:
	if not is_finite(train_rad) or not is_finite(pitch_rad):
		return false
	train.rotation.y = neutral_yaw_rad + clampf(train_rad, -yaw_limit_rad, yaw_limit_rad)
	pitch.rotation.x = clampf(pitch_rad, pitch_min_rad, pitch_max_rad)
	return true
