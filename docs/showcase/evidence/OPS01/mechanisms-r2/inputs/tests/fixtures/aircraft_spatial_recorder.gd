class_name AircraftSpatialRecorder
extends RefCounted

var samples: Array = []
var timeline: Array = []
var stats: Dictionary = {"air_fired":0,"air_hits":0,"air_enemy_hits":0,"air_friendly_hits":0,"air_damaged":0,"exits":0,"impacts":0,"command_rejected":0,
	"rejection_groups":{},"min_friend_m":100000.0,"max_pose_velocity_error_rad":0.0,"max_gun_forward_error_rad":0.0,"units":{}}
var previous: Dictionary = {}
var rejected_samples: Array = []
var air_ids: Array[String] = []
var initial_rounds: int = 0

func setup(world: SimulationWorld) -> void:
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if world.unit_definition(unit.definition_id).domain == "aircraft":
			air_ids.append(id)
			initial_rounds += rounds(unit)
			stats.units[id] = {"max_up_deg":0.0,"max_down_deg":0.0,"max_bank_deg":0.0,"min_y_m":unit.position_m.y,
				"max_y_m":unit.position_m.y,"max_vertical_mps":0.0,"min_speed_mps":100000.0,"max_speed_mps":0.0,
				"max_load_g":0.0,"pitch_over_15_s":0.0,"pitch_over_25_s":0.0,"maneuvers":{},"safety":{}}

static func rounds(unit: UnitState) -> int:
	var count: int = 0
	for weapon: WeaponState in unit.weapons.values():
		for n: int in weapon.remaining_rounds:
			count += n
	return count

func collect(world: SimulationWorld, events: Array[BattleEvent], sample: bool = true) -> void:
	for event: BattleEvent in events:
		if event.kind == "fired" and air_ids.has(event.entity_id):
			stats.air_fired += 1
			var unit: UnitState = world.get_unit(event.entity_id)
			var fwd: Vector3 = -Basis.from_euler(unit.rotation_rad).z
			stats.max_gun_forward_error_rad = maxf(float(stats.max_gun_forward_error_rad),fwd.angle_to(event.data.muzzle_direction))
		elif event.kind == "hit" and air_ids.has(event.entity_id):
			stats.air_hits += 1
			stats["air_friendly_hits" if bool(event.data.get("friendly",false)) else "air_enemy_hits"] += 1
		elif event.kind == "damaged" and air_ids.has(event.entity_id):
			stats.air_damaged += 1
		elif event.kind == "aircraft_exit":
			stats.exits += 1
		elif event.kind == "unit_impact" and air_ids.has(event.entity_id):
			stats.impacts += 1
		elif event.kind == "command_rejected":
			stats.command_rejected += 1
			var request: Dictionary = event.data.get("request",{})
			var actor: String = str(request.get("entity_id",event.entity_id))
			if actor.is_empty(): actor = str(event.data.get("issuer_id","unknown"))
			var kind: String = str(event.data.get("kind",""))
			var reason: String = str(event.data.get("reason",""))
			var key: String = kind+"|"+reason+"|"+actor
			if not stats.rejection_groups.has(key):
				stats.rejection_groups[key] = {"kind":kind,"reason":reason,"actor":actor,"issuer":event.data.get("issuer_id",""),"count":0,"first_tick":event.tick,"last_tick":event.tick}
			stats.rejection_groups[key].count += 1
			stats.rejection_groups[key].last_tick = event.tick
			rejected_samples.append(event.snapshot())
			if rejected_samples.size() > 32: rejected_samples.remove_at(16)
	for id: String in air_ids:
		var unit: UnitState = world.get_unit(id)
		var task: Dictionary = unit.task.get("aircraft",{})
		var flight: Dictionary = unit.module_data.aircraft_motion
		var mode: String = str(task.get("maneuver_phase",task.get("phase","idle")))
		var safety: String = str(flight.get("safety_state","legacy"))
		if str(previous.get(id,"")) != mode+":"+safety:
			timeline.append({"tick":world.tick,"time_s":world.time_s(),"id":id,"mode":mode,"reason":task.get("maneuver_reason",task.get("reason","")),"safety":safety,"position_m":SimData.array3(unit.position_m),"speed_mps":unit.velocity_mps.length()})
			previous[id] = mode+":"+safety
		var pitch: float = AircraftFlightMath.pitch(unit.velocity_mps)
		var bank: float = float(flight.get("bank_rad",unit.rotation_rad.z))
		if unit.active:
			var row: Dictionary = stats.units[id]
			row.max_up_deg = maxf(float(row.max_up_deg),rad_to_deg(pitch))
			row.max_down_deg = minf(float(row.max_down_deg),rad_to_deg(pitch))
			row.max_bank_deg = maxf(float(row.max_bank_deg),absf(rad_to_deg(bank)))
			row.min_y_m = minf(float(row.min_y_m),unit.position_m.y)
			row.max_y_m = maxf(float(row.max_y_m),unit.position_m.y)
			row.max_vertical_mps = maxf(float(row.max_vertical_mps),absf(unit.velocity_mps.y))
			row.min_speed_mps = minf(float(row.min_speed_mps),unit.velocity_mps.length())
			row.max_speed_mps = maxf(float(row.max_speed_mps),unit.velocity_mps.length())
			row.max_load_g = maxf(float(row.max_load_g),float(flight.get("load_factor",0)))
			if absf(pitch) > deg_to_rad(15): row.pitch_over_15_s += world.fixed_delta_s()
			if absf(pitch) > deg_to_rad(25): row.pitch_over_25_s += world.fixed_delta_s()
			row.maneuvers[mode] = float(row.maneuvers.get(mode,0))+world.fixed_delta_s()
			row.safety[safety] = float(row.safety.get(safety,0))+world.fixed_delta_s()
			stats.max_pose_velocity_error_rad = maxf(float(stats.max_pose_velocity_error_rad),(-Basis.from_euler(unit.rotation_rad).z).angle_to(unit.velocity_mps))
			for other_id: String in air_ids:
				var other: UnitState = world.get_unit(other_id)
				if other.active and other.id > unit.id and other.faction_id == unit.faction_id:
					stats.min_friend_m = minf(float(stats.min_friend_m),unit.position_m.distance_to(other.position_m))
		if sample:
			samples.append({"tick":world.tick,"time_s":world.time_s(),"id":id,"active":unit.active,"position_m":SimData.array3(unit.position_m),
				"velocity_mps":SimData.array3(unit.velocity_mps),"rotation_rad":SimData.array3(unit.rotation_rad),"pitch_deg":rad_to_deg(pitch),"bank_deg":rad_to_deg(bank),
				"load_g":flight.get("load_factor",0),"energy_height_m":flight.energy_height_m,"fuel_kg":flight.fuel_kg,"mode":mode,"phase":task.get("phase","idle"),"safety":safety})
			samples[-1].merge({"body_roll_rate_degps":rad_to_deg(float(flight.get("body_roll_rate_radps",0))),
				"heading_rate_degps":rad_to_deg(float(flight.get("heading_rate_radps",0))),
				"path_pitch_rate_degps":rad_to_deg(float(flight.get("path_pitch_rate_radps",0))),
				"path_curvature_degps":rad_to_deg(float(flight.get("path_turn_rate_radps",0))),
				"requested_load_g":flight.get("requested_load_g",0),"induced_drag_mps2":flight.get("induced_drag_mps2",0)})

func result(world: SimulationWorld) -> Dictionary:
	var remaining: int = 0
	var endings: Dictionary = {}
	for id: String in air_ids:
		var unit: UnitState = world.get_unit(id)
		remaining += rounds(unit)
		endings[id] = {"active":unit.active,"exit_reason":unit.module_data.aircraft_motion.get("exit_reason",""),"damage_phase":unit.module_data.get("damage",{}).get("phase","operational")}
	stats["inventory_used"] = initial_rounds-remaining
	return {"map_id":world.shared_state.get("terrain",{}).get("id","flat_sea"),"summary":stats,"timeline":timeline,"rejected_samples":rejected_samples,"samples":samples,"endings":endings,"time_s":world.time_s()}
