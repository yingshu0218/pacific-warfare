extends AllUnitsShowcase

const MAP_VIEW: Script = preload("res://scripts/map02/expanded_map_view.gd")
const DIRECTOR: Script = preload("res://scripts/showcase/expansion/expansion_missions.gd")
const BOMB_LABELS: Script = preload("res://scripts/showcase/bombing/labels.gd")
const OPS_LABELS: Script = preload("res://scripts/showcase/expansion/operations_labels.gd")
const QINGJIA_TEXT: Script = preload("res://scripts/showcase/qingjia/report_text.gd")
const QINGJIA_SCENARIO: String = "res://data/scenarios/qj01_qingjia.json"
const BOMB_MODES: Array[String] = ["attack_sb2c","attack_d4y","attack_g4m","attack_b25","intercept_g4m","intercept_b25"]
const NEW_MODES: Array[String] = ["harbor","carrier_gunnery","carrier_single","carrier_pair","carrier_partial","inspect_d4y2","inspect_g4m1","inspect_b25j","attack_sb2c","attack_d4y","attack_g4m","attack_b25","intercept_g4m","intercept_b25","qingjia"]
const NEW_TITLES: Array[String] = ["港湾实战观战","两航母航行与炮战","F6F 单机甲板作业","F6F 双机整波作业","单机出动限制示例","D4Y2 · 模型展示","G4M1 · 模型展示","B-25J · 模型展示","SB2C · 俯冲轰炸","D4Y2 · 俯冲轰炸","G4M1 · 水平轰炸","B-25J · 舰艇轰炸","F6F 截击 G4M1","零战截击 B-25J","青岬归航 · 双机回收"]
var operation_text: Label
var air_combat_button: Button
var carrier_menu: OptionButton
var manual_serial: int = 0
var static_models: Dictionary = {}
var camera_subject: String = ""
var expansion_probe: RefCounted
var bomb_view: Node3D
var bomb_event_generation: int = -1
var last_bomb_release_s: float = -100
var last_bomb_contact: Dictionary = {}
var last_aircraft_contact: Dictionary = {}

func _ready() -> void:
	super._ready()
	expansion_probe = preload("res://scripts/showcase/expansion/web_probe.gd").new(self)
	if exercise == "harbor":
		_action("camera","auto")
		_refresh_guide_ui()

func _process(dt: float) -> void:
	var qingjia_pending: bool = running and session.qingjia_mission != null and session.ended_reason.is_empty()
	super._process(dt)
	if not running: return
	if qingjia_pending and not session.ended_reason.is_empty():
		hud.refresh(session, camera.mode, camera.shot_label)
		_refresh_guide_ui()
	if expansion_probe != null: expansion_probe.observe(dt)

func _action(kind: String, value: Variant) -> void:
	super._action(kind,value)
	if kind=="restart" and exercise=="harbor":
		guide.active=false;camera.set_mode("auto");_refresh_guide_ui()

func apply_presentation(events: Array[BattleEvent]) -> void:
	super.apply_presentation(events)
	if expansion_probe != null: expansion_probe.consume(events)
	if bomb_view == null:
		bomb_view = preload("res://scripts/showcase/bombing/projectile_view.gd").new();add_child(bomb_view)
	bomb_view.present(session,models)
	if bomb_event_generation != session.world.generation:
		bomb_event_generation = session.world.generation;last_bomb_release_s = -100;last_bomb_contact.clear();last_aircraft_contact.clear()
	for event: BattleEvent in presentation_events:
		if event.kind == "bomb_released": last_bomb_release_s = event.time_s
		elif event.kind in ["bomb_contact","bomb_explosion"]: last_bomb_contact = {"time_s":event.time_s,"position_m":event.position_m,"surface":event.data.get("surface",""),"kind":event.kind}
		elif event.kind == "unit_surface_contact" and session.units.get(event.entity_id,{}).get("module_data",{}).has("bomb_rack"):
			last_aircraft_contact = {"time_s":event.time_s,"position_m":event.position_m,"surface":event.data.get("surface","")}

func _install_missions() -> void:
	if session.qingjia_mission != null:
		missions = ShowcaseMissions.new(exercise)
	elif session.scenario.has("carrier_operations"):
		missions = DIRECTOR.new(exercise)
		var receipt: Dictionary = session.world.register_module(missions)
		if not receipt.accepted: push_error("S14 expansion director: "+str(receipt))
		session.refresh_view(true)
	else:
		super._install_missions()

func _build_guide_ui() -> void:
	super._build_guide_ui()
	var combat: Button = Button.new()
	combat.text = "实际交战"
	combat.tooltip_text = "跟随真实主炮、防空、空战与弹着事件；右键或移动键可随时接管。"
	combat.pressed.connect(func() -> void: _action("camera","auto"))
	var main_row: HBoxContainer = guide_panel.get_child(0).get_child(0) as HBoxContainer
	main_row.add_child(combat);main_row.move_child(combat,2)
	air_combat_button = ObserverHud._button(main_row, "空中交战", func() -> void: _action("camera", "air"))
	air_combat_button.tooltip_text = "在当前战局里观察轰炸、拦截和战斗机狗斗。"
	main_row.move_child(air_combat_button, 3)
	for title: String in NEW_TITLES: segment_menu.add_item(title)
	segment_menu.tooltip_text = "选择后重置整场；青岬归航、港湾实战、甲板作业、训练及实际轰炸／截击。"
	operation_text = Label.new()
	operation_text.add_theme_font_size_override("font_size",13)
	operation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var line: HBoxContainer = HBoxContainer.new()
	(guide_panel.get_child(0) as VBoxContainer).add_child(line)
	carrier_menu = OptionButton.new()
	for title: String in ["舰载高层指令","整波巡逻／放飞","整波召回／回收","仅一架出动 · 限制示例"]: carrier_menu.add_item(title)
	carrier_menu.custom_minimum_size.x = 190
	carrier_menu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	carrier_menu.item_selected.connect(_carrier_command)
	line.add_child(carrier_menu)
	_watch_popup(carrier_menu)
	operation_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(operation_text)
	_refresh_guide_ui()

func choose_exercise(index: int) -> void:
	if index < MODES.size():
		super.choose_exercise(index)
		return
	var at: int = index-MODES.size()
	if at < 0 or at >= NEW_MODES.size(): return
	exercise = NEW_MODES[at]
	var path: String = QINGJIA_SCENARIO if exercise == "qingjia" else "res://data/scenarios/"+("s14_" if BOMB_MODES.has(exercise) else "s14_expansion_")+exercise+".json"
	var errors: PackedStringArray = session.load_battle(path)
	if not errors.is_empty():
		hud.show_error("扩展装配失败\n"+"\n".join(errors))
		return
	_install_missions()
	_reset_presentation()
	guide.reset(exercise)
	if exercise == "harbor": guide.active=false;camera.set_mode("auto")
	_update_guide(0)
	_refresh_guide_ui()

func _reset_presentation() -> void:
	if bomb_view != null: bomb_view.clear()
	_clear_static_models()
	_reconcile_models()
	if session.world.shared_state.has("terrain"):
		var terrain: Dictionary = session.world.shared_state.terrain
		environment_view.set_terrain(terrain)
		if map_view != null and str(map_view.terrain.source.id) != str(terrain.source.id):
			map_view.free()
			map_view = (load(str(session.scenario.environment.get("view_script","res://scripts/presentation/maps/island_harbor_view.gd"))) as Script).new() as IslandHarborView
			add_child(map_view); map_view.build(terrain)
		camera.terrain = terrain; hud.set_terrain(terrain)
		if gallery != null:
			gallery.free(); gallery = ShowcaseWeaponGallery.new(); add_child(gallery); gallery.build(terrain)
	super._reset_presentation()
	_build_static_models()

func _reconcile_models() -> void:
	for id: String in models.keys():
		if session.units.has(id) and str(metadata.get(id,{}).get("definition_id","")) == str(session.units[id].definition_id): continue
		(models[id] as Node).free(); models.erase(id); metadata.erase(id); recoils.erase(id)
		if wakes.has(id): (wakes[id] as Node).free(); wakes.erase(id)
	for id: String in session.world.unit_ids():
		if models.has(id): continue
		var definition: UnitDefinition = session.catalog.unit(session.units[id].definition_id)
		var model: Node3D = (load(definition.model_scene) as PackedScene).instantiate() as Node3D
		model.name = id; add_child(model); models[id] = model
		metadata[id] = ObserverCamera.describe_unit(definition); metadata[id]["name"] = session.scenario.presentation.names[id]; metadata[id]["definition_id"] = definition.id
		if definition.domain in ["ship","ground"]:
			var recoil: VisualRecoil = VisualRecoil.new(); recoil.bind_model(model); recoils[id] = recoil
			if definition.domain == "ship": _make_wake(id,definition.dimensions_m.z)

func _build_static_models() -> void:
	_clear_static_models()
	if not models.has("jp_cv"): return
	var d4y: Node3D = (load("res://aircraft/d4y2/d4y2.tscn") as PackedScene).instantiate() as Node3D
	(models.jp_cv as Node3D).add_child(d4y)
	d4y.transform = Transform3D(Basis.IDENTITY,Vector3(0,14.15,-80))*d4y.get_parked_transform()
	StaticModelBatch.apply(d4y,"s14_static_d4y2")
	static_models.d4y2 = d4y
	var g4m: Node3D = (load("res://aircraft/g4m1/g4m1.tscn") as PackedScene).instantiate() as Node3D
	add_child(g4m)
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map02/regions.json"))
	var station: Dictionary = regions.airfield.parking_stands[0]
	g4m.transform = Transform3D(Basis(Vector3.UP,float(station.get("heading_rad",0))),SimData.vec3(station.position_m))*g4m.get_parked_transform()
	StaticModelBatch.apply(g4m,"s14_static_g4m1")
	static_models.g4m1 = g4m
	var b25: Node3D = (load("res://aircraft/b25j/b25j.tscn") as PackedScene).instantiate() as Node3D
	add_child(b25)
	var other: Dictionary = regions.airfield.parking_stands[7]
	b25.transform = Transform3D(Basis(Vector3.UP,float(other.heading_rad)),SimData.vec3(other.position_m))*b25.get_parked_transform()
	StaticModelBatch.apply(b25,"s14_static_b25j")
	static_models.b25j = b25

func _clear_static_models() -> void:
	for value: Variant in static_models.values():
		if is_instance_valid(value): (value as Node).free()
	static_models.clear()

func _update_guide(dt: float) -> void:
	if guide.active: camera.manual_free = false
	if BOMB_MODES.has(exercise) and guide.active and guide.current != "gallery":
		_bombing_camera();camera.shot_label = str(guide_state.label);environment_view.update_observer(camera.position);return
	if not NEW_MODES.has(exercise) or not guide.active or guide.current == "gallery":
		super._update_guide(dt)
		return
	guide.current = "expansion"
	if exercise == "qingjia":
		camera.follow(session.qingjia_mission.carrier_id)
		camera.update_view(dt, session.presentation_time_s, session.presentation_units, session.world.paused)
		guide_state = {"section":"qingjia", "label":"青岬归航 · 母舰跟随"}
	elif exercise.begins_with("inspect_"):
		_static_camera(exercise.trim_prefix("inspect_"))
	elif exercise in ["carrier_single","carrier_pair","carrier_partial"]:
		_operation_camera()
	elif exercise == "carrier_gunnery":
		var id: String = "us_cv" if fmod(session.world.time_s(),24)<12 else "jp_cv"
		camera.follow(id); camera.distance_m = 330; camera.pitch = .32; camera.yaw = -.9
		camera.update_view(dt,session.presentation_time_s,session.presentation_units,session.world.paused)
		guide_state = {"section":"carrier_gunnery","ids":[id],"label":"实际航行／火控／弹药／损伤"}
	else:
		_harbor_camera(dt)
	environment_view.update_observer(camera.position)

func _static_camera(id: String) -> void:
	if not static_models.has(id): return
	var model: Node3D = static_models[id]
	var offset: Vector3 = Vector3(-17,10,-21) if id == "d4y2" else (Vector3(35,16,27) if id == "b25j" else Vector3(40,19,30))
	var focus: Vector3 = model.global_position+Vector3.UP
	_pose_camera(focus,focus+offset)
	guide_state = {"section":"static","ids":[],"label":_static_label(id)}

func _static_label(id: String) -> String:
	var names: Dictionary = {"d4y2":"D4Y2 · 翔鹤甲板","g4m1":"G4M1 · MAP02机场","b25j":"B-25J · MAP02机场"}
	return str(names[id])+" · 模型检视 · 轰炸任务另选"

func _operation_camera() -> void:
	var preferred: String = ""
	var weight: int = -1
	var weights: Dictionary = {"approach":10,"touchdown":12,"arresting":12,"takeoff_roll":9,"taxi_out":7,"climb":8,"taxi_clear":6,"respotting":5,"servicing":3,"queued":2,"preparing":2,"standby":1}
	for id: String in session.presentation_units:
		var state: Dictionary = session.presentation_units[id].module_data.get("carrier_ops",{})
		if state.is_empty(): continue
		var value: int = int(weights.get(str(state.phase),0))
		if value > weight: preferred = id; weight = value
	if preferred.is_empty(): return
	camera_subject = preferred
	var unit: Dictionary = session.presentation_units[preferred]
	var state: Dictionary = unit.module_data.carrier_ops
	var focus: Vector3 = unit.position_m+Vector3.UP*.7
	var ship_basis: Basis = Basis.from_euler(session.presentation_units.us_cv.rotation_rad)
	var offset: Vector3 = Vector3(-26,11,23)
	if not bool(state.on_deck): offset = Vector3(-30,10,24)
	_pose_camera(focus,focus+ship_basis*offset)
	guide_state = {"section":"carrier_operations","ids":[preferred],"label":OPS_LABELS.phase(str(state.phase))+" · 甲板作业"}

func _harbor_camera(dt: float) -> void:
	var points: Array = session.world.shared_state.terrain.source.viewpoints
	var cycle: int = int(session.presentation_time_s/10)% (points.size()+5)
	if cycle < points.size():
		camera.locate_map(points[cycle]); camera.update_view(dt,session.presentation_time_s,session.presentation_units,session.world.paused)
		guide_state = {"section":"map02","ids":[],"label":str(points[cycle].get("label",points[cycle].get("id","港湾区域"))).replace("空阵地","阵地")}
	elif cycle in [points.size(),points.size()+1]:
		var id: String = "us_cv" if cycle == points.size() else "jp_cv"
		camera.follow(id); camera.distance_m = 340; camera.pitch = .45
		camera.update_view(dt,session.presentation_time_s,session.presentation_units,session.world.paused)
		guide_state = {"section":"carrier","ids":[id],"label":("埃塞克斯" if id == "us_cv" else "翔鹤")+" · 真实航行与固定炮位"}
	else: _static_camera(["d4y2","g4m1","b25j"][cycle-points.size()-2])

func _pose_camera(focus: Vector3, at: Vector3) -> void:
	# Explicit port/above-deck view bypasses the generic whole-ship bounding
	# sphere used by distant observers. It reads actual unit motion only.
	camera.mode = "free"; camera.followed_id = ""; camera.focus = focus
	camera.position = at; camera.distance_m = at.distance_to(focus); camera.near = .8
	var offset: Vector3 = at-focus
	camera.yaw = atan2(offset.x,offset.z)
	camera.pitch = asin(offset.y/camera.distance_m)
	camera.look_at(focus,Vector3.UP)
	camera.views = session.presentation_units
	camera.adopt_current_view()

func _refresh_guide_ui() -> void:
	super._refresh_guide_ui()
	if operation_text == null: return
	var expanded: bool = NEW_MODES.has(exercise)
	air_combat_button.visible = exercise in ["harbor", "fire"]
	operation_text.visible = expanded
	carrier_menu.visible = expanded and exercise in ["carrier_single","carrier_pair","carrier_partial"]
	if not expanded: return
	segment_menu.select(MODES.size()+NEW_MODES.find(exercise))
	resume_guide_button.text = "港湾导览" if exercise=="harbor" else "继续导览"
	var view_label: String = "空中交战" if camera.air_focus else ("实际交战" if camera.mode == "auto" else "手动观察")
	if camera.mode == "fighter": view_label = "自主飞行"
	guide_status.text = str(guide_state.get("label","港湾扩展")) if guide.active else view_label + " · " + camera.shot_label
	var lines: PackedStringArray = []
	if exercise == "qingjia":
		var report: Dictionary = session.qingjia_mission.report(session.world)
		guide_status.text = "青岬归航 · " + QINGJIA_TEXT.summary(report)
		lines.append(QINGJIA_TEXT.brief(report, session.scenario.presentation.subtitle))
	elif exercise.begins_with("inspect_"):
		guide_status.text = _static_label(exercise.trim_prefix("inspect_"))
		lines.append("静态安装已完成。机场／日军舰载起降、防御枪位尚未接入；飞行与轰炸请选任务菜单。")
	elif BOMB_MODES.has(exercise):
		for id: String in session.units:
			var unit: Dictionary = session.units[id]
			var rack: Dictionary = unit.module_data.get("bomb_rack",{})
			if rack.is_empty(): continue
			var task: Dictionary = unit.module_data.get("bombing",{})
			var damage: Dictionary = unit.module_data.get("damage",{})
			var phase: String = str(damage.phase) if str(damage.get("phase","operational")) != "operational" else str(task.get("phase","awaiting_contact"))
			lines.append(str(session.scenario.presentation.names[id])+" · "+BOMB_LABELS.phase(phase)+" · 已投%d / 余%d"%[int(rack.released),int(rack.remaining)]+" · "+BOMB_LABELS.reason(str(task.get("abort_reason","")) if not str(task.get("abort_reason","")).is_empty() else str(task.get("reason","awaiting_contact"))))
		lines.append("在空开始 · 返航至撤离空域")
	elif exercise == "harbor":
		lines.append(_harbor_air_status())
	elif exercise == "carrier_gunnery":
		lines.append("两艘航母的航行与炮火。左侧菜单可切换至甲板作业。")
	else:
		for id: String in session.units:
			var state: Dictionary = session.units[id].module_data.get("carrier_ops",{})
			if state.is_empty(): continue
			var deadline: String = " · 巡逻任务%.0f秒后返航"%float(state.on_station_duration_s) if float(state.get("on_station_duration_s",-1)) > 0 else ""
			lines.append(str(session.scenario.presentation.names[id])+" → 埃塞克斯 · "+OPS_LABELS.phase(str(state.phase))+" · "+OPS_LABELS.reason(str(state.reason))+" · 出动%d / 回收%d"%[int(state.sorties),int(state.recoveries)]+deadline)
		for order: Dictionary in session.orders:
			if str(order.reason) == "carrier_complete_wave_required": lines.append("指令已拒绝："+OPS_LABELS.reason(str(order.reason)))
		for entry: Dictionary in session.journal:
			if entry.kind == "command_rejected" and str(entry.record.get("reason","")) == "carrier_complete_wave_required": lines.append("指令已拒绝："+OPS_LABELS.reason(str(entry.record.reason)))
		var ops: Dictionary = session.carrier_operations.snapshot_state() if session.carrier_operations != null else {}
		if not ops.is_empty(): lines.append("母舰有限库存：油料 %.0f 千克 / 弹药 %d 发 · 零环境风 · 仅F6F完整1／2机波次"%[float(ops.fuel_stock_kg),int(ops.ammo_stock_rounds)])
	operation_text.text = "\n".join(lines)

func _harbor_air_status() -> String:
	var reports: PackedStringArray = []
	for goal: Dictionary in session.scenario.get("bombing_goals", []):
		var available: int = 0
		var loaded: int = 0
		var released: int = 0
		var phase: String = "awaiting_contact"
		for id: String in goal.unit_ids:
			var unit: Dictionary = session.units[id]
			var rack: Dictionary = unit.module_data.get("bomb_rack", {})
			released += int(rack.get("released", 0))
			if not unit.active: continue
			available += 1
			loaded += int(rack.get("remaining", 0))
			var state: Dictionary = unit.module_data.get("bombing", {})
			if phase == "awaiting_contact" and not state.is_empty(): phase = str(state.phase)
		var name_text: String = str(session.scenario.presentation.names[goal.id]).get_slice(" ", 0)
		var status: String = "已退出战斗" if available == 0 else BOMB_LABELS.phase(phase)
		reports.append("%s %s · 已投%d / 余%d" % [name_text, status, released, loaded])
	return "   |   ".join(reports)

func _carrier_command(index: int) -> void:
	carrier_menu.select(0)
	if index == 0 or session.carrier_operations == null: return
	var roster: Dictionary = session.carrier_operations.get("roster")
	var ids: Array[String] = []
	for id: String in roster:
		if session.world.get_unit(id).active: ids.append(id)
	if ids.is_empty(): return
	if index == 3: ids.resize(1)
	manual_serial += 1
	var order: BattleOrder = BattleOrder.new()
	order.order_id = "s14:deck:%d:%d"%[session.world.generation,manual_serial]
	order.source = "human"; order.issuer_id = "user_carrier_command"; order.faction_id = "us"
	order.recipient_ids = ids; order.target_id = "us_cv"
	order.order_type = "retreat" if index == 2 else "patrol"
	var center: Vector3 = session.world.get_unit("us_cv").world_transform()*Vector3(-1000,700,-3500)
	order.area = {"center_m":SimData.array3(center),"radius_m":1200.0}
	if order.order_type == "patrol": order.area["on_station_duration_s"] = 110.0
	order.intent = "carrier_wave_recall" if index == 2 else "carrier_wave_patrol"
	session.world.submit_order(order)

func _create_effects() -> CombatEffects:
	return BombingEffects.new()

func _bombing_camera() -> void:
	guide.current = "bombing"
	if not last_aircraft_contact.is_empty() and session.world.time_s()-float(last_aircraft_contact.time_s)<3.0:
		var point: Vector3 = last_aircraft_contact.position_m
		_pose_camera(point,point+Vector3(55,32,65))
		guide_state = {"section":"aircraft_contact","label":"实际落海 · 水面接触" if last_aircraft_contact.surface == "sea" else "实际坠地 · 地面接触"}
		return
	if not last_bomb_contact.is_empty() and session.world.time_s()-float(last_bomb_contact.time_s)<2.5:
		var point: Vector3 = last_bomb_contact.position_m
		_pose_camera(point,point+Vector3(55,32,65))
		guide_state = {"section":"bomb_contact","label":"实际弹着 · "+("海面" if last_bomb_contact.surface=="sea" else "目标／地面")}
		return
	if session.bomb_stores != null and session.world.time_s()-last_bomb_release_s>1.2:
		for round: Dictionary in session.presentation_bombs.values():
			_pose_camera(round.position_m,round.position_m+Vector3(22,12,25))
			guide_state = {"section":"bomb_flight","label":"实际弹体 · 无制导下落"}
			return
	var subject: String = ""
	var weight: int = -10
	for id: String in session.presentation_units:
		var candidate: Dictionary = session.presentation_units[id]
		if not candidate.module_data.has("bomb_rack"): continue
		var phase: String = str(candidate.module_data.get("damage",{}).get("phase","operational"))
		if not bool(candidate.active) and phase not in ["crashing","wreck"]: continue
		var value: int = 4 if phase=="crashing" else (1 if bool(candidate.active) else 0)
		if value>weight: subject=id;weight=value
	if subject.is_empty():
		if session.presentation_units.has("bomber"):
			var point: Vector3 = session.presentation_units.bomber.position_m
			_pose_camera(point,point+Vector3(80,45,85))
		guide_state = {"section":"bombing_exit","label":"编组已退出 · 最后相关位置"}
		return
	camera_subject = subject
	var unit: Dictionary = session.presentation_units[subject]
	var focus: Vector3 = unit.position_m
	var basis: Basis = Basis(Vector3.UP,float(unit.rotation_rad.y))
	var span: float = float(metadata[subject].get("span",25))
	var offset: Vector3 = Vector3(-maxf(28,span*1.7),maxf(12,span*.6),maxf(30,span*1.6))
	var task: Dictionary = unit.module_data.get("bombing",{})
	if str(task.get("phase","")) == "inbound" and session.presentation_units.has("wing") and bool(session.presentation_units.wing.active):
		var separation: float = (session.presentation_units.wing.position_m as Vector3).distance_to(unit.position_m)
		focus = (focus+(session.presentation_units.wing.position_m as Vector3))*.5
		offset = offset.normalized()*maxf(offset.length(),separation*1.5+30)
	_pose_camera(focus,focus+basis*offset)
	var damage: String = str(unit.module_data.get("damage",{}).get("phase","operational"))
	guide_state = {"section":"bombing","ids":[subject],"label":("实际截击 · " if exercise.begins_with("intercept_") else "实际轰炸 · ")+BOMB_LABELS.phase(damage if damage!="operational" else str(task.get("phase","awaiting_contact")))}
