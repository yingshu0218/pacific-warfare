class_name FleetFormations
extends RefCounted

static func elect(world: SimulationWorld, owned: Array[String], config: FleetConfig, incumbent: String = "") -> String:
	if owned.has(incumbent):
		return incumbent
	var leader: String = ""
	var rank: float = -INF
	for id: String in owned:
		var unit: UnitState = world.get_unit(id) # friendly current ownership only
		var score: float = float(unit.module_data.get("ship_initial", {}).get("flagship_priority", config.profile(unit.definition_id).flag_rank))
		if score > rank:
			rank = score
			leader = id
	return leader

static func station(leader: UnitState, index: int, kind: String, spacing: float) -> Vector3:
	var offset: Vector3
	if kind == "engage":
		offset = Vector3(0, 0, spacing * float(index + 1)) # line ahead exposes one broadside
	elif kind == "escort":
		offset = Vector3(spacing * (-1.0 if index % 2 == 0 else 1.0), 0, -spacing * 0.45 * float(index / 2 + 1))
	else:
		offset = Vector3(spacing * (0.55 if index % 2 == 0 else -0.55), 0, spacing * float(index + 1))
	return leader.position_m + Basis(Vector3.UP, leader.rotation_rad.y) * offset

static func speed_limit(world: SimulationWorld, owned: Array[String], config: FleetConfig) -> float:
	var result: float = INF
	for id: String in owned:
		var unit: UnitState = world.get_unit(id)
		var p: Dictionary = config.profile(unit.definition_id)
		var propulsion: float = float(unit.module_data.get("damage", {}).get("propulsion_factor", 1.0))
		result = minf(result, minf(float(p.cruise_mps), float(p.max_mps) * propulsion * 0.90))
	return result
