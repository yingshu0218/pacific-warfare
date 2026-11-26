class_name AircraftDamageFixture
extends RefCounted

const FIX: Script = preload("res://tests/fixtures/combat_fixture.gd")

static func arena(definition_id: String, altitude: float = 600.0) -> Dictionary:
	var a: Dictionary = FIX.arena([FIX.spawn("shooter","us",Vector3(5000,2000,0)),
		FIX.spawn("target","jp",Vector3(0,altitude,0),definition_id,Vector3(0,0,-100))],null,false)
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
	var pose: Transform3D = unit.world_transform()
	var shots: Array[Dictionary] = []
	for i: int in count:
		shots.append({"ammo":ammo_id,"position":pose*(local_point-direction*distance)+unit.velocity_mps/60.0,"direction":pose.basis*direction})
	(a.launcher as FIX.Launcher).pending = shots


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
