extends SceneTree
const DATA: Script=preload("res://tests/bombing/data_fixture.gd")

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var out: String="res://.local/integration"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var parameters: Dictionary=DATA.parameters()
	var config: CombatConfig=DATA.config()
	var all_performance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/aircraft/performance.json"))
	var profiles: Dictionary={}
	var performance: Dictionary={"schema_version":1}
	for id: String in parameters.aircraft:
		profiles[id]=config.data.unit_profiles[id].duplicate(true)
		performance[id]=all_performance[id].duplicate(true)
	for row: Array in [["combat_profiles.json",{"unit_profiles":profiles,"ammo_profiles":parameters.ammo_profiles}], ["performance.json",performance]]:
		var file: FileAccess=FileAccess.open(out.path_join(str(row[0])),FileAccess.WRITE)
		file.store_string(JSON.stringify(row[1],"\t"));file.close()
	print("BOMB01_INTEGRATION four explicit aircraft profiles exported; no old fighter profiles")
	call_deferred("quit")
