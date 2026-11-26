class_name CombatContacts
extends SimulationModule

var config: CombatConfig
var frame: CombatFrame
var records: Dictionary = {}
var next_scan_s: float = 0.0

func _init(parameters: CombatConfig, geometry: CombatFrame) -> void:
	module_id = "combat_contacts"
	priority = 100
	config = parameters
	frame = geometry

func reset(world_ref: RefCounted) -> void:
	records.clear()
	next_scan_s = 0.0
	(world_ref as SimulationWorld).shared_state["combat_contacts"] = records

static func find(world: SimulationWorld, faction_id: String, entity_id: String, fresh_only: bool = true) -> Dictionary:
	# Per-world pure index, cleared by reset; never materialize a commander snapshot.
	var contact: Dictionary = world.shared_state.get("combat_contacts", {}).get(faction_id, {}).get(entity_id, {})
	if contact.is_empty() or not contact.valid or (fresh_only and not contact.fresh):
		return {}
	return contact.duplicate(true)

func fixed_update(world_ref: RefCounted, _delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	var scan: bool = world.time_s() + 0.000001 >= next_scan_s
	if scan:
		next_scan_s += float(config.data.contacts.scan_interval_s)
	for id: String in world.unit_ids():
		var observer: UnitState = world.get_unit(id)
		if not records.has(observer.faction_id):
			records[observer.faction_id] = {}
		if not scan or not observer.active or not CombatPresence.is_present(observer.module_data):
			continue
		for target_id: String in world.unit_ids():
			var target: UnitState = world.get_unit(target_id)
			if not target.active or not CombatPresence.is_present(target.module_data) or target.faction_id == observer.faction_id:
				continue
			var sensor: String = _observe(world, observer, target)
			if sensor.is_empty():
				continue
			var domain: String = (frame.definitions[target_id] as UnitDefinition).domain
			records[observer.faction_id][target_id] = {"entity_id": target_id, "domain": domain, "classification": domain,
				"position_m": target.position_m, "velocity_mps": target.velocity_mps, "observed_tick": world.tick,
				"aim_offset_m": Vector3.UP * float(config.data.unit_profiles[target.definition_id].get("aim_height_m", 0.0)),
				"observed_time_s": world.time_s(), "sensor": sensor, "fresh": true, "valid": true, "uncertainty_m": 0.0}
	for faction: String in records:
		var contacts: Array = []
		var ids: Array = records[faction].keys()
		ids.sort()
		for id: String in ids:
			var contact: Dictionary = records[faction][id]
			var age: float = world.time_s() - float(contact.observed_time_s)
			if age > float(config.data.contacts.expiry_s):
				records[faction].erase(id)
				continue
			contact.fresh = age <= float(config.data.contacts.fresh_s)
			contact.uncertainty_m = age * float(config.data.contacts.uncertainty_mps)
			contacts.append(contact.duplicate(true))
		world.set_contacts(faction, contacts)

func _observe(world: SimulationWorld, observer: UnitState, target: UnitState) -> String:
	var p: Dictionary = config.data.unit_profiles[observer.definition_id]
	var target_profile: Dictionary = config.data.unit_profiles[target.definition_id]
	var eye: Vector3 = observer.world_transform() * Vector3(0, float(p.sensor_height_m), 0)
	var point: Vector3 = target.world_transform() * Vector3(0, float(target_profile.sensor_height_m) * 0.5, 0)
	var distance: float = eye.distance_to(point)
	var horizon: float = 3570.0 * (sqrt(maxf(eye.y, 0.0)) + sqrt(maxf(point.y, 0.0)))
	if distance > horizon:
		return ""
	var domain: String = (frame.definitions[target.id] as UnitDefinition).domain
	var radar: float = float(p.get("radar_" + domain + "_m", 0.0))
	var visual: float = float(p.visual_m)
	if distance > maxf(radar, visual):
		return ""
	if world.shared_state.has("terrain") and not TerrainQueries.segment_hit(world,eye,point,false).is_empty():
		return ""
	if CombatGeometry.masked(eye, point, config.data.environment.get("solids", [])):
		return ""
	for id: String in frame.proxies:
		if id == observer.id or id == target.id:
			continue
		if not CombatPresence.is_present(world.get_unit(id).module_data):continue
		var inverse: Transform3D = (frame.starts[id] as Transform3D).affine_inverse()
		if CombatGeometry.masked(inverse * eye, inverse * point, frame.proxies[id]):
			return ""
	return "visual" if distance <= visual else "radar"

func snapshot_state() -> Dictionary:
	return {"records": records.duplicate(true), "next_scan_s": next_scan_s}
