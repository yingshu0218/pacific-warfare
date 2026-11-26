extends Node3D

const SINGLE_GUN: PackedScene = preload("res://scenes/weapons/type96_25mm_single.tscn")


func _ready() -> void:
	name = "Type96Twin25mm_Weapon"
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/naval_weapon_profiles.json"))
	var profile: Dictionary = profiles.get("type96_25mm_single_gun", {})
	var center_spacing: float = float(profile.get("twin_center_spacing_estimate_m", 0.38))
	for index: int in range(2):
		var gun: Node3D = SINGLE_GUN.instantiate() as Node3D
		gun.name = "GunLeft" if index == 0 else "GunRight"
		gun.position.x = (-0.5 if index == 0 else 0.5) * center_spacing
		add_child(gun)
