extends SceneTree

const FIX: Script = preload("res://tests/fixtures/combat_fixture.gd")

func _initialize() -> void:
	var arena: Dictionary = FIX.arena([
		FIX.spawn("shooter", "us", Vector3(0, 100, 0)),
		FIX.spawn("departed", "jp", Vector3(0, 100, -100), "jp_a6m5a_1944")])
	var world: SimulationWorld = arena.world
	world.step_ticks(1)
	world.drain_events()
	var departed: UnitState = world.get_unit("departed")
	# Reproduce the public S04 state after an actual aircraft_exit.
	departed.active = false
	departed.module_data["aircraft_motion"] = {"exited": true}
	var before: float = float(departed.module_data.damage.structure)
	arena.launcher.pending.append({"position": Vector3(0, 100, -20), "speed": 12000.0, "gravity": 0.0, "lifetime": 1.0})
	world.step_ticks(2)
	var hits: int = 0
	var damage_events: int = 0
	for event: BattleEvent in world.drain_events():
		if event.target_id == "departed" and event.kind == "hit": hits += 1
		if event.target_id == "departed" and event.kind == "damaged": damage_events += 1
	print(JSON.stringify({"probe": "departed_aircraft_collision", "exited": departed.module_data.aircraft_motion.exited,
		"hits_after_exit": hits, "damage_events_after_exit": damage_events, "structure_before": before,
		"structure_after": departed.module_data.damage.structure, "phase_after": departed.module_data.damage.phase}))
	quit(1 if hits > 0 or damage_events > 0 else 0)
