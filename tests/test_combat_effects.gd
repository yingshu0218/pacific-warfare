extends "res://tests/fixtures/combat_test.gd"

func run_test() -> void:
	var on: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(100,100,0)),FIX.spawn("enemy","jp",Vector3(0,100,-40))])
	var off: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(100,100,0)),FIX.spawn("enemy","jp",Vector3(0,100,-40))])
	var effects: CombatEffects=CombatEffects.new()
	effects.effect_capacity=2
	effects.sound_capacity=0
	effects.sound_enabled=false
	root.add_child(effects)
	for world_data: Dictionary in [on,off]:
		(world_data.launcher as FIX.Launcher).pending=[{"ammo":"us_127mm_5in38_shell","gravity":0.},{"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,-10),"gravity":0.}]
	var replay: Array[BattleEvent]=[]
	for tick_index: int in range(120):
		on.world.step_ticks(1)
		var events: Array[BattleEvent]=on.world.drain_events()
		replay.append_array(events)
		effects.consume(events,on.world.generation)
		effects.advance(1./60.)
		off.world.step_ticks(1)
	var before: int=effects.shown_events
	effects.consume(replay,on.world.generation)
	expect(effects.shown_events==before,"Repeated presentation events deduplicated by generation and sequence")
	expect(effects.statistics().allocated<=2 and effects.dropped_visuals>0,"Visual pool overflow remains bounded and explicitly counted")
	expect(on.world.snapshot()==off.world.snapshot(),"Effects enabled/overflow/every-tick consume versus no consumer leave exact same simulation")
	effects.effects_enabled=false
	effects.consume(off.world.drain_events(),off.world.generation)
	effects.advance(1.)
	expect(effects.statistics().active==0,"Disabled effects clear visuals while still advancing event cursor")
	effects.clear(on.world.generation+1)
	effects.effects_enabled=true
	effects.consume(replay,on.world.generation+1)
	expect(effects.shown_events==replay.size(),"New generation accepts reused sequences exactly once")
	var stream: AudioStreamWAV=CombatAudioBank.synthesize("heavy")
	expect(stream.data.size()>1000 and stream.mix_rate==11025,"Original procedural audio provides finite PCM without external assets")
	effects.free()
	finish("effects isolation")
