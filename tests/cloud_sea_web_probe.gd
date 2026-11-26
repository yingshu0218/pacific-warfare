extends Node3D

## Isolated validation entry only. This script is never added to normal Showcase.
var game: FirstPlayableGame
var shot: String = "ship_low"
var visual_mode: String = "new"
var latest_command: int = 0
var elapsed_s: float = 0.0
var legacy_sky: ProceduralSkyMaterial
var original_shader: Shader
var legacy_water_material: ShaderMaterial
var environment_only: bool = false
var _new_fog: Dictionary = {}

func _ready() -> void:
	process_priority = 100
	game = (load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	add_child(game)
	game.camera.mode = "free"
	game.camera.followed_id = ""
	legacy_sky = ProceduralSkyMaterial.new()
	legacy_sky.sky_top_color = Color("5b92b5")
	legacy_sky.sky_horizon_color = Color("b5d0d8")
	legacy_sky.ground_horizon_color = Color("b5d0d8")
	original_shader = load("res://tests/fixtures/s13_original_ocean.gdshader") as Shader
	legacy_water_material = ShaderMaterial.new()
	legacy_water_material.shader = original_shader
	var environment: Environment = game.environment_view.world_environment.environment
	_new_fog = {"mode": environment.fog_mode, "color": environment.fog_light_color, "density": environment.fog_density}
	_set_camera()

func _process(delta_s: float) -> void:
	if not game.running: return
	var pending: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.S13.commands.splice(0))", true)))
	if pending is Array:
		for command: Dictionary in pending:
			match str(command.kind):
				"shot":
					shot = str(command.value)
					_set_camera()
				"visual": _visual(str(command.value))
				"environment_only": _environment_only(bool(command.value))
			latest_command = int(command.id)
	elapsed_s += delta_s
	if elapsed_s < .2: return
	elapsed_s = 0
	var buttons: Dictionary = {}
	for button: Node in game.hud.pause_button.get_parent().get_children():
		if button is Button:
			var rect: Rect2 = (button as Button).get_global_rect()
			buttons[(button as Button).text] = [rect.get_center().x, rect.get_center().y]
	var speed_rect: Rect2 = game.hud.speeds.get_global_rect()
	var popup: PopupMenu = game.hud.speeds.get_popup()
	var environment_snapshot: Dictionary = game.environment_view.snapshot()
	environment_snapshot.sky_id = str(game.environment_view.sky_material.get_instance_id())
	environment_snapshot.water_id = str(game.environment_view.water_material.get_instance_id())
	var result: Dictionary = {"command_id": latest_command, "visual_mode": visual_mode, "shot": shot,
		"sim_s": game.session.world.time_s(), "paused": game.session.world.paused, "speed": game.session.world.time_scale,
		"generation": game.session.world.generation, "game_children": game.get_child_count(), "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"environment": environment_snapshot, "speed_popup": {"visible": popup.visible, "position": [popup.position.x, popup.position.y], "size": [popup.size.x, popup.size.y]}, "environment_only": environment_only,
		"camera": SimData.array3(game.camera.position), "buttons": buttons, "speed_control": [speed_rect.get_center().x, speed_rect.get_center().y]}
	JavaScriptBridge.eval("window.S13.accept(" + JSON.stringify(result) + ")", true)

func _set_camera() -> void:
	game.camera.mode = "free"
	game.camera.followed_id = ""
	var ship: Vector3 = game.session.units.jp_bb.position_m
	match shot:
		"ship_low":
			game.camera.position = ship + Vector3(360, 46, 210)
			game.camera.look_at(ship + Vector3(0, 12, 0))
		"sky":
			game.camera.position = ship + Vector3(360, 46, 210)
			game.camera.look_at(game.camera.position + Vector3(-.4, .32, -1) * 2000)
		"air_high":
			var aircraft: Vector3 = game.session.units.us_air_1.position_m
			game.camera.position = aircraft + Vector3(55, 22, 48)
			game.camera.look_at(aircraft + Vector3(0, 2, 0))
		"harbor":
			game.camera.position = Vector3(-1700, 360, -2750)
			game.camera.look_at(Vector3(-3850, 25, -3800))
		"far_edge":
			game.camera.position = Vector3(15000, 5800, 12000)
			game.camera.look_at(Vector3(0, 1800, -40000))
	# Use the normal observer camera update after configuring this exact pose.
	var distance_m: float = 420.0 if shot == "ship_low" else 75.0 if shot == "air_high" else 2000.0
	game.camera.focus = game.camera.position - game.camera.basis.z * distance_m
	game.camera.distance_m = distance_m
	var offset: Vector3 = game.camera.position - game.camera.focus
	game.camera.yaw = atan2(offset.x, offset.z)
	game.camera.pitch = asin(offset.y / distance_m)
	game.camera._snap = true

func _visual(value: String) -> void:
	visual_mode = value
	var view: CloudSeaEnvironment = game.environment_view
	var environment: Environment = view.world_environment.environment
	var legacy: bool = value == "legacy"
	environment.sky.sky_material = legacy_sky if legacy else view.sky_material
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL if legacy else int(_new_fog.mode)
	environment.fog_light_color = Color("aac5cc") if legacy else _new_fog.color
	environment.fog_density = .000012 if legacy else float(_new_fog.density)
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG if legacy else Environment.REFLECTION_SOURCE_DISABLED
	view.water.material_override = legacy_water_material if legacy else view.water_material
	legacy_water_material.set_shader_parameter("simulation_time", game.session.world.time_s())
	(view.water.mesh as PlaneMesh).size = Vector2(120000, 120000) if legacy else Vector2(800000, 800000)
	if not legacy:
		view.set_clouds_enabled(value != "no_clouds")

func _environment_only(value: bool) -> void:
	environment_only = value
	game.set_process(not value)
	for model: Node3D in game.models.values(): model.visible = not value
	for wake: Node3D in game.wakes.values(): wake.visible = not value
	game.map_view.visible = not value
	game.effects.visible = not value
	game.hud.visible = not value
