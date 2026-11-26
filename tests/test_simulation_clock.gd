extends SceneTree

const FIXTURE: Script = preload("res://tests/fixtures/simulation_fixture.gd")
var failures: int = 0

class MotionProbe extends SimulationModule:
	var samples: int = 0
	func _init() -> void:
		module_id = "test_motion"
		priority = 100
	func reset(_world: RefCounted) -> void:
		samples = 0
	func fixed_update(world_ref: RefCounted, delta_s: float) -> void:
		var world: SimulationWorld = world_ref as SimulationWorld
		for id: String in world.unit_ids():
			var state: UnitState = world.get_unit(id)
			state.position_m += state.velocity_mps * delta_s
			state.module_data["rng_sum"] = float(state.module_data.get("rng_sum", 0.0)) + world.rng.randf()
		if world.tick % 30 == 0:
			samples += 1
			world.emit_event("test_sample", "f6f_01", "", world.get_unit("f6f_01").position_m, {"sample": samples})
	func snapshot_state() -> Dictionary:
		return {"samples": samples}

class EventProbe extends SimulationModule:
	var samples: int = 0
	func _init() -> void:
		module_id = "test_events"
		priority = 200
	func reset(_world: RefCounted) -> void:
		samples = 0
	func fixed_update(world_ref: RefCounted, _delta_s: float) -> void:
		var world: SimulationWorld = world_ref as SimulationWorld
		for event: BattleEvent in world.events_for_tick(world.tick):
			if event.kind == "test_sample":
				samples += 1
				event.data["sample"] = -999
	func snapshot_state() -> Dictionary:
		return {"samples": samples}

func _initialize() -> void:
	call_deferred("run_test")

func expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func make_world() -> SimulationWorld:
	var result: SimulationWorld = SimulationWorld.new()
	expect(result.configure(FIXTURE.catalog(), FIXTURE.scenario()).is_empty(), "Configured real data world")
	expect(result.register_module(EventProbe.new()).accepted, "Registered event consumer")
	expect(result.register_module(MotionProbe.new()).accepted, "Registered fixed-step probe")
	return result

func run_test() -> void:
	var fast: SimulationWorld = make_world()
	var slow: SimulationWorld = make_world()
	var irregular: SimulationWorld = make_world()
	var events_fast: Array = []
	for index: int in range(600):
		fast.advance(1.0 / 60.0)
		for event: BattleEvent in fast.drain_events():
			events_fast.append(event.snapshot())
	for index: int in range(240):
		slow.advance(1.0 / 24.0)
	for index: int in range(100):
		for delta: float in [0.007, 0.023, 0.011, 0.059]:
			irregular.advance(delta)
	expect(fast.tick == 600 and slow.tick == 600 and irregular.tick == 600, "Equal 10 s external time reaches exactly 600 ticks across frame patterns")
	expect(fast.snapshot() == slow.snapshot() and fast.snapshot() == irregular.snapshot(), "Same seed/input matches every position, random sample and module state across frame patterns")
	expect(fast.get_unit("f6f_01").position_m.is_equal_approx(Vector3(1000.0, 1000.0, -700.0)), "Injected fixed-step movement has expected physical result")
	var events_slow: Array = []
	for event: BattleEvent in slow.drain_events():
		events_slow.append(event.snapshot())
	expect(events_fast == events_slow and events_fast.size() == 20, "Display draining rate does not alter event payloads or simulated state")
	expect(fast.snapshot().modules.test_events.samples == 20, "Independent module mailbox survives UI draining")
	var clock: SimulationWorld = make_world()
	clock.advance(0.008)
	clock.set_paused(true)
	var alpha: float = clock.interpolation_alpha()
	clock.advance(999.0)
	expect(clock.tick == 0 and clock.interpolation_alpha() == alpha, "Pause neither advances tick nor accumulates paused wall time")
	clock.set_paused(false)
	clock.advance(1.0 / 60.0 - 0.008)
	expect(clock.tick == 1, "Pre-pause fractional step retained")
	clock.reset()
	expect(clock.set_time_scale(0.5), "Slow motion supported")
	clock.advance(2.0)
	expect(clock.tick == 60, "0.5x two wall seconds equals one simulated second")
	clock.reset()
	clock.set_time_scale(2.0)
	clock.advance(0.5)
	expect(clock.tick == 60, "2x half wall second equals one simulated second")
	var frozen: Dictionary = clock.snapshot()
	expect(not clock.set_time_scale(NAN) and not clock.set_time_scale(-1.0), "Invalid speed rejected")
	clock.advance(-1.0)
	clock.advance(NAN)
	expect(clock.snapshot() == frozen, "Invalid external delta has no effect")
	clock.set_time_scale(0.0)
	clock.advance(10.0)
	expect(clock.snapshot() == frozen, "Zero playback speed freezes world")
	clock.reset()
	var first: UnitState = clock.get_unit("f6f_01")
	var second: UnitState = clock.get_unit("f6f_02")
	var mount_id: String = "wing_port_01"
	(first.weapons[mount_id] as WeaponState).remaining_rounds[0] = 0
	(first.weapons[mount_id] as WeaponState).train_rad = 1.0
	first.module_data.formation.role = "changed"
	expect((second.weapons[mount_id] as WeaponState).remaining_rounds[0] == 400 and (second.weapons[mount_id] as WeaponState).train_rad == 0.0, "Shared definition does not share weapon inventory or pose")
	expect(second.module_data.formation.role == "wingman", "Nested per-instance module data isolated")
	var view: Dictionary = clock.snapshot()
	view.units.f6f_02.weapons[mount_id].remaining_rounds[0] = -10
	view.units.f6f_02.module_data.formation.role = "mutated_snapshot"
	expect((second.weapons[mount_id] as WeaponState).remaining_rounds[0] == 400 and second.module_data.formation.role == "wingman", "Observer snapshot detached from live state")
	var pending: BattleCommand = FIXTURE.command("after_reset", BattleCommand.CEASE_FIRE, {"enabled": true})
	clock.submit_command(pending)
	clock.shared_state["temporary"] = [1, 2, 3]
	clock.emit_event("test_external")
	clock.set_paused(true)
	clock.reset()
	var pristine: SimulationWorld = make_world()
	expect(clock.snapshot() == pristine.snapshot() and clock.drain_events().is_empty(), "Reset clears clock, RNG, event queues, shared/module and per-unit state")
	clock.step_ticks(2)
	expect(not clock.get_unit("f6f_01").cease_fire, "Reset cleared pending commands")
	clock.reset()
	clock.step_ticks(600)
	expect(clock.snapshot() == fast.snapshot(), "Reset and same inputs reproduce entire simulation state")
	clock.reset(12345)
	clock.step_ticks(600)
	expect(clock.get_unit("f6f_01").module_data.rng_sum != fast.get_unit("f6f_01").module_data.rng_sum, "Different seed changes random stream")
	var budgeted: SimulationWorld = make_world()
	var offline: SimulationWorld = make_world()
	expect(budgeted.advance(100.0, 7) == 7 and budgeted.tick == 7 and budgeted.pending_ticks() == 5993, "Large wall delta executes only requested budget and retains debt")
	while budgeted.pending_ticks() > 0:
		expect(budgeted.advance(0.0, 13) <= 13, "Each catch-up call obeys per-frame budget")
	offline.step_ticks(6000)
	expect(budgeted.tick == 6000 and budgeted.snapshot() == offline.snapshot(), "Gradually drained debt equals 6000 offline ticks without skipped simulation")
	expect(budgeted.pending_time_s() < budgeted.fixed_delta_s(), "Catch-up leaves at most fractional time")
	var default_budget: SimulationWorld = make_world()
	expect(default_budget.advance(100.0) == 240, "Default catch-up is bounded for browser resume")
	print("PASS fixed clock, frame independence, pause/speed/reset, seeded modules and instance isolation" if failures == 0 else "FAIL clock: %d" % failures)
	quit(0 if failures == 0 else 1)
