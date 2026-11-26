extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle()
	check(errors.is_empty(), "load: " + str(errors))
	if not errors.is_empty(): finish(); return
	check(session.units.size() == 12 and session.definition_index.size() == 6, "formal six types / twelve units")
	for index: int in range(120): session.advance(1.0 / 60.0)
	check(session.orders.size() >= 6, "real commander parallel orders")
	check(int(session.counts.get("order_issued", 0)) >= 6, "real orders emitted")
	var tick: int = session.world.tick
	var before: Dictionary = session.world.snapshot()
	session.world.set_paused(true)
	session.advance(10.0)
	check(session.world.tick == tick, "paused clock")
	check(session.world.snapshot().units == before.units, "paused units and ammunition")
	session.world.set_paused(false)
	session.world.set_time_scale(0.5)
	session.advance(1.0, 60)
	check(session.world.tick == tick + 30, "half speed")
	session.world.set_time_scale(4.0)
	session.advance(1.0, 8)
	check(session.world.pending_ticks() >= 232, "retains tick backlog")
	while session.world.pending_ticks() > 0: session.advance(0.0, 60)
	check(session.world.tick == tick + 270, "backlog drains without deleted ticks")
	var initial_generation: int = session.world.generation
	for restart_index: int in range(3):
		check(session.restart(), "restart")
		check(session.world.generation == initial_generation + restart_index + 1, "generation")
		check(session.world.tick == 0 and session.units.size() == 12 and session.orders.is_empty() and session.journal.is_empty() and session.last_sequence == 0, "clear history and references")
		for index: int in range(120): session.advance(1.0 / 60.0)
		check(session.world.snapshot().units == before.units, "same seed after restart")
		check(session.world.drain_events().is_empty(), "event outbox consumed exactly once")
	var isolated: FirstPlayableSession = FirstPlayableSession.new()
	check(isolated.load_battle().is_empty(), "isolation load")
	for index: int in range(120): isolated.advance(1.0 / 60.0)
	var camera: ObserverCamera = ObserverCamera.new()
	root.add_child(camera)
	var metadata: Dictionary = {}
	for id: String in session.units:
		metadata[id] = {"domain":session.definition_index[session.units[id].definition_id].domain, "length":260.0}
	camera.reset_view(session.world.generation, metadata)
	var effects: CombatEffects = CombatEffects.new()
	effects.sound_enabled = false
	effects.effects_enabled = false
	root.add_child(effects)
	for index: int in range(1200):
		var events: Array[BattleEvent] = session.advance(1.0 / 60.0)
		isolated.advance(1.0 / 60.0)
		camera.set_mode("free" if index % 2 == 0 else "auto")
		camera.consume(events)
		camera.update_view(1.0 / 60.0, session.world.time_s(), session.units, false)
		effects.consume(events, session.world.generation)
		effects.advance(1.0 / 60.0)
	check(session.world.snapshot() == isolated.world.snapshot(), "camera and effects do not change combat")
	check(ObserverText.reason("withdrawn:low_fuel").contains("余油"), "Chinese terminal reason")
	check(ObserverText.execution(session.orders[0], session.scenario.presentation.names).length() > 0, "real execution text")
	finish()

func finish() -> void:
	for failure: String in failures: push_error("S07: " + failure)
	print("S07 integration checks: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
