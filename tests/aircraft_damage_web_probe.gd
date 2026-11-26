extends Node3D

const REVIEW: Script = preload("res://tests/fixtures/dm01_review_stage.gd")
var game: FirstPlayableGame
var review: Node3D
var parked_environment: WorldEnvironment
var elapsed_s: float = 0.0
var latest_command: int = 0
var mode: String = "normal"

func _ready() -> void:
	process_priority = 100
	game = (load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	add_child(game)

func _process(delta_s: float) -> void:
	var pending: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.DM01.commands.splice(0))",true)))
	if pending is Array:
		for command: Dictionary in pending:
			match str(command.kind):
				"review": _show_review(str(command.value.definition_id),str(command.value.case))
				"normal": _normal()
				"review_pause": review.world.set_paused(not review.world.paused)
				"review_speed": review.world.set_time_scale(float(command.value))
				"review_restart":
					review.world.reset()
					review.event_log.clear()
					review.maximum_fragments = 0
					review.peak_effect_meshes = 0
					review.peak_effect_kinds.clear()
					review.effects.clear(review.world.generation)
					review.present([],0)
			latest_command = int(command.id)
	if mode == "controlled": review.advance_wall(delta_s)
	elapsed_s += delta_s
	if elapsed_s < .1: return
	elapsed_s = 0
	var result: Dictionary = {"mode":mode,"command_id":latest_command,"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"global_fragment_nodes":AircraftAdapter.live_fragment_nodes,"global_fragment_cap":AircraftAdapter.GLOBAL_FRAGMENT_CAP,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	if mode == "controlled":
		result.merge(review.snapshot())
		result["projected_center"] = SimData.array3(Vector3(review.camera.unproject_position(review.world.get_unit("target").position_m).x,review.camera.unproject_position(review.world.get_unit("target").position_m).y,0))
		result["paused"] = review.world.paused
		result["speed"] = review.world.time_scale
		result["generation"] = review.world.generation
	else:
		var unit_states: Dictionary = {}
		for id: String in game.session.units:
			var state: Dictionary = game.session.units[id]
			unit_states[id] = {"active":state.active,"phase":state.module_data.damage.phase,"definition_id":state.definition_id}
		var buttons: Dictionary = {}
		for button: Node in game.hud.pause_button.get_parent().get_children():
			if button is Button:
				var rect: Rect2 = (button as Button).get_global_rect()
				buttons[(button as Button).text] = [rect.get_center().x,rect.get_center().y]
		var speed_rect: Rect2 = game.hud.speeds.get_global_rect()
		var popup: PopupMenu = game.hud.speeds.get_popup()
		result.merge({"time_s":game.session.world.time_s(),"tick":game.session.world.tick,"paused":game.session.world.paused,"speed":game.session.world.time_scale,"generation":game.session.world.generation,"pending_simulation_s":game.session.world.pending_time_s(),"models":game.models.size(),"units":unit_states,"orders":game.session.orders.size(),"environment":game.environment_view.snapshot(),"effects":game.effects.statistics(),"buttons":buttons,"speed_control":[speed_rect.get_center().x,speed_rect.get_center().y],"speed_popup":{"visible":popup.visible,"position":[popup.position.x,popup.position.y],"size":[popup.size.x,popup.size.y]}})
	JavaScriptBridge.eval("window.DM01.accept("+JSON.stringify(AircraftDamageFixture.json_data(result))+")",true)

func _show_review(definition_id: String, case_name: String) -> void:
	if review != null: review.free()
	game.visible = false
	game.set_process(false)
	game.set_process_input(false)
	game.hud.visible = false
	if parked_environment == null:
		parked_environment = game.environment_view.world_environment
		game.environment_view.remove_child(parked_environment)
	mode = "controlled"
	# A single Web viewport avoids Compatibility subviewport cropping on Metal.
	# Only presentation nodes change; both worlds retain independent sim states.
	review = REVIEW.new()
	review.definition_id = definition_id
	review.case_name = case_name
	review.include_fx = true
	add_child(review)

func _normal() -> void:
	if review != null:
		review.free()
		review = null
	if parked_environment != null:
		game.environment_view.add_child(parked_environment)
		parked_environment = null
	mode = "normal"
	game.visible = true
	game.hud.visible = true
	game.camera.make_current()
	game.set_process_input(true)
	game.set_process(true)

func _exit_tree() -> void:
	if parked_environment != null:
		parked_environment.free()
		parked_environment = null
