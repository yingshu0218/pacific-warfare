class_name BombingEffects
extends CombatEffects

## Adds only bounded visuals for real explosions; damage remains CombatDamage.
var last_bomb_sequence: int=0
func consume(events: Array[BattleEvent], new_generation: int) -> void:
	if generation!=new_generation:last_bomb_sequence=0
	super.consume(events,new_generation)
	for event: BattleEvent in events:
		if event.kind!="bomb_explosion" or event.sequence<=last_bomb_sequence:continue
		last_bomb_sequence=event.sequence
		emission_time_s=event.time_s;emission_seed=float(event.sequence)*.131;component_index=0
		var size: float=clampf(float(event.data.visual_radius_m)*.45,1.0,14.0)
		if event.data.get("surface","")!="sea":
			_emit("fire",event.position_m,Vector3.UP*size,size*.65,1.0)
			_emit("smoke",event.position_m,Vector3.UP*size*.8,size,3.0)
			_emit("dust",event.position_m,Vector3.UP*2.0,size,2.5)
