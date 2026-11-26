extends RefCounted

const TASKS: Script = preload("res://scripts/showcase/expansion/carrier_tasks.gd")
const FLIGHT: Script = preload("res://scripts/air_operations/flight_bridge.gd")
const DECK: Script = preload("res://scripts/air_operations/deck_motion.gd")
const SUPPORT: Script = preload("res://scripts/air_operations/deck_contact_support.gd")

static func install(world: SimulationWorld, options: Dictionary, delegate: CarrierMissionDelegate = null) -> Dictionary:
	var ops: CarrierOperations = CarrierOperations.new()
	ops.carrier_id = str(options.carrier_id)
	var tasks: AircraftTasks = TASKS.new()
	tasks.set("operations",ops)
	tasks.set("mission_delegate",delegate)
	var flight: AircraftMotion = FLIGHT.new()
	flight.set("operations",ops)
	var deck: SimulationModule = DECK.new()
	deck.set("operations",ops)
	var support: SimulationModule = SUPPORT.new()
	support.set("operations",ops)
	for module: SimulationModule in [tasks,ops,flight,deck,support]:
		var receipt: Dictionary = world.register_module(module)
		if not receipt.accepted: return {"errors":PackedStringArray(["carrier_install:"+str(receipt.reason)]),"operations":null}
	return {"errors":PackedStringArray(),"operations":ops}
