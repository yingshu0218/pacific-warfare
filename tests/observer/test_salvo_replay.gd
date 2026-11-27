extends SceneTree
## Uses the normal Open Sea scene and its unchanged seeded events, not scripted hits.
const SCENE: PackedScene = preload("res://showcase/open_sea.tscn")
var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var game: FirstPlayableGame = SCENE.instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	_check(game.running and not game.salvo_replay and not game.salvo_overlay.visible,"real scene loads with no overlay")
	if not game.running: quit(1); return
	var matching: Dictionary = {}
	var terminal_events: Dictionary = {}
	var tape: RefCounted = game.session.observed_salvos()
	for seconds: int in 44:
		game.session.world.step_ticks(60)
		var events: Array[BattleEvent] = game.session.consume_world()
		game.apply_presentation(events)
		for event: BattleEvent in events:
			if event.kind in ["hit","surface_impact","airburst"]:
				terminal_events[str(event.data.get("projectile_id",""))] = event
		for group: Dictionary in tape.groups:
			var kinds: Dictionary = {}
			for id: String in group.ids: kinds[tape.tracks[id].terminal] = true
			if kinds.has("sea") and kinds.has("hit"):
				matching = group
				break
		if not matching.is_empty(): break
	_check(not matching.is_empty(),"one actual salvo produced both hit and sea terminals")
	if matching.is_empty(): quit(1); return
	var before: Dictionary = game.session.world.snapshot()
	var source: String = matching.source
	for i: int in game.hud.selector.item_count:
		if game.hud.selector.get_item_metadata(i) != source: continue
		game.hud.selector.select(i)
		game.hud.selector.item_selected.emit(i)
		break
	game.hud.salvo_button.pressed.emit()
	_check(game.salvo_replay and game.salvo_overlay.visible,"visible using actual observer HUD")
	var rank: int = 0
	var shown_time: float = game.session.presentation_time_s
	while rank < 24 and tape.latest(source,shown_time,rank) != matching:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_T; key.pressed = true; key.shift_pressed = true
		game._input(key)
		rank += 1
	_check(rank < 24 and game._salvo_rank == rank,"Shift+T selects previous actual salvo")
	var first_time: float = float(matching.time_s)+.25
	var early: Array[Dictionary] = tape.visible_tracks(matching,first_time)
	for row: Dictionary in early:
		_check(str(row.terminal).is_empty() and row.points.size()>=2,"scrubbed replay shows no future terminal")
		var track: Dictionary = tape.tracks[row.id]
		_check(float(track.times[row.points.size()-1])<=first_time,"last visible coordinate is already recorded at playback time")
	var completed: Array[Dictionary] = tape.visible_tracks(matching,shown_time)
	var center: Vector3 = Vector3.ZERO
	for row: Dictionary in completed:
		var event: BattleEvent = terminal_events[row.id]
		_check(row.points[-1].is_equal_approx(event.position_m),"terminal marker uses authoritative event coordinate")
		center += event.position_m
	center /= float(completed.size())
	game.camera.set_mode("free")
	var counts: Array[Dictionary] = []
	for distance: float in [450.,3800.]:
		game.camera.position = center+Vector3(.42,.47,.79)*distance
		game.camera.look_at(center)
		game._refresh_salvo_overlay()
		counts.append(game.salvo_overlay.terminal_counts.duplicate())
		_check(game.salvo_overlay.visible and game.salvo_overlay.point_count > 20 and game.salvo_overlay.lines.get_surface_count()==1,"overlay renders at near and far observer distances")
		for row: Dictionary in completed:
			_check(root.get_visible_rect().has_point(game.camera.unproject_position(row.points[-1])),"actual terminal remains inside camera view")
	_check(counts[0] == counts[1] and counts[0].has("sea") and counts[0].has("hit"),"both visually distinct terminal types retained across views")
	game.hud.salvo_button.pressed.emit()
	_check(not game.salvo_overlay.visible and game.salvo_overlay.lines.get_surface_count()==0,"toggle removes trail and terminals")
	_check(before==game.session.world.snapshot(),"selection, replay, camera and disable leave simulation snapshot byte-equivalent")
	print(JSON.stringify({"salvo_event":matching.id,"source":source,"terminal_counts":counts,"rounds":completed.size(),"rank":rank,"failures":failures}))
	game._action("restart",null)
	_check(not game.salvo_replay and game.session.observed_salvos().groups.is_empty(),"restart clears tape and stays off")
	game.free()
	for message: String in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
