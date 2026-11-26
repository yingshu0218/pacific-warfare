extends SceneTree

## Real Showcase capture; the same four camera transforms are used before/after.
var game: FirstPlayableGame
var directory: String = "res://docs/showcase/evidence/S13"
var baseline: bool = false
var continuous: bool = false
var open_sea: bool = false
var short_sequence: bool = false
var audit: Dictionary = {"views": [], "frames": [], "scope": "Native, 1280x720; simulation and models unchanged"}
var failures: PackedStringArray = []

func _initialize() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	continuous = "--continuous" in OS.get_cmdline_user_args()
	open_sea = "--open-sea" in OS.get_cmdline_user_args()
	short_sequence = "--short-sequence" in OS.get_cmdline_user_args()
	if baseline: directory = directory.path_join("before")
	if open_sea: directory = directory.path_join("open_sea")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): directory = argument.trim_prefix("--evidence-dir=")
	call_deferred("run")

func tick(count: int) -> void:
	for index: int in count:
		game.session.world.step_ticks(1)
		game.apply_presentation(game.session.consume_world())

func draw() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false, 0.0)

func set_camera(label_value: String) -> void:
	game.camera.mode = "free"
	game.camera.followed_id = ""
	var ship: Vector3 = game.session.units.jp_bb.position_m
	match label_value:
		"ship_low":
			game.camera.position = ship + Vector3(360, 46, 210)
			game.camera.look_at(ship + Vector3(0, 12, 0))
		"fleet":
			game.camera.position = ship + Vector3(2800, 650, 3500)
			game.camera.look_at(ship + Vector3(0, 25, -500))
		"air_high":
			var aircraft: Vector3 = game.session.units.us_air_1.position_m
			game.camera.position = aircraft + Vector3(55, 22, 48)
			game.camera.look_at(aircraft + Vector3(0, 2, 0))
		"harbor":
			game.camera.position = Vector3(-1700, 360, -2750)
			game.camera.look_at(Vector3(-3850, 25, -3800))
		"sky":
			game.camera.position = ship + Vector3(360, 46, 210)
			game.camera.look_at(game.camera.position + Vector3(-.4, .32, -1) * 2000)
		"far_edge":
			game.camera.position = Vector3(15000, 5800, 12000)
			game.camera.look_at(Vector3(0, 1800, -40000))
	game.camera.near = .8
	game.camera.far = 70000
	if not baseline: game.environment_view.update_observer(game.camera.position)

func view(label_value: String) -> void:
	set_camera(label_value)
	await draw()
	root.get_texture().get_image().save_png(directory.path_join(label_value + ".png"))
	audit.views.append({"name": label_value, "time_s": game.session.world.time_s(), "camera": SimData.array3(game.camera.position), "basis": str(game.camera.basis)})

func run() -> void:
	audit.source_hashes_start = source_hashes()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.content_scale_size = Vector2i(1280, 720)
	AudioServer.set_bus_mute(0, true)
	var scene: String = "res://showcase/open_sea.tscn" if open_sea else "res://showcase/island_harbor.tscn"
	game = (load(scene) as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	if not game.running:
		push_error("S13 capture: Showcase did not start")
		quit(1)
		return
	if baseline: _install_legacy_environment()
	game.hud.hide()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	tick(120)
	for label_value: String in (["ship_low", "air_high", "far_edge"] if open_sea else ["ship_low", "fleet", "air_high", "harbor", "sky", "far_edge"]):
		await view(label_value)
	if not baseline:
		game.hud.show()
		game.hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
		set_camera("ship_low")
		await draw()
		root.get_texture().get_image().save_png(directory.path_join("normal_ui.png"))
		game.hud.hide()
		if continuous:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory.path_join("sequence")))
			var index: int = 0
			for shot: String in (["ship_low", "harbor", "far_edge"] if short_sequence else ["ship_low", "sky", "air_high", "far_edge"]):
				var frame_count: int = 16 if short_sequence else 120 if shot == "sky" else 48
				for frame: int in frame_count:
					tick(6)
					set_camera(shot)
					if shot == "far_edge":
						game.camera.rotate_y(float(frame) * .0015)
					await draw()
					root.get_texture().get_image().save_png(directory.path_join("sequence/frame_%03d.png" % index))
					audit.frames.append({"index": index, "shot": shot, "simulation_s": game.session.world.time_s(), "environment": game.environment_view.snapshot(), "camera": SimData.array3(game.camera.position), "basis": str(game.camera.basis)})
					index += 1
			# Freeze the actual game clock while rendering several more wall frames.
			game.session.world.set_paused(true)
			set_camera("sky")
			await draw()
			var paused_hash: String = root.get_texture().get_image().get_data().hex_encode().sha256_text()
			for frame: int in 8:
				game.apply_presentation(game.session.advance(.1))
				await draw()
			var after_hash: String = root.get_texture().get_image().get_data().hex_encode().sha256_text()
			audit.pause_pixels_identical = paused_hash == after_hash
			if paused_hash != after_hash: failures.append("paused sky/water image changed")
			game.session.world.set_paused(false)
	audit.source_hashes_end = source_hashes()
	if audit.source_hashes_start != audit.source_hashes_end: failures.append("runtime sources changed during capture")
	audit.failures = failures
	var file: FileAccess = FileAccess.open(directory.path_join("native_capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(audit, "\t"))
	file.close()
	game.queue_free()
	for failure: String in failures: push_error("S13 capture: " + failure)
	quit(0 if failures.is_empty() else 1)

func _install_legacy_environment() -> void:
	# Replay the exact pre-S13 visual configuration, without swapping live sources.
	var environment: Environment = game.environment_view.world_environment.environment
	var sky: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("5b92b5")
	sky.sky_horizon_color = Color("b5d0d8")
	sky.ground_horizon_color = Color("b5d0d8")
	environment.sky.sky_material = sky
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_color = Color("aac5cc")
	environment.fog_density = .000012
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	game.water_material.shader = load("res://tests/fixtures/s13_original_ocean.gdshader") as Shader
	(game.environment_view.water.mesh as PlaneMesh).size = Vector2(120000, 120000)

func source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["res://scripts/presentation/environment/cloud_sea_environment.gd", "res://scripts/presentation/environment/daylight_sky.gdshader", "res://scripts/presentation/environment/cloud_noise.png", "res://scripts/presentation/environment/wave_slopes.png", "res://scripts/presentation/ocean.gdshader", "res://scripts/game/first_playable.gd", "res://scripts/game/first_playable_session.gd", "res://scripts/presentation/cameras/observer_camera.gd", "res://scripts/presentation/maps/island_harbor_view.gd", "res://scripts/presentation/maps/shore.gdshader", "res://scripts/behaviors/aircraft/air_combat_tactics.gd", "res://scripts/simulation/aircraft_motion/aircraft_motion.gd", "res://scripts/simulation/ship_motion/ship_motion.gd", "res://data/maps/island_harbor.json", "res://data/scenarios/first_playable.json", "res://data/scenarios/island_harbor.json", "res://ui/observer_hud.gd", "res://ui/observer_map.gd", "res://project.godot", "res://assets/ocean.gdshader"]:
		result[path] = FileAccess.get_sha256(path)
	return result
