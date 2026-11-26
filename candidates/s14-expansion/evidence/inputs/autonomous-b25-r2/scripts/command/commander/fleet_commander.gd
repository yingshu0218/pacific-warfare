class_name FleetCommander
extends SimulationModule

var config: FleetConfig
var planner: FleetPlanner
var next_decision_s: float = 0.0
var last_receipts: Array[Dictionary] = []

func _init(parameters: FleetConfig) -> void:
	module_id = "fleet_commander"
	priority = 200
	config = parameters
	planner = FleetPlanner.new(config)

func reset(_world: RefCounted) -> void:
	planner.reset()
	next_decision_s = 0.0
	last_receipts.clear()

func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	if world.time_s() + 0.000001 < next_decision_s:
		return
	next_decision_s = world.time_s() + float(config.data.policy.decision_period_s)
	last_receipts.clear()
	var factions: Array = config.data.commanders.keys()
	factions.sort()
	for faction: String in factions:
		var view: Dictionary = world.commander_snapshot(faction)
		for order: BattleOrder in planner.plan(view):
			var receipt: Dictionary = world.submit_order(order)
			planner.remember(view, order, bool(receipt.accepted))
			last_receipts.append({"order_id": order.order_id, "accepted": receipt.accepted, "reason": receipt.reason, "time_s": world.time_s()})

func snapshot_state() -> Dictionary:
	return {"planner": planner.snapshot_state(), "next_decision_s": next_decision_s, "last_receipts": last_receipts.duplicate(true)}
