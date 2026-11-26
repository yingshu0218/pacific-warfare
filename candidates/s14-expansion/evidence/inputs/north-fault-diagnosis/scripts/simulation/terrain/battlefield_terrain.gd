class_name BattlefieldTerrain
extends SimulationModule

var data: Dictionary = {}

func _init(compiled: Dictionary = {}) -> void:
	module_id = "battlefield_terrain"
	priority = 10
	data = compiled

static func install(world: SimulationWorld, path: String) -> PackedStringArray:
	if world.tick != 0 or world.shared_state.has("terrain"): return ["terrain_install_once_before_first_tick"]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return ["terrain_invalid_json:"+path]
	var record: Dictionary = parsed
	for key: String in ["id","sea_level_m","bounds_m","islands","pads","objects","deployment_sites","viewpoints"]:
		if not record.has(key): return ["terrain_missing:"+key]
	if not SimData.pure_data(record): return ["terrain_requires_pure_data"]
	for island: Dictionary in record.islands:
		var center: Vector3 = SimData.vec3(island.center_m)
		var winding: float = 0.0
		for i: int in island.outline_m.size():
			var a: Vector3 = SimData.vec3(island.outline_m[i])-center
			var b: Vector3 = SimData.vec3(island.outline_m[(i+1)%island.outline_m.size()])-center
			var cross_value: float = a.x*b.z-a.z*b.x
			if absf(cross_value) < .001: return ["terrain_radial_edge_degenerate:"+str(island.id)]
			if winding*cross_value < 0.0: return ["terrain_radial_center_outside_polygon_kernel:"+str(island.id)]
			winding = cross_value

	var receipt: Dictionary = world.register_module(BattlefieldTerrain.new(TerrainQueries.compile(record)))
	return [] if receipt.accepted else ["terrain_register:"+str(receipt.reason)]

func reset(world_ref: RefCounted) -> void:
	(world_ref as SimulationWorld).shared_state["terrain"] = data

func snapshot_state() -> Dictionary:
	return {"map_id":data.get("id",""),"triangle_count":data.get("triangles",[]).size(),"solid_count":data.get("solids",[]).size()}
