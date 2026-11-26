extends SceneTree

var failures: PackedStringArray = []
var game: FirstPlayableGame

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func tick(count: int) -> Array[BattleEvent]:
	var all_events: Array[BattleEvent] = []
	for index: int in range(count):
		game.session.world.step_ticks(1)
		var events: Array[BattleEvent] = game.session.consume_world()
		game.apply_presentation(events)
		all_events.append_array(events)
	return all_events

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game = (load("res://showcase/open_sea.tscn") as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	check(game.running, "scene loads")
	if not game.running: finish(); return
	tick(120)
	var initial_counts: Dictionary = game.session.counts.duplicate()
	var initial_sequence: int = game.session.last_sequence
	var initial_orders: int = game.session.orders.size()
	game.hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
	await process_frame
	check(game.models.size() == 12 and game.session.units.size() == 12, "actual scene assembly")
	check(game.hud.cards.jp.get_global_rect().end.x < game.hud.cards.us.get_global_rect().position.x, "720p default cards do not overlap")
	var fixed_tick: int = game.session.world.tick
	game.hud.pause_button.pressed.emit()
	game._process(2.0)
	check(game.session.world.tick == fixed_tick, "pause button prevents clock advance")
	game.hud.pause_button.pressed.emit()
	game._process(1.0 / 60.0)
	check(game.session.world.tick == fixed_tick + 1, "continue button resumes")
	var current: Dictionary = game.session.orders[0]
	game.hud._select(current)
	game.hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
	await process_frame
	check(game.hud.timeline_panel.visible and game.camera.mode == "free", "command selection opens timeline and locates")
	check(game.hud.cards_scroll.get_global_rect().end.x + 10 <= game.hud.timeline_panel.get_global_rect().position.x, "720p columns do not overlap")
	check(game.hud.cards_scroll.get_global_rect().end.y < game.hud.unit_detail.get_global_rect().position.y, "720p scroll above unit details")
	check(game.hud.timeline_panel.get_global_rect().end.y < game.hud.unit_detail.get_global_rect().position.y, "720p timeline above unit details")
	check(game.hud.detail.text.contains("下达") and game.hud.detail.text.contains("接收"), "lifecycle times shown")
	for button: Node in game.hud.root.find_children("*", "Button", true, false):
		var control: Control = button as Control
		if not control.is_visible_in_tree() or game.hud.timeline_rows.is_ancestor_of(control) or game.hud.cards_scroll.is_ancestor_of(control): continue
		check(control.get_global_rect().end.x <= 1280.5, "button stays inside width: " + str(button.text))
	game.hud.cinema = true
	game.hud._layout()
	check(not game.hud.cards.jp.visible and not game.hud.timeline_panel.visible, "cinema hides info")
	game.hud.cinema = false
	game.hud._layout()
	check(game.hud.cards.jp.visible and game.hud.timeline_panel.visible, "cinema restores info")
	game._action("follow", "us_air_1")
	check(game.camera.mode == "follow" and game.camera.followed_id == "us_air_1", "unit follow")
	game._action("camera", "auto")
	check(game.camera.mode == "auto", "restore auto camera")
	game.hud.root.hide()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(640, 360)
	Input.parse_input_event(press)
	await process_frame
	var yaw_before: float = game.camera.yaw
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(658, 363)
	motion.relative = Vector2(18, 3)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion)
	await process_frame
	var first_yaw: float = game.camera.yaw
	Input.parse_input_event(motion)
	await process_frame
	check(game.camera.mode == "free" and not is_equal_approx(first_yaw, yaw_before) and not is_equal_approx(game.camera.yaw, first_yaw), "right drag continues through auto takeover")
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	var released_yaw: float = game.camera.yaw
	Input.parse_input_event(motion)
	await process_frame
	check(is_equal_approx(game.camera.yaw, released_yaw), "right release ends drag")
	game.camera.follow("jp_bb")
	Input.parse_input_event(press)
	await process_frame
	var follow_yaw: float = game.camera.yaw
	Input.parse_input_event(motion)
	await process_frame
	var follow_first_yaw: float = game.camera.yaw
	Input.parse_input_event(motion)
	await process_frame
	check(game.camera.mode == "follow" and game.camera.followed_id == "jp_bb" and not is_equal_approx(follow_first_yaw, follow_yaw) and not is_equal_approx(game.camera.yaw, follow_first_yaw), "right drag continuously orbits followed unit")
	Input.parse_input_event(release)
	await process_frame
	game.hud.root.show()
	var fired: Array[BattleEvent] = []
	for index: int in range(600):
		fired = tick(1)
		if fired.any(func(e: BattleEvent) -> bool: return e.kind == "salvo"): break
	var before: Dictionary = game.session.world.snapshot()
	var markers: Dictionary = {}
	for id: String in game.recoils:
		var model: Node3D = game.models[id]
		for socket: Dictionary in model.mount_sockets(): markers[id + "/" + socket.id] = model.muzzle_transform_global(socket.id, 0)
	for recoil: VisualRecoil in game.recoils.values(): recoil.advance(0.1)
	check(game.session.world.snapshot() == before, "visual recoil cannot change world")
	for id: String in game.recoils:
		var model: Node3D = game.models[id]
		for socket: Dictionary in model.mount_sockets(): check(model.muzzle_transform_global(socket.id, 0).is_equal_approx(markers[id + "/" + socket.id]), "recoil preserves muzzle contract")
	for index: int in range(3):
		game._action("restart", null)
		check(game.session.units.size() == 12 and game.models.size() == 12, "scene reset keeps all units")
		check(game.session.orders.is_empty() and game.session.journal.is_empty(), "scene reset clears history")
		for recoil: VisualRecoil in game.recoils.values():
			for mount: Dictionary in recoil.mounts.values():
				for piece: Dictionary in mount.pieces: check((piece.node as Node3D).position.is_equal_approx(piece.rest), "recoil rest after reset")
		tick(120)
		check(game.session.last_sequence == initial_sequence and game.session.orders.size() == initial_orders and game.session.counts == initial_counts, "no duplicate restart events or orders")
	game.hud.speeds.select(3)
	game.hud.speeds.item_selected.emit(3)
	for index: int in range(game.hud.selector.item_count):
		if game.hud.selector.get_item_metadata(index) == "us_air_3":
			game.hud.selector.select(index)
			game.hud.selector.item_selected.emit(index)
	game.hud.pause_button.pressed.emit()
	check(game.session.world.time_scale == 4.0 and game.session.world.paused and game.hud._selected_unit == "us_air_3", "UI selects four-times speed, followed unit and pause")
	var restart_button: Button
	for node: Node in game.hud.root.find_children("*", "Button", true, false):
		if node.text == "重开": restart_button = node as Button
	check(restart_button != null, "restart button exists")
	if restart_button != null: restart_button.pressed.emit()
	check(game.session.world.time_scale == 1.0 and game.hud.speeds.selected == 1, "restart synchronizes speed selector with world")
	check(not game.session.world.paused and game.hud.pause_button.text == "暂停", "restart synchronizes pause label")
	check(game.hud._selected_unit == "jp_bb" and game.hud.selector.get_item_metadata(game.hud.selector.selected) == "jp_bb", "restart synchronizes unit selector")
	var font: Font = game.hud.root.theme.default_font
	for letter: String in "指挥态势巡逻接收执行拦截撤离损伤舰队僚机火情余油零战衣阿华": check(font.has_char(letter.unicode_at(0)), "bundled CJK glyph")
	finish()

func finish() -> void:
	for failure: String in failures: push_error("S07 UI: " + failure)
	print("S07 scene UI checks: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
