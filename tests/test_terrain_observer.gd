extends SceneTree
var failures: PackedStringArray=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	var game: FirstPlayableGame=(load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	# Keep this S09 regression on its original four-ship/eight-aircraft map fixture.
	game.scenario_path="res://data/scenarios/island_harbor.json"
	root.add_child(game);game.set_process(false)
	check(game.running,"map game loads")
	if not game.running:finish();return
	for i: int in 120:
		game.session.world.step_ticks(1);game.apply_presentation(game.session.consume_world())
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label);await process_frame
	var selector_rect: Rect2=game.hud.map_selector.get_global_rect()
	check(selector_rect.end.x<=1257 and selector_rect.position.y>=650,"map selector fits 720p control row")
	for faction: String in ["jp","us"]:
		check(game.hud.card_rows[faction].get_child_count()==4,"four real commander cards "+faction)
		var rect: Rect2=(game.hud.cards[faction] as Control).get_global_rect()
		check(not selector_rect.intersects(rect),"map selector does not hide commander "+faction)
	check(not game.hud.map.get_global_rect().intersects(game.hud.cards.us.get_global_rect()),"map does not hide fourth US order")
	var before: Dictionary=game.session.world.snapshot()
	for i: int in range(1,game.hud.map_selector.item_count):
		game.hud.map_selector.item_selected.emit(i)
		game.camera.update_view(0,2.0,game.session.units,true)
		var clearance: float=game.camera.position.y-TerrainQueries.height_data(game.camera.terrain,game.camera.position,true)
		check(clearance>=7.99,"camera above terrain/buildings after locate")
		check(TerrainQueries.hit_data(game.camera.terrain,game.camera.focus+Vector3.UP*3,game.camera.position,false).is_empty(),"located camera sightline above real terrain")
	check(game.session.world.snapshot()==before,"map positioning cannot affect simulation")
	game.camera.focus=Vector3(-5100,640,-4900);game.camera.distance_m=500;game.camera.pitch=.1
	game.camera.update_view(.016,2.0,game.session.units,true)
	check(game.camera.position.y>=TerrainQueries.height_data(game.camera.terrain,game.camera.position,true)+7.99,"free camera below hillside is corrected")
	var unit: Dictionary=game.session.units.us_air_1
	game.hud._selected_unit="us_air_1";game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	check(not game.hud.unit_detail.text.contains("maneuver_") and not game.hud.unit_detail.text.contains("safety_state"),"normal UI uses Chinese maneuver state")
	check(ObserverText.maneuver({"maneuver_phase":"dive_attack","maneuver_reason":"height_advantage"},{"safety_state":"normal","height_agl_m":300}).contains("俯冲攻击"),"actual maneuver phase translated")
	check(ObserverText.maneuver({"maneuver_phase":"recover","maneuver_reason":"low_altitude_recovery"},{"safety_state":"low_altitude_recovery"}).contains("低空改出"),"actual safety state translated")
	game.queue_free();finish()
func finish() -> void:
	for failure: String in failures:push_error("S09 observer: "+failure)
	print("S09 map observer: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
