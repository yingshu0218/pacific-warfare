extends SceneTree

const PROPS: Script = preload("res://scripts/map02/harbor_support_props.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: FirstPlayableGame = (load("res://showcase/carrier_harbor.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_process(false)
	if not game.running or game.map_view == null:
		quit(2)
		return
	var view: Node3D = game.map_view.get_node_or_null("HarborSupportProps")
	if view == null:
		push_error("Props are missing from the actual harbor scene")
		quit(2)
		return
	var terrain: Dictionary = game.map_view.terrain
	var seen: Dictionary = {}
	var triangles: int = 0
	for item: Dictionary in PROPS.LAYOUT:
		var prop: MeshInstance3D = view.get_node_or_null(item.id) as MeshInstance3D
		if prop == null or prop.mesh == null or prop.get_child_count() != 0:
			_fail(item.id,"expected one static visual mesh")
			continue
		if prop.mesh.get_surface_count() != 1: _fail(item.id,"unbatched mesh")
		if seen.has(item.kind) and seen[item.kind] != prop.mesh: _fail(item.id,"shared mesh missing")
		seen[item.kind] = prop.mesh
		triangles += int(prop.mesh.surface_get_array_index_len(0) / 3)
		var local_box: AABB = prop.mesh.get_aabb()
		var center: Vector3 = prop.position
		var min_h: float = INF
		var max_h: float = -INF
		for i: int in range(9):
			var offset: Vector3 = local_box.get_endpoint(i) if i < 8 else Vector3.ZERO
			offset.y = 0.0
			var point: Vector3 = center + prop.basis * offset
			var land: bool = TerrainQueries.land_data(terrain,point)
			if land == bool(item.water):
				_fail(item.id,"footprint on wrong side of shoreline at "+str(point))
			var floor: float = TerrainQueries.height_data(terrain,point,false)
			var solid: float = TerrainQueries.height_data(terrain,point,true)
			if solid > maxf(center.y,floor)+.08:
				_fail(item.id,"overlaps existing solid at "+str(point))
			min_h = minf(min_h,floor)
			max_h = maxf(max_h,floor)
		if item.water:
			if not (local_box.position.y<0 and local_box.end.y>0):
				_fail(item.id,"no waterline crossing")
		elif max_h-min_h > .10 or absf(center.y-max_h) > .03:
			_fail(item.id,"ground contact or slope")
	if triangles < 100 or triangles > 16000: _fail("inventory","visual mesh budget exceeded")
	if seen.size() != 8 or view.get_child_count() != PROPS.LAYOUT.size():
		_fail("inventory","incorrect prop count")
	print("PORT03 props=",view.get_child_count()," unique=",seen.size()," scene meshes=",game.map_view.statistics.mesh_instances,
		" prop triangles=",triangles," terrain solids=",terrain.solids.size()," terrain sites=",terrain.source.deployment_sites.size()," failures=",failures)
	game.free()
	var inspector: Node = (load("res://scenes/map02/expanded_map.tscn") as PackedScene).instantiate()
	root.add_child(inspector)
	inspector.set_process(false)
	for p: Dictionary in PROPS.INSPECTION_POINTS:
		var at: int = inspector.points.find(p)
		if at < 0:
			_fail(p.id,"missing from map inspection menu")
		else:
			inspector.select_point(at)
			if inspector.selector.selected != at or not inspector.camera.global_position.is_finite():
				_fail(p.id,"viewpoint could not be selected")
	print("PORT03 inspection views=",PROPS.INSPECTION_POINTS.size()," failures=",failures)
	inspector.free()
	quit(1 if failures else 0)

func _fail(prop: String, msg: String) -> void:
	failures += 1
	push_error(prop + ": " + msg)
