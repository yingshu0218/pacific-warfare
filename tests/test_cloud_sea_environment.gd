extends SceneTree

var failures: PackedStringArray = []
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label_value: String) -> void:
	checks.append({"check": label_value, "passed": ok})
	if not ok: failures.append(label_value)

func run() -> void:
	var game: FirstPlayableGame = (load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	check(game.running, "actual Showcase loads with cloud/sea component")
	if not game.running:
		finish(game)
		return
	var view: CloudSeaEnvironment = game.environment_view
	var initial: Dictionary = game.session.world.snapshot()
	var resources: Dictionary = view.snapshot()
	for iteration: int in 10:
		view.advance(float(iteration) * 37.0)
		view.update_observer(Vector3(iteration * 1000, iteration * 700, -4000))
		view.set_clouds_enabled(iteration % 2 == 0)
	check(game.session.world.snapshot() == initial, "environment time, wind appearance and camera cannot mutate simulation")
	view.set_clouds_enabled(true)
	game.apply_presentation([])
	game.session.world.set_paused(true)
	for frame: int in 30:
		game.apply_presentation(game.session.advance(1.0 / 60.0))
	check(view.presentation_time_s == 0.0 and view.snapshot().sky_time_s == 0.0 and view.snapshot().water_time_s == 0.0, "pause freezes both absolute material clocks")
	game.session.world.set_paused(false)
	game.session.world.set_time_scale(1.0)
	for frame: int in 30: game.apply_presentation(game.session.advance(1.0 / 60.0))
	check(is_equal_approx(view.presentation_time_s, 0.5), "1x advances both materials by simulation half second")
	game.session.world.set_time_scale(4.0)
	for frame: int in 30: game.apply_presentation(game.session.advance(1.0 / 60.0))
	check(is_equal_approx(view.presentation_time_s, 2.5), "4x advances materials by four times wall interval")
	check(view.snapshot().sky_time_s == view.snapshot().water_time_s, "sky and ocean share exact same time")
	var children: int = game.get_child_count()
	for iteration: int in 3:
		game._action("restart", null)
		check(view.presentation_time_s == 0.0, "restart returns visual phase to zero " + str(iteration))
		check(game.get_child_count() == children and view.get_child_count() == 3, "restart retains one environment " + str(iteration))
		check(view.snapshot().sky_id == resources.sky_id and view.snapshot().water_id == resources.water_id, "restart reuses material resources " + str(iteration))
	check((view.water.mesh as PlaneMesh).size == Vector2(800000, 800000) and view.water.position.y == 0.0, "sea stays at simulation y=0 and covers camera far range")
	check(not "TIME" in FileAccess.get_file_as_string("res://scripts/presentation/ocean.gdshader").split("void vertex")[1], "ocean does not depend on engine wall clock")
	var clone: FirstPlayableSession = FirstPlayableSession.new()
	check(clone.load_battle(game.scenario_path).is_empty(), "control simulation installs without environment")
	for tick: int in 90:
		game.session.world.step_ticks(1)
		clone.world.step_ticks(1)
		game.apply_presentation(game.session.consume_world())
		clone.consume_world()
	check(game.session.world.snapshot().units == clone.world.snapshot().units, "same seed and inputs give identical actual unit state with and without environment")
	finish(game)

func finish(game: FirstPlayableGame) -> void:
	var path: String = "res://docs/showcase/evidence/S13/environment_checks.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	for failure: String in failures: push_error("S13 environment: " + failure)
	print("S13 environment checks: ", "PASS" if failures.is_empty() else failures)
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
