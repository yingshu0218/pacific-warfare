class_name BattleOrder
extends RefCounted

const TYPES: PackedStringArray = ["patrol", "escort", "intercept", "engage", "regroup", "retreat", "aircraft_training", "bombing"]
const TERMINAL: PackedStringArray = ["completed", "failed", "cancelled", "superseded"]
const TRANSITIONS: Dictionary = {
	"issued": ["received", "failed", "cancelled"],
	"received": ["executing", "completed", "failed", "cancelled", "superseded"],
	"executing": ["completed", "failed", "cancelled", "superseded"]
}
const COMMAND_POSTS: Array[String] = ["fleet", "air"]

static func post_issuer(faction: String, post: String) -> String:
	return "%s_%s_commander" % [faction, post]

static func issuer_post(issuer: String) -> String:
	for post: String in COMMAND_POSTS:
		if issuer.ends_with("_%s_commander" % post):
			return post
	return ""

static func may_replace(active: Dictionary, issuer: String) -> bool:
	if active.is_empty() or active.get("status", "") in TERMINAL:
		return true
	if active.source != "ai" or active.order_type in ["retreat", "aircraft_training", "bombing"]:
		return false
	if active.order_type == "patrol" and str(active.intent).begins_with("scenario_initial_"):
		return true
	if active.issuer_id == issuer:
		return true
	# Older fleet planners used one identity for ship and air orders.
	return active.issuer_id == str(active.faction_id) + "_commander" and str(active.order_id).begins_with("fleet_ai:")

static func unit_reserved(module_data: Dictionary, task: Dictionary) -> bool:
	var ops: Dictionary = module_data.get("carrier_ops", {})
	return (not ops.is_empty() and (bool(ops.get("on_deck", false)) or ops.get("phase", "") != "mission")) \
		or module_data.has("carrier_delegated_mission") \
		or module_data.get("command_assignment", {}).get("phase", "") == "active" \
		or task.get("aircraft", {}).get("phase", "") in ["withdraw", "training"] \
		or task.get("ship", {}).get("phase", "") == "withdraw"

var order_id: String = ""
var issuer_id: String = ""
var source: String = "ai"
var faction_id: String = ""
var recipient_ids: Array[String] = []
var order_type: String = "patrol"
var target_id: String = ""
## Optional {center_m: [x,y,z], radius_m: metres}; intention, never teleportation.
var area: Dictionary = {}
var waypoints_m: Array = []
var intent: String = ""
var training: Dictionary = {}
var bombing: Dictionary = {}
var status: String = "issued"
var issued_tick: int = -1
var received_tick: int = -1
var changed_tick: int = -1
var reason: String = ""
var progress: String = ""
var replacement_order_id: String = ""
var history: Array = []
## Current ownership and per-unit execution remain visible after partial reassignment.
var assigned_unit_ids: Array[String] = []
var execution: Dictionary = {}

static func from_data(data: Dictionary) -> BattleOrder:
	var result: BattleOrder = BattleOrder.new()
	result.order_id = data.get("order_id", "")
	result.issuer_id = data.get("issuer_id", "")
	result.source = data.get("source", "ai")
	result.faction_id = data.get("faction_id", "")
	result.recipient_ids.assign(data.get("recipient_ids", []))
	result.order_type = data.get("order_type", "patrol")
	result.target_id = data.get("target_id", "")
	result.area = data.get("area", {}).duplicate(true)
	result.waypoints_m = data.get("waypoints_m", []).duplicate(true)
	result.intent = data.get("intent", "")
	result.training = data.get("training", {}).duplicate(true)
	result.bombing = data.get("bombing", {}).duplicate(true)
	result.status = data.get("status", "issued")
	result.issued_tick = int(data.get("issued_tick", -1))
	result.received_tick = int(data.get("received_tick", -1))
	result.changed_tick = int(data.get("changed_tick", -1))
	result.reason = data.get("reason", "")
	result.progress = data.get("progress", "")
	result.replacement_order_id = data.get("replacement_order_id", "")
	result.history = data.get("history", []).duplicate(true)
	result.assigned_unit_ids.assign(data.get("assigned_unit_ids", []))
	result.execution = data.get("execution", {}).duplicate(true)
	return result

func request_data() -> Dictionary:
	return {"order_id": order_id, "issuer_id": issuer_id, "source": source, "faction_id": faction_id,
		"recipient_ids": recipient_ids.duplicate(), "order_type": order_type, "target_id": target_id,
		"area": area.duplicate(true), "waypoints_m": waypoints_m.duplicate(true), "intent": intent, "training": training.duplicate(true), "bombing": bombing.duplicate(true)}

func snapshot() -> Dictionary:
	var result: Dictionary = request_data()
	result.merge({"status": status, "issued_tick": issued_tick, "received_tick": received_tick,
		"changed_tick": changed_tick, "reason": reason, "progress": progress,
		"replacement_order_id": replacement_order_id, "history": history.duplicate(true),
		"assigned_unit_ids": assigned_unit_ids.duplicate(), "execution": execution.duplicate(true)})
	return result
