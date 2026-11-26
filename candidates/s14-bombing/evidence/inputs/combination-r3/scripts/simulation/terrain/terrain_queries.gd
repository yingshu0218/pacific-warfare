class_name TerrainQueries
extends RefCounted

## Read-only pure-data queries. The empty chart is an infinite, flat sea.
const CELL_M: float = 320.0

static func height_m(world: SimulationWorld, point: Vector3, include_buildings: bool = false) -> float:
	return height_data(world.shared_state.get("terrain", {}), point, include_buildings)

static func is_land(world: SimulationWorld, point: Vector3) -> bool:
	return land_data(world.shared_state.get("terrain", {}), point)

static func segment_hit(world: SimulationWorld, a: Vector3, b: Vector3, include_sea: bool = true) -> Dictionary:
	return hit_data(world.shared_state.get("terrain", {}), a, b, include_sea)

static func land_data(data: Dictionary, p: Vector3) -> bool:
	for island: Dictionary in data.get("islands", []):
		if _inside_bounds(p, island.bounds) and _inside_polygon(p, island.outline): return true
	return false

static func height_data(data: Dictionary, p: Vector3, buildings: bool = false) -> float:
	var height: float = float(data.get("sea_level_m", 0.0))
	for index: int in data.get("grid", {}).get(_key(p), []):
		var tri: Dictionary = data.triangles[index]
		if _inside_triangle(p, tri):
			height = maxf(height, _plane_height(p, tri))
	if buildings:
		for index: int in data.get("solid_grid", {}).get(_key(p), []):
			var solid: Dictionary = data.solids[index]
			if absf(p.x - solid.center.x) <= solid.half.x and absf(p.z - solid.center.z) <= solid.half.z:
				height = maxf(height, solid.center.y + solid.half.y)
	return height

static func hit_data(data: Dictionary, a: Vector3, b: Vector3, include_sea: bool = true) -> Dictionary:
	var best: Dictionary = {}
	var fraction: float = INF
	var delta: Vector3 = b - a
	var candidates: Dictionary = {}
	var solids: Dictionary = {}
	var below_terrain_ceiling: bool = minf(a.y, b.y) <= float(data.get("max_height_m", 0.0))
	if below_terrain_ceiling:
		for key: String in _segment_cells(a, b):
			for i: int in data.get("grid", {}).get(key, []): candidates[i] = true
			for i: int in data.get("solid_grid", {}).get(key, []): solids[i] = true
		for index: int in solids:
			var solid: Dictionary = data.solids[index]
			var t: float = CombatGeometry.segment_box(a, b, solid.center, solid.half)
			if t < fraction:
				fraction = t
				best = {"fraction":t,"position_m":a.lerp(b,t),"normal":CombatGeometry.normal_for_box(a.lerp(b,t), {"center_m":SimData.array3(solid.center),"half_extents_m":SimData.array3(solid.half)}),"surface":solid.surface,"target_id":solid.id}
		for index: int in candidates:
			var tri: Dictionary = data.triangles[index]
			if minf(a.y, b.y) > float(tri.max_y) + 0.001: continue
			var t: float = INF
			if _inside_triangle(a, tri) and a.y <= _plane_height(a,tri) + 0.001:
				t = 0.0
			else:
				var denom: float = delta.dot(tri.normal)
				if absf(denom) < 0.0000001: continue
				t = ((tri.a as Vector3) - a).dot(tri.normal) / denom
				if t < -0.000001 or t > 1.000001 or not _inside_triangle(a.lerp(b,t),tri): continue
				t = clampf(t,0.0,1.0)
			if t < fraction:
				fraction = t
				best = {"fraction":t,"position_m":a.lerp(b,t),"normal":tri.normal,"surface":"ground","target_id":tri.island_id}
	if include_sea:
		var sea: float = float(data.get("sea_level_m", 0.0))
		var t: float = INF
		if a.y <= sea and not land_data(data,a): t = 0.0
		elif a.y >= sea and b.y <= sea and a.y > b.y: t = (a.y-sea)/(a.y-b.y)
		if t < fraction and not land_data(data,a.lerp(b,t)):
			best = {"fraction":t,"position_m":a.lerp(b,t),"normal":Vector3.UP,"surface":"sea","target_id":""}
	return best

static func compile(source: Dictionary) -> Dictionary:
	var result: Dictionary = {"id":source.id,"sea_level_m":source.sea_level_m,"bounds_m":source.bounds_m.duplicate(),"islands":[],"triangles":[],"grid":{},"solids":[],"solid_grid":{},"max_height_m":0.0,"source":source.duplicate(true)}
	for spec: Dictionary in source.islands:
		var vertices: Array[Vector3] = []
		var outline: Array[Vector3] = []
		var center: Vector3 = SimData.vec3(spec.center_m)
		for v: Array in spec.outline_m: outline.append(SimData.vec3(v))
		var count: int = outline.size()
		var rings: int = int(spec.rings)
		vertices.append(Vector3(center.x,_height_source(center,0.0,spec,source.pads),center.z))
		for ring: int in range(1,rings+1):
			var ratio: float = float(ring)/rings
			for i: int in count:
				var p: Vector3 = center.lerp(outline[i],ratio)
				p.y = _height_source(p,ratio,spec,source.pads) if ring < rings else 0.0
				vertices.append(p)
		var indices: Array[int] = []
		for i: int in count: indices.append_array([0,1+i,1+(i+1)%count])
		for ring: int in range(1,rings):
			var inner: int = 1+(ring-1)*count
			var outer: int = 1+ring*count
			for i: int in count:
				var j: int = (i+1)%count
				indices.append_array([inner+i,outer+i,outer+j,inner+i,outer+j,inner+j])
		for k: int in range(0,indices.size(),3):
			var a: Vector3 = vertices[indices[k]]
			var b: Vector3 = vertices[indices[k+1]]
			var c: Vector3 = vertices[indices[k+2]]
			var normal: Vector3 = (b-a).cross(c-a).normalized()
			if normal.y < 0.0:
				var swap: int = indices[k+1]; indices[k+1]=indices[k+2]; indices[k+2]=swap
				var v: Vector3 = b; b=c; c=v; normal = -normal
			var denominator: float = (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
			if absf(denominator) < 0.0001: continue
			var tri: Dictionary = {"a":a,"b":b,"c":c,"normal":normal,"denom":denominator,"max_y":maxf(a.y,maxf(b.y,c.y)),"island_id":spec.id}
			var idx: int = result.triangles.size()
			result.triangles.append(tri)
			_index_bounds(result.grid,a.min(b).min(c),a.max(b).max(c),idx)
			result.max_height_m = maxf(result.max_height_m,tri.max_y)
		var low: Vector3 = outline[0]; var high: Vector3 = outline[0]
		for v: Vector3 in outline: low=low.min(v); high=high.max(v)
		result.islands.append({"id":spec.id,"label":spec.label,"outline":outline,"vertices":vertices,"indices":indices,"bounds":[low,high]})
	for obj: Dictionary in result.source.objects:
		if obj.kind == "crane": continue # Slender decorative gantry; not a hidden building-sized collider.
		var p: Vector3 = SimData.vec3(obj.position_m)
		if obj.kind in ["house","warehouse"]:
			var footprint: Vector3=SimData.vec3(obj.size_m)*.5
			var low: float=height_data(result,p)
			var high: float=low
			for dx: float in [-1.0,1.0]:
				for dz: float in [-1.0,1.0]:
					var h: float=height_data(result,p+Vector3(dx*footprint.x,0,dz*footprint.z))
					low=minf(low,h);high=maxf(high,h)
			p.y=high
			obj.position_m[1]=high
			obj["foundation_bottom_m"]=low-.6
		var size: Vector3 = SimData.vec3(obj.size_m)
		var extra_roof: float = 3.0 if obj.kind in ["house","warehouse"] else 0.0
		var center: Vector3 = p+Vector3.UP*(size.y+extra_roof)*0.5
		var half: Vector3 = Vector3(size.x,size.y+extra_roof,size.z)*0.5
		if obj.has("foundation_bottom_m"):
			var bottom: float=float(obj.foundation_bottom_m)
			var top: float=center.y+half.y
			center.y=(top+bottom)*.5;half.y=(top-bottom)*.5
		result.solids.append({"id":obj.id,"surface":"ground" if obj.kind == "quay" else "building","center":center,"half":half})
		_index_bounds(result.solid_grid,center-half,center+half,result.solids.size()-1)
		result.max_height_m = maxf(result.max_height_m,center.y+half.y)
	return result

static func _height_source(p: Vector3, ratio: float, spec: Dictionary, pads: Array) -> float:
	var height: float = 9.0
	for peak: Dictionary in spec.peaks:
		var center: Vector3 = SimData.vec3(peak.position_m)
		var distance: float = Vector2(p.x-center.x,p.z-center.z).length()/float(peak.radius_m)
		height = maxf(height,float(peak.height_m)*exp(-distance*distance*1.8))
	# A narrow beach/rock shelf gives way to the mountain; no square plateau mountain.
	height *= smoothstep(0.0,0.085,1.0-ratio)
	for pad: Dictionary in pads:
		var center: Vector3 = SimData.vec3(pad.position_m)
		var distance: float = Vector2(p.x-center.x,p.z-center.z).length()
		if distance < float(pad.radius_m)+float(pad.blend_m):
			height = lerpf(center.y,height,smoothstep(float(pad.radius_m),float(pad.radius_m)+float(pad.blend_m),distance))
	return height

static func _inside_triangle(p: Vector3, tri: Dictionary) -> bool:
	var a: Vector3 = tri.a; var b: Vector3 = tri.b; var c: Vector3 = tri.c
	var u: float = ((b.z-c.z)*(p.x-c.x)+(c.x-b.x)*(p.z-c.z))/float(tri.denom)
	var v: float = ((c.z-a.z)*(p.x-c.x)+(a.x-c.x)*(p.z-c.z))/float(tri.denom)
	return u >= -0.00001 and v >= -0.00001 and u+v <= 1.00001

static func _plane_height(p: Vector3, tri: Dictionary) -> float:
	var n: Vector3 = tri.normal
	var a: Vector3 = tri.a
	return a.y - (n.x*(p.x-a.x)+n.z*(p.z-a.z))/n.y

static func _inside_polygon(p: Vector3, points: Array) -> bool:
	var inside: bool = false
	var j: int = points.size()-1
	for i: int in points.size():
		var a: Vector3 = points[i]; var b: Vector3 = points[j]
		if (a.z > p.z) != (b.z > p.z) and p.x < (b.x-a.x)*(p.z-a.z)/(b.z-a.z)+a.x: inside = not inside
		j=i
	return inside

static func _inside_bounds(p: Vector3, bounds: Array) -> bool:
	return p.x >= bounds[0].x and p.x <= bounds[1].x and p.z >= bounds[0].z and p.z <= bounds[1].z

static func _key(p: Vector3) -> String:
	return str(floori(p.x/CELL_M))+":"+str(floori(p.z/CELL_M))

static func _index_bounds(grid: Dictionary, low: Vector3, high: Vector3, index: int) -> void:
	for x: int in range(floori(low.x/CELL_M),floori(high.x/CELL_M)+1):
		for z: int in range(floori(low.z/CELL_M),floori(high.z/CELL_M)+1):
			var key: String = str(x)+":"+str(z)
			if not grid.has(key): grid[key]=[]
			grid[key].append(index)

static func _segment_cells(a: Vector3, b: Vector3) -> Array[String]:
	var result: Array[String] = []
	var x: int = floori(a.x/CELL_M); var z: int = floori(a.z/CELL_M)
	var ex: int = floori(b.x/CELL_M); var ez: int = floori(b.z/CELL_M)
	var dx: float = b.x-a.x; var dz: float = b.z-a.z
	var sx: int = 1 if dx>=0 else -1; var sz: int = 1 if dz>=0 else -1
	var tx: float = ((x+(1 if sx>0 else 0))*CELL_M-a.x)/dx if absf(dx)>0.000001 else INF
	var tz: float = ((z+(1 if sz>0 else 0))*CELL_M-a.z)/dz if absf(dz)>0.000001 else INF
	var stepx: float = CELL_M/absf(dx) if absf(dx)>0.000001 else INF
	var stepz: float = CELL_M/absf(dz) if absf(dz)>0.000001 else INF
	for iteration: int in range(absi(ex-x)+absi(ez-z)+3):
		result.append(str(x)+":"+str(z))
		if x==ex and z==ez: break
		if tx<tz: x+=sx; tx+=stepx
		else: z+=sz; tz+=stepz
	return result
