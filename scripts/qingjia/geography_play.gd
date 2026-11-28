extends "res://scripts/showcase/expansion/carrier_harbor.gd"

func _build_guide_ui() -> void:
	super._build_guide_ui()
	segment_menu.set_item_text(MODES.size(), "青岬群岛 · 海陆空试玩")

func choose_exercise(index: int) -> void:
	if index != MODES.size():
		super.choose_exercise(index)
		return
	var errors := session.load_battle(scenario_path)
	if not errors.is_empty():
		hud.show_error("青岬群岛装配失败\n" + "\n".join(errors))
		return
	exercise = "harbor"
	_install_missions()
	_reset_presentation()
	guide.reset(exercise)
	guide.active = false
	camera.set_mode("auto")
	_update_guide(0)
	_refresh_guide_ui()
