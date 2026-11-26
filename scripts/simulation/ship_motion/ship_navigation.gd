class_name ShipNavigation
extends RefCounted

## Static sea-chart geometry. Expanded visibility graph, no position correction.
static func boxes(solids: Array, margin: float) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for solid: Dictionary in solids:
		var c: Vector3 = SimData.vec3(solid.center_m)
		var h: Vector3 = SimData.vec3(solid.half_extents_m)
		result.append(Rect2(Vector2(c.x - h.x - margin, c.z - h.z - margin), Vector2(2.0 * (h.x + margin), 2.0 * (h.z + margin))))
	return result

static func blocked(a: Vector3, b: Vector3, obstacles: Array[Rect2]) -> bool:
	for box: Rect2 in obstacles:
		var enter: float = 0.0
		var leave: float = 1.0
		var p: Vector2 = Vector2(a.x, a.z)
		var d: Vector2 = Vector2(b.x - a.x, b.z - a.z)
		var hit: bool = true
		for axis: int in range(2):
			if absf(d[axis]) < 0.00001:
				if p[axis] < box.position[axis] or p[axis] > box.end[axis]:
					hit = false
					break
			else:
				var lo: float = (box.position[axis] - p[axis]) / d[axis]
				var hi: float = (box.end[axis] - p[axis]) / d[axis]
				enter = maxf(enter, minf(lo, hi))
				leave = minf(leave, maxf(lo, hi))
				if enter > leave:
					hit = false
					break
		if hit:
			return true
	return false

static func route(start: Vector3, goal: Vector3, obstacles: Array[Rect2]) -> Array[Vector3]:
	if not blocked(start, goal, obstacles):
		return [goal]
	var nodes: Array[Vector3] = [start, goal]
	for box: Rect2 in obstacles:
		var outer: Rect2 = box.grow(30.0)
		for corner: Vector2 in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
			nodes.append(Vector3(corner.x, start.y, corner.y))
	var costs: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for i: int in nodes.size():
		costs.append(INF)
		previous.append(-1)
		visited.append(false)
	costs[0] = 0.0
	for iteration: int in nodes.size():
		var nearest: int = -1
		var best: float = INF
		for i: int in nodes.size():
			if not visited[i] and costs[i] < best:
				nearest = i
				best = costs[i]
		if nearest < 0:
			return []
		if nearest == 1:
			break
		visited[nearest] = true
		for i: int in nodes.size():
			if visited[i] or i == nearest or blocked(nodes[nearest], nodes[i], obstacles):
				continue
			var distance: float = best + nodes[nearest].distance_to(nodes[i])
			if distance < costs[i]:
				costs[i] = distance
				previous[i] = nearest
	if previous[1] < 0:
		return []
	var path: Array[Vector3] = []
	var cursor: int = 1
	while cursor > 0:
		path.push_front(nodes[cursor])
		cursor = previous[cursor]
	return path
