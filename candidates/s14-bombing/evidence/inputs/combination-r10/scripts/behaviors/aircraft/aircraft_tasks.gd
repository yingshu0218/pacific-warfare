class_name AircraftTasks
extends SimulationModule

## One aircraft-domain executor. Reads only friendly state and own contact records.
var performance: AircraftPerformance = AircraftPerformance.new()
var tasks: Dictionary = {}
var rosters: Dictionary = {}
var homes: Dictionary = {}
var submitted_targets: Dictionary = {}
var command_serial: int = 0
## Optional delegate on the single domain executor. No second aircraft owner.
var bombing_delegate: RefCounted = null

func _init() -> void:
	module_id = "aircraft_tasks"
	priority = 300

func supported_order_types() -> PackedStringArray:
	return ["patrol", "escort", "intercept", "engage", "regroup", "retreat", "aircraft_training", "bombing"] if bombing_delegate != null else ["patrol", "escort", "intercept", "engage", "regroup", "retreat", "aircraft_training"]

func order_domains() -> PackedStringArray:
	return ["aircraft"]

func accept_order(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String]) -> Dictionary:
	var world: SimulationWorld = world_ref as SimulationWorld
	if bombing_delegate != null and bombing_delegate.supports(order.order_type): return bombing_delegate.accept(world,order,unit_ids)
	for id: String in unit_ids:
		if not performance.supports(world.get_unit(id).definition_id):
			return {"accepted": false, "reason": "aircraft_performance_missing:" + id}
	for id: String in unit_ids:
		var profile: Dictionary = performance.profile(world.get_unit(id).definition_id)
		if profile.get("role","") in ["dive_bomber","level_bomber","strike_navigation_only"] and order.order_type not in ["patrol","regroup","retreat","bombing"]:
			return {"accepted":false,"reason":"bomber_role_forbids_fighter_task:"+id}
	if order.order_type == "aircraft_training":
		if not order.target_id.is_empty() or not order.area.is_empty() or not order.waypoints_m.is_empty():
			return {"accepted":false,"reason":"training_uses_explicit_parameters_only"}
		for id: String in unit_ids:
			var unit: UnitState = world.get_unit(id)
			var reason: String = AircraftTraining.validate(unit,performance.profile(unit.definition_id),order.training)
			if not reason.is_empty(): return {"accepted":false,"reason":reason+":"+id}
		return {"accepted":true,"reason":"training_executor_capable"}
	if order.order_type in ["regroup", "retreat"] and order.area.is_empty() and order.waypoints_m.is_empty():
		return {"accepted": false, "reason": "aircraft_destination_required"}
	return {"accepted": true, "reason": "aircraft_executor_capable"}

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	tasks.clear()
	rosters.clear()
	homes.clear()
	submitted_targets.clear()
	command_serial = 0
	if bombing_delegate != null: bombing_delegate.reset(world)
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not performance.supports(unit.definition_id):
			continue
		var initial: Dictionary = unit.module_data.get("aircraft_initial", {})
		var fallback: Vector3 = unit.position_m + Basis(Vector3.UP, unit.rotation_rad.y) * Vector3(0, 0, 6000)
		homes[id] = {"center": SimData.vec3(initial.withdrawal_center_m) if initial.has("withdrawal_center_m") else fallback,
			"radius": float(initial.get("withdrawal_radius_m", 500.0))}
		unit.module_data.erase("aircraft_control")
		unit.module_data.erase("aircraft_avoidance")
		unit.module_data.erase("aircraft_maneuver")
		unit.module_data.erase("aircraft_training")
		unit.module_data["combat_intent"] = {"fire": false, "allow_aa": false, "burst_until_tick": -1}

func on_order_units_released(world_ref: RefCounted, _order: BattleOrder, unit_ids: Array[String], _reason: String) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	if bombing_delegate != null and bombing_delegate.supports(_order.order_type): bombing_delegate.released(world,_order,unit_ids,_reason)
	for id: String in unit_ids:
		var unit: UnitState = world.get_unit(id)
		if tasks.has(id):
			_abort_attitude(unit,tasks[id],world.time_s(),"order_released")
			if tasks[id].has("training"):
				var training: Dictionary = tasks[id].training
				if training.status == "executing": AircraftTraining.abort(training,_reason)
				unit.module_data["aircraft_training"] = AircraftTraining.public_state(training)
		tasks.erase(id)
		unit.module_data.erase("aircraft_control")
		unit.module_data.erase("aircraft_avoidance")
		unit.module_data.erase("air_formation")
		_hold_fire(world, unit)

func fixed_update(world_ref: RefCounted, _delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for record: Dictionary in world.orders_snapshot():
		var owned: Array[String] = world.owned_order_unit_ids(record.order_id, "aircraft")
		if owned.is_empty():
			continue
		if not rosters.has(record.order_id):
			rosters[record.order_id] = owned.duplicate()
		for id: String in owned:
			var unit: UnitState = world.get_unit(id)
			if not tasks.has(id) or str(tasks[id].order_id) != str(record.order_id):
				tasks[id] = {"order_id": record.order_id, "phase": "", "reason": "", "waypoint": 0, "last_report": -999,
					"started_s": world.time_s(), "last_seen_s": world.time_s(), "has_seen": false,
					"last_point": unit.position_m, "selected_target": "", "break_until_s": 0.0,
					"next_burst_s": 0.0, "burst_until_tick": -1, "withdraw_reason": "", "regroup_since_s": -1.0}
				world.report_order_unit_status(record.order_id, id, "executing", "flight_task_received", "forming")
			var formation: Dictionary = AirFormations.assignment(rosters[record.order_id], owned, id)
			unit.module_data["air_formation"] = formation
			_update_unit(world, unit, record, owned, formation)

func _update_unit(world: SimulationWorld, unit: UnitState, order: Dictionary, owned: Array[String], formation: Dictionary) -> void:
	if bombing_delegate != null and bombing_delegate.supports(str(order.order_type)):
		bombing_delegate.step(world,unit,order,owned,formation)
		return
	var task: Dictionary = tasks[unit.id]
	var p: Dictionary = performance.profile(unit.definition_id)
	if order.order_type == "aircraft_training":
		_training(world,unit,order,task,p)
		return
	var danger: String = _exit_reason(unit, p)
	if not danger.is_empty() and str(task.withdraw_reason).is_empty():
		task.withdraw_reason = danger
	if order.order_type == "retreat" or not str(task.withdraw_reason).is_empty():
		_withdraw(world, unit, order, task, p)
		return
	var contacts: Array = world.shared_state.get("combat_contacts", {}).get(unit.faction_id, {}).values()
	var local_foes: int = 0
	var local_friends: int = 0
	for contact: Dictionary in contacts:
		if contact.domain == "aircraft" and bool(contact.fresh) and bool(contact.valid) and unit.position_m.distance_to(contact.position_m) < 2200.0:
			local_foes += 1
	for friend_id: String in owned:
		if world.get_unit(friend_id).position_m.distance_to(unit.position_m) < 2200.0:
			local_friends += 1
	if local_foes >= 3 and local_foes > local_friends * 2 and unit.velocity_mps.length() < float(p.cruise_mps) * 0.85:
		task.withdraw_reason = "outnumbered_low_energy"
		_withdraw(world, unit, order, task, p)
		return
	var target: Dictionary = {}
	var protected: UnitState
	if order.order_type == "escort":
		# Only a friendly protected entity may be read directly.
		protected = world.get_unit(order.target_id)
		if protected == null or protected.faction_id != unit.faction_id or not protected.active:
			task.withdraw_reason = "protected_unit_lost"
			_withdraw(world, unit, order, task, p)
			return
		var protect_radius: float = float(order.area.get("radius_m", 2500.0))
		target = _select_contact(unit, contacts, formation, world, protected.position_m, protect_radius)
		if unit.position_m.distance_to(protected.position_m) > protect_radius * 1.15:
			target.clear()
		# The support pair (or the wingman of a single pair) stays with the ward.
		var guard: bool = (str(formation.section_role) == "support" if owned.size() > 2 else str(formation.role) == "wingman")
		if guard and not target.is_empty() and (target.position_m as Vector3).distance_to(protected.position_m) > protect_radius * 0.45:
			target.clear()
	elif order.order_type in ["intercept", "engage"]:
		target = CombatContacts.find(world, unit.faction_id, order.target_id)
		if int(formation.pair_index) > 0:
			var distributed: Dictionary = _select_contact(unit, contacts, formation, world)
			if not distributed.is_empty():
				target = distributed
		if str(formation.role) == "wingman":
			var leader: UnitState = world.get_unit(formation.pair_leader_id)
			var covering: Dictionary = _cover_threat(leader, contacts, str(target.get("entity_id", "")))
			if leader.position_m.distance_to(unit.position_m) > 1200.0:
				target.clear()
			elif not covering.is_empty():
				target = covering
			else:
				target.clear()
	# Once the pilot has rolled into a defensive maneuver, a wingman station or
	# momentary contact change cannot seize the controls halfway through it.
	if _continue_maneuver(world,unit,task,p): return
	if not target.is_empty():
		task.has_seen = true
		task.last_seen_s = world.time_s()
		task.last_point = target.position_m
		task.selected_target = target.entity_id
		_combat(world, unit, order, task, p, target, contacts)
		return
	_hold_fire(world, unit)
	if order.order_type in ["engage", "intercept"] and str(formation.role) == "leader":
		var stale: Dictionary = CombatContacts.find(world, unit.faction_id, str(task.selected_target) if not str(task.selected_target).is_empty() else order.target_id, false)
		if not stale.is_empty():
			task.has_seen = true
			task.last_point = stale.position_m
			# Last actual observation time, not the current time of a stale record.
			task.last_seen_s = stale.observed_time_s
		if world.time_s() - float(task.last_seen_s) > 30.0:
			task.withdraw_reason = "contact_not_reacquired"
			_withdraw(world, unit, order, task, p)
			return
		task["maneuver_phase"] = "search"
		task["maneuver_reason"] = "last_known_contact" if task.has_seen else "awaiting_own_contact"
		if task.has("spatial"):
			_abort_attitude(unit,task,world.time_s(),"contact_lost")
			task.spatial.clear()
		var search: Vector3 = task.last_point
		if not bool(task.has_seen) and not order.area.is_empty():
			search = SimData.vec3(order.area.center_m)
		if unit.position_m.distance_to(search) < 650.0:
			search += Basis(Vector3.UP, unit.rotation_rad.y + 0.8) * Vector3(0, 80, -1600)
		_steer(world, unit, search, float(p.cruise_mps))
		_progress(world, unit, task, "search", "last_known_contact" if task.has_seen else "awaiting_own_contact", search.distance_to(unit.position_m))
		return
	_navigation(world, unit, order, owned, formation, task, p, protected)

func _training(world: SimulationWorld, unit: UnitState, order: Dictionary, task: Dictionary, p: Dictionary) -> void:
	_hold_fire(world,unit)
	unit.module_data.erase("aircraft_avoidance")
	if not task.has("training"):
		task["training"] = AircraftTraining.begin(unit,order.training,world.time_s(),str(order.order_id))
	var state: Dictionary = task.training
	var control: Dictionary = AircraftTraining.step(unit,p,state,world.time_s())
	# Friendly states are available; no enemy state or observer knowledge is used.
	for id: String in world.unit_ids():
		var friend: UnitState = world.get_unit(id)
		if id != unit.id and friend.faction_id == unit.faction_id and friend.active and world.unit_definition(friend.definition_id).domain == "aircraft" and friend.position_m.distance_to(unit.position_m) < 110:
			AircraftTraining.abort(state,"training_friendly_conflict")
			control.clear()
	var published: Dictionary = AircraftTraining.public_state(state)
	unit.module_data["aircraft_training"] = published
	unit.task["aircraft"] = {"phase":"training","reason":state.reason,"maneuver_phase":state.maneuver+"_"+state.phase,"maneuver_reason":state.reason,"training":published}
	if state.status in ["completed","aborted"]:
		unit.module_data.erase("aircraft_control")
		world.report_order_unit_status(str(order.order_id),unit.id,"completed" if state.status == "completed" else "failed",str(state.reason),str(state.phase))
		return
	unit.module_data["aircraft_control"] = control
	if str(task.phase) != str(state.phase) or world.tick-int(task.last_report) >= 120:
		world.report_order_unit_progress(str(order.order_id),unit.id,"training %s/%s: roll %.0fdeg, turn %.0fdeg, height %+.0fm" % [state.maneuver,state.phase,rad_to_deg(float(state.roll_accum_rad)),rad_to_deg(float(state.heading_change_rad)),float(state.height_change_m)],"training_actual_geometry")
		task.phase = state.phase
		task.last_report = world.tick

func _navigation(world: SimulationWorld, unit: UnitState, order: Dictionary, owned: Array[String], formation: Dictionary, task: Dictionary, p: Dictionary, protected: UnitState) -> void:
	_abort_attitude(unit,task,world.time_s(),"task_navigation")
	var goal: Vector3
	var speed: float = float(p.cruise_mps)
	var phase: String = "patrol"
	var reason: String = "following_route"
	if str(formation.role) == "wingman":
		var leader: UnitState = world.get_unit(formation.pair_leader_id)
		goal = AirFormations.station(leader, formation)
		speed = clampf(leader.velocity_mps.length() + (unit.position_m.distance_to(goal) - 80.0) * 0.035, float(p.stall_mps) * 1.35, float(p.combat_mps))
		phase = "cover" if order.order_type in ["engage", "intercept"] else "formation"
		reason = "rejoining_pair" if unit.position_m.distance_to(goal) > 500.0 else "wingman_station"
		if unit.position_m.distance_to(goal) < 350.0:
			# A moving station is pursued with velocity feed-forward, never bound to it.
			goal += leader.velocity_mps * 4.0
	elif int(formation.pair_index) > 0 and str(formation.flight_leader_id) != unit.id and order.order_type != "regroup":
		var flight_lead: UnitState = world.get_unit(formation.flight_leader_id)
		goal = AirFormations.station(flight_lead, formation, true) + flight_lead.velocity_mps * 4.0
		speed = clampf(flight_lead.velocity_mps.length() + (unit.position_m.distance_to(goal) - 400.0) * 0.025, float(p.stall_mps) * 1.35, float(p.combat_mps))
		phase = "support"
		reason = "support_pair_station"
	elif protected != null:
		goal = _route_point(protected.position_m + Vector3(0, 700, 0), 1000.0, task, unit)
		phase = "guard"
		reason = "escort_protection_area"
	else:
		var route: Array = order.waypoints_m
		if route.is_empty():
			var center: Vector3 = SimData.vec3(order.area.center_m) if not order.area.is_empty() else task.last_point
			goal = _route_point(center, maxf(1000.0, float(order.area.get("radius_m", 1600.0)) * 0.7), task, unit)
		else:
			goal = SimData.vec3(route[int(task.waypoint) % route.size()])
			if unit.position_m.distance_to(goal) < maxf(170.0, unit.velocity_mps.length() * 2.0):
				task.waypoint = (int(task.waypoint) + 1) % route.size()
				goal = SimData.vec3(route[int(task.waypoint)])
	if order.order_type == "regroup":
		var center: Vector3 = SimData.vec3(order.area.center_m) if not order.area.is_empty() else SimData.vec3(order.waypoints_m[-1])
		var radius: float = float(order.area.get("radius_m", 1400.0))
		var together: bool = true
		for id: String in owned:
			if world.get_unit(id).position_m.distance_to(center) > radius:
				together = false
		if together:
			if float(task.regroup_since_s) < 0.0:
				task.regroup_since_s = world.time_s()
			if world.time_s() - float(task.regroup_since_s) > 2.0:
				world.report_order_unit_status(order.order_id, unit.id, "completed", "regroup_area_reached", "assembled")
				return
		else:
			task.regroup_since_s = -1.0
		goal = center + Vector3(float(formation.slot) * 130.0, 0, 0)
		phase = "regroup"
		reason = "gathering_surviving_members"
	var vertical_rejoin: bool = phase in ["formation","cover","support"] and absf(goal.y-unit.position_m.y) > 90.0
	task["maneuver_phase"] = "vertical_rejoin" if vertical_rejoin else ("high_cover" if phase in ["cover","support"] else "track")
	task["maneuver_reason"] = reason
	_steer(world, unit, goal, speed, vertical_rejoin, deg_to_rad(25.0))
	_progress(world, unit, task, phase, reason, goal.distance_to(unit.position_m))

func _route_point(center: Vector3, radius: float, task: Dictionary, unit: UnitState) -> Vector3:
	var corners: Array[Vector3] = [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	var goal: Vector3 = center + corners[int(task.waypoint) % 4] * radius
	if unit.position_m.distance_to(goal) < maxf(220.0, unit.velocity_mps.length() * 2.5):
		task.waypoint = (int(task.waypoint) + 1) % 4
		goal = center + corners[int(task.waypoint)] * radius
	return goal

func _select_contact(unit: UnitState, contacts: Array, formation: Dictionary, world: SimulationWorld, anchor: Vector3 = Vector3.ZERO, leash: float = INF) -> Dictionary:
	var result: Dictionary = {}
	var best: float = INF
	var lead_target: String = ""
	if int(formation.pair_index) > 0 and tasks.has(formation.flight_leader_id):
		lead_target = str(tasks[formation.flight_leader_id].selected_target)
	for contact: Dictionary in contacts:
		if not bool(contact.valid) or not bool(contact.fresh) or contact.domain != "aircraft":
			continue
		if (contact.position_m as Vector3).distance_to(anchor) > leash:
			continue
		var score: float = unit.position_m.distance_to(contact.position_m)
		if str(contact.entity_id) == lead_target:
			score += 1800.0
		if score < best:
			best = score
			result = contact.duplicate(true)
	return result

func _cover_threat(leader: UnitState, contacts: Array, attacking: String) -> Dictionary:
	var result: Dictionary = {}
	var best: float = 1500.0
	for contact: Dictionary in contacts:
		if not bool(contact.fresh) or not bool(contact.valid) or contact.domain != "aircraft":
			continue
		var distance: float = leader.position_m.distance_to(contact.position_m)
		var closing: float = (contact.velocity_mps as Vector3).normalized().dot((leader.position_m - (contact.position_m as Vector3)).normalized())
		if distance < best and (str(contact.entity_id) != attacking or closing > 0.55):
			best = distance
			result = contact.duplicate(true)
	return result

func _combat(world: SimulationWorld, unit: UnitState, _order: Dictionary, task: Dictionary, p: Dictionary, contact: Dictionary, contacts: Array) -> void:
	var age: float = maxf(0.0,world.time_s()-float(contact.observed_time_s))
	var point: Vector3 = contact.position_m+(contact.velocity_mps as Vector3)*age
	var distance: float = unit.position_m.distance_to(point)
	var forward: Vector3 = -Basis.from_euler(unit.rotation_rad).z
	var delta: Vector3 = point-unit.position_m
	var ammo_speed: float = 750.0 if unit.definition_id == "jp_a6m5a_1944" else 890.0
	var solution: Dictionary = CombatFireControl.intercept(unit.position_m,unit.velocity_mps,point,contact.velocity_mps,ammo_speed,9.80665,5.0)
	var aim: Vector3 = delta.normalized() if solution.is_empty() else solution.direction
	if not task.has("spatial"):
		task["spatial"] = {}
	var guidance: Dictionary = AirCombatTactics.decide(unit,p,task.spatial,contact,contacts,aim,world.time_s())
	var goal: Vector3 = unit.position_m+(guidance.direction as Vector3)*maxf(700,distance)
	_steer(world,unit,goal,float(guidance.speed_mps),true)
	unit.module_data.aircraft_control["max_bank_rad"] = guidance.max_bank_rad
	unit.module_data.aircraft_control["turn_side"] = guidance.turn_side
	if bool(unit.module_data.aircraft_control.get("avoiding",false)) and guidance.has("attitude"):
		_abort_attitude(unit,task,world.time_s(),"friendly_separation")
	else:
		for key: String in guidance.get("attitude",{}):
			unit.module_data.aircraft_control[key] = guidance.attitude[key]
	task["maneuver_phase"] = guidance.mode
	task["maneuver_reason"] = guidance.reason
	task["spatial_geometry"] = {"relative_height_m":guidance.relative_height_m,"closing_mps":guidance.closing_mps,"energy_margin_m":guidance.energy_margin_m,"last_exit":guidance.last_exit}
	if guidance.has("maneuver_roll_error_rad"):
		task.spatial_geometry["roll_error_rad"] = guidance.maneuver_roll_error_rad
		task.spatial_geometry["bend_rad"] = guidance.maneuver_bend_rad
	var angle: float = forward.angle_to(aim)
	var firing: bool = false
	if bool(guidance.permit_fire) and not bool(unit.module_data.aircraft_control.get("avoiding",false)):
		_set_target(world,unit,str(contact.entity_id))
		if distance > 160 and distance < 750 and angle < 0.10 and world.time_s() >= float(task.next_burst_s):
			task.burst_until_tick = world.tick+maxi(1,int(0.45/world.fixed_delta_s()))
			task.next_burst_s = world.time_s()+1.10
		firing = world.tick <= int(task.burst_until_tick) and distance < 800 and angle < 0.14
		unit.module_data["combat_intent"] = {"fire":firing,"allow_aa":false,"burst_until_tick":int(task.burst_until_tick)}
	else:
		_hold_fire(world,unit)
	var reason: String = "short_burst_window" if firing else ("align_fixed_guns" if guidance.mode == "track" else str(guidance.reason))
	_progress(world,unit,task,"burst" if firing else str(guidance.phase),reason,distance)

func _continue_maneuver(world: SimulationWorld, unit: UnitState, task: Dictionary, p: Dictionary) -> bool:
	if not task.get("spatial",{}).has("attitude"): return false
	# This branch uses only its committed plane and current own state. No new
	# maneuver can start from the empty contact dictionaries, and fire stays off.
	var guidance: Dictionary = AirCombatManeuvers.decide(unit,p,task.spatial,{}, {},world.time_s())
	if guidance.is_empty(): return false
	_steer(world,unit,unit.position_m+(guidance.direction as Vector3)*700,float(guidance.speed_mps),true)
	unit.module_data.aircraft_control["turn_side"] = guidance.turn_side
	if bool(unit.module_data.aircraft_control.get("avoiding",false)):
		_abort_attitude(unit,task,world.time_s(),"friendly_separation")
	else:
		for key: String in guidance.attitude: unit.module_data.aircraft_control[key] = guidance.attitude[key]
	_hold_fire(world,unit)
	task["maneuver_phase"] = guidance.mode
	task["maneuver_reason"] = guidance.reason
	task["spatial_geometry"] = {"roll_error_rad":guidance.maneuver_roll_error_rad,"bend_rad":guidance.maneuver_bend_rad,
		"maneuver_committed":true,"geometry_observed_s":task.last_seen_s,"last_exit":guidance.last_exit}
	_progress(world,unit,task,"evade",guidance.reason,unit.position_m.distance_to(task.last_point))
	return true

func _steer(world: SimulationWorld, unit: UnitState, goal: Vector3, speed: float, spatial: bool = false, pitch_limit_rad: float = deg_to_rad(65.0)) -> void:
	var safety: Dictionary = AirFormations.avoid_friends(world, unit, goal)
	var vector: Vector3 = (safety.goal as Vector3) - unit.position_m
	unit.module_data["aircraft_control"] = {"heading_rad": atan2(-vector.x, -vector.z), "altitude_m": (safety.goal as Vector3).y,
		"speed_mps": speed, "avoiding": safety.avoiding, "nearest_friend_m": safety.nearest_friend_m if is_finite(float(safety.nearest_friend_m)) else -1.0}
	if spatial or bool(safety.avoiding):
		unit.module_data.aircraft_control["flight_direction"] = AircraftFlightMath.elevated(vector,clampf(AircraftFlightMath.pitch(vector),-pitch_limit_rad,pitch_limit_rad),-Basis.from_euler(unit.rotation_rad).z)
		unit.module_data.aircraft_control["max_bank_rad"] = deg_to_rad(70.0)


func _exit_reason(unit: UnitState, p: Dictionary) -> String:
	var damage: Dictionary = unit.module_data.get("damage", {})
	if float(damage.get("propulsion_factor", 1.0)) < 0.45 or float(damage.get("control_factor", 1.0)) < 0.55 or float(damage.get("structure", 1.0)) < float(damage.get("structure_max", 1.0)) * 0.30:
		return "severe_damage"
	var fuel: float = float(unit.module_data.get("aircraft_motion", {}).get("fuel_kg", p.fuel_capacity_kg))
	var home: Dictionary = homes[unit.id]
	var need: float = unit.position_m.distance_to(home.center) / float(p.cruise_mps) * float(p.cruise_burn_kgps) * 1.5
	if fuel < float(p.cruise_burn_kgps) * float(p.reserve_s) + need:
		return "low_fuel"
	var rounds: int = 0
	for weapon: WeaponState in unit.weapons.values():
		if weapon.enabled:
			for remaining: int in weapon.remaining_rounds:
				rounds += remaining
	if rounds == 0:
		return "no_ammunition"
	return ""

func _withdraw(world: SimulationWorld, unit: UnitState, order: Dictionary, task: Dictionary, p: Dictionary) -> void:
	task["maneuver_phase"] = "withdraw"
	task["maneuver_reason"] = str(task.withdraw_reason)
	if task.has("spatial"):
		_abort_attitude(unit,task,world.time_s(),"task_withdrawal")
		task.spatial.clear()
	_hold_fire(world, unit)
	var center: Vector3 = homes[unit.id].center
	var radius: float = float(homes[unit.id].radius)
	if order.order_type == "retreat":
		center = SimData.vec3(order.area.center_m) if not order.area.is_empty() else SimData.vec3(order.waypoints_m[-1])
		radius = float(order.area.get("radius_m", 500.0))
	var distance: float = unit.position_m.distance_to(center)
	var reason: String = "ordered_retreat" if str(task.withdraw_reason).is_empty() else str(task.withdraw_reason)
	if distance <= radius:
		world.report_order_unit_status(order.order_id, unit.id, "completed", "withdrawn:" + reason, "exited_combat_area")
		unit.module_data.aircraft_motion.exited = true
		unit.module_data.aircraft_motion["exit_reason"] = reason
		unit.active = false
		world.emit_event("aircraft_exit", unit.id, "", unit.position_m, {"reason": reason, "destroyed": false, "landed": false})
		return
	_steer(world, unit, center, float(p.cruise_mps))
	_progress(world, unit, task, "withdraw", reason, distance)

func _abort_attitude(unit: UnitState, task: Dictionary, now: float, reason: String) -> void:
	if not task.get("spatial",{}).has("attitude"): return
	task.spatial.erase("attitude")
	task.spatial.mode = "track"
	task.spatial.cooldown_until_s = now+6.0
	task.spatial.last_exit = reason
	unit.module_data["aircraft_maneuver"] = {"blocked_until_s":now+6.0,"last_exit":reason}

func _hold_fire(world: SimulationWorld, unit: UnitState) -> void:
	unit.module_data["combat_intent"] = {"fire": false, "allow_aa": false, "burst_until_tick": -1}
	_set_target(world, unit, "")

func _set_target(world: SimulationWorld, unit: UnitState, target_id: String) -> void:
	# Release callbacks also run after loss. Clear intent, but a dead recipient
	# cannot accept a command and has no remaining fire-control target to clear.
	if not unit.active:
		submitted_targets.erase(unit.id)
		return
	if str(submitted_targets.get(unit.id, unit.target_id)) == target_id:
		return
	var command: BattleCommand = BattleCommand.new()
	command_serial += 1
	command.command_id = "air_target:%d:%s" % [command_serial, unit.id]
	command.issuer_id = module_id
	command.source = "ai"
	command.faction_id = unit.faction_id
	command.entity_id = unit.id
	command.kind = BattleCommand.SET_TARGET
	command.payload = {"target_id": target_id}
	var receipt: Dictionary = world.submit_command(command)
	if receipt.accepted:
		submitted_targets[unit.id] = target_id

func _progress(world: SimulationWorld, unit: UnitState, task: Dictionary, phase: String, reason: String, distance: float) -> void:
	if bool(unit.module_data.get("aircraft_control",{}).get("avoiding",false)):
		task["maneuver_phase"] = "separation"
		task["maneuver_reason"] = "friendly_conflict"
		reason = "friendly_conflict"
	var changed: bool = str(task.phase) != phase or str(task.reason) != reason
	task.phase = phase
	task.reason = reason
	unit.task["aircraft"] = {"phase": phase, "reason": reason, "target_id": task.selected_target,
		"distance_m": distance, "pair_index": unit.module_data.air_formation.pair_index,
		"role": unit.module_data.air_formation.role, "section_role": unit.module_data.air_formation.section_role,
		"maneuver_phase":task.get("maneuver_phase","track"),"maneuver_reason":task.get("maneuver_reason",reason),
		"spatial_geometry":task.get("spatial_geometry",{}).duplicate(true)}
	if changed or world.tick - int(task.last_report) >= 120:
		world.report_order_unit_progress(task.order_id, unit.id, "%s: %.0f m" % [phase, distance], reason)
		task.last_report = world.tick

func snapshot_state() -> Dictionary:
	return {"tasks": tasks.duplicate(true), "rosters": rosters.duplicate(true), "homes": homes.duplicate(true),
		"submitted_targets": submitted_targets.duplicate(true), "command_serial": command_serial}
