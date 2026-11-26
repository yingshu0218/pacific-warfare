class_name CarrierOperations
extends SimulationModule

## No nodes, animation or independent clock. One roster entry per real UnitState.
const PARAMS: String = "res://scripts/air_operations/parameters.json"
const GROUND_PHASES: PackedStringArray = ["standby", "preparing", "queued", "respotting", "taxi_out", "takeoff_roll", "touchdown", "arresting", "taxi_clear", "servicing", "deck_hold"]
var parameters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARAMS))
var deck: CarrierDeckGeometry = CarrierDeckGeometry.new()
var airframe: CarrierAirframeGeometry = CarrierAirframeGeometry.new()
var carrier_id: String = "essex"
var roster: Dictionary = {}
var launch_queue: Array[String] = []
var recovery_queue: Array[String] = []
var strip_owner: String = ""
var strip_use: String = ""
var external_block: bool = false
var available: bool = true
var fuel_stock_kg: float = 0.0
var ammo_stock_rounds: int = 0
var fuel_delivered_kg: float = 0.0
var ammo_delivered: int = 0
var angular_velocity: Vector3 = Vector3.ZERO
var last_ship_basis: Basis = Basis.IDENTITY
var history: Array[Dictionary] = []
var parking: Dictionary = {}

func _init() -> void:
	module_id = "carrier_operations"
	priority = 350

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	roster.clear(); launch_queue.clear(); recovery_queue.clear(); parking.clear(); history.clear()
	strip_owner = ""; strip_use = ""; available = true; external_block = false
	fuel_stock_kg = float(parameters.fuel_stock_kg); ammo_stock_rounds = int(parameters.ammo_stock_rounds)
	fuel_delivered_kg = 0.0; ammo_delivered = 0; angular_velocity = Vector3.ZERO
	deck = CarrierDeckGeometry.new()
	var ship: UnitState = world.get_unit(carrier_id)
	if ship == null: return
	last_ship_basis = ship.world_transform().basis
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		var initial: Dictionary = unit.module_data.get("carrier_initial",{})
		if str(initial.get("carrier_id","")) != carrier_id: continue
		var local: Vector3 = ship.world_transform().affine_inverse()*unit.position_m
		var parked: Transform3D = airframe.parked_pose()
		roster[id] = {"phase":"standby", "reason":"parked_inventory", "since_s":0.0, "order_id":"", "carrier_id":carrier_id, "sortie_order_id":"", "local_m":local,"local_rotation_rad":parked.basis.get_euler(),"angle_of_attack_rad":parked.basis.get_euler().x,
			"relative_velocity_mps":Vector3.ZERO, "local_yaw_rad":0.0, "on_deck":true, "recoveries":0, "sorties":0,
			"go_arounds":0, "route_index":0, "cancelled":false, "service_done":false, "parking_slot":"", "last_local_m":local,
			"gear_down":true, "hook_down":false, "flaps_down":false, "touchdown_count":0}
		_publish(unit)

func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	var ship: UnitState = world.get_unit(carrier_id)
	if ship == null: return
	_respot_scheduler(world)
	for id: String in roster:
		var unit: UnitState = world.get_unit(id)
		var s: Dictionary = roster[id]
		if s.phase == "lost": continue
		if s.phase == "diverted":
			if terminal_owns(unit): _phase(world,unit,"lost","released_aircraft_reached_terminal_damage")
			continue
		if s.on_deck and not ship.active and not terminal_owns(unit):
			_release(id); s.on_deck = false
			unit.module_data.erase("aircraft_control")
			_phase(world,unit,"diverted","carrier_lost_support_released")
			if not str(s.order_id).is_empty(): world.report_order_unit_status(s.order_id,id,"failed","carrier_lost_support_released","diverted")
			continue
		if damage_owns(unit):
			_release(id)
			if s.on_deck and not terminal_owns(unit):
				s.cancelled = true
				_phase(world,unit,"deck_hold","unfit_aircraft_remains_physically_parked")
			else:
				s.on_deck = false
				_phase(world,unit,"lost" if terminal_owns(unit) else "diverted","terminal_damage_owns_motion" if terminal_owns(unit) else "ops_released_flight_continues")
			unit.module_data.erase("aircraft_control")
			if not str(s.order_id).is_empty(): world.report_order_unit_status(s.order_id,id,"failed","aircraft_unfit_for_carrier_operation",str(s.phase))
			continue
		var order: Dictionary = _order(world,unit.active_order_id)
		if not order.is_empty() and str(s.order_id) != str(order.order_id):
			s.order_id = order.order_id; s.cancelled = false
			s["on_station_duration_s"] = float(order.get("area",{}).get("on_station_duration_s",-1))
			if s.on_deck:
				if s.phase == "respotting" and order.order_type != "retreat":
					s.respot_return_phase = "preparing"
				elif order.order_type == "retreat":
					_release(id); _phase(world,unit,"standby","recall_already_aboard")
					world.report_order_unit_status(s.order_id,id,"completed","recall_already_aboard","standby")
				else: _phase(world,unit,"preparing","sortie_order_received")
			elif order.order_type == "retreat":
				_request_recovery(world,unit,"recall_order_received")
			else:
				_release(id); _phase(world,unit,"mission","airborne_retask_received")
		if not _base_reason(world).is_empty():
			if s.on_deck:
				if s.phase not in ["standby","deck_hold"]:
					_release(id); _phase(world,unit,"deck_hold",_base_reason(world))
			elif s.phase not in ["mission","climb","return","holding","go_around"]:
				_wave_off(world,unit,_base_reason(world))
		match str(s.phase):
			"preparing":
				if world.time_s()-float(s.since_s) >= float(parameters.preparation_seconds):
					if not launch_queue.has(id): launch_queue.append(id)
					_phase(world,unit,"queued","awaiting_clear_launch_deck")
			"queued":
				if not launch_queue.is_empty() and launch_queue[0] == id and _can_launch(world,id):
					strip_owner = id; strip_use = "launch"
					_phase(world,unit,"taxi_out","exclusive_launch_clearance")
				else:
					var reason: String = _base_reason(world)
					if reason.is_empty(): reason = "awaiting_continuous_deck_respot" if (s.local_m as Vector3).z < 55.0 else "launch_deck_or_queue_occupied"
					_phase(world,unit,"queued",reason)
			"climb":
				_steer(unit,ship.world_transform()*Vector3(-3,500,-3500),78.0)
				if unit.position_m.y > 380.0 and unit.velocity_mps.length() > 65.0:
					_phase(world,unit,"mission","climb_and_assembly_complete")
			"mission":
				# AircraftTasks owns this phase. OPS only observes elapsed real patrol
				# and resources before initiating a return; no duplicate patrol pilot.
				var delegated: Dictionary = unit.module_data.get("carrier_delegated_mission",{})
				var station_duration_s: float = float(order.get("area",{}).get("on_station_duration_s",-1))
				s["on_station_duration_s"] = station_duration_s
				if bool(delegated.get("return_requested",false)):
					_request_recovery(world,unit,str(delegated.get("return_reason","delegated_mission_complete")))
				elif float(unit.module_data.aircraft_motion.fuel_kg) < 80.0:
					_request_recovery(world,unit,"low_fuel_return")
				elif not bool(delegated.get("active",false)) and station_duration_s > 0 and world.time_s()-float(s.since_s) >= station_duration_s:
					_request_recovery(world,unit,"on_station_duration_complete")
			"return", "holding", "go_around", "approach":
				_recover_guidance(world,unit,ship)
			"deck_hold":
				if _base_reason(world).is_empty() and not s.cancelled and not unit.active_order_id.is_empty():
					_phase(world,unit,"preparing","base_available_again")
		_publish(unit)

func damage_owns(unit: UnitState) -> bool:
	var d: Dictionary = unit.module_data.get("damage",{})
	return not unit.active or str(d.get("phase","operational")) != "operational" or float(d.get("propulsion_factor",1)) < 0.5 or float(unit.module_data.get("aircraft_motion",{}).get("fuel_kg",1)) <= 0.0 or not (d.get("aircraft",{}).get("detached_parts",[]) as Array).is_empty()

func terminal_owns(unit: UnitState) -> bool:
	return not unit.active or str(unit.module_data.get("damage",{}).get("phase","operational")) in ["crashing","wreck","removed"]

func _order(world: SimulationWorld, id: String) -> Dictionary:
	for order: Dictionary in world.orders_snapshot():
		if str(order.order_id) == id and order.status not in BattleOrder.TERMINAL: return order
	return {}

func _base_reason(world: SimulationWorld) -> String:
	var ship: UnitState = world.get_unit(carrier_id)
	if ship == null or not ship.active or not available: return "carrier_unavailable"
	for id: String in world.unit_ids():
		if bool(world.get_unit(id).module_data.get("carrier_deck_contact",{}).get("supporting",false)): return "wreck_on_flight_deck"
	var damage: Dictionary = ship.module_data.get("damage",{})
	if str(damage.get("phase","operational")) != "operational" or bool(damage.get("flight_deck_disabled",false)): return "flight_deck_disabled"
	if absf(float(ship.module_data.ship_motion.get("turn_rate_radps",0))) > deg_to_rad(float(parameters.max_ship_turn_degps)): return "carrier_turning"
	if maxf(absf(ship.rotation_rad.x),absf(ship.rotation_rad.z)) > deg_to_rad(float(parameters.max_ship_tilt_deg)): return "carrier_attitude_outside_envelope"
	var wind: Vector3 = world.shared_state.get("air_wind_mps",Vector3.ZERO)
	if wind.length() > 0.05: return "nonzero_air_wind_not_supported_stage1"
	var relative: Vector3 = ship.world_transform().basis.inverse()*(ship.velocity_mps-wind)
	if -relative.z < float(parameters.min_wind_over_deck_mps): return "insufficient_wind_over_deck"
	if absf(relative.x) > float(parameters.max_crosswind_mps): return "crosswind_outside_envelope"
	for key: String in deck.elevators:
		if absf(float(deck.elevators[key])-float(parameters.deck_height_m)) > 0.02: return "elevator_not_at_flight_deck"
	return ""

func _base_reason_for_contact(ship: UnitState) -> String:
	if not ship.active or not available: return "carrier_unavailable"
	if absf(float(ship.module_data.ship_motion.get("turn_rate_radps",0))) > deg_to_rad(float(parameters.max_ship_turn_degps)): return "carrier_turning"
	if bool(ship.module_data.get("damage",{}).get("flight_deck_disabled",false)): return "flight_deck_disabled"
	return ""

func deck_local(world: SimulationWorld, point: Vector3) -> Vector3:
	return world.get_unit(carrier_id).world_transform().affine_inverse()*point

func _can_launch(world: SimulationWorld, id: String) -> bool:
	if not _base_reason(world).is_empty() or external_block or not strip_owner.is_empty(): return false
	var local: Vector3 = roster[id].local_m
	if local.z < 55.0: return false # run must be long enough; never move aft instantly
	for peer: String in roster:
		if peer != id and bool(roster[peer].on_deck) and (roster[peer].local_m as Vector3).z < local.z: return false
	return true

func _respot_scheduler(world: SimulationWorld) -> void:
	# A straight-deck wave must be respotted aft before anybody launches through
	# forward parked aircraft. Move the aftmost parked aircraft first into the
	# furthest free aft station, then the next one. Nobody passes through a peer.
	if not strip_owner.is_empty() or external_block or not _base_reason(world).is_empty(): return
	var requested: bool = false
	for id: String in launch_queue:
		if roster.has(id) and roster[id].phase == "queued": requested = true
	if not requested: return
	var candidate: String = ""
	var furthest_aft: float = -INF
	for id: String in roster:
		var s: Dictionary = roster[id]
		if not s.on_deck or s.phase not in ["standby","queued","deck_hold"] or damage_owns(world.get_unit(id)): continue
		if (s.relative_velocity_mps as Vector3).length() > 0.05: continue
		var z: float = (s.local_m as Vector3).z
		if z < 55.0 and z > furthest_aft: candidate = id; furthest_aft = z
	if candidate.is_empty(): return
	var target: float = NAN
	for station: float in [105.0,75.0]:
		var clear: bool = true
		for id: String in roster:
			if id == candidate or not roster[id].on_deck: continue
			var z: float = (roster[id].local_m as Vector3).z
			if absf(station-z) < 14.0 or (z > furthest_aft and z < station+13.0): clear = false
		if clear: target = station; break
	if is_nan(target): return
	var s: Dictionary = roster[candidate]
	s["respot_target_z"] = target
	s["respot_return_phase"] = str(s.phase)
	for slot: String in parking.keys():
		if parking[slot] == candidate: parking.erase(slot)
	s.parking_slot = ""
	strip_owner = candidate; strip_use = "respot"
	_phase(world,world.get_unit(candidate),"respotting","deck_handling_force_clears_forward_parking")

func _request_recovery(world: SimulationWorld, unit: UnitState, reason: String) -> void:
	var s: Dictionary = roster[unit.id]
	_release(unit.id)
	if not recovery_queue.has(unit.id): recovery_queue.append(unit.id)
	s.route_index = 0
	_phase(world,unit,"return",reason)

func _recover_guidance(world: SimulationWorld, unit: UnitState, ship: UnitState) -> void:
	var s: Dictionary = roster[unit.id]
	var pose: Transform3D = ship.world_transform()
	var local: Vector3 = pose.affine_inverse()*unit.position_m
	var relative: Vector3 = pose.basis.inverse()*(unit.velocity_mps-CarrierDeckGeometry.velocity_at(ship,local,angular_velocity))
	s.local_m = local; s.relative_velocity_mps = relative
	if s.phase == "go_around":
		_steer(unit,pose*Vector3(-3,420,-2500),78.0)
		if unit.position_m.y > 300.0 and local.z < -1200.0: _request_recovery(world,unit,"go_around_rejoin_queue")
		return
	if s.phase == "approach":
		if external_block or strip_owner != unit.id or not _base_reason(world).is_empty():
			_wave_off(world,unit,"approach_deck_occupied" if external_block else "approach_clearance_invalid")
			return
		var target_basis: Basis = Basis(Vector3.RIGHT,deg_to_rad(float(parameters.approach_body_pitch_deg)))
		var y: float = float(parameters.deck_height_m)+airframe.support_height(target_basis,s)+maxf(0.0,local.z-108.0)*float(parameters.glideslope)
		var sink: float = clampf(relative.z*float(parameters.glideslope)-(local.y-y)*0.22,-3.7,1.0)
		var intercepting: bool = local.z > 1800.0
		var vx_limit: float = 25.0 if intercepting else 8.0
		var vx: float = clampf((-3.0-local.x)*0.45,-vx_limit,vx_limit)
		var desired: Vector3 = pose.basis*Vector3(vx,sink,-sqrt(maxf(1.0,49.0*49.0-sink*sink-vx*vx)))
		unit.module_data["aircraft_control"] = {"flight_direction":desired.normalized(),"speed_mps":parameters.approach_air_mps,"max_bank_rad":deg_to_rad(35.0 if intercepting else 12.0)}
		if local.z < 600.0 and (absf(local.x+3.0) > 7.0 or absf(local.y-y) > 12.0 or absf(relative.x) > 5.0):
			_wave_off(world,unit,"unstable_approach")
		elif local.z < 70.0 and local.y > y+0.5:
			_wave_off(world,unit,"missed_wire_zone")
		return
	# Port pattern, then a long straight intercept. Moving goals are pilot inputs;
	# no aircraft is attached to these points or teleported between segments.
	var pattern: Array[Vector3] = [Vector3(-1400,350,-700),Vector3(-1400,300,3500),Vector3(-3,260,4500)]
	var index: int = int(s.route_index)
	var goal: Vector3 = pose*pattern[mini(index,2)]
	_steer(unit,goal,72.0 if index < 2 else 58.0)
	if unit.position_m.distance_to(goal) < 260.0:
		if index < 2:
			s.route_index += 1
		else:
			var clear: bool = not recovery_queue.is_empty() and recovery_queue[0] == unit.id and strip_owner.is_empty() and not external_block and _base_reason(world).is_empty()
			for peer: String in roster:
				if peer != unit.id and roster[peer].on_deck and (roster[peer].local_m as Vector3).z > -40.0: clear = false
			if clear:
				strip_owner = unit.id; strip_use = "recovery"
				_phase(world,unit,"approach","exclusive_recovery_clearance")
			else:
				s.route_index = 0
				_phase(world,unit,"holding","awaiting_recovery_deck")

func _wave_off(world: SimulationWorld, unit: UnitState, reason: String) -> void:
	_release(unit.id)
	roster[unit.id].go_arounds += 1
	_phase(world,unit,"go_around",reason)

func _steer(unit: UnitState, goal: Vector3, speed: float) -> void:
	var delta: Vector3 = goal-unit.position_m
	var flat: Vector3 = Vector3(delta.x,0,delta.z).normalized()
	var vertical: float = clampf(delta.y*0.15,-8.0,12.0)
	unit.module_data["aircraft_control"] = {"flight_direction":(flat*sqrt(speed*speed-vertical*vertical)+Vector3.UP*vertical).normalized(),"speed_mps":speed,"max_bank_rad":deg_to_rad(38.0)}

func order_released(world: SimulationWorld, unit: UnitState, reason: String) -> void:
	if not roster.has(unit.id): return
	var s: Dictionary = roster[unit.id]
	# Completing servicing has already finished the lifecycle. Replacement gets
	# picked up next tick through the normal single-domain AircraftTasks handler.
	if s.phase in ["standby","lost","diverted"] or s.reason == "unfit_aircraft_remains_physically_parked": return
	_release(unit.id); s.order_id = ""; s.cancelled = true
	if s.on_deck:
		_phase(world,unit,"deck_hold",reason)
	else:
		_request_recovery(world,unit,"cancelled_sortie_recover")

func _release(id: String) -> void:
	launch_queue.erase(id); recovery_queue.erase(id)
	if strip_owner == id: strip_owner = ""; strip_use = ""
	for slot: String in parking.keys():
		if parking[slot] == id: parking.erase(slot)

func _phase(world: SimulationWorld, unit: UnitState, phase: String, reason: String) -> void:
	var s: Dictionary = roster[unit.id]
	if s.phase == phase and s.reason == reason: return
	var previous: String = s.phase
	s.phase = phase; s.reason = reason; s.since_s = world.time_s()
	var entry: Dictionary = {"tick":world.tick,"time_s":world.time_s(),"unit_id":unit.id,"from":previous,"phase":phase,"reason":reason,"order_id":s.order_id}
	if reason in ["airspeed_and_deck_run_complete", "recovered_and_parked"]:
		entry["sortie_serial"] = s.sorties
		entry["sortie_order_id"] = s.sortie_order_id
	history.append(entry)
	world.emit_event("carrier_operation_phase",unit.id,"",unit.position_m,entry,carrier_id)
	if not str(s.order_id).is_empty(): world.report_order_unit_progress(s.order_id,unit.id,phase,reason)
	_publish(unit)

func _publish(unit: UnitState) -> void:
	var s: Dictionary = roster[unit.id]
	if s.phase not in ["lost","diverted"]:
		s.gear_down = bool(s.on_deck) or s.phase in ["return","holding","approach","go_around"] or (s.phase == "climb" and unit.position_m.y < 50.0)
		s.hook_down = s.phase in ["approach","touchdown","arresting"]
		s.flaps_down = s.phase in ["takeoff_roll","approach","touchdown","arresting"] or (s.phase == "climb" and unit.velocity_mps.length() < 65.0)
	unit.module_data["carrier_ops"] = s.duplicate(true)

func snapshot_state() -> Dictionary:
	return {"carrier_id":carrier_id,"roster":roster.duplicate(true),"launch_queue":launch_queue.duplicate(),"recovery_queue":recovery_queue.duplicate(),"strip_owner":strip_owner,"strip_use":strip_use,"available":available,"external_block":external_block,"parking":parking.duplicate(true),"fuel_stock_kg":fuel_stock_kg,"ammo_stock_rounds":ammo_stock_rounds,"fuel_delivered_kg":fuel_delivered_kg,"ammo_delivered":ammo_delivered,"history":history.duplicate(true),"elevators":deck.elevators.duplicate(true)}
