extends SceneTree

const QINGJIA_TEXT: Script = preload("res://scripts/showcase/qingjia/report_text.gd")

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("run")

func check(passed: bool, label: String) -> void:
	if not passed:
		failures.append(label)
		push_error("QJ01 observer: " + label)

func _menu_item(menu: OptionButton, title_prefix: String) -> int:
	for index: int in range(menu.item_count):
		if menu.get_item_text(index).begins_with(title_prefix): return index
	return -1

func _button(node: Node, title: String) -> Button:
	if node is Button and (node as Button).text == title: return node as Button
	for child: Node in node.get_children():
		var found: Button = _button(child, title)
		if found != null: return found
	return null

func run() -> void:
	var game := preload("res://showcase/carrier_harbor.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	check(game.running and game.exercise == "harbor" and game.session.units.size() == 27 and game.session.qingjia_mission == null, "default harbor remains a 27-unit non-mission scenario")
	var selector: OptionButton = game.hud.selector
	var harbor_subject: String = str(selector.get_item_metadata(selector.selected))
	var menu: OptionButton = game.segment_menu
	var mission_index: int = _menu_item(menu, "青岬归航 · 双机回收")
	var harbor_index: int = _menu_item(menu, "港湾实战观战")
	var training_index: int = _menu_item(menu, "F6F 训练")
	var fighter_index: int = _menu_item(menu, "单机自主空战观察")
	var report_button: Button = _button(game.hud.root, "战报")
	var finish_button: Button = _button(game.hud.root, "结束")
	var restart_button: Button = _button(game.hud.root, "重开")
	check(mission_index > harbor_index and harbor_index >= 0 and training_index >= 0 and fighter_index >= 0, "mission is appended without replacing the old entries")
	check(report_button != null and finish_button != null and restart_button != null, "HUD buttons remain connected")
	if not failures.is_empty():
		game.free()
		quit(1)
		return
	menu.item_selected.emit(mission_index)
	check(game.exercise == "qingjia" and game.session.qingjia_mission != null and game.models.size() == 12 and game.hud.selector.item_count == 12, "selecting the mission loads its own models and unit selector")
	check(selector.get_item_metadata(selector.selected) == "us_cv" and game.camera.followed_id == "us_cv", "mission entry selects the carrier actually followed by the camera")
	check("东侧外海撤离区：距边缘 10.75 公里" in game.operation_text.text and "已回收且仍在舰 0/2" in game.operation_text.text and not game.hud.report_panel.visible, "brief shows the distance to the exit boundary without premature adjudication")
	for index: int in range(selector.item_count):
		if selector.get_item_metadata(index) != "us_deck_1": continue
		selector.select(index)
		selector.item_selected.emit(index)
		break
	game._process(0.0)
	check(selector.get_item_metadata(selector.selected) == "us_deck_1" and game.camera.followed_id == "us_deck_1", "manual aircraft selection survives the next refresh")
	report_button.pressed.emit()
	var report: String = game.hud.report_text.text
	check(game.hud.report_panel.visible and "尚未结算" in report and "东侧外海撤离区：距边缘 10.75 公里" in report, "report shows the ongoing mission and the exit distance")
	check("F6F · 青岬一号：在埃塞克斯甲板，尚未起飞" in report.split("\n") and "F6F · 青岬二号：在埃塞克斯甲板，尚未起飞" in report.split("\n"), "each initial aircraft row is one plain-language status")
	check("qj01:" not in report and "舰位 (" not in report and "22550" not in report, "player report omits internal order IDs and coordinates")
	var sample: Dictionary = game.session.qingjia_mission.report(game.session.world)
	sample.merge({"status":"partial", "reason":"exit_reached", "aboard_count":1, "withdrawn_count":1}, true)
	sample.airframes[0].merge({"launch_tick":1365, "recovery_tick":24214, "status":"recovered_aboard", "withdrew":true}, true)
	sample.airframes[1].merge({"launch_tick":3133, "status":"unknown", "last_known":"go_around", "last_known_tick":35273}, true)
	report = QINGJIA_TEXT.report_body(sample, game.hud.names)
	check("东侧外海撤离区：已到区" in report and "起飞 00:22 · 回收 06:43 · 已随舰撤出" in report and "去向未明（最后可知 09:47：复飞中）" in report, "report retains real times, withdrawal and last known go-around")
	sample.airframes[1].status = "lost"
	check("起飞 00:52 · 已确认损失" in QINGJIA_TEXT.report_body(sample, game.hud.names), "confirmed loss is still explicit")
	finish_button.pressed.emit()
	check("任务中断" in game.hud.report_text.text and game.session.world.paused, "finish button reports interruption")
	restart_button.pressed.emit()
	check("尚未结算" in game.hud.report_text.text and not game.hud.report_panel.visible and not game.session.world.paused, "restart clears the battle report and resumes")
	check(selector.get_item_metadata(selector.selected) == "us_cv" and game.camera.followed_id == "us_cv", "restart restores the carrier selection")
	menu.item_selected.emit(harbor_index)
	check(game.exercise == "harbor" and game.session.units.size() == 27 and game.models.size() == 27 and game.session.qingjia_mission == null, "returning to harbor restores its original roster and report")
	check(selector.get_item_metadata(selector.selected) == harbor_subject, "normal harbor retains its original default selection")
	menu.item_selected.emit(training_index)
	check(game.exercise == "train_us_bank_turn" and game.session.qingjia_mission == null, "F6F training entry still loads")
	menu.item_selected.emit(fighter_index)
	check(game.exercise == "maneuver" and game.fighter_camera_button.visible and game.session.qingjia_mission == null, "autonomous fighter entry and camera remain reachable")
	game.free()
	print(JSON.stringify({"suite":"QJ01 observer menu", "failures":failures}))
	quit(0 if failures.is_empty() else 1)
