extends SceneTree

const HARBOR: String = "res://showcase/carrier_harbor.tscn"
const WARMUP: int = 180
const DEFAULT_FRAMES: int = 3420
const DELTAS: Array[float] = [1.0 / 120.0, 1.0 / 120.0, 1.0 / 30.0, 1.0 / 60.0]

class TimingProbe extends WebRunProbe:
	var stages_us: Array[int] = []
	var frame_events: Array[BattleEvent] = []

	func _init(owner: FirstPlayableGame) -> void:
		super(owner)
		enabled = true

	func consume(source: Array[BattleEvent]) -> void:
		frame_events = source

	func observe(_delta_s: float, advance_us: int, presentation_us: int, camera_us: int, hud_us: int) -> void:
		stages_us.assign([advance_us, presentation_us, camera_us, hud_us])

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() else "full"
	var frames: int = int(args[1]) if args.size() > 1 else DEFAULT_FRAMES
	if mode not in ["full", "paused", "world", "mixed"] or frames <= 0 or frames % 60 != 0:
		push_error("PF01 expected full/paused/world/mixed and a positive multiple of 60 frames")
		quit(1)
		return
	var game: FirstPlayableGame = (load(HARBOR) as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	var world: SimulationWorld = game.session.world
	if not game.running or world.seed_value != 707 or world.unit_ids().size() != 27 or world.time_scale != 1.0:
		push_error("PF01 unexpected initial harbor state")
		quit(1)
		return
	game._action("camera", "fighter")
	var probe: TimingProbe = TimingProbe.new(game)
	game._web_probe = probe
	var measures: Dictionary = {"total": [], "advance_or_world": [], "presentation": [], "camera": [], "hud": [], "hud_at_least_20us": [], "advance_zero_tick": [], "advance_nonzero_tick": []}
	var events_digest: HashingContext = HashingContext.new()
	events_digest.start(HashingContext.HASH_SHA256)
	var view_digest: HashingContext = HashingContext.new()
	view_digest.start(HashingContext.HASH_SHA256)
	var digest_checkpoints: Array[Dictionary] = []
	var counts: Dictionary = {}
	var event_count: int = 0
	var start_tick: int = -1
	var measurement_us: int = 0
	var wall_start_us: int = 0
	for frame: int in range(WARMUP + frames):
		if frame == WARMUP:
			if mode == "paused": world.set_paused(true)
			start_tick = world.tick
			wall_start_us = Time.get_ticks_usec()
		var delta_s: float = DELTAS[frame % DELTAS.size()] if mode == "mixed" else 1.0 / 60.0
		var events: Array[BattleEvent]
		var tick_before: int = world.tick
		var start_us: int = Time.get_ticks_usec()
		if mode == "world":
			world.advance(delta_s, 16)
			events = world.drain_events()
		else:
			game._process(delta_s)
			events = probe.frame_events
		var elapsed_us: int = Time.get_ticks_usec() - start_us
		if frame >= WARMUP:
			measurement_us += elapsed_us
			measures.total.append(elapsed_us)
			var advance_us: int = elapsed_us if mode == "world" else probe.stages_us[0]
			measures.advance_or_world.append(advance_us)
			var advance_key: String = "advance_zero_tick" if world.tick == tick_before else "advance_nonzero_tick"
			measures[advance_key].append(advance_us)
			if mode != "world":
				measures.presentation.append(probe.stages_us[1])
				measures.camera.append(probe.stages_us[2])
				measures.hud.append(probe.stages_us[3])
				if probe.stages_us[3] >= 20: measures.hud_at_least_20us.append(probe.stages_us[3])
		for event: BattleEvent in events:
			events_digest.update(var_to_bytes(event.snapshot()))
			event_count += 1
			counts[event.kind] = int(counts.get(event.kind, 0)) + 1
		if (frame + 1) % 60 == 0:
			digest_checkpoints.append({"tick":world.tick, "world":_digest(world.snapshot()), "events":event_count,
				"effects":_digest(game.effects.statistics()) if mode != "world" else ""})
		if mode != "world" and (frame % 4 == 0 or (frame + 1) % 60 == 0):
			view_digest.update(var_to_bytes([game.session.units, game.session.presentation_units,
				game.session.command_postures, game.session.presentation_bombs, game.session.presentation_alpha,
				game.session.presentation_time_s, game.session.orders, game.session.journal,
				game.session.phases, game.session.counts, game.session.report()]))
	var wall_s: float = float(Time.get_ticks_usec() - wall_start_us) / 1000000.0
	var statistics: Dictionary = {}
	for stage: String in measures: statistics[stage] = _statistics(measures[stage])
	var result: Dictionary = {"mode":mode, "samples":statistics, "wall_s_including_digest":wall_s,
		"seed":world.seed_value, "units":world.unit_ids().size(), "speed":world.time_scale,
		"paused":world.paused, "start_tick":start_tick, "tick":world.tick,
		"sim_delta_s":float(world.tick - start_tick) * world.fixed_delta_s(), "pending_s":world.pending_time_s(),
		"measured_cpu_wall_s":float(measurement_us) / 1000000.0, "camera":game.camera.mode,
		"display_server":DisplayServer.get_name(), "end_reason":game.session.ended_reason,
		"checkpoints":digest_checkpoints, "event_count":event_count, "counts":counts,
		"events_sha256":events_digest.finish().hex_encode(), "views_sha256":view_digest.finish().hex_encode()}
	if mode != "world":
		game._action("restart", null)
		game._action("camera", "fighter")
		for frame: int in range(60): game._process(1.0 / 60.0)
		result["restart"] = {"tick":world.tick, "generation":world.generation, "units":game.session.units.size(),
			"world":_digest(world.snapshot()), "effects":_digest(game.effects.statistics()),
			"view":_digest(game.session.presentation_units), "events":game.session.counts}
	print("PF01_JSON ", JSON.stringify(result))
	game.free()
	quit()

func _digest(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func _statistics(values: Array) -> Dictionary:
	if values.is_empty(): return {"n":0}
	values.sort()
	return {"n":values.size(), "p50":_percentile(values, 0.50), "p95":_percentile(values, 0.95),
		"p99":_percentile(values, 0.99)}

func _percentile(values: Array, percentile: float) -> float:
	return float(values[ceili(values.size() * percentile) - 1]) / 1000.0
