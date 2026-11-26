class_name FleetSuite
extends RefCounted

static func install(world: SimulationWorld, parameters: FleetConfig = null, enable_commanders: bool = true) -> PackedStringArray:
	if world.tick != 0:
		return ["fleet_install_before_first_tick"]
	var config: FleetConfig = FleetConfig.new()
	var errors: PackedStringArray = config.load_file() if parameters == null else config.load_data(parameters.data)
	if not errors.is_empty():
		return errors
	for id: String in world.unit_ids():
		var definition: UnitDefinition = world.unit_definition(world.get_unit(id).definition_id)
		if definition.domain == "ship" and not config.supports(definition.id):
			errors.append("fleet_performance_missing:" + definition.id)
		if definition.domain == "ship":
			var initial: Variant = world.get_unit(id).module_data.get("ship_initial", {})
			if not initial is Dictionary:
				errors.append("fleet_invalid_initial:" + id)
			else:
				if initial.has("fuel_fraction") and (not SimData.finite_number(initial.fuel_fraction) or float(initial.fuel_fraction) < 0.0 or float(initial.fuel_fraction) > 1.0):
					errors.append("fleet_invalid_initial_fuel:" + id)
				if initial.has("flagship_priority") and not FleetConfig._positive(initial.flagship_priority):
					errors.append("fleet_invalid_flagship_priority:" + id)
	var existing: Dictionary = world.snapshot().modules
	for id: String in ["fleet_tasks", "ship_motion", "fleet_commander"]:
		if existing.has(id):
			errors.append("fleet_module_already_registered:" + id)
	if not errors.is_empty():
		return errors
	var modules: Array[SimulationModule] = [FleetTasks.new(config), ShipMotion.new(config)]
	if enable_commanders:
		modules.append(FleetCommander.new(config))
	for module: SimulationModule in modules:
		var receipt: Dictionary = world.register_module(module)
		if not receipt.accepted:
			return ["fleet_register:" + str(receipt.reason)]
	return []
