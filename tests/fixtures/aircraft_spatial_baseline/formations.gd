class_name BaselineAirFormations
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
	var offset: Vector3 = Vector3(90.0, 45.0, 150.0)
	if pair_station:
		offset = Vector3(-350.0, 130.0, 330.0)
	return leader.position_m + Basis(Vector3.UP, leader.rotation_rad.y) * offset

static func avoid_friends(world: SimulationWorld, unit: UnitState, goal: Vector3) -> Dictionary:
	var correction: Vector3 = Vector3.ZERO
	var closest: float = INF
	for other_id: String in world.unit_ids():
		var other: UnitState = world.get_unit(other_id)
		if other.id == unit.id or not other.active or other.faction_id != unit.faction_id or not other.module_data.has("aircraft_motion"):
			continue
		var separation: Vector3 = unit.position_m - other.position_m
		var relative: Vector3 = unit.velocity_mps - other.velocity_mps
		var distance: float = separation.length()
		closest = minf(closest, distance)
		var t: float = clampf(-separation.dot(relative) / maxf(1.0, relative.length_squared()), 0.0, 4.0)
		var predicted: float = (separation + relative * t).length()
		if distance < 70.0:
			correction += separation.normalized() * (70.0 - distance) * 8.0
		elif predicted < 32.0 and distance < 450.0 and t > 0.0:
			# Predictive, reciprocal right turns; no position snapping or shared track.
			correction += Basis(Vector3.UP, unit.rotation_rad.y) * Vector3(420.0, 35.0 if unit.id < other.id else -35.0, 0.0)
	return {"goal": goal + correction, "avoiding": correction.length_squared() > 1.0, "nearest_friend_m": closest}
