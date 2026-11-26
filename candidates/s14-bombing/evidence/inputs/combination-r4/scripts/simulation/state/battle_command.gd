class_name BattleCommand
extends RefCounted

const ISSUE_ORDER: String = "issue_order"
const CANCEL_ORDER: String = "cancel_order"
const SET_TARGET: String = "set_target"
const CEASE_FIRE: String = "cease_fire"

var command_id: String = ""
var issuer_id: String = ""
var source: String = "ai"
var faction_id: String = ""
var entity_id: String = ""
var kind: String = ISSUE_ORDER
## -1 means next fixed tick; no wall-clock timestamps.
var execute_tick: int = -1
var payload: Dictionary = {}

func snapshot() -> Dictionary:
	return {"command_id": command_id, "issuer_id": issuer_id, "source": source, "faction_id": faction_id,
		"entity_id": entity_id, "kind": kind, "execute_tick": execute_tick, "payload": payload.duplicate(true)}

static func from_data(data: Dictionary) -> BattleCommand:
	var result: BattleCommand = BattleCommand.new()
	result.command_id = data.command_id
	result.issuer_id = data.issuer_id
	result.source = data.source
	result.faction_id = data.faction_id
	result.entity_id = data.entity_id
	result.kind = data.kind
	result.execute_tick = int(data.execute_tick)
	result.payload = data.payload.duplicate(true)
	return result
