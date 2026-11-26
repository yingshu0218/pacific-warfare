class_name BombingEffects
extends CombatEffects

func _consume_event(event: BattleEvent) -> void:
	if event.kind != "bomb_explosion":
		super._consume_event(event)
		return
	var width: float = clampf(float(event.data.visual_radius_m)*.52,4.,34.)
	var surface: String = str(event.data.get("surface",""))
	if surface == "sea":
		_splash(event.position_m,clampf(width*.52,.7,17.))
	else:
		_contact_blast(event.position_m,surface,width,event.data.get("normal",Vector3.UP))
	_play(event.position_m,"impact",-2.)
