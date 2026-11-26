extends "res://tests/fixtures/fleet_test.gd"

func run_test() -> void:
	var world: SimulationWorld = FLEET.world([FLEET.spawn("ship", Vector3.ZERO)])
	var unit: UnitState = world.get_unit("ship")
	unit.module_data.ship_control = {"goal_m": Vector3(-5000, 0, 0), "speed_mps": 100.0}
	world.step_ticks(1)
	expect(unit.velocity_mps.length() < 0.01 and absf(unit.rotation_rad.y) < 0.00001, "A stationary ship accelerates gradually and cannot pivot on its first tick")
	var largest_accel: float = 0.0
	var largest_turn: float = 0.0
	for i: int in range(12000):
		var old_speed: float = unit.velocity_mps.length()
		var old_yaw: float = unit.rotation_rad.y
		var old_point: Vector3 = unit.position_m
		world.step_ticks(1)
		largest_accel = maxf(largest_accel, absf(unit.velocity_mps.length() - old_speed) * 60.0)
		largest_turn = maxf(largest_turn, absf(wrapf(unit.rotation_rad.y - old_yaw, -PI, PI)) * 60.0)
		if unit.position_m.distance_to(old_point) > 0.32:
			expect(false, "No teleportation at bounded historical maximum speed")
			break
		world.drain_events()
	expect(largest_accel < 0.116 and largest_turn < 0.073, "Acceleration and turning remain finite throughout a 90-degree course change")
	expect(unit.velocity_mps.length() <= 35.0 * 1852.0 / 3600.0 + 0.001, "Requested excess speed cannot exceed Yukikaze's historical maximum baseline")
	expect(unit.position_m.x < -1000 and absf(wrapf(unit.rotation_rad.y - PI * 0.5, -PI, PI)) < 0.6, "A helm command changes the actual track through a curved turn")
	evidence["limited_motion"] = {"max_acceleration_mps2": largest_accel, "max_yaw_radps": largest_turn, "position_m": unit.position_m}
	_collision_case(false)
	_collision_case(true)
	_damage_cases()
	_coast_case()
	_wreck_obstacle()
	_shore_case()
	finish("ship_motion")

func _collision_case(crossing: bool) -> void:
	var a: Dictionary = FLEET.spawn("a", Vector3(0, 0, 1000), 10.0)
	var b: Dictionary = FLEET.spawn("b", Vector3(-1000, 0, 0) if crossing else Vector3(0, 0, -1000), 10.0, -PI * 0.5 if crossing else PI)
	var world: SimulationWorld = FLEET.world([a, b])
	world.get_unit("a").module_data.ship_control = {"goal_m": Vector3(0, 0, -4500), "speed_mps": 10.0}
	world.get_unit("b").module_data.ship_control = {"goal_m": Vector3(4500, 0, 0) if crossing else Vector3(0, 0, 4500), "speed_mps": 10.0}
	var closest: float = INF
	var avoided: int = 0
	var side_changes: int = 0
	var last_sign: float = 0.0
	for tick: int in range(18000):
		world.step_ticks(1)
		var ship: UnitState = world.get_unit("a")
		closest = minf(closest, ship.position_m.distance_to(world.get_unit("b").position_m))
		if not str(ship.module_data.ship_motion.avoidance_reason).is_empty():
			avoided += 1
			var sign_now: float = signf(float(ship.module_data.ship_motion.turn_rate_radps))
			if sign_now != 0.0 and last_sign != 0.0 and sign_now != last_sign:
				side_changes += 1
			if sign_now != 0.0:
				last_sign = sign_now
		world.drain_events()
	expect(closest > 180.0, "Crossing/head-on traffic keeps full hulls separated without position correction")
	expect(avoided > 0 and side_changes < 6, "Give-way choice remains stable without frame-by-frame left/right oscillation")
	expect(world.get_unit("a").position_m.z < -600.0, "Avoidance eventually releases and navigation makes forward progress")
	evidence["crossing" if crossing else "head_on"] = {"minimum_center_distance_m": closest, "avoidance_ticks": avoided, "turn_sign_changes": side_changes,
		"a_position_m": world.get_unit("a").position_m, "b_position_m": world.get_unit("b").position_m}

func _damage_cases() -> void:
	var values: Array[Dictionary] = []
	for damage: Dictionary in [{}, {"propulsion_factor": 0.25}, {"control_factor": 0.15}]:
		var world: SimulationWorld = FLEET.world([FLEET.spawn("ship", Vector3.ZERO, 10.0)])
		var ship: UnitState = world.get_unit("ship")
		ship.module_data.damage = damage
		ship.module_data.ship_control = {"goal_m": Vector3(-10000, 0, 0), "speed_mps": 12.0}
		FLEET.run(world, 80.0)
		values.append({"speed": ship.velocity_mps.length(), "yaw": absf(ship.rotation_rad.y), "distance": ship.module_data.ship_motion.distance_m})
	expect(float(values[1].speed) < float(values[0].speed) * 0.5, "Propulsion damage reduces reachable speed with finite deceleration")
	expect(float(values[2].yaw) < float(values[0].yaw) * 0.6, "Steering damage limits actual course change")
	evidence["damage_comparison"] = values

func _coast_case() -> void:
	var world: SimulationWorld = FLEET.world([FLEET.spawn("ship", Vector3.ZERO, 10.0)])
	var ship: UnitState = world.get_unit("ship")
	ship.active = false
	ship.module_data.damage = {"phase": "disabled", "control_factor": 0.0, "propulsion_factor": 0.4}
	world.step_ticks(1)
	expect(ship.velocity_mps.length() > 9.9 and ship.position_m.z < 0.0 and ship.position_m.y == 0.0, "Disabled is still afloat and retains real inertia instead of stopping instantly")
	FLEET.run(world, 110.0)
	expect(ship.velocity_mps.length() < 0.001 and ship.position_m.length() <= 501.0, "Disabled drift has a bounded stopping time and distance")
	var stopped: Vector3 = ship.position_m
	ship.module_data.damage.phase = "sinking"
	ship.velocity_mps = Vector3(0, -1, -8)
	FLEET.run(world, 2.0)
	expect(ship.position_m == stopped, "S06 does not integrate sinking displacement owned by S05")
	evidence["disabled_stopping_distance_m"] = stopped.length()

func _shore_case() -> void:
	var config: FleetConfig = FLEET.config()
	config.data.navigation.solids = [{"id": "island", "center_m": [0, 0, -1500], "half_extents_m": [350, 40, 350]}]
	var world: SimulationWorld = FLEET.world([FLEET.spawn("ship", Vector3.ZERO, 9.0)], [], false, false, config)
	var unit: UnitState = world.get_unit("ship")
	unit.module_data.ship_control = {"goal_m": Vector3(0, 0, -4000), "speed_mps": 10.0}
	var collision: bool = false
	var detours: int = 0
	var path: Array[Vector3] = []
	for tick: int in range(42000):
		world.step_ticks(1)
		var p: Vector3 = unit.position_m
		if absf(p.x) < 430.0 and absf(p.z + 1500.0) < 430.0:
			collision = true
		if str(unit.module_data.ship_motion.avoidance_reason) == "coast_detour":
			detours += 1
		if tick % 600 == 0:
			path.append(p)
		world.drain_events()
	expect(not collision and detours > 0, "Ship routes around the actual shoreline projection with hull clearance")
	expect(unit.position_m.z < -2400.0, "Shore avoidance completes a detour instead of indefinitely braking at the coast")
	evidence["shore"] = {"collision": collision, "detour_ticks": detours, "position_m": unit.position_m, "track_10s": path}

func _wreck_obstacle() -> void:
	var results: Dictionary = {}
	for phase: String in ["disabled", "sinking", "removed"]:
		var world: SimulationWorld = FLEET.world([FLEET.spawn("moving", Vector3(0, 0, 1000), 8.0), FLEET.spawn("hull", Vector3.ZERO)])
		world.get_unit("hull").active = false
		world.get_unit("hull").module_data.damage = {"phase": phase, "control_factor": 0.0}
		world.get_unit("moving").module_data.ship_control = {"goal_m": Vector3(0, 0, -4000), "speed_mps": 8.0}
		var minimum: float = INF
		var avoidance_ticks: int = 0
		for tick: int in range(21600):
			world.step_ticks(1)
			minimum = minf(minimum, world.get_unit("moving").position_m.distance_to(Vector3.ZERO))
			if str(world.get_unit("moving").module_data.ship_motion.avoidance_id) == "hull":
				avoidance_ticks += 1
			world.drain_events()
		results[phase] = {"minimum_m": minimum, "avoidance_ticks": avoidance_ticks, "position_m": world.get_unit("moving").position_m}
		if phase != "removed":
			expect(minimum > 150.0 and avoidance_ticks > 0 and world.get_unit("moving").position_m.z < -500.0, "Disabled/sinking hull remains an obstacle until removal; moving ship passes without touching it")
		else:
			expect(minimum < 2.0 and avoidance_ticks == 0, "Removed hull releases the navigable sea lane")
	evidence["wreck_obstacles"] = results
