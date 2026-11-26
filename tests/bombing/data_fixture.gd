extends RefCounted

const BASE: Script = preload("res://tests/fixtures/combat_fixture.gd")

static func parameters() -> Dictionary:
	var result: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/bombing/data/parameters.json"))
	var check: Script=load("res://scripts/bombing/configuration.gd")
	assert((check.call("validate",result) as PackedStringArray).is_empty())
	return result

static func catalog() -> DefinitionCatalog:
	var units: Array = []
	var ammunition: Array = []
	var guns: Array = []
	for pair: Array in [["res://data/units",units],["res://data/ammunition",ammunition],["res://data/units/weapons",guns]]:
		for file: String in DirAccess.get_files_at(pair[0]):
			if file.ends_with(".json"): pair[1].append(JSON.parse_string(FileAccess.get_file_as_string(str(pair[0])+"/"+file)))
	units.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tests/bombing/data/units.json")))
	ammunition.append_array(parameters().ammunition.values())
	var result: DefinitionCatalog = BASE.catalog()
	var errors: PackedStringArray = result.load_data(units,ammunition,guns)
	assert(errors.is_empty(),str(errors))
	return result

static func config() -> CombatConfig:
	var c: CombatConfig = BASE.config()
	var params: Dictionary = parameters()
	c.data.ammo_profiles.merge(params.ammo_profiles,true)
	var sb: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/s14_sb2c.json"))
	c.data.unit_profiles.merge(sb.unit_profiles,true)
	for id: String in params.aircraft:
		if c.data.unit_profiles.has(id): continue
		var large: bool = "g4m1" in id or "b25j" in id
		var profile: Dictionary = c.data.unit_profiles.us_f6f5_1944.duplicate(true)
		profile.structure = 160.0 if large else 85.0
		profile.visual_m = 15000.0
		profile.boxes = [
			{"part":"control","center_m":[0,0,0],"half_extents_m":[1.25,1.0,7.8] if large else [.5,.6,3.5],"armor_mm":0.0},
			{"part":"engine","center_m":[-3.85,0,-4.8] if large else [0,0,-3.4],"half_extents_m":[.9,.9,1.3],"armor_mm":0.0},
			{"part":"engine","center_m":[3.85,0,-4.8] if large else [0,0,-3.4],"half_extents_m":[.9,.9,1.3],"armor_mm":0.0},
			{"part":"wing_left","center_m":[-6.6,0,-2.0] if large else [-3.,0,-.5],"half_extents_m":[5.8,.2,1.8] if large else [2.7,.15,1.2],"armor_mm":0.0},
			{"part":"wing_right","center_m":[6.6,0,-2.0] if large else [3.,0,-.5],"half_extents_m":[5.8,.2,1.8] if large else [2.7,.15,1.2],"armor_mm":0.0},
			{"part":"tail","center_m":[0,.4,8.] if large else [0,.4,4.1],"half_extents_m":[4.6,1.2,1.5] if large else [2.2,1.,.8],"armor_mm":0.0}]
		if "b25j" in id:
			profile.boxes = [
				{"part":"control","center_m":[0,0,-1.4],"half_extents_m":[.7,.8,6.4],"armor_mm":0.0},
				{"part":"engine","center_m":[-3.12,.12,-3.1],"half_extents_m":[.75,.8,1.1],"armor_mm":0.0},
				{"part":"engine","center_m":[3.12,.12,-3.1],"half_extents_m":[.75,.8,1.1],"armor_mm":0.0},
				{"part":"wing_left","center_m":[-5.4,.2,-.6],"half_extents_m":[4.85,.18,1.45],"armor_mm":0.0},
				{"part":"wing_right","center_m":[5.4,.2,-.6],"half_extents_m":[4.85,.18,1.45],"armor_mm":0.0},
				{"part":"tail","center_m":[0,.6,7.1],"half_extents_m":[3.8,1.3,1.45],"armor_mm":0.0}]
		var model_name: String = "b25j" if "b25j" in id else ("g4m1" if "g4m1" in id else "d4y2")
		var interfaces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://aircraft/"+model_name+"/data/interfaces.json"))
		for marker: Dictionary in interfaces.markers:
			var part: String = "wing_left" if marker.id in ["DAMAGE_WING_LEFT_CUT","DAMAGE_LEFT_WING_CUT"] else ("wing_right" if marker.id in ["DAMAGE_WING_RIGHT_CUT","DAMAGE_RIGHT_WING_CUT"] else ("tail" if marker.id == "DAMAGE_TAIL_CUT" else ""))
			if not part.is_empty(): profile.aircraft_damage.anchors_m[part] = marker.position_m.duplicate()
			if marker.id in ["ENGINE_LEFT_SMOKE","ENGINE_SMOKE"]:
				var anchor: Array=marker.position_m.duplicate()
				if large:anchor[0]=0.0 # Aggregate propulsion damage, no invented engine side.
				profile.damage_effects.fire_anchor_m = anchor.duplicate()
				profile.damage_effects.smoke_anchor_m = anchor.duplicate()
		c.data.unit_profiles[id] = profile
	assert(c.load_data(c.data).is_empty())
	return c

static func spawn(id: String, faction: String, position: Vector3, definition: String, velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	var result: Dictionary = BASE.spawn(id,faction,position,definition,velocity)
	if velocity.length() > 1:
		result["rotation_rad"] = SimData.array3(AircraftFlightMath.frame(velocity.normalized(),Vector3.UP).get_euler())
	result["module_data"] = {"aircraft_initial":{"withdrawal_center_m":SimData.array3(Vector3(position.x,1300,position.z+2500))},"combat_intent":{"fire":false,"allow_aa":false,"burst_until_tick":-1}}
	return result

static func order(world: SimulationWorld, ids: Array, mode: String, target: String = "target", area: Dictionary = {}) -> Dictionary:
	var unit: UnitState = world.get_unit(ids[0])
	var data: Dictionary = {"order_id":"bomb_"+str(world.tick),"issuer_id":"test_commander","source":"ai","faction_id":unit.faction_id,"recipient_ids":ids,"order_type":"bombing","target_id":target,"bombing":{"mode":mode},"intent":"Attack with finite bomb load"}
	if not area.is_empty():
		data["area"] = area
		data.bombing["area_id"] = "range"
		world.shared_state["bombing_known_areas"] = {unit.faction_id:{"range":area}}
	return world.submit_order(BattleOrder.from_data(data))

static func json_data(value: Variant) -> Variant:
	if value is Vector3: return SimData.array3(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = json_data(value[key])
		return result
	if value is Array or value is PackedStringArray:
		var result: Array = []
		for item: Variant in value: result.append(json_data(item))
		return result
	return value

