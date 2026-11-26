extends "res://scripts/showcase/all_units_showcase.gd"

## Web acceptance observer only; interactions use the visible production UI.
var probe_time_s: float = 0
var probe_events: Array[Dictionary] = []

func apply_presentation(events: Array[BattleEvent]) -> void:
	super.apply_presentation(events)
	for event: BattleEvent in events:
		var record: Dictionary = event.snapshot()
		record["generation"] = session.world.generation
		record["exercise"] = exercise
		probe_events.append(record)

func _process(delta_s: float) -> void:
	super._process(delta_s)
	if not running or not OS.has_feature("web"): return
	probe_time_s += delta_s
	if probe_time_s < .1: return
	probe_time_s = 0
	var unit_states: Dictionary = {}
	for id: String in session.units:
		var unit: Dictionary = session.units[id]
		unit_states[id] = {"definition_id":unit.definition_id,"active":unit.active,"position_m":unit.position_m,"velocity_mps":unit.velocity_mps,"rotation_rad":unit.rotation_rad,"task":unit.task.duplicate(true),"training":unit.module_data.get("aircraft_training",{}).duplicate(true),"damage_phase":unit.module_data.get("damage",{}).get("phase",""),"formation":unit.module_data.get("air_formation",{}).duplicate(true)}
	var buttons: Dictionary = {}
	for button: Node in hud.pause_button.get_parent().get_children():
		if button is Button and (button as Button).is_visible_in_tree(): buttons[(button as Button).text] = center(button as Control)
	var projected: Dictionary = {}
	for id: String in guide_state.get("ids",[]):
		var point: Vector2 = camera.unproject_position(session.units[id].position_m)
		projected[id] = [point.x,point.y]
	var result: Dictionary = {"exercise":exercise,"time_s":session.world.time_s(),"tick":session.world.tick,"generation":session.world.generation,"paused":session.world.paused,"speed":session.world.time_scale,"pending_s":session.world.pending_time_s(),"models":models.size(),"units":unit_states,"modes":MODES,"mission":missions.snapshot_state(),"training":training_view(),"guide":guide_state.duplicate(true),"gallery_index":guide.selected_gallery,"projected":projected,"label":guide_status.text,"tooltip":guide_status.tooltip_text,"camera_mode":camera.mode,"followed_id":camera.followed_id,"effects":effects.statistics(),"counts":session.counts.duplicate(),"orders":session.orders.duplicate(true),"events":probe_events,"render_size":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"global_fragments":AircraftAdapter.live_fragment_nodes,"ui":{"cinema":hud.cinema,"expanded":hud.expanded,"both_cards":hud.cards.jp.visible and hud.cards.us.visible,"timeline":hud.timeline_panel.visible,"unit_detail":hud.unit_detail.text},"controls":{"status":center(guide_status),"segment":center(segment_menu),"weapon":center(weapon_menu),"unit":center(hud.selector),"speed":center(hud.speeds)},"popups":{"segment":popup(segment_menu),"weapon":popup(weapon_menu),"unit":popup(hud.selector),"speed":popup(hud.speeds)},"buttons":buttons,"environment":environment_view.snapshot()}
	JavaScriptBridge.eval("window.S14.accept("+JSON.stringify(json_data(result))+")",true)
	probe_events = []

func center(control: Control) -> Array:
	var value: Vector2=control.get_global_rect().get_center()
	return [value.x,value.y]
func popup(control: OptionButton) -> Dictionary:
	var value: PopupMenu=control.get_popup()
	var labels: Array[String]=[]
	var metadata_values: Array=[]
	for index: int in value.item_count: labels.append(value.get_item_text(index))
	for index: int in value.item_count: metadata_values.append(control.get_item_metadata(index))
	return {"visible":value.visible,"position":[value.position.x,value.position.y],"size":[value.size.x,value.size.y],"count":value.item_count,"labels":labels,"metadata":metadata_values}
static func json_data(value: Variant) -> Variant:
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Dictionary:
		var result: Dictionary={}
		for key: Variant in value: result[str(key)]=json_data(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value: result.append(json_data(item))
		return result
	return value
