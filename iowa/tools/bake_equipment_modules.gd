extends SceneTree

const GEOMETRY = preload("res://scripts/iowa_geometry.gd")
const EQUIPMENT_SCRIPT = preload("res://scripts/iowa_equipment_module.gd")
const OUTPUT_PATHS: Dictionary = {
	"aircraft_catapult": "res://scenes/equipment/aircraft_catapult_turntable.tscn",
	"aircraft_crane": "res://scenes/equipment/aircraft_crane_lattice.tscn"
}

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var equipment_directory: String = ProjectSettings.globalize_path("res://scenes/equipment")
	DirAccess.make_dir_recursive_absolute(equipment_directory)
	var equipment_profiles: Dictionary = _load_equipment_profiles()
	var palette: Dictionary = {
		"foundation": GEOMETRY.material(Color("59636a"), 0.78),
		"deck_detail": GEOMETRY.material(Color("555f65"), 0.78),
		"superstructure_dark": GEOMETRY.material(Color("6e787c"), 0.85),
		"gunmetal": GEOMETRY.material(Color("414a50"), 0.68, 0.18),
		"steel": GEOMETRY.material(Color("a0a6a7"), 0.68, 0.12),
		"frame": GEOMETRY.material(Color("788287"), 0.78)
	}
	for module_type: String in OUTPUT_PATHS:
		var module: IowaEquipmentModule = EQUIPMENT_SCRIPT.new() as IowaEquipmentModule
		var profile: Dictionary = equipment_profiles.get(module_type, {})
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

func _load_equipment_profiles() -> Dictionary:
	var profile_path: String = "res://data/equipment_profiles.json"
	if not FileAccess.file_exists(profile_path):
		push_warning("Equipment profile file is missing: %s" % profile_path)
		return {}
	var profile_file: FileAccess = FileAccess.open(profile_path, FileAccess.READ)
	if profile_file == null:
		push_error("Could not open equipment profile file: %s" % profile_path)
		return {}
	var parsed: Variant = JSON.parse_string(profile_file.get_as_text())
	if not parsed is Dictionary:
		push_error("Equipment profile file must contain a JSON object: %s" % profile_path)
		return {}
	return parsed as Dictionary

func _assign_owner(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		_assign_owner(child, scene_root)
