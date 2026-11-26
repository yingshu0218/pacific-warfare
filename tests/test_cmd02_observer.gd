extends "res://tests/fixtures/combat_test.gd"

const HARBOR: PackedScene = preload("res://showcase/carrier_harbor.tscn")
const OUT: String = "res://docs/showcase/evidence/CMD02"

func run_test() -> void:
	var capture: bool = DisplayServer.get_name() != "headless"
	if capture:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		AudioServer.set_bus_mute(0, true)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var game: AllUnitsShowcase = HARBOR.instantiate() as AllUnitsShowcase
	root.add_child(game)
	game.set_process(false)
	expect(game.running, "Normal 720p harbor launches")
	if not game.running:
		game.queue_free()
		finish("CMD02 observer")
		return
	for i: int in 240:
		game._process(1.0 / 30.0)
	var hud: ObserverHud = game.hud
	var restore: Button = _button(hud.root, "恢复信息")
	if restore != null:
		restore.pressed.emit()
	game._refresh_guide_ui()
	var selected_index: int = -1
	for index: int in hud.selector.item_count:
		if hud.selector.get_item_metadata(index) == "jp_bb":
			selected_index = index
			break
	if selected_index >= 0:
		hud.selector.select(selected_index)
		hud.selector.item_selected.emit(selected_index)
	await process_frame
	expect(hud.unit_detail.is_visible_in_tree() and hud.unit_detail.text.contains("主炮") and hud.unit_detail.text.contains("防空炮"), "Selected ship exposes actual mount groups")
	expect(hud.unit_detail.text.contains(hud.names["us_bb"]), "Actual flagship target is present in the selected Yamato summary")
	expect(not hud.cards.us.get_global_rect().intersects(hud.map.get_global_rect())
		and not hud.cards.jp.get_global_rect().intersects(hud.unit_detail.get_global_rect())
		and hud.map_selector.get_global_rect().end.x <= 1280.0, "720p compact cards fit above the map and unit summary")
	if capture:
		_capture("720p-harbor.png")
	var command_button: Button = _button(hud.root, "指挥态势")
	expect(command_button != null and command_button.is_visible_in_tree(), "Normal command panel entry is available")
	command_button.pressed.emit()
	game._refresh_guide_ui()
	hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
	await process_frame
	expect(hud.expanded and hud.timeline_panel.visible and hud.cards_scroll.visible, "Normal command action opens both sides and timeline")
	for faction: String in ["jp", "us"]:
		for post: String in BattleOrder.COMMAND_POSTS:
			var label: Label = hud.post_labels[faction][post]
			expect(label.is_visible_in_tree() and hud.cards_scroll.get_global_rect().encloses(label.get_global_rect())
				and label.text == ObserverText.post_status(post, game.session.command_postures[faction][post]),
				"Actual posture and Chinese reason are visible for %s/%s" % [faction, post])
	var timeline: String = ""
	var aviation_row: Button
	for node: Node in hud.timeline_rows.get_children():
		var button: Button = node as Button
		timeline += button.text + "\n"
		if aviation_row == null and button.text.contains("航空指挥官") and button.text.contains("轰炸任务"):
			aviation_row = button
	expect(timeline.contains("舰队指挥官") and timeline.contains("航空指挥官"), "Timeline rows identify both command posts")
	expect(timeline.contains("已下达") and timeline.contains("执行中"), "Timeline contains observed orders and real execution changes")
	expect(aviation_row != null, "Real aviation bombing record is selectable")
	if aviation_row != null:
		aviation_row.pressed.emit()
		hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
		expect(hud.detail.text.contains("航空指挥官") and hud.detail.text.contains("下达") and hud.detail.text.contains("接收"),
			"Selected record retains issuer, dispatch and receipt timing")
	await process_frame
	var cards: Rect2 = hud.cards_scroll.get_global_rect()
	var history: Rect2 = hud.timeline_panel.get_global_rect()
	var unit: Rect2 = hud.unit_detail.get_global_rect()
	expect(not cards.intersects(history) and not history.intersects(unit) and history.end.x <= 1280.0 and unit.end.y < 720.0,
		"720p cards, timeline and unit summary occupy separate regions")
	if capture:
		_capture("720p-command.png")
	_check_fast_restart(game)
	game.queue_free()
	await process_frame
	finish("CMD02 observer")

func _check_fast_restart(game: AllUnitsShowcase) -> void:
	var hud: ObserverHud = game.hud
	var world: SimulationWorld = game.session.world
	var flagship_order: String = world.get_unit("jp_bb").active_order_id
	while world.tick < 90 * world.tick_hz and int(world.order_snapshot(flagship_order, "jp").get("changed_tick", -1)) < world.tick_hz:
		world.step_ticks(world.tick_hz)
		game.session.consume_world()
	hud.refresh(game.session, game.camera.mode, game.camera.shot_label)
	var previous: Button = _flagship_card(hud)
	var previous_entry: Button = hud.timeline_rows.get_child(0) as Button if hud.timeline_rows.get_child_count() > 0 else null
	var restart: Button = _button(hud.root, "重开")
	expect(previous != null and previous_entry != null and restart != null, "Previous battle has a flagship card, a timeline row, and the restart control")
	if previous == null or previous_entry == null or restart == null:
		return
	var located: Array[Dictionary] = []
	hud.order_selected.connect(func(record: Dictionary, _target: bool) -> void: located.append(record))
	previous.pressed.emit()
	var old_record: Dictionary = hud.selected_order.duplicate(true)
	var old_changed_tick: int = int(old_record.get("changed_tick", -1))
	var generation: int = game.session.generation
	expect(old_changed_tick > int(old_record.get("received_tick", -1)), "Previous fleet order has execution changes after receipt")
	restart.pressed.emit()
	expect(game.session.generation > generation and game.session.world.tick == 0, "Restart control starts a fresh battle synchronously")
	expect(hud.card_rows.jp.find_children("*", "Button", false, false).is_empty()
		and hud.card_rows.us.find_children("*", "Button", false, false).is_empty()
		and hud.timeline_rows.get_child_count() == 0, "Restart removes previous order buttons from both sides and the timeline immediately")
	located.clear()
	previous.pressed.emit()
	previous_entry.pressed.emit()
	expect(located.is_empty() and hud.selected_order.is_empty() and not hud.detail.text.contains("最近变化"),
		"A same-frame callback from a detached order or history button cannot select a previous-battle order")
	for i: int in 3:
		game._process(1.0 / 30.0)
	expect(_flagship_card(hud) == null and hud.selected_order.is_empty(), "At 0.1 seconds no stale flagship order can be clicked while the new view catches up")
	var current: Button = _flagship_card(hud)
	for i: int in 30:
		if current != null:
			break
		game._process(1.0 / 30.0)
		current = _flagship_card(hud)
	expect(current != null, "First new flagship order becomes clickable")
	if current == null:
		return
	located.clear()
	previous.pressed.emit()
	expect(located.is_empty(), "Even after the order ID is reused, an old callback cannot select the new order")
	current.pressed.emit()
	var tick: int = game.session.world.tick
	var record: Dictionary = hud.selected_order
	expect(located.size() == 1 and record.get("order_id") == old_record.get("order_id"), "The first new flagship order reuses the old ID and selects correctly")
	expect(int(record.get("issued_tick", -1)) >= 0 and int(record.get("issued_tick", -1)) <= tick
		and int(record.get("received_tick", -1)) >= 0 and int(record.get("received_tick", -1)) <= tick
		and int(record.get("changed_tick", -1)) >= 0 and int(record.get("changed_tick", -1)) <= tick and old_changed_tick > tick,
		"The selected new order's issue, receipt and change times are in the new battle")
	print("CMD02 restart reuses ", record.get("order_id"), ", prior change tick ", old_changed_tick,
		", new change tick ", record.get("changed_tick"), ", selected at new tick ", tick)

func _flagship_card(hud: ObserverHud) -> Button:
	for node: Node in hud.card_rows.jp.get_children():
		var row: Button = node as Button
		if row != null and row.text.begins_with("舰队指挥官") and row.text.contains(str(hud.names.jp_bb) + " →"):
			return row
	return null

func _capture(filename: String) -> void:
	RenderingServer.force_draw(false, 0)
	var result: Error = root.get_texture().get_image().save_png(OUT.path_join(filename))
	expect(result == OK, "Native screenshot " + filename)

func _button(node: Node, label: String) -> Button:
	for child: Node in node.find_children("*", "Button", true, false):
		if (child as Button).text == label:
			return child as Button
	return null
