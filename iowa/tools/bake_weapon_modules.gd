extends SceneTree

const GEOMETRY = preload("res://scripts/iowa_geometry.gd")
const WEAPON_SCRIPT = preload("res://scripts/iowa_weapon_mount.gd")
const OUTPUT_PATHS: Dictionary = {
	"main_16in": "res://scenes/weapons/main_16in_three_gun.tscn",
	"secondary_5in": "res://scenes/weapons/secondary_5in38_twin.tscn",
	"bofors_40mm": "res://scenes/weapons/bofors_40mm_quad.tscn",
	"oerlikon_20mm": "res://scenes/weapons/oerlikon_20mm_single.tscn"
}

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var absolute_directory: String = ProjectSettings.globalize_path("res://scenes/weapons")
	DirAccess.make_dir_recursive_absolute(absolute_directory)
	var weapon_profiles: Dictionary = _load_weapon_profiles()
	var palette: Dictionary = {
		"deck_detail": GEOMETRY.material(Color("555f65"), 0.78),
		"barbettes": GEOMETRY.material(Color("59636a"), 0.78),
		"turret": GEOMETRY.material(Color("707a7f"), 0.78),
		"turret_roof": GEOMETRY.material(Color("8b9294"), 0.78),
		"gunmetal": GEOMETRY.material(Color("414a50"), 0.68, 0.18),
		"steel": GEOMETRY.material(Color("a0a6a7"), 0.68, 0.12),
		"dark_glass": GEOMETRY.material(Color("202d34"), 0.32, 0.16),
		"port_buckler": GEOMETRY.material(Color("343d42"), 0.96),
		"seat": GEOMETRY.material(Color("465056"), 0.86)
	}
	for module_type: String in OUTPUT_PATHS:
		var module: IowaWeaponMount = WEAPON_SCRIPT.new() as IowaWeaponMount
		var profile: Dictionary = weapon_profiles.get(module_type, {})
		module.build_module_template(module_type, palette, profile)
		_assign_owner(module, module)
		var packed: PackedScene = PackedScene.new()
		var pack_error: Error = packed.pack(module)
		module.free()
		if pack_error != OK:
			push_error("Could not pack reusable %s scene: %s" % [module_type, error_string(pack_error)])
			quit(1)
			return
		var output_path: String = str(OUTPUT_PATHS[module_type])
		var save_error: Error = ResourceSaver.save(packed, output_path, ResourceSaver.FLAG_RELATIVE_PATHS)
		if save_error != OK:
			push_error("Could not save reusable %s scene: %s" % [module_type, error_string(save_error)])
			quit(1)
			return
		print("BAKED: %s" % output_path)
	quit(0)

func _load_weapon_profiles() -> Dictionary:
	var profile_path: String = "res://data/weapon_profiles.json"
	if not FileAccess.file_exists(profile_path):
		push_warning("Weapon profile file is missing: %s" % profile_path)
		return {}
	var profile_file: FileAccess = FileAccess.open(profile_path, FileAccess.READ)
	if profile_file == null:
		push_error("Could not open weapon profile file: %s" % profile_path)
		return {}
	var parsed: Variant = JSON.parse_string(profile_file.get_as_text())
	if not parsed is Dictionary:
		push_error("Weapon profile file must contain a JSON object: %s" % profile_path)
		return {}
	return parsed as Dictionary

func _assign_owner(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		_assign_owner(child, scene_root)

