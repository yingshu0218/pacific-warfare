extends RefCounted

## Protocol2 opt-in observer: compact state, changed orders and sequence events.
## Production UI history remains in Session/Hud and never travels every sample.
const MAX_ORDERS: int = 48
var game: Node3D
var enabled: bool = false
var until_s: float = 0
var generation: int = -1
var seen_sequence: int = 0
var order_signatures: Dictionary = {}

func _init(owner: Node3D) -> void:
	game = owner
	enabled = OS.has_feature("web") and bool(JavaScriptBridge.eval("typeof window.S14X !== 'undefined' && window.S14X.protocol === 2"))

func _generation() -> void:
	if generation == game.session.world.generation: return
	generation = game.session.world.generation;seen_sequence = 0;order_signatures.clear()
	JavaScriptBridge.eval("window.S14X.reset("+str(generation)+")")

func observe(dt: float) -> void:
	if not enabled: return
	until_s -= dt
	if until_s>0: return
	until_s = .25
	_generation()
	_orders_delta()
	var units: Dictionary = {}
	for id: String in game.session.units:
		var u: Dictionary = game.session.units[id]
		var m: Dictionary = u.module_data
		var damage: Dictionary = m.get("damage",{})
		var rack: Dictionary = m.get("bomb_rack",{})
		var task: Dictionary = u.task.get("aircraft",{})
		var bombing: Dictionary = m.get("bombing",{})
		var fragments: Array = []
		for part: Dictionary in damage.get("aircraft",{}).get("fragments",[]):
			if fragments.size()>=3: break
			fragments.append({"part_id":part.part_id,"position_m":part.position_m,"rotation_rad":part.rotation_rad})
		var slots: Array = []
		for slot: Dictionary in rack.get("slots",[]): slots.append(bool(slot.loaded))
		units[id] = {"definition_id":u.definition_id,"active":u.active,"position_m":u.position_m,"rotation_rad":u.rotation_rad,"velocity_mps":u.velocity_mps,"carrier_ops":m.get("carrier_ops",{}),"command_assignment":m.get("command_assignment",{}),"fuel_kg":m.get("aircraft_motion",{}).get("fuel_kg",-1),"aircraft_task":{"phase":task.get("phase",""),"reason":task.get("reason","")},"bombing":{"phase":bombing.get("phase",""),"reason":bombing.get("reason",""),"abort_reason":bombing.get("abort_reason",""),"order_id":bombing.get("order_id","")},"rack":{"remaining":rack.get("remaining",-1),"released":rack.get("released",0),"bay":rack.get("bay",0),"crutch":rack.get("crutch",0),"brake":rack.get("brake",0),"slots":slots},"damage":{"phase":damage.get("phase",""),"structure":damage.get("structure",0),"structure_max":damage.get("structure_max",1),"propulsion_factor":damage.get("propulsion_factor",1),"control_factor":damage.get("control_factor",1),"fire":damage.get("fire",0),"detached_parts":damage.get("aircraft",{}).get("detached_parts",[]),"fragments":fragments}}
	var bombs: Array = []
	if game.session.bomb_stores != null:
		for round: CombatProjectiles.Round in game.session.bomb_stores.projectiles.rounds.values():
			if round.release_mode!="gravity_release" or bombs.size()>=96: continue
			bombs.append({"id":round.id,"entity_id":round.entity_id,"slot":round.slot,"position_m":round.position_m,"velocity_mps":round.velocity_mps,"forward_m":round.forward_m,"up_m":round.up_m})
	var buttons: Dictionary = {}
	for value: Node in game.hud.root.find_children("*","Button",true,false):
		var button: Button = value as Button
		if button.is_visible_in_tree(): buttons[button.text] = center(button)
	var data: Dictionary = {"protocol":2,"ended":game.session.ended_reason,"generation":generation,"tick":game.session.world.tick,"time_s":game.session.world.time_s(),"paused":game.session.world.paused,"speed":game.session.world.time_scale,"pending_s":game.session.world.pending_time_s(),"exercise":game.exercise,"models":game.models.size(),"static_models":game.static_models.keys(),"units":units,"bombs":bombs,"training":game.training_view(),"label":game.guide_status.text,"operation_text":game.operation_text.text,"operation_text_visible":game.operation_text.visible,"guide_active":game.guide.active,"guide_current":game.guide.current,"camera_distance_m":game.camera.distance_m,"camera_subject":game.camera_subject,"camera_mode":game.camera.mode,"followed_id":game.camera.followed_id,"buttons":buttons,"controls":{"segment":center(game.segment_menu),"unit":center(game.hud.selector),"speed":center(game.hud.speeds),"carrier":center(game.carrier_menu)},"popups":{"segment":popup(game.segment_menu),"unit":popup(game.hud.selector),"speed":popup(game.hud.speeds),"carrier":popup(game.carrier_menu)},"ui":{"cinema":game.hud.cinema,"expanded":game.hud.expanded},"environment":game.environment_view.snapshot(),"sound_enabled":game.effects.sound_enabled,"effects":game.effects.statistics(),"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	JavaScriptBridge.eval("window.S14X.receive("+JSON.stringify(json_data(data))+")")

func _orders_delta() -> void:
	var selected: Array[Dictionary] = []
	for order: Dictionary in game.session.orders:
		if order.status not in BattleOrder.TERMINAL and selected.size()<MAX_ORDERS: selected.append(order)
	for index: int in range(game.session.orders.size()-1,-1,-1):
		var order: Dictionary = game.session.orders[index]
		if selected.size()>=MAX_ORDERS: break
		if order.status in BattleOrder.TERMINAL: selected.append(order)
	var present: Dictionary = {};var upserts: Array = [];var removed: Array = []
	for order: Dictionary in selected:
		var execution: Dictionary = {}
		for id: String in order.execution:
			var e: Dictionary = order.execution[id]
			execution[id] = {"status":e.status,"reason":e.reason,"progress":str(e.progress).get_slice(":",0)}
		var row: Dictionary = {"order_id":order.order_id,"issuer_id":order.issuer_id,"source":order.source,"faction_id":order.faction_id,"recipient_ids":order.recipient_ids,"assigned_unit_ids":order.assigned_unit_ids,"order_type":order.order_type,"target_id":order.target_id,"intent":order.intent,"status":order.status,"reason":order.reason,"progress":str(order.progress).get_slice(":",0),"issued_tick":order.issued_tick,"execution":execution}
		var signature: String = JSON.stringify(row)
		present[order.order_id] = true
		if str(order_signatures.get(order.order_id,"")) != signature:
			order_signatures[order.order_id] = signature;row["changed_tick"] = order.changed_tick;upserts.append(row)
	for id: String in order_signatures.keys():
		if not present.has(id): removed.append(id);order_signatures.erase(id)
	if not upserts.is_empty() or not removed.is_empty():
		JavaScriptBridge.eval("window.S14X.orders_delta("+JSON.stringify(json_data({"generation":generation,"upserts":upserts,"removed":removed,"total_orders":game.session.orders.size(),"limit":MAX_ORDERS}))+ ")")

func consume(events: Array[BattleEvent]) -> void:
	if not enabled: return
	_generation()
	var rows: Array = []
	for event: BattleEvent in events:
		if event.sequence<=seen_sequence: continue
		seen_sequence=event.sequence
		if not event.kind.begins_with("carrier_") and not event.kind.begins_with("bomb") and event.kind not in ["fired","hit","damaged","damage_phase","aircraft_part_detached","unit_surface_contact","unit_impact","order_issued","order_status_changed","command_rejected"]: continue
		var compact: Dictionary = {}
		for key: String in ["projectile_id","ammo_id","order_id","order_type","source","issuer_id","faction_id","recipient_ids","assigned_unit_ids","status","reason","intent","phase","part_id","surface","armed","slot","destroyed","damage_allowed","velocity_mps","forward_m","up_m","distance_m","wire_id","geometry_id"]:
			if event.data.has(key): compact[key] = event.data[key]
		rows.append({"generation":generation,"exercise":game.exercise,"sequence":event.sequence,"time_s":event.time_s,"kind":event.kind,"entity_id":event.entity_id,"target_id":event.target_id,"weapon_id":event.weapon_id,"position_m":event.position_m,"data":compact})
	if not rows.is_empty(): JavaScriptBridge.eval("window.S14X.events("+JSON.stringify(json_data(rows))+")")

func center(control: Control) -> Array:
	var at: Vector2 = control.get_global_rect().get_center()
	return [at.x,at.y]

func popup(control: OptionButton) -> Dictionary:
	var p: PopupMenu = control.get_popup()
	var labels: Array = [];var metadata: Array = []
	for index: int in p.item_count: labels.append(p.get_item_text(index));metadata.append(p.get_item_metadata(index))
	var panel: StyleBox = p.get_theme_stylebox("panel")
	var font: Font = p.get_theme_font("font")
	return {"visible":p.visible,"count":p.item_count,"labels":labels,"metadata":metadata,"selected":control.selected,"position":[p.position.x,p.position.y],"size":[p.size.x,p.size.y],"row_height":ceilf(font.get_height(p.get_theme_font_size("font_size")))+p.get_theme_constant("v_separation"),"padding_top":panel.get_margin(SIDE_TOP),"padding_bottom":panel.get_margin(SIDE_BOTTOM)}

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
