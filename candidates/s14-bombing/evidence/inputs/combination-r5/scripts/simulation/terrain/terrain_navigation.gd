class_name TerrainNavigation
extends RefCounted

## A bounded visibility graph from expanded coast polygons, not terrain cells.
static func chart(data: Dictionary, clearance_m: float) -> Dictionary:
	var shapes: Array[Dictionary] = []
	for island: Dictionary in data.get("islands", []):
		var polygon: PackedVector2Array = PackedVector2Array()
		for p: Vector3 in island.outline: polygon.append(Vector2(p.x,p.z))
		for expanded: PackedVector2Array in Geometry2D.offset_polygon(polygon,clearance_m,Geometry2D.JOIN_MITER):
			shapes.append(_shape(expanded))
	for solid: Dictionary in data.get("solids", []):
		if solid.surface != "ground": continue
		var c: Vector3 = solid.center; var h: Vector3 = solid.half+Vector3.ONE*clearance_m
		shapes.append(_shape(PackedVector2Array([Vector2(c.x-h.x,c.z-h.z),Vector2(c.x+h.x,c.z-h.z),Vector2(c.x+h.x,c.z+h.z),Vector2(c.x-h.x,c.z+h.z)])))
	var nodes: Array[Vector3] = []
	for shape: Dictionary in shapes:
		# Second small offset keeps visibility segments outside all closed boundaries.
		for outer: PackedVector2Array in Geometry2D.offset_polygon(shape.polygon,35.0,Geometry2D.JOIN_MITER):
			for p: Vector2 in outer:
				var node: Vector3 = Vector3(p.x,0,p.y)
				if not blocked(node,node,shapes): nodes.append(node)
	return {"shapes":shapes,"nodes":nodes,"edges":[],"clearance_m":clearance_m}

static func blocked(a: Vector3, b: Vector3, shapes: Array[Dictionary]) -> bool:
	var p: Vector2 = Vector2(a.x,a.z); var q: Vector2 = Vector2(b.x,b.z)
	var low: Vector2 = p.min(q); var high: Vector2 = p.max(q)
	for shape: Dictionary in shapes:
		var bounds: Rect2 = shape.bounds
		if high.x < bounds.position.x or low.x > bounds.end.x or high.y < bounds.position.y or low.y > bounds.end.y: continue
		var poly: PackedVector2Array = shape.polygon
		if Geometry2D.is_point_in_polygon(p,poly) or Geometry2D.is_point_in_polygon(q,poly): return true
		for i: int in poly.size():
			if Geometry2D.segment_intersects_segment(p,q,poly[i],poly[(i+1)%poly.size()]) != null: return true
	return false

static func route(start: Vector3, goal: Vector3, chart_data: Dictionary) -> Array[Vector3]:
	var shapes: Array[Dictionary] = chart_data.shapes
	if not blocked(start,goal,shapes): return [goal]
	if blocked(start,start,shapes) or blocked(goal,goal,shapes): return []
	var base: Array[Vector3] = chart_data.nodes
	if chart_data.edges.is_empty():
		var edges: Array[Array] = []
		for i: int in base.size(): edges.append([])
		for i: int in base.size():
			for j: int in range(i+1,base.size()):
				if not blocked(base[i],base[j],shapes):
					edges[i].append([j,base[i].distance_to(base[j])]); edges[j].append([i,base[i].distance_to(base[j])])
		chart_data.edges=edges
	var nodes: Array[Vector3] = [start,goal]
	nodes.append_array(base)
	var edges: Array[Array] = [[],[]]
	for i: int in base.size():
		var row: Array = []
		for link: Array in chart_data.edges[i]: row.append([int(link[0])+2,link[1]])
		edges.append(row)
	for special: int in [0,1]:
		for i: int in base.size():
			if not blocked(nodes[special],base[i],shapes):
				var distance: float = nodes[special].distance_to(base[i])
				edges[special].append([i+2,distance]); edges[i+2].append([special,distance])
	var costs: Array[float] = []; var previous: Array[int] = []; var visited: Array[bool] = []
	for i: int in nodes.size(): costs.append(INF); previous.append(-1); visited.append(false)
	costs[0]=0.0
	for iteration: int in nodes.size():
		var nearest: int = -1; var best: float = INF
		for i: int in nodes.size():
			if not visited[i] and costs[i]<best: nearest=i; best=costs[i]
		if nearest<0: return []
		if nearest==1: break
		visited[nearest]=true
		for link: Array in edges[nearest]:
			var i: int = int(link[0]); var distance: float = best+float(link[1])
			if not visited[i] and distance < costs[i]: costs[i]=distance; previous[i]=nearest
	if previous[1]<0: return []
	var path: Array[Vector3] = []; var cursor: int = 1
	while cursor>0:
		path.push_front(Vector3(nodes[cursor].x,start.y,nodes[cursor].z)); cursor=previous[cursor]
	return path

static func _shape(poly: PackedVector2Array) -> Dictionary:
	var bounds: Rect2 = Rect2(poly[0],Vector2.ZERO)
	for p: Vector2 in poly: bounds=bounds.expand(p)
	return {"polygon":poly,"bounds":bounds}
