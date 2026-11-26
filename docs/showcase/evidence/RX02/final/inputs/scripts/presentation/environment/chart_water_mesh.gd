extends RefCounted

## Sea geometry excludes the exact chart coast polygons. It remains at y=0;
## neither terrain height nor the simulation's water/collision queries change.
var _coasts: Array[PackedVector2Array] = []
var _surface: SurfaceTool
var _triangles: int = 0
var _cells: int = 0

func build(terrain: Dictionary) -> ArrayMesh:
	_coasts.clear();_triangles=0;_cells=0
	for island: Dictionary in terrain.islands:
		var polygon: PackedVector2Array = PackedVector2Array()
		for point: Vector3 in island.outline: polygon.append(Vector2(point.x,point.z))
		_coasts.append(polygon)
	_surface=SurfaceTool.new();_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cell(Rect2(-400000,-400000,800000,800000),0)
	var mesh: ArrayMesh = _surface.commit()
	mesh.set_meta("chart_water_triangles",_triangles)
	mesh.set_meta("chart_water_cells",_cells)
	mesh.set_meta("chart_id",str(terrain.source.id))
	return mesh

func _cell(rect: Rect2, depth: int) -> void:
	var p: Vector2 = rect.position
	var s: Vector2 = rect.size
	var polygons: Array[PackedVector2Array] = [PackedVector2Array([p,p+Vector2(s.x,0),p+s,p+Vector2(0,s.y)])]
	for coast: PackedVector2Array in _coasts:
		var next: Array[PackedVector2Array] = []
		for polygon: PackedVector2Array in polygons:
			next.append_array(Geometry2D.clip_polygons(polygon,coast))
		polygons=next
		if polygons.is_empty(): return
		if _has_holes(polygons):
			# A whole island inside a cell creates a hole, which the simple polygon
			# triangulator cannot consume. Split only such cells, never rasterize or
			# approximate the coast. All emitted boundaries are real polygon clips.
			if depth>=20:push_error("chart_water_unresolved_hole");return
			var half: Vector2 = s*.5
			for offset: Vector2 in [Vector2.ZERO,Vector2(half.x,0),half,Vector2(0,half.y)]:
				_cell(Rect2(p+offset,half),depth+1)
			return
	_cells+=1
	for polygon: PackedVector2Array in polygons:
		var indices: PackedInt32Array=Geometry2D.triangulate_polygon(polygon)
		if indices.is_empty() and absf(_area(polygon))>.01:
			push_error("chart_water_triangulation_failed");continue
		for at: int in range(0,indices.size(),3):
			var a: Vector2=polygon[indices[at]]
			var b: Vector2=polygon[indices[at+1]]
			var c: Vector2=polygon[indices[at+2]]
			var edge: float=maxf(a.distance_to(b),maxf(b.distance_to(c),c.distance_to(a)))
			# Float32 clipping can turn three collinear coast/grid points into a
			# sub-millimetre sliver. It has no area at chart precision; don't rasterize it.
			if edge<.001 or absf(_area(PackedVector2Array([a,b,c])))*2.0/edge<.002: continue
			for point: Vector2 in [a,b,c]:
				_surface.set_normal(Vector3.UP)
				_surface.add_vertex(Vector3(point.x,0,point.y))
			_triangles+=1

static func _has_holes(polygons: Array[PackedVector2Array]) -> bool:
	var largest: float = 0
	var outer_clockwise: bool = false
	for polygon: PackedVector2Array in polygons:
		var area: float=absf(_area(polygon))
		if area>largest:largest=area;outer_clockwise=Geometry2D.is_polygon_clockwise(polygon)
	for polygon: PackedVector2Array in polygons:
		if Geometry2D.is_polygon_clockwise(polygon)!=outer_clockwise: return true
	return false

static func _area(polygon: PackedVector2Array) -> float:
	var area: float=0
	for i: int in polygon.size():
		var a: Vector2=polygon[i];var b: Vector2=polygon[(i+1)%polygon.size()]
		area+=float(a.x)*float(b.y)-float(b.x)*float(a.y)
	return area*.5
