extends SceneTree
var checks: int = 0
var evidence: Dictionary = {}

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func _initialize() -> void:
	var world: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("lead", "jp", Vector3(0, 1500, 0))])
	var unit: UnitState = world.get_unit("lead")
	unit.module_data["aircraft_control"] = {"heading_rad": 0.0, "altitude_m": 1500.0, "speed_mps": 110.0, "throttle": 0.60}
	AircraftFixture.run(world, 60)
	check(unit.position_m.z < -6000.0, "sustained cruise")
	check(unit.position_m.y > 1490.0 and unit.position_m.y < 1510.0, "cruise height")
	check(unit.velocity_mps.length() < 175.0, "finite speed")
	check(float(unit.module_data.aircraft_motion.fuel_used_kg) > 1.0, "fuel consumed")
	evidence.cruise = {"position": SimData.array3(unit.position_m), "speed_mps": unit.velocity_mps.length(), "fuel_used_kg": unit.module_data.aircraft_motion.fuel_used_kg}
	world.reset()
	unit = world.get_unit("lead")
	unit.module_data["aircraft_control"] = {"heading_rad": PI, "altitude_m": 100000.0, "speed_mps": 110.0, "throttle": 0.60}
	var before: Vector3 = unit.position_m
	world.step_ticks(1)
	check(unit.position_m.distance_to(before) < 2.0, "no teleport")
	check(absf(unit.rotation_rad.y) < 0.002 and absf(unit.rotation_rad.z) < 0.03, "finite first-tick turn and roll")
	AircraftFixture.run(world, 20)
	check(unit.position_m.y < 1820.0, "climb bounded")
	check(unit.velocity_mps.length() < float(evidence.cruise.speed_mps) - 5.0, "climb and turn cost energy")
	evidence.maneuver = {"position": SimData.array3(unit.position_m), "speed_mps": unit.velocity_mps.length(), "bank_rad": unit.rotation_rad.z}
	# Same control and exact tick budget through different display steps.
	var a: Dictionary = _framed([1.0 / 30.0], false)
	var b: Dictionary = _framed([0.013, 0.027, 0.009, 0.031], true)
	check(a == b, "frame steps, pause, speed and reset deterministic")
	evidence.determinism = true
	var glider: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("glider", "jp", Vector3(0, 1500, 0), "jp_a6m5a_1944", 0, 65, {"fuel_kg": 0})])
	AircraftFixture.run(glider, 20)
	check(glider.get_unit("glider").position_m.y < 1400, "fuel exhaustion causes glide")
	check(glider.get_unit("glider").position_m.z < -1000, "no invulnerable hover")
	var high: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("high", "jp", Vector3(0, 11740, 0))])
	high.get_unit("high").module_data["aircraft_control"] = {"altitude_m": 100000.0}
	AircraftFixture.run(high, 20)
	check(high.get_unit("high").position_m.y < 11741, "ceiling limits climb")
	var file: FileAccess = FileAccess.open("res://docs/showcase/deliveries/S04-motion.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	print("S04 aircraft motion PASS checks=", checks, " evidence=", evidence)
	quit(0)

func _framed(steps: Array[float], extras: bool) -> Dictionary:
	var world: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("lead", "jp", Vector3(0,1500,0))])
	AircraftFixture.order(world, "route", ["lead"], "patrol", "", Vector3(0, 1500, -1000), 1800)
	if extras:
		world.set_paused(true)
		world.advance(100.0)
		check(world.tick == 0, "pause does not accumulate")
		world.set_paused(false)
		world.set_time_scale(2.0)
	var time: float = 0.0
	var frame: int = 0
	while time < 15.0 - 0.0000001:
		var delta: float = minf(steps[frame % steps.size()], 15.0 - time)
		world.advance(delta / (2.0 if extras else 1.0))
		world.drain_events()
		time += delta
		frame += 1
	world.advance(0.00000001)
	var first: Dictionary = world.snapshot()
	check(world.reset(), "reset success")
	AircraftFixture.order(world, "route", ["lead"], "patrol", "", Vector3(0, 1500, -1000), 1800)
	world.step_ticks(900)
	world.drain_events()
	var second: Dictionary = world.snapshot()
	# Generation is deliberately different; all simulation states agree.
	first.erase("generation")
	second.erase("generation")
	check(first == second, "reset restores identical controls, fuel and order state")
	return first
