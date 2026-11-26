extends RefCounted
## MAP02 adapter only: all world geometry queries stay in the existing S09 implementation.
const MAP_PATH: String="res://data/maps/island_harbor_expanded.json"
const REGIONS_PATH: String="res://data/map02/regions.json"

static func load_source() -> Dictionary:
	var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	return source if source is Dictionary else {}

static func compile() -> Dictionary:
	var source: Dictionary=load_source()
	return TerrainQueries.compile(source) if not source.is_empty() else {}

static func regions() -> Dictionary:
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(REGIONS_PATH))
	return value if value is Dictionary else {}

static func load_for_world(world: SimulationWorld) -> PackedStringArray:
	# Future integration can use the exact same shared module, with no Session patch.
	return BattlefieldTerrain.install(world,MAP_PATH)
