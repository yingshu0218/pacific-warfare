extends "res://tests/fixtures/combat_test.gd"

## Check the actual consumer order at 15/60Hz, using real engine projectile hits.
func run_test() -> void:
	var records: Array[Dictionary] = []
	for definition_id: String in ["us_f6f5_1944","jp_a6m5a_1944"]:
		for ticks_per_frame: int in [1,4]:
			var a: Dictionary = AircraftDamageFixture.arena(definition_id)
			var world: SimulationWorld = a.world
			var effects: CombatEffects = CombatEffects.new()
			effects.sound_enabled = false
			effects.effect_capacity = 384
			root.add_child(effects)
			effects.consume([],world.generation)
			effects.apply_snapshot(world.snapshot())
			AircraftDamageFixture.shoot(a,"engine",14)
			var maximum_error: float = 0
			var checked: int = 0
			for frame: int in 180/ticks_per_frame:
				var events: Array[BattleEvent] = []
				for i: int in ticks_per_frame:
					world.step_ticks(1)
					events.append_array(world.drain_events())
				# Exactly the agreed production interface order.
				effects.advance(float(ticks_per_frame)/60)
				effects.consume(events,world.generation)
				effects.apply_snapshot(world.snapshot())
				var target: UnitState = world.get_unit("target")
				var anchor: Vector3 = SimData.vec3((a.config as CombatConfig).unit_profile(definition_id).damage_effects.smoke_anchor_m)
				for slot: Dictionary in effects.slots:
					if slot.active and slot.get("emitter_id","") == "engine_smoke" and absf(float(slot.born_s)-effects.elapsed_s)<.0001:
						maximum_error = maxf(maximum_error,(slot.position as Vector3).distance_to(target.world_transform()*anchor))
						checked += 1
			expect(checked > 2,"Real engine damage emits current smoke samples")
			expect(maximum_error < .25,"Newborn engine smoke source remains at current nose under advance/consume/snapshot order: "+definition_id+" ticks/frame="+str(ticks_per_frame)+" error_m="+str(maximum_error))
			records.append({"definition_id":definition_id,"ticks_per_frame":ticks_per_frame,"samples":checked,"maximum_newborn_smoke_anchor_error_m":maximum_error})
			effects.free()
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/DM01/emitter-timing.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	finish("DM01 current engine source")
