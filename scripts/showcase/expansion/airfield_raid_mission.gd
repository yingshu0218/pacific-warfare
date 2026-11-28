extends ShowcaseMissions
## Initial orders only; the normal air/BombingCommander/GroundTasks modules execute.
## The opposing flight gets a patrol area and can only intercept its own contacts.
func reset(world_ref: RefCounted) -> void:
	serial = 0
	receipts.clear()
	history.clear()
	next_observer_s = 0
	var world: SimulationWorld = world_ref as SimulationWorld
	var escorts: Array[String] = world.recipient_unit_ids("us_air")
	escort_order_id = _order(world,"us",["us_air"],"escort","us_b25_1",[],[4000,1800,-4600],2500)
	if not escort_order_id.is_empty():
		_assign_manager(world,escorts,"escort_initial_goal","active")
	var field: UnitState = world.get_unit("jp_airfield_aa")
	if field != null:
		# Hold a local watch, rather than pinning this game unit to the first
		# distant contact. GroundTasks still acquires and tracks live contacts.
		_order(world,"jp",["jp_airfield_aa"],"patrol","",[],SimData.array3(field.position_m),2743.2)
