class_name FirstPlayableGame
extends Node3D

@export var scenario_path: String = "res://data/scenarios/island_harbor_defence.json"
var map_view: IslandHarborView
var session: FirstPlayableSession
var camera: ObserverCamera
var hud: ObserverHud
var effects: CombatEffects
const SALVO_OVERLAY: Script = preload("res://scripts/presentation/effects/observed_salvo_overlay.gd")
var salvo_overlay: SALVO_OVERLAY
var salvo_replay: bool = false
var _salvo_timer_s: float = 0.
var _salvo_rank: int = 0
var _salvo_source: String = ""
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
var presentation_events: Array[BattleEvent] = []
var _pending_presentation_events: Array[BattleEvent] = []
var _presentation_event_sequence: int = 0

func _ready() -> void:
	_build_environment()
	camera = ObserverCamera.new()
	add_child(camera)
	get_window().focus_exited.connect(camera.release_input)
	get_viewport().gui_focus_changed.connect(func(control: Control) -> void:
		if control != null: camera.release_input())
	effects = _create_effects()
	effects.sound_enabled = false
	effects.effect_capacity = 384
	add_child(effects)
	salvo_overlay = SALVO_OVERLAY.new()
	add_child(salvo_overlay)
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
		environment_view.set_terrain(terrain)
		if session.scenario.environment.has("view_script"):
			var map_script: Script = load(str(session.scenario.environment.view_script))
			map_view = map_script.new() as IslandHarborView
		else:
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
		metadata[id]["definition_id"] = definition.id
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
	camera.update_view(delta_s, session.presentation_time_s, session.presentation_units, session.world.paused)
	environment_view.update_observer(camera.position)
	if salvo_replay:
		_salvo_timer_s -= delta_s
		if _salvo_timer_s <= 0.:
			_salvo_timer_s = .10
			_refresh_salvo_overlay()
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
	var simulation_delta_s: float = maxf(0.0, session.presentation_time_s - _last_time_s)
	_last_time_s = session.presentation_time_s
	for event: BattleEvent in events:
		if event.sequence<=_presentation_event_sequence: continue
		_presentation_event_sequence=event.sequence
		_pending_presentation_events.append(event)
	presentation_events.clear()
	while not _pending_presentation_events.is_empty() and _pending_presentation_events[0].time_s<=session.presentation_time_s+0.0000001:
		presentation_events.append(_pending_presentation_events.pop_front())
	for id: String in models:
		var view: Dictionary = session.presentation_units[id]
		var model: Node3D = models[id]
		model.apply_state(view)
		var damage: Dictionary = view.module_data.get("damage", {})
		if metadata[id].domain=="ground":
			var recoil: VisualRecoil = recoils[id]
			recoil.advance(simulation_delta_s)
			recoil.consume(presentation_events,id,session.world.generation)
		if metadata[id].domain == "ship":
			model.visible = not bool(view.module_data.get("ship_motion", {}).get("exited", false)) and (view.active or damage.get("phase", "") in ["disabled", "sinking", "wreck"])
			# Only visual list; S05 owns actual sinking position and functional damage.
			model.rotation.z += float(damage.get("list_rad", 0.0))
			var recoil: VisualRecoil = recoils[id]
			recoil.advance(simulation_delta_s)
			recoil.consume(presentation_events, id, session.world.generation)
			var wake: MeshInstance3D = wakes[id]
			wake.visible = bool(view.active) and (view.velocity_mps as Vector3).length() > 0.5
			wake.transform = Transform3D(Basis.from_euler(Vector3(0, view.rotation_rad.y, 0)), view.position_m + Vector3.UP * 0.09)
	# Age existing visuals first, so newly consumed flashes are visible even at high speed.
	effects.advance(simulation_delta_s)
	effects.consume(presentation_events, session.world.generation)
	effects.apply_presentation_units(session.presentation_units)
	# Web sample playback resumes by creating a new Web Audio source. Reapplying
	# false each frame can repeatedly restart looping sources in the fixed engine.
	for player: AudioStreamPlayer3D in effects.sounds:
		if player.stream_paused != session.world.paused: player.stream_paused = session.world.paused
	for player: AudioStreamPlayer3D in effects.engine_sources:
		if player.stream_paused != session.world.paused: player.stream_paused = session.world.paused
	camera.consume(presentation_events)
	environment_view.advance(session.presentation_time_s)
	if map_view != null: map_view.advance(session.presentation_time_s)

func _refresh_salvo_overlay() -> void:
	var source: String = hud.selected_unit_id()
	if source != _salvo_source:
		_salvo_source = source
		_salvo_rank = 0
	var count: int = salvo_overlay.show_salvo(session.observed_salvos(),source,session.presentation_time_s,_salvo_rank)
	if count == 0 and _salvo_rank > 0:
		_salvo_rank = 0
		count = salvo_overlay.show_salvo(session.observed_salvos(),source,session.presentation_time_s)
	hud.set_salvo_replay(salvo_replay,count,_salvo_rank)

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
		"salvo_replay":
			salvo_replay = not salvo_replay
			if salvo_replay:
				_salvo_rank = 0
				_refresh_salvo_overlay()
			else:
				salvo_overlay.reset()
				hud.set_salvo_replay(false,0)
		"older_salvo":
			if salvo_replay:
				_salvo_rank += 1
				_refresh_salvo_overlay()
		"finish": session.finish()
		"restart":
			if session.restart(): _reset_presentation()
	if kind in ["camera","follow","map_location"]:
		get_viewport().gui_release_focus()
	hud.refresh(session, camera.mode, camera.shot_label)

func _reset_presentation() -> void:
	_last_time_s = 0.0
	presentation_events.clear();_pending_presentation_events.clear();_presentation_event_sequence=0
	_report_shown = false
	salvo_replay = false
	salvo_overlay.reset()
	hud.set_salvo_replay(false,0)
	effects.clear(session.world.generation)
	for recoil: VisualRecoil in recoils.values(): recoil.reset(session.world.generation)
	camera.reset_view(session.world.generation, metadata)
	hud.reset_hud(session)
	apply_presentation([])
	camera.views = session.presentation_units
	camera.followed_id = "jp_bb" if session.units.has("jp_bb") else str(session.world.unit_ids()[0])
	camera.fit_unit(camera.followed_id)
	camera.shot_label = "舰队跟随"
	camera.hold_s = 10.0
	camera.update_view(0.0, 0.0, session.presentation_units, true)
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
	# Releases must reach the camera even if a popup consumed the press/focus.
	if event is InputEventKey and not event.pressed: camera.release_key(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		camera.end_drag()
	if _camera_keyboard_blocked(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if ObserverCamera._key(event) == KEY_SHIFT:
			camera.handle_input(event)
			return
		if ObserverCamera.is_movement_key(event):
			_manual_camera_takeover(true)
			camera.handle_input(event)
			get_viewport().set_input_as_handled()
			return
		match event.physical_keycode:
			KEY_SPACE: _action("pause", null)
			KEY_C: _action("camera", "auto")
			KEY_F: _action("camera", "free")
			KEY_TAB: hud.expanded = not hud.expanded; hud._layout()
			KEY_H: hud.cinema = not hud.cinema; hud._layout()
			KEY_R: _action("restart", null)
			KEY_T: _action("older_salvo" if event.shift_pressed else "salvo_replay",null)
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		camera.handle_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if not running or _camera_popup_visible(): return
	# Keyboard was routed above with GUI focus protection. A menu may leave a
	# letter unhandled; it must not reach a second, unguarded camera key path.
	if event is InputEventKey: return
	if event is InputEventMouse:
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE: return
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()
		if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_manual_camera_takeover(false)
	if camera.handle_input(event): get_viewport().set_input_as_handled()

func _manual_camera_takeover(move: bool) -> void:
	camera.adopt_current_view()
	if move:
		if camera.mode != "free" or not camera.manual_free: camera.set_mode("free")
	elif camera.mode in ["auto", "fighter"] or (camera.mode == "free" and not camera.manual_free):
		camera.set_mode("free")

func _camera_popup_visible() -> bool:
	for control: Node in hud.root.find_children("*","OptionButton",true,false):
		if (control as OptionButton).get_popup().visible: return true
	return false

func _camera_keyboard_blocked() -> bool:
	return get_viewport().gui_get_focus_owner() != null or _camera_popup_visible()

func observer_frame() -> Dictionary:
	var subject: String = camera.followed_id
	if subject.is_empty() and get("camera_subject") is String: subject = str(get("camera_subject"))
	if subject.is_empty() and session.presentation_units.has("bomber"): subject = "bomber"
	if not models.has(subject): return {}
	var model: Node3D = models[subject]
	var point: Vector2 = camera.unproject_position(model.global_position)
	return {"id":subject,"generation":session.world.generation,"tick":session.world.tick,"presentation_time_s":session.presentation_time_s,"alpha":session.presentation_alpha,"model_m":SimData.array3(model.global_position),"focus_m":SimData.array3(camera.focus),"camera_m":SimData.array3(camera.position),"screen_px":[point.x,point.y],"viewport_px":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]}

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

func _create_effects() -> CombatEffects:
	return CombatEffects.new()
