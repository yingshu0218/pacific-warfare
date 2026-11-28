extends SceneTree
## The shipped harbor menu opens the same seed used by the camera-only recording.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var game: AllUnitsShowcase = load("res://showcase/carrier_harbor.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var index: int = -1
	for i: int in game.segment_menu.item_count:
		if game.segment_menu.get_item_text(i).begins_with("青岬空袭"): index = i
	if index < 0: push_error("Raid menu entry missing"); quit(1); return
	game.segment_menu.item_selected.emit(index)
	if game.exercise != "airfield_raid" or game.session.units.size() != 9:
		push_error("Raid failed to initialize through the harbor menu"); quit(1); return
	var world: SimulationWorld = game.session.world
	var firing: Dictionary = {}
	var valid_ground_impacts: int = 0
	var releases: int = 0
	var escort: bool = false
	var intercept: bool = false
	for i: int in 120:
		world.step_ticks(60)
		for row: Dictionary in world.orders_snapshot():
			escort = escort or (row.order_type == "escort" and row.target_id == "us_b25_1" and row.assigned_unit_ids.has("us_escort_1"))
			intercept = intercept or (row.order_type == "intercept" and row.assigned_unit_ids.has("jp_intercept_1"))
		for event: BattleEvent in game.session.consume_world():
			if event.kind == "fired":
				firing[event.entity_id] = int(firing.get(event.entity_id,0))+1
			elif event.kind == "bomb_released" and event.entity_id.begins_with("us_b25"):
				releases += 1
			elif event.kind == "bomb_explosion" and event.entity_id.begins_with("us_b25") and event.target_id == "east_cape":
				valid_ground_impacts += 1
	var pass_check: bool = escort and intercept and releases > 0 and valid_ground_impacts > 0
	for id: String in ["jp_harbor_aa_service","jp_harbor_aa_ridge","jp_airfield_aa","jp_intercept_2"]:
		pass_check = pass_check and firing.has(id)
	print("Raid QA escort=",escort," intercept=",intercept," releases=",releases," east_cape explosions=",valid_ground_impacts," fired=",firing)
	quit(0 if pass_check else 1)
