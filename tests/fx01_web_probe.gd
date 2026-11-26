extends Node3D

## Isolated validation harness. The production entry and simulator are unchanged.
const DEMO: Script=preload("res://tests/fixtures/fx01_demo.gd")
var game: FirstPlayableGame
var demo: Node3D
var mode: String="production"
var enabled: bool=true
var generation: int=0
var command_id: int=0
var elapsed: float=0.
var accumulator: float=0.

func _ready() -> void:
	process_priority=100
	game=(load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	add_child(game)
	demo=DEMO.new()
	add_child(demo)
	demo.configure(false)
	demo.hide()
	generation=game.session.world.generation
	_production_camera()

func _production_camera() -> void:
	game.camera.mode="free"
	game.camera.followed_id=""
	var point: Vector3=game.session.units.jp_bb.position_m
	game.camera.position=point+Vector3(360,46,210)
	game.camera.look_at(point+Vector3(0,12,0))
	game.camera.distance_m=420.
	game.camera.focus=game.camera.position-game.camera.basis.z*420.
	var offset: Vector3=game.camera.position-game.camera.focus
	game.camera.yaw=atan2(offset.x,offset.z)
	game.camera.pitch=asin(offset.y/420.)
	game.camera._snap=true

func set_case(value: String) -> void:
	mode=value
	accumulator=0.
	if mode=="production":
		demo.hide()
		game.effects.show()
		game.set_process(true)
		_production_camera()
	else:
		game.set_process(false)
		game.effects.hide()
		demo.show()
		demo.start(mode)
		demo.effects.effects_enabled=enabled
		demo.camera_pose(game.camera)

func _process(delta: float) -> void:
	if not game.running:return
	var commands: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.FX01.commands.splice(0))",true)))
	if commands is Array:
		for command: Dictionary in commands:
			match str(command.kind):
				"case":set_case(str(command.value))
				"enabled":
					enabled=bool(command.value)
					game.effects.effects_enabled=enabled
					demo.effects.effects_enabled=enabled
			command_id=int(command.id)
	if generation!=game.session.world.generation:
		generation=game.session.world.generation
		if mode!="production":demo.start(mode)
	if mode!="production":
		if not game.session.world.paused:
			accumulator+=delta*game.session.world.time_scale
			var steps: int=mini(16,floori(accumulator*60.))
			if steps>0:
				demo.step_ticks(steps)
				accumulator-=float(steps)/60.
			if demo.age_s>(6.5 if mode=="water" else 8. if mode=="flak" else 5. if mode=="tracer" else 7.):demo.start(mode)
		demo.camera_pose(game.camera)
		game.environment_view.advance(float(demo.arena.world.time_s()))
		game.environment_view.update_observer(game.camera.position)
	elapsed+=delta
	if elapsed<.1:return
	elapsed=0.
	if mode!="production":game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	var rect: Rect2=game.hud.speeds.get_global_rect()
	var popup: PopupMenu=game.hud.speeds.get_popup()
	var result: Dictionary={"command_id":command_id,"mode":mode,"enabled":enabled,"paused":game.session.world.paused,"speed":game.session.world.time_scale,"generation":generation,"sim_s":game.session.world.time_s(),"demo_age_s":0. if mode=="production" else demo.age_s,"demo_tick":0 if mode=="production" else demo.arena.world.tick,"effects":game.effects.statistics() if mode=="production" else demo.effects.statistics(),"game_children":game.get_child_count(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"environment":game.environment_view.snapshot(),"speed_control":[rect.get_center().x,rect.get_center().y],"speed_popup":{"visible":popup.visible,"position":[popup.position.x,popup.position.y],"size":[popup.size.x,popup.size.y]}}
	if mode!="production":result.event_counts=demo.snapshot().event_counts
	JavaScriptBridge.eval("window.FX01.accept("+JSON.stringify(result)+")",true)
