extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var evidence: Dictionary = {}
	var effects: CombatEffects = CombatEffects.new()
	effects.sound_enabled = false
	root.add_child(effects)
	for kind: String in ["four","current"]:
		var world: SimulationWorld = AircraftSpatialFixture.build(kind)
		var seconds: float = 110.0 if kind == "four" else 40.0
		var first: Dictionary = _advance(world,effects,[1.0/30.0],seconds,false)
		check(world.reset(),kind+" spatial world reset")
		if kind == "four": AircraftSpatialFixture.issue(world,4)
		var second: Dictionary = _advance(world,effects,[0.013,0.027,0.009,0.031],seconds,true)
		check(first.state == second.state,kind+" full spatial state identical after reset, irregular frames, pause and 2x")
		check(first.events == second.events,kind+" all commands, real shots, hits and maneuver events identical with effects toggled")
		evidence[kind] = {"seconds":seconds,"ticks":world.tick,"events":first.events.size(),
			"state_sha256":_digest(first.state),"events_sha256":_digest(first.events)}
	effects.free()
	evidence["checks"] = checks
	evidence["failures"] = failures
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-spatial/replay.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	print("S04 spatial reset/frame/effect replay ","PASS" if failures == 0 else "FAIL"," checks=",checks)
	quit(0 if failures == 0 else 1)

func _advance(world: SimulationWorld, effects: CombatEffects, frames: Array[float], seconds: float, extras: bool) -> Dictionary:
	var all_events: Array = []
	var elapsed: float = 0.0
	var frame: int = 0
	if extras:
		world.set_paused(true)
		world.advance(100.0)
		check(world.tick == 0,"paused reset world accumulates no simulation time")
		world.set_paused(false)
		world.set_time_scale(2.0)
	while elapsed < seconds-0.00000001:
		var delta: float = minf(frames[frame%frames.size()],seconds-elapsed)
		world.advance(delta/(2.0 if extras else 1.0))
		var events: Array[BattleEvent] = world.drain_events()
		for event: BattleEvent in events: all_events.append(event.snapshot())
		effects.effects_enabled = extras and frame%11 < 7
		effects.consume(events,world.generation)
		effects.apply_snapshot(world.snapshot())
		effects.advance(delta)
		elapsed += delta
		frame += 1
	world.advance(0.00000001)
	for event: BattleEvent in world.drain_events(): all_events.append(event.snapshot())
	return {"state":world.snapshot(),"events":all_events}

func _digest(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()
