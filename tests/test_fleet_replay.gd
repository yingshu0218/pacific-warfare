extends "res://tests/fixtures/fleet_test.gd"

func run_test() -> void:
	var spawns: Array = [FLEET.spawn("core", Vector3.ZERO, 7.0, 0.0, "jp_yamato_1944_04"), FLEET.spawn("screen", Vector3(-620, 0, 700), 7.0)]
	var world: SimulationWorld = FLEET.world(spawns, [], true)
	var baseline: Dictionary = _drive(world, false)
	for repetition: int in 3:
		expect(world.reset(), "World resets with the installed fleet modules")
		expect(world.orders_snapshot().is_empty() and world.get_unit("core").active_order_id.is_empty(), "Reset removes old high-level ownership")
		var again: Dictionary = _drive(world, repetition % 2 == 0)
		expect(again == baseline, "Three replays reproduce actual unit, command, formation and commander state with different frame grouping")
	var config: FleetConfig = FLEET.config()
	var alien: SimulationWorld = FLEET.world(spawns, [], true, false, config)
	config.data.profiles.jp_yamato_1944_04.historical_max_knots = 1.0
	var isolated: Dictionary = _drive(alien, true)
	expect(isolated == baseline, "Caller-owned configuration mutation cannot alter an installed simulation")
	# Real retreat is a once-only exit; it is not resumed by the commander.
	var retiring: SimulationWorld = FLEET.world([FLEET.spawn("ship", Vector3.ZERO)], [], true)
	FLEET.order(retiring, "retire", ["ship"], "retreat", "", Vector3(0, 0, -120), 180.0, "human")
	var events: Array[BattleEvent] = FLEET.run(retiring, 45.0)
	var exits: int = 0
	for event: BattleEvent in events:
		if event.kind == "ship_exit":
			exits += 1
			expect(not event.data.destroyed and not event.data.sunk, "Ship exit is explicitly separate from destruction and sinking")
	expect(exits == 1 and retiring.orders_snapshot().size() == 1 and not retiring.get_unit("ship").active, "A completed withdrawal exits once and cannot be redispatched by the program commander")
	expect(retiring.reset() and retiring.get_unit("ship").active and not retiring.get_unit("ship").module_data.ship_motion.exited, "Reset restores an exited ship and clears its exit marker")
	# Released old low-level commands must not survive cancellation into control.
	evidence["baseline"] = baseline
	evidence["reset_replays"] = 3
	finish("fleet_replay")

func _drive(world: SimulationWorld, grouped: bool) -> Dictionary:
	for frame: int in range(600 if grouped else 1800):
		world.advance(1.0 / 20.0 if grouped else 1.0 / 60.0)
		world.drain_events()
	var snapshot: Dictionary = world.snapshot()
	return {"units": snapshot.units, "orders": snapshot.orders, "modules": snapshot.modules, "tick": snapshot.tick}
