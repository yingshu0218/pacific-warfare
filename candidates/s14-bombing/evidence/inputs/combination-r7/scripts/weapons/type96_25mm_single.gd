extends "res://scripts/ship_geometry.gd"

var gunmetal: StandardMaterial3D = material(Color("596169"))
var casing: StandardMaterial3D = material(Color("414b51"))


func _ready() -> void:
	name = "Type96_25mm_SingleGun"
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/naval_weapon_profiles.json"))
	var profile: Dictionary = profiles.get("type96_25mm_single_gun", {})
	var barrel_length: float = float(profile.get("barrel_length_m", 1.501775))
	var caliber: float = float(profile.get("nominal_caliber_m", 0.025))
	var fin_count: int = int(profile.get("cooling_fin_count", 36))
	var finned_length: float = float(profile.get("cooling_finned_section_length_m", 0.7366))
	var fin_thickness: float = float(profile.get("cooling_fin_thickness_m", 0.009525))
	var fin_outer_breech_radius: float = float(profile.get("cooling_fin_outer_diameter_breech_m", 0.092075)) * 0.5
	var fin_outer_muzzle_radius: float = float(profile.get("cooling_fin_outer_diameter_muzzle_m", 0.079375)) * 0.5
	var fin_inner_breech_radius: float = float(profile.get("cooling_fin_inner_diameter_breech_m", 0.073025)) * 0.5
	var fin_inner_muzzle_radius: float = float(profile.get("cooling_fin_inner_diameter_muzzle_m", 0.060325)) * 0.5
	var muzzle_wall_thickness: float = float(profile.get("barrel_wall_thickness_muzzle_m", 0.0098552))
	var recoil_length: float = float(profile.get("recoil_cylinder_length_m", 0.4302252))
	var recoil_radius: float = float(profile.get("recoil_cylinder_outer_diameter_m", 0.066675)) * 0.5
	var recoil_count: int = maxi(1, int(profile.get("recoil_cylinder_count_for_twin", 4)) / 2)
	# Origin lies on the gun's trunnion axis so this scene can be attached to a mount socket.
	box(Vector3(0.0, 0.0, 0.24), Vector3(0.18, 0.22, 0.46), casing)
	box(Vector3(0.0, 0.22, 0.15), Vector3(0.13, 0.3, 0.17), gunmetal)
	box(Vector3(0.0, -0.13, 0.28), Vector3(0.2, 0.06, 0.24), gunmetal)
	# Twin mounts have four reported hydro-spring recoil cylinders: two fixed alongside each gun.
	for recoil_index: int in range(recoil_count):
		var recoil_side: float = -0.07 if recoil_index == 0 else 0.07
		var recoil_center_z: float = -0.16
		var recoil: MeshInstance3D = cylinder(Vector3(recoil_side, -0.16, recoil_center_z), recoil_radius, recoil_length, casing)
		recoil.rotation.x = PI / 2.0
		for end_sign: int in [-1, 1]:
			var end_z: float = recoil_center_z + float(end_sign) * recoil_length * 0.5
			rod(Vector3(recoil_side, -0.16, end_z - 0.012), Vector3(recoil_side, -0.16, end_z + 0.012), recoil_radius * 1.08, gunmetal)
	var barrel_start_z: float = 0.05
	var muzzle_z: float = barrel_start_z - barrel_length
	var finned_end_z: float = barrel_start_z - finned_length
	var muzzle_barrel_radius: float = caliber * 0.5 + muzzle_wall_thickness
	tapered_rod(Vector3(0.0, 0.0, barrel_start_z), Vector3(0.0, 0.0, finned_end_z), fin_inner_breech_radius, fin_inner_muzzle_radius)
	tapered_rod(Vector3(0.0, 0.0, finned_end_z), Vector3(0.0, 0.0, muzzle_z), fin_inner_muzzle_radius, muzzle_barrel_radius)
	# Five reported finned sections sum to 29 in; distribute the reported 36 fins over that envelope.
	for fin_index: int in range(fin_count):
		var along_barrel: float = (float(fin_index) + 0.5) / float(fin_count)
		var fin_z: float = barrel_start_z - along_barrel * finned_length
		var fin_radius: float = lerpf(fin_outer_breech_radius, fin_outer_muzzle_radius, along_barrel)
		var cooling_fin: MeshInstance3D = cylinder(Vector3(0.0, 0.0, fin_z), fin_radius, fin_thickness, gunmetal)
		cooling_fin.rotation.x = PI / 2.0
	var muzzle_sleeve: MeshInstance3D = cylinder(Vector3(0.0, 0.0, muzzle_z + 0.035), 0.036, 0.07, gunmetal)
	muzzle_sleeve.rotation.x = PI / 2.0
	var muzzle_bore: MeshInstance3D = cylinder(Vector3(0.0, 0.0, muzzle_z + 0.003), caliber * 0.5, 0.006, dark)
	muzzle_bore.rotation.x = PI / 2.0
	# Charging handles at the rear of the receiver.
	for grip_side: int in [-1, 1]:
		rod(Vector3(float(grip_side) * 0.08, -0.02, 0.46), Vector3(float(grip_side) * 0.16, -0.08, 0.57), 0.025, steel)
