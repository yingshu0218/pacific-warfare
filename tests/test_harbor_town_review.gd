extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene=load("res://scenes/map02/harbor_town_review.tscn")
	if packed==null: quit(2);return
	var view: Node3D=packed.instantiate()
	root.add_child(view)
	var m: Dictionary=view.town.metrics
	var ok: bool=m.shops>=15 and m.homes>=18 and m.hill_y-m.market_y>16.0 and m.max_main_grade<.22
	ok=ok and m.yard_pads==2 and m.foundations==m.shops+m.homes+m.waterfront and m.waterfront>=7 and m.landings==3 and m.landing_clearance>.3 and m.triangles<20000 and view.town.get_child_count()==2
	ok=ok and view.chart.solids.size()==245 and view.chart.source.deployment_sites.size()==7
	ok=ok and view.map_view.has_node("RefinedQuays") and view.map_view.has_node("HarborSupportProps")
	for i: int in 4:
		view.select_view(i)
		ok=ok and view.selected==i and view.camera.global_position.is_finite() and view.camera.global_position.y>0
	print("PORT05 ",m," result=",ok)
	view.free()
	quit(0 if ok else 1)
