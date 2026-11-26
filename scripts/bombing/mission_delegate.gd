class_name BombingMissionDelegate
extends CarrierMissionDelegate

## Same supports/accept/step/released shape as OPS's optional mission delegate.
## Never integrates movement or reads enemy UnitState. Sole inventory writer: stores.
var parameters: Dictionary
var stores: BombStores
var states: Dictionary = {}
var salvos: Dictionary = {}
var plans: Dictionary = {}

func _init(data: Dictionary, racks: BombStores) -> void:
	parameters = data.duplicate(true)
	stores = racks

func supports(order_type: String) -> bool:
	return order_type == "bombing"

func reset(_world: SimulationWorld) -> void:
	states.clear()
	salvos.clear()
	plans.clear()

func accept(world: SimulationWorld, order: BattleOrder, unit_ids: Array[String]) -> Dictionary:
	if order.bombing.get("mode","") not in ["dive","level"]: return {"accepted":false,"reason":"bombing_mode_required"}
	for key: String in order.bombing:
		if key not in ["mode","area_id"]: return {"accepted":false,"reason":"unsupported_bombing_parameter:"+key}
	for id: String in unit_ids:
		var unit: UnitState = world.get_unit(id)
		if not parameters.aircraft.has(unit.definition_id): return {"accepted":false,"reason":"bombing_profile_missing:"+id}
		if parameters.aircraft[unit.definition_id].mode != order.bombing.mode: return {"accepted":false,"reason":"bombing_role_mismatch:"+id}
	if order.target_id.is_empty():
		var known: Dictionary = world.shared_state.get("bombing_known_areas",{}).get(order.faction_id,{}).get(str(order.bombing.get("area_id","")),{})
		if known.is_empty() or order.area != known: return {"accepted":false,"reason":"bombing_area_not_known"}
	else:
		var contact: Dictionary = CombatContacts.find(world,order.faction_id,order.target_id)
		if contact.is_empty() or contact.domain not in ["ship","ground"]: return {"accepted":false,"reason":"bombing_requires_own_surface_contact"}
	return {"accepted":true,"reason":"bombing_executor_capable"}

func released(world: SimulationWorld, order: BattleOrder, unit_ids: Array[String], reason: String) -> void:
	for id: String in unit_ids:
		stores.cancel(id)
		var unit: UnitState = world.get_unit(id)
		if states.has(id):
			states[id].phase = "released"
			states[id].reason = reason
			_publish(unit,states[id])
		states.erase(id)
		unit.module_data.erase("aircraft_control")
		if unit.module_data.has("bomb_rack"):
			for key: String in ["bay_target","crutch_target","brake_target"]: unit.module_data.bomb_rack[key] = 0.0
	# Do not let an obsolete leader's salvo authorise a replacement order.
	if world.owned_order_unit_ids(order.order_id,"aircraft").is_empty():
		salvos.erase(order.order_id)
		plans.erase(order.order_id)

func step(world: SimulationWorld, unit: UnitState, order: Dictionary, owned: Array[String], _formation: Dictionary) -> void:
	var p: Dictionary = parameters.aircraft[unit.definition_id]
	var rack: Dictionary = unit.module_data.bomb_rack
	var flight: Dictionary = unit.module_data.aircraft_motion
	if not states.has(unit.id) or states[unit.id].order_id != order.order_id:
		var obs: Dictionary = _observation(world,unit,order)
		var target: Vector3 = obs.get("point",unit.position_m+unit.velocity_mps*30)
		if not plans.has(str(order.order_id)):
			var lead: UnitState = world.get_unit(owned[0])
			var inbound: Vector3 = (target-lead.position_m)*Vector3(1,0,1)
			if inbound.length() < 1: inbound = lead.velocity_mps*Vector3(1,0,1)
			plans[str(order.order_id)] = {"axis":inbound.normalized(),"members":owned.duplicate()}
		var axis: Vector3 = plans[str(order.order_id)].axis
		var initial: Dictionary = unit.module_data.get("aircraft_initial",{})
		var fallback: Vector3=unit.position_m-axis.normalized()*5000
		fallback.y=float(p.return_altitude_m)
		states[unit.id] = {"order_id":order.order_id,"phase":"inbound","reason":"forming_attack_route","phase_s":world.time_s(),"started_s":world.time_s(),"axis":axis.normalized(),"released_at_start":int(rack.released),"last_prediction_tick":-999,"prediction":{},"release_authorized":false,"home":SimData.vec3(initial.get("withdrawal_center_m",SimData.array3(fallback))),"abort_reason":"","history":[],"stable_since_s":-1.0,"leader_id":owned[0]}
	var s: Dictionary = states[unit.id]
	var observation: Dictionary = _observation(world,unit,order)
	unit.module_data["combat_intent"] = {"fire":false,"allow_aa":false,"burst_until_tick":-1}
	unit.module_data.erase("aircraft_avoidance")
	var outbound: bool = s.phase in ["pullout","egress","regroup","return"]
	if not outbound:
		var abort: String = _abort_reason(world,unit,p,observation,s)
		if not abort.is_empty(): _abort(world,unit,s,abort)
	if world.time_s()-float(s.started_s) > 240.0 and s.phase in ["inbound","roll_in","dive","stabilize","salvo"]: _abort(world,unit,s,"attack_timeout")
	var axis: Vector3 = s.axis
	var direction: Vector3 = axis
	var speed: float = float(p.attack_mps)
	var target: Vector3 = observation.get("point",unit.position_m+axis*1000)
	var along: float = (target-unit.position_m).dot(axis)
	var slot: int = (plans[str(order.order_id)].members as Array).find(unit.id)
	var spacing: float = float(p.formation_spacing_m)
	var side: Vector3 = axis.cross(Vector3.UP)
	var offset: Vector3 = side*(spacing*float(ceili(float(slot)/2.0))*(1.0 if slot%2 == 1 else -1.0)) if slot > 0 else Vector3.ZERO
	if s.phase == "inbound":
		var goal: Vector3 = target-axis*float(p.entry_distance_m)+offset+axis*minf(800,along*0.25)
		goal.y = float(p.entry_altitude_m)
		direction = _toward_altitude(unit,goal,float(p.entry_altitude_m))
		if along <= float(p.entry_distance_m) and absf(unit.position_m.y-float(p.entry_altitude_m)) < 120.0:
			_phase(world,unit,s,"roll_in" if p.mode == "dive" else "stabilize","attack_entry_reached")
	elif s.phase == "roll_in":
		# Small heading offset requests a real bank while beginning the dive.
		direction = AircraftFlightMath.elevated(axis.rotated(Vector3.UP,deg_to_rad(12)),deg_to_rad(-20))
		rack.brake_target = 1.0
		rack.bay_target = 1.0
		if float(flight.path_pitch_rad) <= deg_to_rad(-15): _phase(world,unit,s,"dive","rolling_entry_attitude_reached")
		elif world.time_s()-float(s.phase_s) > 6.0: _abort(world,unit,s,"roll_entry_not_established")
	elif s.phase in ["dive","stabilize","salvo"]:
		var aim: Vector3 = target+offset-unit.position_m
		var pitch: float = deg_to_rad(float(p.dive_pitch_deg)) if p.mode == "dive" else clampf((float(p.entry_altitude_m)-unit.position_m.y)*0.001,-0.04,0.04)
		direction = AircraftFlightMath.elevated(aim,pitch)
		if s.phase == "salvo": direction = AircraftFlightMath.elevated(axis,pitch) # Bomb run stays straight after first release.
		rack.brake_target = 1.0 if p.mode == "dive" else 0.0
		rack.bay_target = 1.0
		rack.crutch_target = float(p.get("required_crutch",0.0))
		var ready: bool = absf(rad_to_deg(float(flight.bank_rad))) < float(p.release_bank_deg) and rad_to_deg(float(flight.path_pitch_rad)) >= float(p.release_pitch_deg[0]) and rad_to_deg(float(flight.path_pitch_rad)) <= float(p.release_pitch_deg[1])
		if ready:
			if float(s.stable_since_s) < 0: s.stable_since_s = world.time_s()
		else: s.stable_since_s = -1.0
		if world.tick-int(s.last_prediction_tick) >= 6:
			s.prediction = _prediction(world,unit,p,rack,observation)
			s.last_prediction_tick = world.tick
		var prediction: Dictionary = s.prediction
		var stable: bool = float(s.stable_since_s) >= 0 and world.time_s()-float(s.stable_since_s) >= float(p.stable_s)
		var leader: String = str(s.leader_id)
		if not owned.has(leader):
			leader = owned[0]
			s.leader_id = leader
		var formation_authorized: bool = leader == unit.id or salvos.has(str(order.order_id))
		if not prediction.is_empty() and stable:
			var error: Vector3 = prediction.target-prediction.point
			var ahead: float = error.dot(axis)
			var cross: float = absf(error.dot(side))
			s["predicted_along_error_m"] = ahead
			s["predicted_cross_error_m"] = cross
			var window: bool = absf(ahead) <= float(p.release_window_m) and cross <= float(p.cross_window_m)
			if s.phase == "salvo": window = true # Finite interval train, no independent steering per bomb.
			if window and formation_authorized:
				if leader == unit.id and not salvos.has(str(order.order_id)): salvos[str(order.order_id)] = {"tick":world.tick,"leader_id":leader}
				stores.request(unit.id,str(order.order_id))
				s.release_authorized = true
			if ahead < -float(p.release_window_m)*2 and s.phase != "salvo": _abort(world,unit,s,"missed_release_window")
		if int(rack.released) > int(s.released_at_start):
			if int(rack.remaining) > 0 and p.mode == "level": _phase(world,unit,s,"salvo","finite_bomb_train")
			else: _phase(world,unit,s,"pullout","load_released")
		if along < -250 and int(rack.released) == int(s.released_at_start): _abort(world,unit,s,"target_passed")
	elif s.phase == "pullout":
		rack.crutch_target = 0.0
		rack.bay_target = 0.0
		rack.brake_target = 1.0 if p.mode == "dive" else 0.0
		direction = AircraftFlightMath.elevated(unit.velocity_mps,deg_to_rad(12))
		if float(flight.path_pitch_rad) > deg_to_rad(4) and world.time_s()-float(s.phase_s) > 2:
			_phase(world,unit,s,"egress","positive_climb_established")
	elif s.phase == "egress":
		rack.brake_target = 0.0
		rack.bay_target = 0.0
		direction = AircraftFlightMath.elevated(axis,deg_to_rad(6))
		var cleared: float=(unit.position_m-(s.get("egress_origin_m",unit.position_m) as Vector3)).dot(axis)
		if cleared > 900.0: _phase(world,unit,s,"regroup","clear_of_attack_run")
	elif s.phase == "regroup":
		var home: Vector3 = s.home
		direction = _toward_altitude(unit,home+offset,float(p.return_altitude_m))
		var lead: UnitState=world.get_unit(owned[0])
		var assembled: bool=true
		for id: String in owned:
			if world.get_unit(id).position_m.distance_to(lead.position_m)>float(p.formation_spacing_m)*maxi(1,owned.size()-1)+260.0:assembled=false
		var home_direction: Vector3=(home-unit.position_m)*Vector3(1,0,1)
		var heading_error: float=absf(wrapf(AircraftFlightMath.heading(home_direction)-AircraftFlightMath.heading(unit.velocity_mps),-PI,PI))
		if assembled and heading_error<deg_to_rad(20): _phase(world,unit,s,"return","formation_on_return_heading")
	elif s.phase == "return":
		var home: Vector3 = s.home
		direction = _toward_altitude(unit,home+offset,float(p.return_altitude_m))
		# OPS consumes the request after egress/reassembly. It alone owns recovery.
		var handoff: bool = bool(p.get("carrier_eligible",false)) and unit.module_data.has("carrier_ops") and unit.module_data.has("carrier_delegated_mission")
		if handoff:
			unit.module_data.carrier_delegated_mission.return_requested = true
			unit.module_data.carrier_delegated_mission.return_reason = str(s.abort_reason) if not str(s.abort_reason).is_empty() else "bombing_sortie_complete"
		if not handoff and unit.position_m.distance_to(home) < 650:
			var status: String = "failed" if not str(s.abort_reason).is_empty() else "completed"
			var reason: String = str(s.abort_reason) if status == "failed" else "airborne_return_area_reached"
			_publish(unit,s)
			world.report_order_unit_status(str(order.order_id),unit.id,status,reason,"return_area")
			return
	unit.module_data["aircraft_control"] = {"flight_direction":direction,"speed_mps":speed,"max_bank_rad":deg_to_rad(float(p.max_bank_deg))}
	if s.phase == "roll_in": unit.module_data.aircraft_control.max_bank_rad = deg_to_rad(30)
	if p.mode == "dive" and s.phase in ["roll_in","dive","pullout"]: unit.module_data.aircraft_control["throttle"] = 0.12
	_publish(unit,s)

func _prediction(world: SimulationWorld, unit: UnitState, p: Dictionary, rack: Dictionary, observation: Dictionary) -> Dictionary:
	if observation.is_empty(): return {}
	var slot: int = -1
	for i: int in rack.slots.size():
		if rack.slots[i].loaded:
			slot = i
			break
	if slot < 0: return {}
	var position: Vector3 = unit.world_transform()*BombStores.local_slot(p,rack,slot)
	var ammo: AmmoDefinition = world.ammo_definition(str(p.ammo_id))
	var prediction: Dictionary = BombBallistics.predict(position,unit.velocity_mps,float(observation.point.y),ammo,world.fixed_delta_s())
	if not prediction.is_empty(): prediction["target"] = observation.point+observation.velocity*float(prediction.time_s)
	return prediction

func _observation(world: SimulationWorld, unit: UnitState, order: Dictionary) -> Dictionary:
	if str(order.target_id).is_empty(): return {"point":SimData.vec3(order.area.center_m),"velocity":Vector3.ZERO}
	var contact: Dictionary = CombatContacts.find(world,unit.faction_id,str(order.target_id))
	if contact.is_empty(): return {}
	var age: float = maxf(0,world.time_s()-float(contact.observed_time_s))
	return {"point":contact.position_m+contact.velocity_mps*age,"velocity":contact.velocity_mps}

func _abort_reason(world: SimulationWorld, unit: UnitState, p: Dictionary, observation: Dictionary, s: Dictionary) -> String:
	var damage_reason: String = _damage_abort(unit)
	if not damage_reason.is_empty(): return damage_reason
	if observation.is_empty(): return "target_lost"
	if s.phase == "inbound" and unit.position_m.y-TerrainQueries.height_m(world,unit.position_m,true) < float(p.min_release_agl_m) and (observation.point-unit.position_m).length() < float(p.entry_distance_m)*1.3: return "too_low"
	if int(unit.module_data.bomb_rack.remaining) == 0 and int(unit.module_data.bomb_rack.released) == int(s.released_at_start): return "empty_load"
	var flight: Dictionary = unit.module_data.aircraft_motion
	if float(flight.fuel_kg) < float(p.fuel_reserve_kg): return "fuel_reserve"
	if s.phase in ["roll_in","dive","stabilize","salvo"]:
		if unit.position_m.y-TerrainQueries.height_m(world,unit.position_m,true) < float(p.min_release_agl_m): return "too_low"
		if str(flight.safety_state) != "normal": return "flight_safety:"+str(flight.safety_state)
		if unit.velocity_mps.length() > float(p.max_release_mps): return "overspeed_abort"
	return ""

func dispatch_ready(unit: UnitState) -> bool:
	var p: Dictionary = parameters.aircraft.get(unit.definition_id, {})
	return not p.is_empty() and _damage_abort(unit).is_empty() and float(unit.module_data.get("aircraft_motion", {}).get("fuel_kg", 0.0)) >= float(p.fuel_reserve_kg)

static func _damage_abort(unit: UnitState) -> String:
	var damage: Dictionary = unit.module_data.get("damage", {})
	if not unit.active or damage.get("phase", "operational") != "operational" or float(damage.get("propulsion_factor", 1.0)) < 0.8 or float(damage.get("control_factor", 1.0)) < 0.8: return "damage_abort"
	if float(damage.get("structure", 1.0)) < float(damage.get("structure_max", 1.0)) * 0.7 or float(damage.get("fire", 0.0)) > 0.25: return "combat_damage_abort"
	return ""

func _abort(world: SimulationWorld, unit: UnitState, s: Dictionary, reason: String) -> void:
	stores.cancel(unit.id)
	if str(s.abort_reason).is_empty(): s.abort_reason = reason
	_phase(world,unit,s,"pullout",reason)

func _phase(world: SimulationWorld, unit: UnitState, s: Dictionary, phase: String, reason: String) -> void:
	if s.phase == phase: return
	s.phase = phase
	s.reason = reason
	if phase == "egress": s["egress_origin_m"] = unit.position_m
	s.phase_s = world.time_s()
	s.history.append({"tick":world.tick,"phase":phase,"reason":reason})
	world.report_order_unit_progress(str(s.order_id),unit.id,phase,reason)
	world.emit_event("bombing_phase",unit.id,"",unit.position_m,{"order_id":s.order_id,"phase":phase,"reason":reason})

func _publish(unit: UnitState, s: Dictionary) -> void:
	unit.module_data["bombing"] = s.duplicate(true)
	unit.task["aircraft"] = {"phase":s.phase,"reason":s.reason,"maneuver_phase":s.phase,"maneuver_reason":s.reason,"bombing":s.duplicate(true)}

func _toward_altitude(unit: UnitState, goal: Vector3, altitude: float) -> Vector3:
	var flat: Vector3 = (goal-unit.position_m)*Vector3(1,0,1)
	return AircraftFlightMath.elevated(flat,clampf((altitude-unit.position_m.y)*0.001,-0.08,0.12))
