extends "res://scripts/ship_geometry.gd"

const TYPE96_MOUNT: PackedScene = preload("res://scenes/mounts/type96_ship_twin_mount.tscn")
const TYPE96_WEAPON: PackedScene = preload("res://scenes/weapons/type96_twin_25mm.tscn")
const VICKERS_MOUNT: PackedScene = preload("res://scenes/mounts/japanese_92_model_f_tripod.tscn")
const VICKERS_WEAPON: PackedScene = preload("res://scenes/weapons/navy_vickers_77mm.tscn")

var ship_deck: StandardMaterial3D = material(Color("525b61"))
var deck_seam: StandardMaterial3D = material(Color("39434a"))


func _ready() -> void:
	name = "NavalWeaponStudy_NotYamatoFit"
	build_deck_sample()
	assemble(TYPE96_MOUNT, TYPE96_WEAPON, Vector3(-2.2, 0.0, 0.0))
	assemble(VICKERS_MOUNT, VICKERS_WEAPON, Vector3(2.2, 0.0, 0.0))


func build_deck_sample() -> void:
	# Plain steel deck fragment for scale and contact checks, not a ship location.
	box(Vector3(0.0, -0.18, 0.0), Vector3(8.5, 0.36, 5.8), ship_deck)
	for x: float in [-3.1875, -1.0625, 1.0625, 3.1875]:
		box(Vector3(x, 0.006, 0.0), Vector3(0.025, 0.012, 5.7), deck_seam)
	for z: float in [-1.933, 1.933]:
		box(Vector3(0.0, 0.006, z), Vector3(8.4, 0.012, 0.025), deck_seam)


func assemble(mount_scene: PackedScene, weapon_scene: PackedScene, position: Vector3) -> void:
	var mount: Node3D = mount_scene.instantiate() as Node3D
	mount.position = position
	add_child(mount)
	var weapon: Node3D = weapon_scene.instantiate() as Node3D
	weapon.position = Vector3.ZERO
	mount.get_node("WeaponSocket").add_child(weapon)


