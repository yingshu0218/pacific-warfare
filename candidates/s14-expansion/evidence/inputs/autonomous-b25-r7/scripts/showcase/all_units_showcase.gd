class_name AllUnitsShowcase
extends FirstPlayableGame

var guide: ShowcaseGuide = ShowcaseGuide.new()
var missions: ShowcaseMissions
var gallery: ShowcaseWeaponGallery
var segment_menu: OptionButton
var weapon_menu: OptionButton
var guide_status: Label
var guide_panel: PanelContainer
var exercise: String = "guided"
var guide_state: Dictionary = {}
var camera_input_blocked_until_ms: int = 0
const TRAINING: Script = preload("res://scripts/showcase/training_labels.gd")
const MODES: Array[String] = ["guided","pair","four","maneuver","escort","fire","train_us_bank_turn","train_us_climb_dive","train_us_axial_roll","train_us_roll_reversal","train_us_split_s","train_jp_bank_turn","train_jp_climb_dive","train_jp_axial_roll","train_jp_roll_reversal","train_jp_split_s"]

func _ready() -> void:
	super._ready()
	if not running: return
	exercise = str(session.scenario.showcase.mode)
	_install_missions()
	gallery = ShowcaseWeaponGallery.new()
	add_child(gallery)
	gallery.build(session.world.shared_state.get("terrain",{}))
	_build_guide_ui()
	hud.cinema = true
	hud._layout()
	guide.reset(exercise)
	_update_guide(0)

func _install_missions() -> void:
	missions = ShowcaseMissions.new(exercise)
	var receipt: Dictionary = session.world.register_module(missions)
	if not receipt.accepted: push_error("S14 missions: " + str(receipt))
	session.refresh_view(true)

func _process(delta_s: float) -> void:
	if not running: return
	var begin_us: int = Time.get_ticks_usec()
	var events: Array[BattleEvent] = session.advance(delta_s,16)
	var advance_us: int = Time.get_ticks_usec()
	apply_presentation(events)
	var presentation_us: int = Time.get_ticks_usec()
	_update_guide(delta_s)
	var camera_us: int = Time.get_ticks_usec()
	_ui_timer_s -= delta_s
	if _ui_timer_s <= 0:
		hud.refresh(session,camera.mode,camera.shot_label)
		_refresh_guide_ui()
		_ui_timer_s = .25
	if not session.ended_reason.is_empty() and not _report_shown:
		_report_shown = true
		hud.report_panel.show()
	if _web_probe != null and _web_probe.enabled:
		_web_probe.observe(delta_s,advance_us-begin_us,presentation_us-advance_us,camera_us-presentation_us,Time.get_ticks_usec()-camera_us)

func _update_guide(dt: float) -> void:
	guide.training_subject = missions.training_subject
	guide.cycle_phase = missions.cycle_status
	guide_state = guide.update(camera,session.units,session.world.time_s(),dt,gallery)
	if guide.active and guide.current == "gallery":
		var orbit: Vector3 = Vector3(sin(camera.yaw)*cos(camera.pitch),sin(camera.pitch),cos(camera.yaw)*cos(camera.pitch))*camera.distance_m
		camera.position = camera.focus+orbit
		camera.position.y = maxf(camera.position.y,TerrainQueries.height_data(gallery.terrain,camera.position,true)+.20)
		camera.near = .06
		camera.look_at(camera.focus,Vector3.UP)
	else:
		camera.update_view(dt,session.world.time_s(),session.units,session.world.paused)
	environment_view.update_observer(camera.position)

func choose_exercise(index: int) -> void:
	if index < 0 or index >= MODES.size(): return
	exercise = MODES[index]
	var errors: PackedStringArray = session.load_battle("res://data/scenarios/s14_"+exercise+".json")
	if not errors.is_empty():
		hud.show_error("演示装配失败\n"+"\n".join(errors))
		return
	_install_missions()
	_reset_presentation()
	guide.reset(exercise)
	_update_guide(0)
	_refresh_guide_ui()

func inspect_weapon(index: int) -> void:
	if index < 0 or index >= gallery.entries.size(): return
	guide.reset("gallery")
	guide.selected_gallery = index
	_update_guide(0)
	_refresh_guide_ui()

func _action(kind: String, value: Variant) -> void:
	if kind in ["follow","camera","map_location"]: guide.active = false
	super._action(kind,value)
	if kind == "restart":
		guide.reset(exercise)
		_update_guide(0)
	if guide_status != null: _refresh_guide_ui()

func _locate_order(record: Dictionary, target: bool) -> void:
	guide.active = false
	super._locate_order(record,target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if Time.get_ticks_msec() < camera_input_blocked_until_ms: return
		for control: OptionButton in [segment_menu,weapon_menu,hud.selector,hud.speeds]:
			if control != null and control.get_popup().visible: return
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE: return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]: guide.active = false
	super._unhandled_input(event)

func _watch_popup(control: OptionButton) -> void:
	# Web wheel events queued by an embedded popup must not zoom the world
	# while that same menu is closing. This guards observer input only.
	control.get_popup().popup_hide.connect(func() -> void: camera_input_blocked_until_ms = Time.get_ticks_msec()+300)

func _build_guide_ui() -> void:
	guide_panel = ObserverHud._panel()
	guide_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	guide_panel.offset_left = 24
	guide_panel.offset_right = -24
	guide_panel.offset_top = 78
	guide_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.root.add_child(guide_panel)
	var box: VBoxContainer = VBoxContainer.new()
	guide_panel.add_child(box)
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	segment_menu = OptionButton.new()
	for mode: String in MODES:
		var titles: Dictionary = {"guided":"连续导览","pair":"双机协调转弯","four":"四机自主任务","maneuver":"单机自主空战观察","escort":"SB2C 护航任务","fire":"舰队与岸防实战"}
		var title: String = str(titles.get(mode,""))
		if mode.begins_with("train_"):
			var faction: String = mode.get_slice("_",1)
			title = ("F6F 训练 · " if faction == "us" else "A6M 训练 · ")+TRAINING.name_of(mode.trim_prefix("train_"+faction+"_"))
		segment_menu.add_item(title)
	segment_menu.tooltip_text = "选择后重置整场受控演示；全部单位仍在同一地图。"
	segment_menu.item_selected.connect(choose_exercise)
	segment_menu.fit_to_longest_item = false
	segment_menu.custom_minimum_size.x = 220
	segment_menu.get_popup().max_size.y = 580
	row.add_child(segment_menu)
	var replay: Button = Button.new()
	replay.text = "重新演示"
	replay.pressed.connect(func() -> void: choose_exercise(segment_menu.selected))
	row.add_child(replay)
	var resume: Button = Button.new()
	resume.text = "继续导览"
	resume.pressed.connect(func() -> void: guide.reset(exercise); _update_guide(0); _refresh_guide_ui())
	row.add_child(resume)
	weapon_menu = OptionButton.new()
	weapon_menu.fit_to_longest_item = false
	weapon_menu.custom_minimum_size.x = 310
	weapon_menu.add_item("港口兵器检视（不重置）")
	for entry: Dictionary in gallery.entries: weapon_menu.add_item(entry.name)
	weapon_menu.item_selected.connect(func(index: int) -> void:
		if index > 0: inspect_weapon(index-1))
	row.add_child(weapon_menu)
	guide_status = Label.new()
	guide_status.add_theme_font_size_override("font_size",13)
	guide_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(guide_status)
	for control: OptionButton in [segment_menu,weapon_menu,hud.selector,hud.speeds]: _watch_popup(control)
	_refresh_guide_ui()

func _refresh_guide_ui() -> void:
	guide_panel.visible = not hud.expanded and not hud.report_panel.visible
	if not hud.expanded:
		# Keep both actual command streams visible while leaving the middle wide
		# enough to see a group and a full ship. Expanded mode retains the old UI.
		var width: float = minf(280,(hud.root.size.x-72)*.24)
		for faction: String in hud.cards:
			var card: PanelContainer = hud.cards[faction]
			card.offset_top = 202
			if faction == "jp": card.offset_right = 24+width
			else: card.offset_left = -24-width
		for scroll: ScrollContainer in hud.card_scrollers.values(): scroll.custom_minimum_size.y = 176
	segment_menu.select(MODES.find(exercise))
	var label: String = str(guide_state.get("label","手动观战 · 可恢复导览"))
	guide_status.text = "演示模式 · "+label
	guide_status.tooltip_text = ""
	if not missions.training_order_id.is_empty() and guide.current == "training" and guide.active:
		var progress: Dictionary = training_view()
		guide_status.text = str(progress.label)
		var state: Dictionary = progress.get("training",{})
		if not state.is_empty():
			guide_status.text += " · 滚转 %.0f° / 高度 %+.0f米" % [rad_to_deg(float(state.get("peak_roll_rad",0))),float(state.get("height_change_m",0))]
		guide_status.tooltip_text = str(progress.label)
		if not state.is_empty():
			guide_status.tooltip_text += "\n"+TRAINING.reason(str(state.get("reason","")))
	elif exercise in ["four","escort"]:
		var phases: Dictionary = {"forming":"编队巡航","engaging":"实际交战","regrouping":"脱离与集结","regrouped":"集结已完成","guarding":"贴近保护区域","threat_approaching":"威胁正在接近","intercepting":"护航接敌","threat_withdrawing":"威胁撤离 · 回防","guard_restored":"回防已恢复 · 持续护航","protected_unit_lost":"保护对象已损失"}
		guide_status.text = str(phases.get(missions.cycle_status,"正在执行任务"))+" · "+label

func training_view() -> Dictionary:
	return TRAINING.view(session.units,session.orders,missions.training_subject,missions.training_order_id)
