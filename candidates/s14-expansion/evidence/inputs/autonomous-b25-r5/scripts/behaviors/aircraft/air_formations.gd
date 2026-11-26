class_name AirFormations
extends RefCounted

## Stable roster slots survive loss/reassignment; each survivor flies independently.
static func assignment(roster: Array, owned: Array[String], id: String) -> Dictionary:
	var slot: int = roster.find(id)
	var pair_index: int = slot / 2
	var pair: Array[String] = []
	for index: int in range(pair_index * 2, mini(pair_index * 2 + 2, roster.size())):
		if owned.has(str(roster[index])):
			pair.append(str(roster[index]))
	var flight_lead: String = ""
	for candidate: String in roster:
		if owned.has(candidate):
			flight_lead = candidate
			break
	return {"slot": slot, "pair_index": pair_index, "pair_leader_id": pair[0] if not pair.is_empty() else id,
		"flight_leader_id": flight_lead, "role": "leader" if pair.is_empty() or pair[0] == id else "wingman",
		"section_role": "attack" if pair_index == 0 else "support"}

static func station(leader: UnitState, assignment_data: Dictionary, pair_station: bool = false) -> Vector3:
	var offset: Vector3 = Vector3(90.0, 120.0, 180.0)
	if pair_station:
		offset = Vector3(-350.0, 300.0, 360.0)
	var forward: Vector3 = -Basis.from_euler(leader.rotation_rad).z
	var heading: float = AircraftFlightMath.heading(forward,leader.rotation_rad.y)
	return leader.position_m + Basis(Vector3.UP,heading) * offset

static func avoid_friends(world: SimulationWorld, unit: UnitState, goal: Vector3) -> Dictionary:
	var nearest: float = 100000.0
	var conflict: String = ""
	var soonest: float = 100000.0
	for other_id: String in world.unit_ids():
		var other: UnitState = world.get_unit(other_id)
		if other.id == unit.id or not other.active or other.faction_id != unit.faction_id or not other.module_data.has("aircraft_motion"):
			continue
		var separation: Vector3 = unit.position_m-other.position_m
		var relative: Vector3 = unit.velocity_mps-other.velocity_mps
		var distance: float = separation.length()
		nearest = minf(nearest,distance)
		var time: float = clampf(-separation.dot(relative)/maxf(1.0,relative.length_squared()),0,8.0)
		var predicted: float = (separation+relative*time).length()
		var corridor: float = 65.0+minf(70.0,relative.length()*0.25)
		if distance < 110 or (time > 0.1 and time < 7.5 and distance < maxf(900.0,unit.velocity_mps.length()*7.0) and predicted < corridor):
			if time < soonest:
				soonest = time
				conflict = other_id
	var avoidance: Dictionary = unit.module_data.get("aircraft_avoidance",{})
	if not conflict.is_empty():
		if avoidance.is_empty() or str(avoidance.other_id) != conflict:
			var forward: Vector3 = AircraftFlightMath.elevated(unit.velocity_mps,0)
			var right: Vector3 = forward.cross(Vector3.UP).normalized()
			var vertical: float = 0.40 if unit.id < conflict else -0.40
			if float(unit.module_data.aircraft_motion.get("height_agl_m",unit.position_m.y)) < 300:
				vertical = 0.40
			avoidance = {"other_id":conflict,"direction":(forward+right*0.85+Vector3.UP*vertical).normalized(),"until_s":world.time_s()+3.0}
		else:
			avoidance.until_s = world.time_s()+3.0
		unit.module_data["aircraft_avoidance"] = avoidance
	var avoiding: bool = not avoidance.is_empty() and world.time_s() < float(avoidance.until_s) and nearest < 1100
	if avoiding:
		goal = unit.position_m+(avoidance.direction as Vector3)*maxf(900,unit.velocity_mps.length()*8.0)
	else:
		unit.module_data.erase("aircraft_avoidance")
	return {"goal":goal,"avoiding":avoiding,"nearest_friend_m":nearest}
