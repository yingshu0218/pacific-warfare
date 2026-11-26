extends RefCounted

## Optional read-only observer. A normal user page has no S14X global and pays
## no snapshot cost. Never advances the clock or exposes a mutation callback.
var game: Node3D
var enabled: bool = false
var until_s: float = 0.0

func _init(owner: Node3D) -> void:
	game = owner
	enabled = OS.has_feature("web") and bool(JavaScriptBridge.eval("typeof window.S14X !== 'undefined'"))

func observe(dt: float) -> void:
	if not enabled: return
	until_s -= dt
	if until_s > 0: return
	until_s = .10
	var units: Dictionary = {}
	var projected: Dictionary = {}
	for id: String in game.session.units:
		var u: Dictionary = game.session.units[id]
		units[id] = {"definition_id":u.definition_id,"active":u.active,"position_m":u.position_m,"carrier_ops":u.module_data.get("carrier_ops",{}),"fuel_kg":u.module_data.get("aircraft_motion",{}).get("fuel_kg",-1)}
		projected[id] = game.camera.unproject_position(u.position_m)
	var buttons: Dictionary = {}
	for value: Node in game.hud.root.find_children("*","Button",true,false):
		var button: Button = value as Button
		if button.is_visible_in_tree(): buttons[button.text] = center(button)
	var data: Dictionary = {"generation":game.session.world.generation,"tick":game.session.world.tick,"time_s":game.session.world.time_s(),"paused":game.session.world.paused,"speed":game.session.world.time_scale,"pending_s":game.session.world.pending_time_s(),"exercise":game.exercise,"models":game.models.size(),"static_models":game.static_models.keys(),"units":units,"orders":game.session.orders,"journal":game.session.journal,"training":game.training_view(),"label":game.guide_status.text,"operation_text":game.operation_text.text,"operation_text_visible":game.operation_text.visible,"camera_subject":game.camera_subject,"camera_mode":game.camera.mode,"followed_id":game.camera.followed_id,"projected":projected,"buttons":buttons,"controls":{"segment":center(game.segment_menu),"unit":center(game.hud.selector),"speed":center(game.hud.speeds),"carrier":center(game.carrier_menu)},"popups":{"segment":popup(game.segment_menu),"unit":popup(game.hud.selector),"speed":popup(game.hud.speeds),"carrier":popup(game.carrier_menu)},"ui":{"cinema":game.hud.cinema,"expanded":game.hud.expanded},"environment":game.environment_view.snapshot(),"sound_enabled":game.effects.sound_enabled,"effects":game.effects.statistics(),"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	JavaScriptBridge.eval("window.S14X.receive("+JSON.stringify(json_data(data))+")")

func consume(events: Array[BattleEvent]) -> void:
	if not enabled: return
	var selected: Array = []
	for event: BattleEvent in events:
		if event.kind.begins_with("carrier_") or event.kind in ["fired","hit","damaged","order_issued","order_status_changed","command_rejected"]:
			var row: Dictionary = event.snapshot()
			row["generation"] = game.session.world.generation; row["exercise"] = game.exercise
			selected.append(row)
	if not selected.is_empty(): JavaScriptBridge.eval("window.S14X.events("+JSON.stringify(json_data(selected))+")")

func center(control: Control) -> Array:
	var at: Vector2 = control.get_global_rect().get_center()
	return [at.x,at.y]

func popup(control: OptionButton) -> Dictionary:
	var p: PopupMenu = control.get_popup()
	var labels: Array[String] = []
	var metadata: Array = []
	for index: int in p.item_count:
		labels.append(p.get_item_text(index)); metadata.append(p.get_item_metadata(index))
	var panel: StyleBox = p.get_theme_stylebox("panel")
	var font: Font = p.get_theme_font("font")
	var row_height: float = ceilf(font.get_height(p.get_theme_font_size("font_size")))+p.get_theme_constant("v_separation")
	return {"visible":p.visible,"count":p.item_count,"labels":labels,"metadata":metadata,"position":[p.position.x,p.position.y],"size":[p.size.x,p.size.y],"row_height":row_height,"padding_top":panel.get_margin(SIDE_TOP),"padding_bottom":panel.get_margin(SIDE_BOTTOM)}

func json_data(value: Variant) -> Variant:
	if value is Vector3: return SimData.array3(value)
	if value is Vector2: return [value.x,value.y]
	if value is Dictionary:
		var out: Dictionary = {}
		for key: String in value: out[key] = json_data(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value: out.append(json_data(item))
		return out
	return value
