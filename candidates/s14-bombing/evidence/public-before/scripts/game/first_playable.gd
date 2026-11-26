class_name FirstPlayableGame
extends Node3D

@export var scenario_path: String = "res://data/scenarios/island_harbor_defence.json"
var map_view: IslandHarborView
var session: FirstPlayableSession
var camera: ObserverCamera
var hud: ObserverHud
var effects: CombatEffects
var models: Dictionary = {}
var recoils: Dictionary = {}
var metadata: Dictionary = {}
var wakes: Dictionary = {}
var water_material: ShaderMaterial
var environment_view: CloudSeaEnvironment
var running: bool = false
var _ui_timer_s: float = 0.0
var _last_time_s: float = 0.0
var _report_shown: bool = false
var _sound_enabled: bool = false
var _web_probe: WebRunProbe

func _ready() -> void:
	_build_environment()
	camera = ObserverCamera.new()
	add_child(camera)
	effects = CombatEffects.new()
	effects.sound_enabled = false
	effects.effect_capacity = 384
	add_child(effects)
	hud = ObserverHud.new()
	add_child(hud)
	hud.action.connect(_action)
	hud.order_selected.connect(_locate_order)
	session = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle(scenario_path)
	if not errors.is_empty():
		hud.show_error("无法装配场景，请查看交付说明中的资源检查。\n" + "\n".join(errors))
		push_error("S07 initialization: " + str(errors))
		return
	if session.world.shared_state.has("terrain"):
		var terrain: Dictionary = session.world.shared_state.terrain
		map_view = IslandHarborView.new()
		add_child(map_view)
		map_view.build(terrain)
		camera.terrain = terrain
		hud.set_terrain(terrain)
	for id: String in session.world.unit_ids():
		var definition: UnitDefinition = session.catalog.unit(session.units[id].definition_id)
		var packed: PackedScene = load(definition.model_scene) as PackedScene
		if packed == null:
			hud.show_error("作战单位模型资源未就绪")
			return
		var model: Node3D = packed.instantiate() as Node3D
		model.name = id
		add_child(model)
		models[id] = model
		metadata[id] = ObserverCamera.describe_unit(definition)
		metadata[id]["name"] = session.scenario.presentation.names[id]
		if definition.domain in ["ship","ground"]:
			var recoil: VisualRecoil = VisualRecoil.new()
			recoil.bind_model(model)
			recoils[id] = recoil
			if definition.domain=="ship": _make_wake(id, definition.dimensions_m.z)
	_reset_presentation()
	running = true
	_web_probe = WebRunProbe.new(self)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--paused": session.world.set_paused(true)

func _process(delta_s: float) -> void:
	if not running: return
	var begin_us: int = Time.get_ticks_usec()
	var events: Array[BattleEvent] = session.advance(delta_s, 16)
	var advance_us: int = Time.get_ticks_usec()
	apply_presentation(events)
	var presentation_us: int = Time.get_ticks_usec()
	camera.update_view(delta_s, session.world.time_s(), session.units, session.world.paused)
	environment_view.update_observer(camera.position)
	var camera_us: int = Time.get_ticks_usec()
	_ui_timer_s -= delta_s
	if _ui_timer_s <= 0.0:
		hud.refresh(session, camera.mode, camera.shot_label)
		_ui_timer_s = 0.25
	if not session.ended_reason.is_empty() and not _report_shown:
		_report_shown = true
		hud.report_panel.show()
	if _web_probe != null and _web_probe.enabled:
		_web_probe.observe(delta_s, advance_us - begin_us, presentation_us - advance_us, camera_us - presentation_us, Time.get_ticks_usec() - camera_us)

func apply_presentation(events: Array[BattleEvent]) -> void:
	if _web_probe != null and _web_probe.enabled: _web_probe.consume(events)
	var simulation_delta_s: float = maxf(0.0, session.world.time_s() - _last_time_s)
	_last_time_s = session.world.time_s()
	for id: String in models:
		var view: Dictionary = session.units[id]
		var model: Node3D = models[id]
		model.apply_state(view)
		var damage: Dictionary = view.module_data.get("damage", {})
		if metadata[id].domain=="ground":
			var recoil: VisualRecoil = recoils[id]
			recoil.advance(simulation_delta_s)
			recoil.consume(events,id,session.world.generation)
		if metadata[id].domain == "ship":
			model.visible = not bool(view.module_data.get("ship_motion", {}).get("exited", false)) and (view.active or damage.get("phase", "") in ["disabled", "sinking", "wreck"])
			# Only visual list; S05 owns actual sinking position and functional damage.
			model.rotation.z += float(damage.get("list_rad", 0.0))
			var recoil: VisualRecoil = recoils[id]
			recoil.advance(simulation_delta_s)
			recoil.consume(events, id, session.world.generation)
			var wake: MeshInstance3D = wakes[id]
			wake.visible = bool(view.active) and (view.velocity_mps as Vector3).length() > 0.5
			wake.transform = Transform3D(Basis.from_euler(Vector3(0, view.rotation_rad.y, 0)), view.position_m + Vector3.UP * 0.09)
	# Age existing visuals first, so newly consumed flashes are visible even at high speed.
	effects.advance(simulation_delta_s)
	effects.consume(events, session.world.generation)
	effects.apply_snapshot({"units":session.units})
	# Web sample playback resumes by creating a new Web Audio source. Reapplying
	# false each frame can repeatedly restart looping sources in the fixed engine.
	for player: AudioStreamPlayer3D in effects.sounds:
		if player.stream_paused != session.world.paused: player.stream_paused = session.world.paused
	for player: AudioStreamPlayer3D in effects.engine_sources:
		if player.stream_paused != session.world.paused: player.stream_paused = session.world.paused
	camera.consume(events)
	environment_view.advance(session.world.time_s())
	if map_view != null: map_view.advance(session.world.time_s())

func _action(kind: String, value: Variant) -> void:
	if not running: return
	match kind:
		"pause":
			if session.ended_reason.is_empty(): session.world.set_paused(not session.world.paused)
		"speed": session.world.set_time_scale(float(value))
		"camera": camera.set_mode(str(value))
		"follow": camera.follow(str(value))
		"map_location":
			if map_view != null:
				for point: Dictionary in map_view.terrain.source.viewpoints:
					if point.id == str(value): camera.locate_map(point)
		"sound":
			_sound_enabled = not _sound_enabled
			effects.sound_enabled = _sound_enabled
			hud.sound_button.text = "关闭声音" if _sound_enabled else "启用声音"
		"finish": session.finish()
		"restart":
			if session.restart(): _reset_presentation()
	hud.refresh(session, camera.mode, camera.shot_label)

func _reset_presentation() -> void:
	_last_time_s = 0.0
	_report_shown = false
	effects.clear(session.world.generation)
	for recoil: VisualRecoil in recoils.values(): recoil.reset(session.world.generation)
	camera.reset_view(session.world.generation, metadata)
	hud.reset_hud(session)
	apply_presentation([])
	camera.views = session.units
	camera.followed_id = "jp_bb"
	camera.fit_unit("jp_bb")
	camera.shot_label = "舰队跟随"
	camera.hold_s = 10.0
	camera.update_view(0.0, 0.0, session.units, true)
	environment_view.update_observer(camera.position)

func _locate_order(record: Dictionary, target: bool) -> void:
	if record.is_empty(): return
	var ids: Array[String] = []
	if target and session.units.has(record.get("target_id", "")):
		ids.append(record.target_id)
	else:
		for id: String in record.get("execution", {}): ids.append(id)
	var point: Vector3 = Vector3.ZERO
	if not ids.is_empty(): point = session.units[ids[0]].position_m
	elif record.get("area", {}).has("center_m"): point = SimData.vec3(record.area.center_m)
	camera.locate(point, ids)
	if not ids.is_empty() and ids.all(func(id: String) -> bool: return not session.units[id].active): camera.shot_label = "部队已退出 · 最后相关位置"

func _input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: _action("pause", null)
			KEY_C: _action("camera", "auto")
			KEY_F: _action("camera", "free")
			KEY_TAB: hud.expanded = not hud.expanded; hud._layout()
			KEY_H: hud.cinema = not hud.cinema; hud._layout()
			KEY_R: _action("restart", null)
			_: return
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if running: camera.handle_input(event)

func _build_environment() -> void:
	environment_view = CloudSeaEnvironment.new()
	add_child(environment_view)
	water_material = environment_view.water_material

func _make_wake(id: String, length_m: float) -> void:
	var wake: MeshInstance3D = MeshInstance3D.new()
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2(length_m * 0.13, length_m * 0.6)
	mesh.center_offset = Vector3(0, 0, length_m * 0.75)
	wake.mesh = mesh
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://scripts/presentation/wake.gdshader")
	wake.material_override = material
	wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wake)
	wakes[id] = wake
