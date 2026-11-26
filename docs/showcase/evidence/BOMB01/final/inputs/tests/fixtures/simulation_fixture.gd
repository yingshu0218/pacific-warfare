extends RefCounted

static func catalog() -> DefinitionCatalog:
	var result: DefinitionCatalog = DefinitionCatalog.new()
	var errors: PackedStringArray = result.load_files(
		["res://data/units/jp_yamato_1944_04.json", "res://data/units/us_f6f5_1944.json"],
		["res://data/ammunition/jp_460mm_ap.json", "res://data/ammunition/jp_155mm_shell.json", "res://data/ammunition/us_127mm_m2_ball.json", "res://data/ammunition/jp_127mm_type89_shell.json", "res://data/ammunition/jp_25mm_type96_shell.json", "res://data/ammunition/jp_13mm_type93_ball.json"],
		["res://data/units/weapons/us_an_m2_127mm_single.json"])
	assert(errors.is_empty(), str(errors))
	return result

static func scenario() -> Dictionary:
	return {"id": "test_world", "seed": 314159, "tick_hz": 60, "factions": ["jp", "us"],
		"spawns": [
			{"id": "yamato_01", "unit_definition_id": "jp_yamato_1944_04", "faction_id": "jp", "position_m": [0.0, 0.0, 0.0], "velocity_mps": [0.0, 0.0, -12.0]},
			{"id": "f6f_01", "unit_definition_id": "us_f6f5_1944", "faction_id": "us", "position_m": [1000.0, 1000.0, 500.0], "velocity_mps": [0.0, 0.0, -120.0], "module_data": {"formation": {"role": "leader"}}},
			{"id": "f6f_02", "unit_definition_id": "us_f6f5_1944", "faction_id": "us", "position_m": [1050.0, 1000.0, 550.0], "velocity_mps": [0.0, 0.0, -120.0], "module_data": {"formation": {"role": "wingman"}}}
		], "groups": [{"id": "us_pair", "faction_id": "us", "member_ids": ["f6f_01", "f6f_02"]}]}

static func command(id: String, kind: String, payload: Dictionary, entity_id: String = "f6f_01") -> BattleCommand:
	var result: BattleCommand = BattleCommand.new()
	result.command_id = id
	result.issuer_id = "us_commander"
	result.source = "ai"
	result.faction_id = "us"
	result.entity_id = entity_id
	result.kind = kind
	result.payload = payload.duplicate(true)
	return result

static func order(id: String, source: String = "ai") -> BattleOrder:
	var result: BattleOrder = BattleOrder.new()
	result.order_id = id
	result.issuer_id = "us_commander"
	result.source = source
	result.faction_id = "us"
	result.recipient_ids = ["us_pair"]
	result.order_type = "patrol"
	result.area = {"center_m": [1000.0, 1000.0, 0.0], "radius_m": 2000.0}
	result.intent = "test-only controlled task; no gameplay completion claim"
	return result
