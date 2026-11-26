extends SceneTree
func _initialize() -> void:call_deferred("run")
func draw() -> void:
	await process_frame;await process_frame;RenderingServer.force_draw(false,0)
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_size(Vector2i(1280,720));root.content_scale_size=Vector2i(1280,720)
	var game: FirstPlayableGame = (load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game);game.set_process(false)
	if not game.running:quit(1);return
	for index: int in 120:
		game.session.world.step_ticks(1);game.apply_presentation(game.session.consume_world())
	game.camera.follow("us_coast_01");game.hud._selected_unit="us_coast_01"
	game.camera.update_view(0,2,game.session.units,true)
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	await draw()
	(game.hud.card_scrollers.us as ScrollContainer).scroll_vertical=10000
	await draw()
	root.get_texture().get_image().save_png("res://docs/showcase/evidence/S10/ground_scroll.png")
	var can_reach: bool = (game.hud.card_scrollers.us as ScrollContainer).scroll_vertical>0
	game.hud.report_panel.show();await draw()
	root.get_texture().get_image().save_png("res://docs/showcase/evidence/S10/ground_report.png")
	var result: Dictionary = {"can_scroll_to_ground_orders":can_reach,"report_above_cards":game.hud.report_panel.z_index>game.hud.cards.us.z_index,"us_actual_order_cards":game.hud.card_rows.us.get_child_count(),"report_text":game.hud.report_text.text,"ground_detail":game.hud.unit_detail.text}
	FileAccess.open("res://docs/showcase/evidence/S10/ui_check.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if not can_reach:push_error("Cannot scroll to real ground orders")
	game.free();print("S10_GROUND_UI ",result);quit(0 if can_reach else 1)
