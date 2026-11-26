class_name BattleOrder
extends RefCounted

const TYPES: PackedStringArray = ["patrol", "escort", "intercept", "engage", "regroup", "retreat", "aircraft_training"]
const TERMINAL: PackedStringArray = ["completed", "failed", "cancelled", "superseded"]
const TRANSITIONS: Dictionary = {
	"issued": ["received", "failed", "cancelled"],
	"received": ["executing", "completed", "failed", "cancelled", "superseded"],
	"executing": ["completed", "failed", "cancelled", "superseded"]
}

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
		"area": area.duplicate(true), "waypoints_m": waypoints_m.duplicate(true), "intent": intent, "training": training.duplicate(true)}

func snapshot() -> Dictionary:
	var result: Dictionary = request_data()
	result.merge({"status": status, "issued_tick": issued_tick, "received_tick": received_tick,
		"changed_tick": changed_tick, "reason": reason, "progress": progress,
		"replacement_order_id": replacement_order_id, "history": history.duplicate(true),
		"assigned_unit_ids": assigned_unit_ids.duplicate(), "execution": execution.duplicate(true)})
	return result
