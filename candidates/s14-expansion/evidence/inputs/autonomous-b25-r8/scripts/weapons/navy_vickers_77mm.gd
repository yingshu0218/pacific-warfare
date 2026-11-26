extends "res://scripts/ship_geometry.gd"

var gunmetal: StandardMaterial3D = material(Color("596169"))
var casing: StandardMaterial3D = material(Color("414b51"))
var brass: StandardMaterial3D = material(Color("917d4d"))


func _ready() -> void:
	name = "NavyVickers77mm_Weapon"
	# Root is at the barrel-to-mechanism joint; the gun points along local -Z.
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/naval_weapon_profiles.json")).navy_vickers_77mm
	var mechanism_length: float = float(profile.mechanism_length_m)
	var barrel_length: float = float(profile.barrel_assembly_length_m)
	var jacket_length: float = float(profile.water_jacket_length_m)
	var exposed_length: float = barrel_length - jacket_length
	var bore_radius: float = float(profile.nominal_caliber_m)*0.5
	var muzzle_z: float = -barrel_length
	var jacket_end_z: float = -jacket_length
	var jacket_center_z: float = jacket_end_z*0.5
	var receiver: Vector3 = Vector3(0.0, 0.0, mechanism_length*0.5)
	box(receiver, Vector3(0.19, 0.18, mechanism_length), gunmetal)
	box(receiver + Vector3(0.0, 0.02, 0.18), Vector3(0.14, 0.16, 0.12), casing)
	# The 28.4 in barrel assembly comprises a water jacket and a short exposed muzzle section.
	var water_jacket: MeshInstance3D = cylinder(Vector3(0.0, 0.0, jacket_center_z), float(profile.water_jacket_outer_diameter_m)*0.5, jacket_length, gunmetal)
	water_jacket.rotation.x = PI / 2.0
	var exposed_barrel: MeshInstance3D = cylinder(Vector3(0.0, 0.0, muzzle_z+exposed_length*0.5), 0.010, exposed_length, casing)
	exposed_barrel.rotation.x = PI / 2.0
	var muzzle_bore: MeshInstance3D = cylinder(Vector3(0.0, 0.0, muzzle_z-0.006), bore_radius, 0.012, dark)
	muzzle_bore.rotation.x = PI / 2.0
	# Filler cap and compact belt box distinguish the water-cooled belt-fed Vickers.
	cylinder(Vector3(0.0, 0.04, jacket_center_z), 0.018, 0.035, casing)
	box(receiver + Vector3(-0.16, -0.015, -0.02), Vector3(0.16, 0.17, 0.22), casing)
	box(receiver + Vector3(-0.13, -0.01, -0.12), Vector3(0.065, 0.065, 0.14), brass)
	# Two rear spade grips, rather than a rifle stock.
	for grip_side: int in [-1, 1]:
		rod(receiver + Vector3(float(grip_side) * 0.065, -0.02, 0.12), receiver + Vector3(float(grip_side) * 0.065, -0.02, 0.25), 0.025, gunmetal)
		box(receiver + Vector3(float(grip_side) * 0.065, -0.03, 0.29), Vector3(0.07, 0.13, 0.09), casing)
	rod(receiver + Vector3(0.0, -0.08, 0.02), receiver + Vector3(0.0, -0.22, 0.0), 0.03, gunmetal)
	rod(Vector3(-0.1, 0.0, 0.02), Vector3(-0.1, 0.0, -0.1), 0.018, brass)
