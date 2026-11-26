class_name AircraftSuite
extends RefCounted

static func install(world: SimulationWorld) -> PackedStringArray:
	if world.tick != 0:
		return ["aircraft_install_before_first_tick"]
	for module: SimulationModule in [AircraftTasks.new(), AircraftMotion.new()]:
		var result: Dictionary = world.register_module(module)
		if not result.accepted:
			return ["aircraft_install:" + str(result.reason)]
	return []
