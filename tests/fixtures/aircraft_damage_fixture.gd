class_name AircraftDamageFixture
extends RefCounted

const FIX: Script = preload("res://tests/fixtures/combat_fixture.gd")

static func arena(definition_id: String, altitude: float = 600.0) -> Dictionary:
	var settings: CombatConfig = FIX.config()
	if not settings.data.unit_profiles.has(definition_id):
		var overlay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/s14_bombing.json"))
		settings.data.unit_profiles[definition_id] = overlay.unit_profiles[definition_id]
		settings.data.weapon_profiles.merge(overlay.weapon_profiles)
		settings.data.ammo_profiles.merge(overlay.ammo_profiles)
	var a: Dictionary = FIX.arena([FIX.spawn("shooter","us",Vector3(5000,2000,0)),
		FIX.spawn("target","jp",Vector3(0,altitude,0),definition_id,Vector3(0,0,-100))],settings,false)
	if a.is_empty(): return {}
	var receipt: Dictionary = (a.world as SimulationWorld).register_module(AircraftMotion.new())
	if not FIX.require_accepted(receipt,"register damage flight motion"): return {}
	return a

static func shoot(a: Dictionary, part: String, count: int, ammo_id: String = "jp_20mm_type99_2_shell") -> void:
	var unit: UnitState = a.world.get_unit("target")
	var local_point: Vector3 = Vector3(0,0,-3.6)
	var direction: Vector3 = Vector3.BACK
	var distance: float = 5.0
	if part in ["wing_left", "wing_right"]:
		local_point = Vector3(-3.8 if part == "wing_left" else 3.8,0,-0.3)
		direction = Vector3.DOWN
	elif part == "structure":
		local_point = Vector3(0,0,0.5)
		direction = Vector3.DOWN
	elif part == "tail":
		local_point = Vector3(0,0.3,3.7)
		direction = Vector3.DOWN
	if part in ["cockpit", "engine_left", "engine_right"] or (part == "tail" and definition_uses_overlay(unit)):
		for box: Dictionary in a.frame.proxies.target:
			if box.part != part: continue
			local_point = SimData.vec3(box.center_m)
			direction = Vector3.DOWN
			break
	var pose: Transform3D = unit.world_transform()
	var shots: Array[Dictionary] = []
	for i: int in count:
		shots.append({"ammo":ammo_id,"position":pose*(local_point-direction*distance)+unit.velocity_mps/60.0,"direction":pose.basis*direction})
	(a.launcher as FIX.Launcher).pending = shots


static func definition_uses_overlay(unit: UnitState) -> bool:
	return unit.definition_id in ["jp_d4y2_model12_1944_10", "jp_g4m1_1942_07", "us_b25j_1944_07"]

static func json_data(value: Variant) -> Variant:
	if value is Vector3: return SimData.array3(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = json_data(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(json_data(item))
		return result
	return value
