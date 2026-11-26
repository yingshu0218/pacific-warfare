extends RefCounted

static func world(definition_id: String = "us_f6f5_1944", altitude_m: float = 2400, speed_mps: float = 115, initial: Dictionary = {}, showcase_tasks: bool = false) -> SimulationWorld:
	var spawns: Array = [AircraftFixture.spawn("pilot","us",Vector3(0,altitude_m,0),definition_id,0,speed_mps,initial)]
	if not showcase_tasks: return AircraftFixture.world(spawns)
	var result: SimulationWorld = SimulationWorld.new()
	var errors: PackedStringArray = result.configure(AircraftFixture.catalog(),{"id":"training_s14_override","seed":404,"tick_hz":60,"factions":["us","jp"],"spawns":spawns,"groups":[]})
	if not AircraftFixture.CHECK.require_ok(errors.is_empty(),str(errors)): return null
	for module: SimulationModule in [SB2CShowcaseTasks.new(),AircraftMotion.new()]:
		var receipt: Dictionary = result.register_module(module)
		if not AircraftFixture.CHECK.require_accepted(receipt,"training fixture override"): return null
	return result

static func order(world_ref: SimulationWorld, kind: String, direction: int = 1, id: String = "drill", options: Dictionary = {}, unit_id: String = "pilot") -> Dictionary:
	var request: BattleOrder = BattleOrder.new()
	request.order_id = id
	request.issuer_id = "s14_exercise_director"
	request.source = "human"
	request.faction_id = world_ref.get_unit(unit_id).faction_id
	request.recipient_ids = [unit_id]
	request.order_type = "aircraft_training"
	request.training = {"maneuver":kind,"direction":direction}
	request.training.merge(options,true)
	var receipt: Dictionary = world_ref.submit_order(request)
	return {"request":request,"receipt":receipt}

static func record(world_ref: SimulationWorld, id: String = "drill") -> Dictionary:
	for entry: Dictionary in world_ref.orders_snapshot():
		if entry.order_id == id: return entry
	return {}
