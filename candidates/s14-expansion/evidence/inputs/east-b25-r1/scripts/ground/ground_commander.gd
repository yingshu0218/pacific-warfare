class_name GroundCommander
extends SimulationModule
## No world in the planner: friendly snapshot + static profiles only.
var next_s: float = 0.0
var serial: int = 0

func _init() -> void: module_id="ground_commander";priority=205
func reset(_world: RefCounted) -> void:next_s=0.0;serial=0

func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	if world.time_s()<next_s:return
	next_s=world.time_s()+6.0
	for faction: String in ["jp","us"]:
		var view: Dictionary = world.commander_snapshot(faction)
		for proposal: Dictionary in plan(view):
			serial+=1
			proposal.merge({"order_id":"ground_ai:%s:%04d"%[faction,serial],"issuer_id":faction+"_commander","faction_id":faction,"source":"ai"})
			world.submit_order(BattleOrder.from_data(proposal))

static func plan(view: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var owned: Dictionary = {}
	for order: Dictionary in view.orders:
		if order.status not in BattleOrder.TERMINAL:
			for id: String in order.assigned_unit_ids:owned[id]=true
	var ids: Array = view.units.keys();ids.sort()
	for id: String in ids:
		var unit: Dictionary = view.units[id]
		var site: Dictionary = unit.module_data.get("ground_initial",{})
		if site.is_empty() or not unit.active or owned.has(id):continue
		var coastal: bool = site.role=="coastal_gun"
		var selected: Dictionary = {}
		var nearest: float = INF
		for contact: Dictionary in view.contacts:
			if not contact.valid or not contact.fresh or contact.domain!=("ship" if coastal else "aircraft"):continue
			var distance: float = (unit.position_m as Vector3).distance_to(contact.position_m)
			if distance<nearest:nearest=distance;selected=contact
		result.append({"recipient_ids":[id],"order_type":"engage" if not selected.is_empty() else "patrol", "target_id":str(selected.get("entity_id","")),
			"area":{"center_m":SimData.array3(unit.position_m),"radius_m":15636.24 if coastal else 2743.2},"intent":"shore_sector_watch" if coastal else "ground_air_defence"})
	return result

func snapshot_state() -> Dictionary:return {"next_s":next_s,"serial":serial}
