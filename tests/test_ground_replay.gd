extends SceneTree
## Full default world and all events, at different presentation frame groupings.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle("res://data/scenarios/island_harbor_defence.json")
	if not errors.is_empty():push_error(str(errors));quit(1);return
	var baseline: Dictionary = drive(session,[1.0/60.0],false)
	var results: Array = []
	var ok: bool = true
	for index: int in 3:
		session.restart()
		var replay: Dictionary = drive(session,[.013,.027,.009,.031] if index%2==0 else [1.0/20.0],true)
		var same: bool = replay==baseline
		results.append({"restart":index+1,"same_full_state_and_events":same,"event_count":replay.events.size(),"tick":session.world.tick})
		ok=ok and same
	FileAccess.open("res://docs/showcase/evidence/S10/replay.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Actual15-unit default battle,30simulated seconds; all units,orders,modules and events","checks":results,"passed":ok},"\t"))
	if not ok:push_error("S10 full default replay differs with render cadence/pause/2x/restart")
	print("S10_REPLAY ",results);quit(0 if ok else 1)

func drive(session: FirstPlayableSession, frames: Array, controls: bool) -> Dictionary:
	if controls:
		session.world.set_paused(true);session.advance(10.0);session.world.set_paused(false)
		session.world.set_time_scale(2.0)
	else:session.world.set_time_scale(1.0)
	var time: float = 0
	var frame: int = 0
	var events: Array = []
	while time<30.0-.00000001:
		var dt: float = minf(frames[frame%frames.size()],30.0-time)
		for event: BattleEvent in session.advance(dt/(2.0 if controls else 1.0),16):events.append(event.snapshot())
		time+=dt;frame+=1
	for event: BattleEvent in session.advance(.00000001,16):events.append(event.snapshot())
	var state: Dictionary = session.world.snapshot()
	return {"state":state,"events":events,"report":session.report()}
