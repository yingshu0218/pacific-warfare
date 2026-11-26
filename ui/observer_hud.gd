class_name ObserverHud
extends CanvasLayer

const QINGJIA_TEXT: Script = preload("res://scripts/showcase/qingjia/report_text.gd")

signal action(kind: String, value: Variant)
signal order_selected(record: Dictionary, target: bool)

const TIMELINE_ROWS: int = 100
const TIMELINE_EXECUTION_ROWS: int = 24

var root: Control
var cards: Dictionary = {}
var post_labels: Dictionary = {}
var card_rows: Dictionary = {}
var card_scrollers: Dictionary = {}
var names: Dictionary = {}
var timeline_panel: PanelContainer
var timeline_rows: VBoxContainer
var detail: Label
var unit_detail: Label
var report_panel: PanelContainer
var report_text: Label
var status: Label
var shot: Label
var camera_hint: Label
var pause_button: Button
var sound_button: Button
var cinema_button: Button
var map_selector: OptionButton
var map_data: Dictionary = {}
var selector: OptionButton
var speeds: OptionButton
var map: ObserverMap
var cards_scroll: ScrollContainer
var cards_column: VBoxContainer
var expanded: bool = false
var cinema: bool = false
var selected_order: Dictionary = {}
var _journal_sequence: int = -1
var _orders_signature: String = ""
var _order_view_generation: int = 0
var _selected_unit: String = "jp_bb"
var _order_map: Dictionary = {}

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme_value: Theme = Theme.new()
	theme_value.default_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	theme_value.default_font_size = 16
	theme_value.set_color("font_color", "Label", Color("e2edf1"))
	theme_value.set_color("font_color", "Button", Color("e2edf1"))
	theme_value.set_stylebox("normal", "Button", _style(Color("172d3b"), Color("426172"), 7))
	theme_value.set_stylebox("hover", "Button", _style(Color("284757"), Color("7abac4"), 7))
	theme_value.set_stylebox("pressed", "Button", _style(Color("365b67"), Color("c4ddc3"), 7))
	root.theme = theme_value
	var header: HBoxContainer = HBoxContainer.new()
	_place(header, 24, 18, -24, 76, 0, 0, 1, 0)
	root.add_child(header)
	var title: Label = _label("海空交锋", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	status = _label("正在装配战场", 17)
	header.add_child(status)
	cards_scroll = ScrollContainer.new()
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(cards_scroll)
	cards_column = VBoxContainer.new()
	cards_column.add_theme_constant_override("separation", 12)
	cards_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_scroll.add_child(cards_column)
	for faction: String in ["jp", "us"]:
		var panel: PanelContainer = _panel()
		root.add_child(panel)
		cards[faction] = panel
		var content: VBoxContainer = VBoxContainer.new()
		content.add_theme_constant_override("separation", 7)
		panel.add_child(content)
		var heading: Label = _label(ObserverText.faction(faction), 19)
		heading.add_theme_color_override("font_color", Color("efbe92") if faction == "jp" else Color("8ec9ee"))
		content.add_child(heading)
		post_labels[faction] = {}
		for post: String in BattleOrder.COMMAND_POSTS:
			var post_label: Label = _label(ObserverText.post_status(post, {}), 14)
			post_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(post_label)
			post_labels[faction][post] = post_label
		card_rows[faction] = VBoxContainer.new()
		var order_scroll: ScrollContainer = ScrollContainer.new()
		order_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		order_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		order_scroll.custom_minimum_size.y=248
		content.add_child(order_scroll)
		card_scrollers[faction]=order_scroll
		card_rows[faction].size_flags_horizontal=Control.SIZE_EXPAND_FILL
		order_scroll.add_child(card_rows[faction])
		var waiting: Label = _label("正在等待真实指挥命令", 14)
		card_rows[faction].add_child(waiting)
	timeline_panel = _panel()
	root.add_child(timeline_panel)
	_place(timeline_panel, -650, 90, -24, -155, 1, 0, 1, 1)
	var timeline_box: VBoxContainer = VBoxContainer.new()
	timeline_box.add_theme_constant_override("separation", 8)
	timeline_panel.add_child(timeline_box)
	timeline_box.add_child(_label("指挥态势 · 双方指令", 22))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	timeline_box.add_child(scroll)
	timeline_rows = VBoxContainer.new()
	timeline_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_rows.add_theme_constant_override("separation", 7)
	scroll.add_child(timeline_rows)
	detail = _label("选择一条指令查看各成员执行进度。", 14)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var selected_scroll: ScrollContainer = ScrollContainer.new()
	selected_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selected_scroll.custom_minimum_size.y = 104
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_scroll.add_child(detail)
	timeline_box.add_child(selected_scroll)
	var locations: HBoxContainer = HBoxContainer.new()
	timeline_box.add_child(locations)
	_button(locations, "定位受令编组", func() -> void: order_selected.emit(selected_order, false))
	_button(locations, "定位任务目标", func() -> void: order_selected.emit(selected_order, true))
	var tools: HBoxContainer = HBoxContainer.new()
	_place(tools, 24, -62, -24, -18, 0, 1, 1, 1)
	tools.add_theme_constant_override("separation", 6)
	tools.add_theme_font_size_override("font_size", 14)
	root.add_child(tools)
	pause_button = _button(tools, "暂停", func() -> void: action.emit("pause", null))
	speeds = OptionButton.new()
	for label_value: String in ["0.5 倍", "1 倍", "2 倍", "4 倍"]: speeds.add_item(label_value)
	speeds.select(1)
	speeds.item_selected.connect(func(index: int) -> void: action.emit("speed", [0.5, 1.0, 2.0, 4.0][index]))
	tools.add_child(speeds)
	_button(tools, "自动电影", func() -> void: action.emit("camera", "auto"))
	var free_button: Button = _button(tools, "自由观察", func() -> void: action.emit("camera", "free"))
	free_button.tooltip_text = "右键拖动环视；WASD / 方向键平移，Q/E 升降，Shift 加速。滚轮缩放并调整移速，C 恢复自动。"
	selector = OptionButton.new()
	selector.custom_minimum_size.x = 135
	tools.add_child(selector)
	selector.item_selected.connect(func(index: int) -> void: _selected_unit = selector.get_item_metadata(index); action.emit("follow", _selected_unit))
	_button(tools, "跟随", func() -> void: action.emit("follow", _selected_unit))
	_button(tools, "指挥态势", func() -> void:
		expanded = cinema or not expanded
		cinema = false
		_layout())
	cinema_button = _button(tools, "收起信息", func() -> void: cinema = not cinema; _layout())
	sound_button = _button(tools, "启用声音", func() -> void: action.emit("sound", null))
	_button(tools, "战报", func() -> void: report_panel.visible = not report_panel.visible)
	_button(tools, "结束", func() -> void: action.emit("finish", null))
	_button(tools, "重开", func() -> void: action.emit("restart", null))
	unit_detail = _label("", 14)
	unit_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_detail.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(unit_detail, 24, -223, -440, -95, 0, 1, 1, 1)
	root.add_child(unit_detail)
	shot = _label("", 14)
	_place(shot, -430, -122, -24, -97, 1, 1, 1, 1)
	shot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(shot)
	camera_hint = _label("拖动或移动即可接管 · 右键环视 · WASD / 方向键平移 · Q/E 升降 · Shift 加速 · 滚轮缩放与移速",12)
	_place(camera_hint,24,-87,-24,-65,0,1,1,1)
	camera_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(camera_hint)
	map = ObserverMap.new()
	_place(map, -262, -328, -24, -115, 1, 1, 1, 1)
	root.add_child(map)
	map.point_selected.connect(func(id: String) -> void: action.emit("map_location", id))
	map_selector = OptionButton.new()
	map_selector.custom_minimum_size.x = 110
	map_selector.fit_to_longest_item = false
	tools.add_child(map_selector)
	map_selector.item_selected.connect(func(index: int) -> void: action.emit("map_location",map_selector.get_item_metadata(index)))
	map_selector.hide()
	map.unit_selected.connect(func(id: String) -> void: _selected_unit = id; action.emit("follow", id))
	report_panel = _panel()
	report_panel.z_index=20
	_place(report_panel, -310, -200, 310, 160, 0.5, 0.5, 0.5, 0.5)
	root.add_child(report_panel)
	var report_box: VBoxContainer = VBoxContainer.new()
	report_panel.add_child(report_box)
	report_box.add_child(_label("本场战报", 25))
	report_text = _label("", 16)
	report_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_box.add_child(report_text)
	_button(report_box, "继续查看战场", func() -> void: report_panel.hide())
	report_panel.hide()
	root.resized.connect(_layout)
	_layout()

func set_terrain(data: Dictionary) -> void:
	map_data = data
	map.terrain = data
	map_selector.clear()
	map_selector.add_item("地图定位")
	map_selector.set_item_metadata(0, "overview")
	for point: Dictionary in data.source.viewpoints:
		map_selector.add_item(point.label)
		map_selector.set_item_metadata(map_selector.item_count-1,point.id)
	map_selector.show()

func reset_hud(session: FirstPlayableSession) -> void:
	names = session.scenario.presentation.names.duplicate(true)
	report_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if session.qingjia_mission != null else TextServer.AUTOWRAP_OFF
	_order_view_generation += 1
	selected_order = {}
	_journal_sequence = -1
	_orders_signature = ""
	_order_map.clear()
	clear_rows(timeline_rows)
	for rows: VBoxContainer in card_rows.values():
		clear_rows(rows)
		rows.add_child(_label("当前没有执行中的指令", 14))
	report_panel.hide()
	selector.clear()
	_selected_unit = "jp_bb" if session.units.has("jp_bb") else str(session.world.unit_ids()[0])
	if session.qingjia_mission != null: _selected_unit = session.qingjia_mission.carrier_id
	for id: String in session.world.unit_ids():
		selector.add_item(names.get(id, "作战单位"))
		selector.set_item_metadata(selector.item_count - 1, id)
		if id == _selected_unit: selector.select(selector.item_count - 1)
	unit_detail.text = ""
	detail.text = "选择一条指令查看各成员执行进度。"
	refresh(session, "自动电影", "")

func refresh(session: FirstPlayableSession, camera_mode: String, camera_label: String) -> void:
	var world: SimulationWorld = session.world
	var speed_index: int = [0.5, 1.0, 2.0, 4.0].find(world.time_scale)
	if speed_index >= 0 and speeds.selected != speed_index: speeds.select(speed_index)
	var definitions: Dictionary = {}
	for id: String in session.units: definitions[id] = session.definition_index[session.units[id].definition_id]
	map.apply_view(session.units, definitions)
	status.text = "%s   %s · %.1f 倍%s" % [ObserverText.time(world.time_s()), "已暂停" if world.paused else "观战中", world.time_scale, " · 正在追赶 %.1f 秒" % world.pending_time_s() if world.pending_ticks() > 3 else ""]
	pause_button.text = "继续" if world.paused else "暂停"
	shot.text = camera_label + " · " + {"auto":"自动电影", "free":"自由观察", "follow":"单位跟随", "fighter":"战斗机跟拍"}.get(camera_mode, "观战")
	for faction: String in post_labels:
		var posts: Dictionary = session.command_postures.get(faction, {})
		for post: String in post_labels[faction]:
			var label: Label = post_labels[faction][post]
			label.text = ObserverText.post_status(post, posts.get(post, {}))
	var signature: String = ""
	for order: Dictionary in session.orders:
		_order_map[order.order_id] = order
		signature += order.order_id + str(order.changed_tick)
	if signature != _orders_signature:
		_orders_signature = signature
		for faction: String in ["jp", "us"]:
			clear_rows(card_rows[faction])
			var active: Array[Dictionary] = []
			for order: Dictionary in session.orders:
				if order.faction_id == faction and not order.status in BattleOrder.TERMINAL: active.append(order)
			if active.is_empty(): card_rows[faction].add_child(_label("当前没有执行中的指令", 14))
			for order: Dictionary in active:
				var row: Button = _button(card_rows[faction], ObserverText.issuer(order) + " · " + ObserverText.STATUSES.get(order.status, "等待回报") + "\n" + ObserverText.order_title(order, names) + "\n" + _compact_execution(order), _select_current_order.bind(order.order_id, _order_view_generation))
				row.add_theme_font_size_override("font_size", 14)
				row.alignment = HORIZONTAL_ALIGNMENT_LEFT
				row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not selected_order.is_empty():
			selected_order = _order_map.get(selected_order.order_id, selected_order)
			show_detail(selected_order, world.tick_hz)
		_layout()
	var sequence: int = int(session.journal[-1].sequence) if not session.journal.is_empty() else 0
	if sequence != _journal_sequence and expanded:
		_journal_sequence = sequence
		clear_rows(timeline_rows)
		var execution_rows: int = 0
		for index: int in range(session.journal.size() - 1, -1, -1):
			var entry: Dictionary = session.journal[index]
			if entry.kind == "order_execution_changed":
				if execution_rows >= TIMELINE_EXECUTION_ROWS: continue
				execution_rows += 1
			var row: Button = _button(timeline_rows, ObserverText.timeline(entry, names), _select_entry.bind(entry, _order_view_generation))
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_theme_font_size_override("font_size", 14)
			if timeline_rows.get_child_count() >= TIMELINE_ROWS: break
	var id: String = _selected_unit
	if session.units.has(id):
		var view: Dictionary = session.units[id]
		var domain: String = session.definition_index[view.definition_id].domain
		var task: Dictionary = view.task.get(domain, {})
		var damage: Dictionary = view.module_data.get("damage", {})
		var ammo: int = 0
		for gun: Dictionary in view.weapons.values():
			for rounds: int in gun.remaining_rounds: ammo += rounds
		var fuel: Dictionary = view.module_data.get("aircraft_motion", {})
		var condition: String = "可战" if view.active else ("已撤离" if fuel.get("exited", false) or view.module_data.get("ship_motion", {}).get("exited", false) else "已退出战斗")
		unit_detail.text = "%s · %s · 航速 %.0f 节%s\n%s · %s\n弹药 %d 发 · 结构 %.0f%% · 火情 %.0f%% / 进水 %.0f%%" % [names[id], condition, (view.velocity_mps as Vector3).length() / 0.514444, " · 余油 %.0f 千克" % float(fuel.fuel_kg) if fuel.has("fuel_kg") else "", ObserverText.phase(task.get("phase", "")), ObserverText.reason(task.get("reason", "")), ammo, 100.0 * float(damage.get("structure", 1)) / maxf(1.0, float(damage.get("structure_max", 1))), 100.0 * float(damage.get("fire", 0)), 100.0 * float(damage.get("flooding", 0))]
		if domain=="ship":
			var ship: Dictionary=damage.get("ship",{})
			var flotation: float=100.0*float(ship.get("flotation",damage.get("structure",1)))/maxf(1,float(ship.get("flotation_max",damage.get("structure_max",1))))
			unit_detail.text="%s · %s · 航速%.0f节\n%s · %s · 余弹%d\n浮力%.0f%% · 结构%.0f%% · 火情%.0f%% / 进水%.0f%%\n%s"%[names[id],ObserverText.ship_condition(damage),(view.velocity_mps as Vector3).length()/.514444,ObserverText.phase(task.get("phase","")),ObserverText.reason(task.get("reason","")),ammo,flotation,100.0*float(damage.get("structure",1))/maxf(1,float(damage.get("structure_max",1))),100.0*float(damage.get("fire",0)),100.0*float(damage.get("flooding",0)),ObserverText.ship_functions(view)]
			var summary: String = ObserverText.ship_gun_groups(view, session.definition_index[view.definition_id].get("gun_groups", {}), names)
			if not summary.is_empty(): unit_detail.text += "\n" + summary
		if domain=="ground":
			var definition: UnitDefinition = session.catalog.unit(view.definition_id)
			condition={"operational":"可战","disabled":"炮组失能","wreck":"已摧毁 · 残骸","removed":"残骸已清除"}.get(damage.get("phase","operational"),"失能")
			unit_detail.text="%s · %s · 固定阵地\n%s · %s · 首服役年待核\n%s · %s · 目标 %s\n弹药 %d 发 · 结构 %.0f%% · 火情 %.0f%%"%[names[id],condition,definition.display_name,definition.configuration_date,ObserverText.phase(task.get("phase","")),ObserverText.reason(task.get("reason","")),names.get(task.get("target_id",""),"等待接触"),ammo,100.0*float(damage.get("structure",1))/maxf(1,float(damage.get("structure_max",1))),100.0*float(damage.get("fire",0))]
			for weapon: Dictionary in view.weapons.values():unit_detail.text+=" · 转向 %.1f° / 仰角 %.1f° · %s"%[rad_to_deg(float(weapon.train_rad)),rad_to_deg(float(weapon.elevation_rad)),"可用" if weapon.enabled else "武器失效"]
		if not fuel.is_empty():
			unit_detail.text += "\n" + ObserverText.maneuver(task, fuel)
		if view.definition_id == "us_b25j_1944_07":
			var runtime: Dictionary = view.module_data.get("combat_runtime", {})
			var status: String = runtime.get("mount_status", {}).get("dorsal", "")
			var station_text: String = {
				"no_contact":"等待接触", "out_of_range":"目标超出范围", "arc":"目标超出转向范围",
				"masked":"机体遮挡", "terrain_masked":"地形遮挡", "traversing":"跟踪中",
				"fired":"正在还击", "reloading":"还击间隔", "disabled":"失能",
				"empty":"弹药用尽", "hold_fire":"停火", "grounded":"地面停放", "capacity":"等待弹道资源"
			}.get(status, "待命")
			var target_id: String = runtime.get("mount_targets", {}).get("dorsal", "")
			unit_detail.text += "\n背部炮塔 · " + station_text
			if not target_id.is_empty():
				unit_detail.text += " · " + str(names.get(target_id, target_id))
	if session.qingjia_mission != null:
		report_text.text = QINGJIA_TEXT.report_body(session.qingjia_mission.report(world), names)
		return
	var report: Dictionary = session.report()
	var lines: PackedStringArray = []
	if not session.ended_reason.is_empty():
		lines.append({"manual":"观众结束观战", "duration":"达到本场展示时长", "force_depleted":"一方已失去继续作战能力", "disengaged":"双方长期脱离接触", "tasks_finished":"所有任务已结束"}.get(session.ended_reason, "本场已结束"))
	else: lines.append("截至 " + ObserverText.time(world.time_s()))
	for faction: String in ["jp", "us"]:
		var row: Dictionary = report[faction]
		lines.append("\n%s\n可战 %d 舰 / %d 机 · 沉没中 %d / 已沉没 %d · 坠毁 %d\n失能 %d · 迫降退出 %d · 撤离 %d\n消耗 %d 发 · 剩余 %d 发 · 耗油 %.1f 千克" % [ObserverText.faction(faction), row.ships, row.aircraft, int(row.get("sinking",0)), row.sunk, row.crashed, row.disabled, row.ditched, row.withdrawn, row.rounds_used, row.rounds_left, row.fuel_used_kg])
		lines.append("岸防 %d 炮组 · 失能 %d · 摧毁 %d"%[row.ground,row.ground_disabled,row.ground_destroyed])
	report_text.text = "\n".join(lines)

func show_detail(record: Dictionary, tick_hz: int = 60) -> void:
	var lines: PackedStringArray = []
	for key: String in ["issued_tick", "received_tick", "changed_tick"]:
		if int(record.get(key, -1)) >= 0: lines.append({"issued_tick":"下达", "received_tick":"接收", "changed_tick":"最近变化"}[key] + " " + ObserverText.time(float(record[key]) / tick_hz))
	detail.text = ObserverText.issuer_name(record) + " · " + ObserverText.STATUSES.get(record.status, "等待回报") + "\n" + ObserverText.order_title(record, names) + "\n" + " · ".join(lines) + "\n" + ObserverText.execution(record, names)

func _select(record: Dictionary) -> void:
	selected_order = record.duplicate(true)
	expanded = true
	cinema = false
	show_detail(record)
	_layout()
	order_selected.emit(record, false)

func _select_current_order(order_id: String, view_generation: int) -> void:
	# Order IDs repeat on restart. A queued UI event still belongs to its old view.
	if view_generation == _order_view_generation and _order_map.has(order_id):
		_select(_order_map[order_id])

func _select_entry(entry: Dictionary, view_generation: int) -> void:
	if view_generation != _order_view_generation:
		return
	if entry.kind == "command_rejected":
		detail.text = ObserverText.timeline(entry, names)
		return
	_select(entry.record)

func _compact_execution(order: Dictionary) -> String:
	var summaries: PackedStringArray = []
	for execution: Dictionary in order.get("execution", {}).values():
		var line: String = ObserverText.reason(execution.get("reason", ""), str(execution.get("progress", "")).get_slice(":", 0))
		if not summaries.has(line): summaries.append(line)
	return " · ".join(summaries) if not summaries.is_empty() else ObserverText.STATUSES.get(order.status, "等待回报")

func _layout() -> void:
	if cards.size() < 2 or timeline_panel == null or map == null: return
	var width_value: float = root.size.x
	if width_value < 400.0: width_value = get_viewport().get_visible_rect().size.x
	var column_width: float = (width_value - 72.0) * 0.43
	_place(cards_scroll, 24, 90, 24 + column_width, -231, 0, 0, 0, 1)
	_place(timeline_panel, 48 + column_width, 90, -24, -231, 0, 0, 1, 1)
	for faction: String in cards: cards[faction].visible = not cinema
	for scroller: ScrollContainer in card_scrollers.values():
		scroller.custom_minimum_size.y = 0 if expanded else 248
	if expanded:
		for faction: String in cards:
			var panel: PanelContainer = cards[faction]
			if panel.get_parent() != cards_column: panel.reparent(cards_column)
			panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cards_column.custom_minimum_size.x = column_width - 14
	else:
		for faction: String in cards:
			var panel: PanelContainer = cards[faction]
			if panel.get_parent() != root: panel.reparent(root)
		var card_width: float = minf(440.0, (width_value - 72.0) * 0.35)
		_place(cards.jp, 24, 90, 24 + card_width, 0, 0, 0, 0, 0)
		_place(cards.us, -24 - card_width, 90, -24, 0, 1, 0, 1, 0)
	cards_scroll.visible = expanded and not cinema
	timeline_panel.visible = expanded and not cinema
	map.visible = not cinema and not expanded
	if map_selector != null: map_selector.visible = map.visible and not map_data.is_empty()
	unit_detail.visible = not cinema
	cinema_button.text = "恢复信息" if cinema else "收起信息"
	_journal_sequence = -1

func show_error(message: String) -> void:
	status.text = "加载失败"
	report_text.text = message
	report_panel.show()

static func clear_rows(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

static func _label(value: String, size_value: int) -> Label:
	var result: Label = Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size_value)
	return result

static func _style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	result.content_margin_left = 12
	result.content_margin_right = 12
	result.content_margin_top = 7
	result.content_margin_bottom = 7
	return result

static func _panel() -> PanelContainer:
	var result: PanelContainer = PanelContainer.new()
	result.add_theme_stylebox_override("panel", _style(Color(0.035, 0.075, 0.10, 0.92), Color("42616f"), 10))
	return result

static func _button(parent: Node, value: String, callback: Callable) -> Button:
	var result: Button = Button.new()
	result.text = value
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

static func _place(control: Control, left: float, top: float, right: float, bottom: float, aleft: float, atop: float, aright: float, abottom: float) -> void:
	control.anchor_left = aleft
	control.anchor_top = atop
	control.anchor_right = aright
	control.anchor_bottom = abottom
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom
