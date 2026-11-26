class_name WebRunProbe
extends RefCounted

## Opt-in observer. Never advances the world or dispatches commands.
var game: FirstPlayableGame
var enabled: bool = false
var frames: Array = []
var elapsed_s: float = 0.0
var capture_pending: bool = false
var ui_elapsed_s: float = 0.0
var events: Array = []

func consume(source: Array[BattleEvent]) -> void:
	if not enabled: return
	for event: BattleEvent in source:
		if event.kind in ["fired", "damaged", "damage_phase", "aircraft_part_detached", "unit_impact", "surface_impact", "airburst", "aircraft_exit"]:
			events.append({"sequence":event.sequence,"time_s":event.time_s,"generation":game.session.generation,
				"kind":event.kind,"entity_id":event.entity_id,"target_id":event.target_id,"weapon_id":event.weapon_id,
				"position_m":event.position_m,"data":event.data})

func _init(owner: FirstPlayableGame) -> void:
	game = owner
	if OS.has_feature("web"):
		enabled = bool(JavaScriptBridge.eval("typeof window.S08 !== 'undefined'", true))

func observe(delta_s: float, advance_us: int, presentation_us: int, camera_us: int, hud_us: int) -> void:
	if not enabled: return
	var session: FirstPlayableSession = game.session
	session.world.profile_enabled = true
	ui_elapsed_s += delta_s
	if ui_elapsed_s >= 0.1:
		ui_elapsed_s = 0.0
		JavaScriptBridge.eval("window.S08.ui(" + JSON.stringify(_ui_snapshot()) + ")", true)
	frames.append([delta_s * 1000.0, session.world.time_s(), advance_us / 1000.0, presentation_us / 1000.0, camera_us / 1000.0, hud_us / 1000.0, session.world.pending_time_s()])
	elapsed_s += delta_s
	if elapsed_s < 1.0: return
	elapsed_s = 0.0
	var mounts: int = 0
	var active: int = 0
	var moving: int = 0
	for unit: Dictionary in session.units.values():
		mounts += unit.weapons.size()
		if unit.active: active += 1
		if unit.active and (unit.velocity_mps as Vector3).length() > 0.5: moving += 1
	var projectile_count: int = 0
	var projectile_peak: int = 0
	for module: SimulationModule in session.world._modules:
		if module is CombatProjectiles:
			projectile_count = module.rounds.size()
			projectile_peak = module.peak_active
	var result: Dictionary = {"frames":frames, "generation":session.generation, "tick":session.world.tick,
		"sim_s":session.world.time_s(), "pending_s":session.world.pending_time_s(), "paused":session.world.paused,
		"speed":session.world.time_scale, "ended":session.ended_reason, "counts":session.counts,
		"units":session.units.size(), "active_units":active, "moving_units":moving, "mounts":mounts, "projectiles":projectile_count,
		"projectile_peak":projectile_peak, "effects":game.effects.statistics(), "orders":session.orders.size(),
		"camera":{"mode":game.camera.mode, "id":game.camera.followed_id, "shot":game.camera.shot_serial,
			"label":game.camera.shot_label, "yaw":game.camera.yaw, "pitch":game.camera.pitch,
			"position":game.camera.position, "focus":game.camera.focus, "distance_m":game.camera.distance_m},
		"ui":{"expanded":game.hud.expanded, "cinema":game.hud.cinema, "report":game.hud.report_panel.visible,
			"detail":game.hud.detail.text, "selected_order":game.hud.selected_order.get("order_id", "")},
		"sound":game.effects.sound_enabled, "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"static_memory_bytes":OS.get_static_memory_usage(), "static_memory_available":not OS.has_feature("web"),
		"render_buffer":game.get_viewport().get_visible_rect().size,
		"report":session.report(), "last_sequence":session.last_sequence}
	result["profile_us"] = session.world.profile_us.duplicate()
	result["profile_calls"] = session.world.profile_calls.duplicate()
	result["events"] = events
	result["fragments"] = AircraftAdapter.live_fragment_nodes
	result["node_count"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	session.world.profile_us.clear()
	session.world.profile_calls.clear()
	events = []
	frames = []
	var requested: bool = bool(JavaScriptBridge.eval("window.S08.accept(" + JSON.stringify(result) + ")", true))
	if requested and not capture_pending:
		capture_pending = true
		_capture()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var bytes: PackedByteArray = game.get_viewport().get_texture().get_image().save_png_to_buffer()
	JavaScriptBridge.eval("window.S08.image('" + Marshalls.raw_to_base64(bytes) + "')", true)
	capture_pending = false

func _ui_snapshot() -> Dictionary:
	var hud: ObserverHud = game.hud
	var result: Dictionary = {"generation":game.session.generation,"tick":game.session.world.tick,
		"time_s":game.session.world.time_s(),"paused":game.session.world.paused,"speed":game.session.world.time_scale,
		"pending_s":game.session.world.pending_time_s(),"sound":game.effects.sound_enabled,"models":game.models.size(),
		"camera_mode":game.camera.mode,"followed_id":game.camera.followed_id,"yaw":game.camera.yaw,"pitch":game.camera.pitch,
		"ui":{"cinema":hud.cinema,"expanded":hud.expanded,"detail":hud.detail.text,"status":hud.status.text,
			"report":hud.report_panel.visible,"report_text":hud.report_text.text,"timeline":hud.timeline_panel.visible,
			"both_cards":hud.cards.jp.is_visible_in_tree() and hud.cards.us.is_visible_in_tree()},
		"controls":{"unit":_center(hud.selector),"speed":_center(hud.speeds),"map":_center(hud.map)},
		"popups":{"unit":_popup(hud.selector),"speed":_popup(hud.speeds)},"buttons":{},"timeline_buttons":[],
		"effects":game.effects.statistics(),"fragments":AircraftAdapter.live_fragment_nodes,"ended":game.session.ended_reason}
	for child: Node in hud.root.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.is_visible_in_tree(): result.buttons[button.text] = _center(button)
	for child: Node in hud.timeline_rows.get_children():
		if child is Button: result.timeline_buttons.append(_center(child))
	if game is AllUnitsShowcase:
		var showcase: AllUnitsShowcase = game
		result["exercise"] = showcase.exercise
		result["modes"] = showcase.MODES
		result["label"] = showcase.guide_status.text
		result["gallery_index"] = showcase.guide.selected_gallery
		result.controls["segment"] = _center(showcase.segment_menu)
		result.controls["weapon"] = _center(showcase.weapon_menu)
		result.popups["segment"] = _popup(showcase.segment_menu)
		result.popups["weapon"] = _popup(showcase.weapon_menu)
	return result

func _center(control: Control) -> Array:
	var point: Vector2 = control.get_global_rect().get_center()
	return [point.x,point.y]

func _popup(control: OptionButton) -> Dictionary:
	var popup: PopupMenu = control.get_popup()
	var metadata: Array = []
	for index: int in control.item_count: metadata.append(control.get_item_metadata(index))
	return {"visible":popup.visible,"position":[popup.position.x,popup.position.y],"size":[popup.size.x,popup.size.y],"count":popup.item_count,"metadata":metadata}
