class_name IowaSimulation
extends Node

var ship_visual_root: Node3D
var weapon_mounts: Array[IowaWeaponMount] = []
var elapsed_seconds: float = 0.0
var paused: bool = false

func configure(visual_root: Node3D, mounts: Array[IowaWeaponMount]) -> void:
	ship_visual_root = visual_root
	weapon_mounts = mounts

func _physics_process(delta: float) -> void:
	if paused:
		return
	elapsed_seconds += delta
	if is_instance_valid(ship_visual_root):
		ship_visual_root.position.y = sin(elapsed_seconds * 0.47) * 0.14 + sin(elapsed_seconds * 0.21) * 0.08
		ship_visual_root.rotation.x = sin(elapsed_seconds * 0.17) * 0.0035
		ship_visual_root.rotation.z = sin(elapsed_seconds * 0.29) * 0.0045
	for mount: IowaWeaponMount in weapon_mounts:
		if is_instance_valid(mount):
			mount.advance(delta, elapsed_seconds)

func set_paused(value: bool) -> void:
	paused = value

func toggle_paused() -> void:
	paused = not paused

