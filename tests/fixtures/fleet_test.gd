extends SceneTree

const FLEET: Script = preload("res://tests/fixtures/fleet_fixture.gd")
var failures: int = 0
var checks: int = 0
var evidence: Dictionary = {}

func _initialize() -> void:
	call_deferred("run_test")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func finish(label: String) -> void:
	evidence.merge({"checks": checks, "failures": failures})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/showcase/evidence/S06"))
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S06/" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(FLEET.json_data(evidence), "\t") + "\n")
	print("S06 ", label, ": ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)

func run_test() -> void:
	finish("base")
