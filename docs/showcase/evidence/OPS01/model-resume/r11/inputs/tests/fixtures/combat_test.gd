extends SceneTree

const FIX: Script = preload("res://tests/fixtures/combat_fixture.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run_test")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func finish(label: String) -> void:
	print("S05 ", label, ": ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)

func run_test() -> void:
	finish("base")
