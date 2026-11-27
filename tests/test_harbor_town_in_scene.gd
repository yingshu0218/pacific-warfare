extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: FirstPlayableGame=(load("res://showcase/carrier_harbor.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_process(false)
	if not game.running or game.map_view==null: quit(2);return
	var town: Node3D=game.map_view.get_node_or_null("HarborTown")
	if town==null: quit(3);return
	var terrain: Dictionary=game.session.world.shared_state.terrain
	var m: Dictionary=town.metrics
	var ok: bool=m.landings==3 and m.waterfront>=7 and m.landing_clearance>.3 and m.triangles<20000
	ok=ok and terrain.solids.size()==245 and terrain.source.deployment_sites.size()==7 and terrain.source.viewpoints.size()==9
	ok=ok and game.map_view.find_children("HarborTown","Node3D",true,false).size()==1 and town.find_children("*","CollisionObject3D",true,false).is_empty()
	var menu: OptionButton=game.hud.map_selector
	var requested: Array[String]=["map02_town_ferry", "map02_town_market", "map02_town_hill"]
	for id: String in requested:
		var found: bool=false
		for i: int in menu.item_count:
			if menu.get_item_metadata(i)!=id: continue
			menu.item_selected.emit(i)
			found=game.camera.shot_label==menu.get_item_text(i)
		ok=ok and found
	game._reset_presentation()
	ok=ok and menu.item_count==13 and game.map_view.find_children("HarborTown","Node3D",true,false).size()==1
	print("PORT06 real scene harbor town ",m," menu=",menu.item_count," pass=",ok)
	game.free()
	quit(0 if ok else 1)
