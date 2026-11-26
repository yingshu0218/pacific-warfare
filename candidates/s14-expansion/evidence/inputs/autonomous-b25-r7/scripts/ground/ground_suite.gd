class_name GroundSuite
extends RefCounted
static func install(world: SimulationWorld) -> PackedStringArray:
	var errors: PackedStringArray = GroundDeployments.validate(world)
	if not errors.is_empty():return errors
	var has_ground: bool = false
	for id: String in world.unit_ids():
		if world.unit_definition(world.get_unit(id).definition_id).domain=="ground":has_ground=true
	if not has_ground:return []
	for module: SimulationModule in [GroundTasks.new(),GroundCommander.new()]:
		var receipt: Dictionary = world.register_module(module)
		if not receipt.accepted:return ["ground_register:"+str(receipt.reason)]
	return []
