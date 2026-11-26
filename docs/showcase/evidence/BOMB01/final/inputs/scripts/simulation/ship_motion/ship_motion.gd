class_name ShipMotion
extends SimulationModule

var config: FleetConfig
var profiles: Dictionary = {}
var routes: Dictionary = {}
var avoidance: Dictionary = {}
var terrain_charts: Dictionary = {}

func _init(parameters: FleetConfig) -> void:
	module_id = "ship_motion"
	priority = 410
	config = parameters

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	profiles.clear()
	routes.clear()
	avoidance.clear()
	terrain_charts.clear()
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not config.supports(unit.definition_id):
			continue
		var p: Dictionary = config.profile(unit.definition_id)
		p["length_m"] = world.unit_definition(unit.definition_id).dimensions_m.z
		profiles[id] = p
		unit.module_data["ship_motion"] = {"speed_mps": unit.velocity_mps.length(), "turn_rate_radps": 0.0, "distance_m": 0.0, "exited": false, "exit_reason": "",
			"avoidance_reason": "", "avoidance_id": "", "fuel_fraction": clampf(float(unit.module_data.get("ship_initial", {}).get("fuel_fraction", 1.0)), 0.0, 1.0)}

func fixed_update(world_ref: RefCounted, dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	# Same-tick neighbor reads use one frozen frame, independent of iteration order.
	var peers: Dictionary = {}
	for id: String in profiles:
		var unit: UnitState = world.get_unit(id)
		var phase: String = str(unit.module_data.get("damage", {}).get("phase", "operational"))
		# Conservatively keep every afloat/descending hull until S05 removes it.
		# Its position is read for avoidance only; S06 still never moves sinking hulls.
		if phase != "removed" and not bool(unit.module_data.ship_motion.exited):
			peers[id] = {"position": unit.position_m, "velocity": unit.velocity_mps, "yaw": unit.rotation_rad.y, "length_m": profiles[id].length_m}
	for id: String in profiles:
		var unit: UnitState = world.get_unit(id)
		var phase: String = str(unit.module_data.get("damage", {}).get("phase", "operational"))
		if phase in ["sinking", "crashing", "wreck", "removed"]:
			continue # S05 is sole owner of sinking/wreck displacement.
		if unit.active or phase == "disabled":
			_sail(world, unit, profiles[id], peers, dt, phase == "disabled")

func _sail(world: SimulationWorld, unit: UnitState, p: Dictionary, peers: Dictionary, dt: float, disabled: bool) -> void:
	var motion: Dictionary = unit.module_data.ship_motion
	var control: Dictionary = unit.module_data.get("ship_control", {})
	var damage: Dictionary = unit.module_data.get("damage", {})
	var propulsion: float = clampf(float(damage.get("propulsion_factor", 1.0)), 0.0, 1.0)
	var authority: float = clampf(float(damage.get("control_factor", 1.0)), 0.0, 1.0)
	var speed: float = Vector2(unit.velocity_mps.x, unit.velocity_mps.z).length()
	var yaw: float = unit.rotation_rad.y
	var heading: float = yaw
	var desired_speed: float = float(control.get("speed_mps", 0.0))
	var reason: String = ""
	var avoid_id: String = ""
	if not control.is_empty() and not disabled:
		var goal: Vector3 = control.goal_m
		var shore: Dictionary = _shore(world, unit, p, goal, speed)
		heading = float(shore.heading)
		desired_speed = minf(desired_speed, float(shore.speed_cap))
		reason = str(shore.reason)
		var safety: Dictionary = _neighbors(unit, p, peers, heading, speed)
		if not str(safety.reason).is_empty():
			heading = float(safety.heading)
			desired_speed = minf(desired_speed, float(safety.speed_cap))
			reason = str(safety.reason)
			avoid_id = str(safety.id)
	var fueled: bool = float(motion.fuel_fraction) > 0.0
	desired_speed = clampf(desired_speed, 0.0, float(p.max_mps) * propulsion if fueled else 0.0)
	var accel: float = float(p.acceleration_mps2) * propulsion if desired_speed > speed else float(p.braking_mps2)
	var turn_rate: float = 0.0
	if disabled:
		desired_speed = 0.0
		accel = float(p.coast_drag_mps2)
		reason = "disabled_coasting"
		avoidance.erase(unit.id)
	else:
		var limit: float = speed / float(p.turn_radius_m) * authority
		var desired_turn: float = clampf(wrapf(heading - yaw, -PI, PI) * 0.12, -limit, limit)
		turn_rate = move_toward(float(motion.turn_rate_radps), desired_turn, deg_to_rad(float(p.yaw_acceleration_degps2)) * authority * dt)
		turn_rate = clampf(turn_rate, -limit, limit)
	var next_speed: float = move_toward(speed, desired_speed, accel * dt)
	var next_yaw: float = wrapf(yaw + turn_rate * dt, -PI, PI)
	var next_velocity: Vector3 = Vector3(-sin(next_yaw), 0.0, -cos(next_yaw)) * next_speed
	var travel: Vector3 = (unit.velocity_mps + next_velocity) * (0.5 * dt)
	travel.y = 0.0
	unit.position_m += travel
	unit.rotation_rad.y = next_yaw
	unit.velocity_mps = next_velocity
	motion.speed_mps = next_speed
	motion.turn_rate_radps = turn_rate
	motion.distance_m += travel.length()
	motion.avoidance_reason = reason
	motion.avoidance_id = avoid_id
	# An explicit long-duration gameplay endurance, not a historical fuel capacity.
	if not disabled:
		motion.fuel_fraction = maxf(0.0, float(motion.fuel_fraction) - dt / 172800.0 * pow(next_speed / float(p.cruise_mps), 3.0))

func _shore(world: SimulationWorld, unit: UnitState, p: Dictionary, goal: Vector3, speed: float) -> Dictionary:
	if world.shared_state.has("terrain"): return _terrain_shore(world, unit, p, goal, speed)
	var solids: Array = config.data.navigation.solids
	var direct: Vector3 = goal - unit.position_m
	var heading: float = atan2(-direct.x, -direct.z) if direct.length() > 1.0 else unit.rotation_rad.y
	if solids.is_empty():
		return {"heading": heading, "speed_cap": float(p.max_mps), "reason": ""}
	var margin: float = float(p.length_m) * 0.55 + float(config.data.navigation.clearance_m)
	var obstacles: Array[Rect2] = ShipNavigation.boxes(solids, margin + float(p.turn_radius_m))
	if not routes.has(unit.id) or (routes[unit.id].goal as Vector3).distance_to(goal) > 300.0:
		routes[unit.id] = {"goal": goal, "path": ShipNavigation.route(unit.position_m, goal, obstacles)}
	var path: Array = routes[unit.id].path
	while path.size() > 1 and unit.position_m.distance_to(path[0]) < 100.0:
		path.pop_front()
	var reason: String = "coast_detour" if path.size() > 1 else ""
	var cap: float = float(p.max_mps)
	if path.is_empty():
		cap = 0.0
		reason = "coast_braking"
	else:
		var to_waypoint: Vector3 = (path[0] as Vector3) - unit.position_m
		heading = atan2(-to_waypoint.x, -to_waypoint.z)
		if path.size() > 1:
			cap = minf(cap, sqrt(maxf(0.0, to_waypoint.length() - 100.0) * float(p.braking_mps2)) + 2.0)
	var forward: Vector3 = Vector3(-sin(unit.rotation_rad.y), 0, -cos(unit.rotation_rad.y))
	var braking_distance: float = speed * speed / (2.0 * float(p.braking_mps2)) + 90.0
	if ShipNavigation.blocked(unit.position_m, unit.position_m + forward * braking_distance, ShipNavigation.boxes(solids, margin)):
		cap = 0.0
		reason = "coast_braking"
	return {"heading": heading, "speed_cap": cap, "reason": reason}

func _terrain_shore(world: SimulationWorld, unit: UnitState, p: Dictionary, goal: Vector3, speed: float) -> Dictionary:
	var margin: float = float(p.length_m)*0.55+float(config.data.navigation.clearance_m)
	if not terrain_charts.has(unit.id):
		terrain_charts[unit.id] = {"hull":TerrainNavigation.chart(world.shared_state.terrain,margin),"planning":TerrainNavigation.chart(world.shared_state.terrain,margin+float(p.turn_radius_m)*0.25)}
	var chart: Dictionary = terrain_charts[unit.id].planning
	if not routes.has(unit.id) or (routes[unit.id].goal as Vector3).distance_to(goal)>250.0:
		routes[unit.id]={"goal":goal,"path":TerrainNavigation.route(unit.position_m,goal,chart)}
	var path: Array = routes[unit.id].path
	while path.size()>1 and unit.position_m.distance_to(path[0])<maxf(100.0,float(p.turn_radius_m)*0.45): path.pop_front()
	var reason: String = "coast_detour" if path.size()>1 else ""
	var heading: float = unit.rotation_rad.y
	var cap: float = float(p.max_mps)
	if path.is_empty():
		cap=0.0; reason="coast_unreachable"
	else:
		var delta: Vector3 = (path[0] as Vector3)-unit.position_m
		heading=atan2(-delta.x,-delta.z)
		var angle: float = absf(wrapf(heading-unit.rotation_rad.y,-PI,PI))
		if angle>0.5: cap=minf(cap,float(p.cruise_mps)*0.6)
	var forward: Vector3 = Vector3(-sin(unit.rotation_rad.y),0,-cos(unit.rotation_rad.y))
	var stopping: float = speed*speed/(2.0*float(p.braking_mps2))+100.0
	if TerrainNavigation.blocked(unit.position_m,unit.position_m+forward*stopping,terrain_charts[unit.id].hull.shapes):
		cap=0.0; reason="coast_braking"
	return {"heading":heading,"speed_cap":cap,"reason":reason}

func _neighbors(unit: UnitState, p: Dictionary, peers: Dictionary, heading: float, speed: float) -> Dictionary:
	var result: Dictionary = {"heading": heading, "speed_cap": float(p.max_mps), "reason": "", "id": ""}
	var forward: Vector3 = Vector3(-sin(unit.rotation_rad.y), 0, -cos(unit.rotation_rad.y))
	var right: Vector3 = Vector3(cos(unit.rotation_rad.y), 0, -sin(unit.rotation_rad.y))
	var threat: String = ""
	var earliest: float = INF
	for id: String in peers:
		if id == unit.id:
			continue
		var peer: Dictionary = peers[id]
		var delta: Vector3 = (peer.position as Vector3) - unit.position_m
		delta.y = 0.0
		var relative: Vector3 = (peer.velocity as Vector3) - unit.velocity_mps
		var time: float = -delta.dot(relative) / maxf(0.01, relative.length_squared())
		var safety: float = (float(p.length_m) + float(peer.length_m)) * 0.55 + float(config.data.navigation.clearance_m)
		var miss: float = (delta + relative * clampf(time, 0.0, float(config.data.navigation.prediction_s))).length()
		var head_on: bool = forward.dot((peer.velocity as Vector3).normalized()) < -0.65
		var yielding: bool = right.dot(delta.normalized()) > -0.1 or head_on or (peer.velocity as Vector3).length() < 0.5
		# Stern overtaking: faster vessel yields. Stand-on vessel still brakes at close range.
		yielding = yielding or (forward.dot(delta.normalized()) > 0.7 and speed > (peer.velocity as Vector3).length() + 0.5)
		var locked: bool = avoidance.has(unit.id) and str(avoidance[unit.id].id) == id
		var close: bool = delta.length() < safety * 1.5 and delta.dot(relative) < 0.0
		var original_forward: Vector3 = Basis(Vector3.UP, float(avoidance[unit.id].original_yaw)) * Vector3.FORWARD if locked else forward
		if locked and delta.length() < 5000.0 and delta.dot(original_forward) > -safety:
			threat = id
			break
		if ((time > 0.0 and time < float(config.data.navigation.prediction_s) and miss < safety and yielding) or close) and time < earliest:
			threat = id
			earliest = time
	if threat.is_empty():
		avoidance.erase(unit.id)
		return result
	if not avoidance.has(unit.id) or str(avoidance[unit.id].id) != threat:
		# Lock a starboard heading until clear; never alternate left/right per tick.
		avoidance[unit.id] = {"id": threat, "heading": wrapf(unit.rotation_rad.y - 0.90, -PI, PI), "original_yaw": unit.rotation_rad.y}
	var peer: Dictionary = peers[threat]
	var separation: float = unit.position_m.distance_to(peer.position)
	var safety: float = (float(p.length_m) + float(peer.length_m)) * 0.55 + float(config.data.navigation.clearance_m)
	result.heading = avoidance[unit.id].heading
	var delta: Vector3 = (peer.position as Vector3) - unit.position_m
	var relative: Vector3 = (peer.velocity as Vector3) - unit.velocity_mps
	var cpa_time: float = clampf(-delta.dot(relative) / maxf(0.01, relative.length_squared()), 0.0, 30.0)
	var collision_course: bool = (delta + relative * cpa_time).length() < safety and delta.dot(relative) < 0.0
	var emergency: bool = separation < safety * 1.8 and collision_course
	result.speed_cap = 0.0 if emergency else float(p.cruise_mps) * 0.65
	result.reason = "neighbor_yield" if emergency else "neighbor_starboard"
	result.id = threat
	return result

func snapshot_state() -> Dictionary:
	return {"unit_ids": profiles.keys(), "routes": routes.duplicate(true), "avoidance": avoidance.duplicate(true)}
