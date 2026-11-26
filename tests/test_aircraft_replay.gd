extends SceneTree
var failures: int = 0

func _initialize() -> void:
	var a: Dictionary = _run([1.0 / 30.0], false)
	var b: Dictionary = _run([0.013, 0.027, 0.009, 0.031], true)
	if a != b:
		push_error("Aircraft CombatSuite frame/pause/speed replay mismatch")
		quit(1)
		return
	print("S04 combat replay PASS 40s, same full state and all events at 30fps/irregular frames, pause, 2x")
	quit(0)

func _run(frames: Array[float], pause_and_speed: bool) -> Dictionary:
	var world: SimulationWorld = AircraftFixture.world([
		AircraftFixture.spawn("jp_0","jp",Vector3(0,1500,0),"jp_a6m5a_1944",0,120),
		AircraftFixture.spawn("jp_1","jp",Vector3(90,1545,150),"jp_a6m5a_1944",0,120),
		AircraftFixture.spawn("us_0","us",Vector3(0,1500,-3800),"us_f6f5_1944",PI,120),
		AircraftFixture.spawn("us_1","us",Vector3(-90,1545,-3950),"us_f6f5_1944",PI,120)],true)
	AircraftFixture.order(world,"jp_engage",["jp_0","jp_1"],"engage","us_0")
	AircraftFixture.order(world,"us_engage",["us_0","us_1"],"engage","jp_0")
	var events: Array = []
	var time: float = 0.0
	var frame: int = 0
	if pause_and_speed:
		world.set_paused(true)
		world.advance(70.0)
		world.set_paused(false)
		world.set_time_scale(2.0)
	while time < 40.0 - 0.00000001:
		var dt: float = minf(frames[frame % frames.size()], 40.0 - time)
		world.advance(dt / (2.0 if pause_and_speed else 1.0))
		for event: BattleEvent in world.drain_events():
			events.append(event.snapshot())
		time += dt
		frame += 1
	world.advance(0.00000001)
	for event: BattleEvent in world.drain_events():
		events.append(event.snapshot())
	return {"state":world.snapshot(),"events":events}
