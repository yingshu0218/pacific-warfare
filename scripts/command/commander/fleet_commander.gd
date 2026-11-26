class_name FleetCommander
extends SimulationModule

var config: FleetConfig
var planner: FleetPlanner
var air_planner: FleetPlanner
var next_decision_s: float = 0.0
var last_receipts: Array[Dictionary] = []

func _init(parameters: FleetConfig) -> void:
	module_id = "fleet_commander"
	priority = 200
	config = parameters
	planner = FleetPlanner.new(config)
	air_planner = FleetPlanner.new(config)

func reset(world_ref: RefCounted) -> void:
	planner.reset()
	air_planner.reset()
	next_decision_s = 0.0
	last_receipts.clear()
	var world: SimulationWorld = world_ref as SimulationWorld
	var postures: Dictionary = {}
	for faction: String in config.data.commanders:
		if world.commander_snapshot(faction).is_empty():
			continue
		postures[faction] = {}
		for post: String in BattleOrder.COMMAND_POSTS:
			var mode: String = _mode(faction, post)
			postures[faction][post] = {"posture": "balanced" if mode == "auto" else mode,
				"reason": "posture_initial" if mode == "auto" else "posture_fixed",
				"issuer_id": BattleOrder.post_issuer(faction, post), "changed_tick": world.tick}
	world.shared_state["command_postures"] = postures

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
		if view.is_empty():
			continue
		for post: String in BattleOrder.COMMAND_POSTS:
			var post_planner: FleetPlanner = planner if post == "fleet" else air_planner
			var orders: Array[BattleOrder] = post_planner.plan(view, post, _mode(faction, post))
			world.shared_state.command_postures[faction][post] = post_planner.memory[faction].posture.duplicate()
			for order: BattleOrder in orders:
				var receipt: Dictionary = world.submit_order(order)
				post_planner.remember(view, order, bool(receipt.accepted))
				last_receipts.append({"order_id": order.order_id, "accepted": receipt.accepted, "reason": receipt.reason, "time_s": world.time_s()})

func _mode(faction: String, post: String) -> String:
	return config.data.commanders[faction].get("postures", {}).get(post, "balanced")

func snapshot_state() -> Dictionary:
	return {"planner": planner.snapshot_state(), "air_planner": air_planner.snapshot_state(),
		"next_decision_s": next_decision_s, "last_receipts": last_receipts.duplicate(true)}
