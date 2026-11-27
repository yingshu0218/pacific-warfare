extends RefCounted
## One watertight top arrangement per port/elevation. Internal walls and
## coplanar top overlaps are removed; the shared simulation chart is untouched.
const MAX_RECTANGLES: int = 16
const COPLANAR_MARGIN_M: float = .20
const TERRA_SHADER: Shader = preload("res://scripts/map02/quay_terrain_cut.gdshader")
const QUAY_SHADER: Shader = preload("res://scripts/map02/quay_finish.gdshader")
var _chart: Dictionary
var _st: SurfaceTool
var _buckets: Dictionary = {}
var _cuts: Array[Dictionary] = []
var _triangle_count: int = 0
var _detail_count: int = 0
var _covered_area_m2: float = 0.0
var _used: Array[Vector3] = []
var _regions: Dictionary = {}

static func handled(object: Dictionary) -> bool:
	return object.get("kind","") == "quay" and object.get("map02_region_id","") in ["civil_port","naval_base"]

func build(chart: Dictionary, land: MeshInstance3D) -> MeshInstance3D:
	_chart = chart
	for object: Dictionary in chart.source.objects:
		if not handled(object): continue
		var p: Vector3 = SimData.vec3(object.position_m)
		var s: Vector3 = SimData.vec3(object.size_m)
		var rect: Rect2 = Rect2(Vector2(p.x-s.x*.5,p.z-s.z*.5),Vector2(s.x,s.z))
		var top: float = p.y+s.y
		var key: String = str(object.map02_region_id)+":"+str(top)
		var civil: bool = object.map02_region_id == "civil_port"
		if not _buckets.has(key):
			_buckets[key] = {"rects":[],"top":top,"bottom":p.y,"civil":civil}
		var group: Dictionary = _buckets[key]
		group.rects.append(rect)
		group.bottom = minf(float(group.bottom),p.y)
		_cuts.append({"rect":rect,"top":top})
		var region: String = str(object.map02_region_id)
		_regions[region] = rect if not _regions.has(region) else (_regions[region] as Rect2).merge(rect)
	if _cuts.is_empty(): return null
	assert(_cuts.size() <= MAX_RECTANGLES)
	var footprint: PackedVector4Array = PackedVector4Array()
	var deck_limit: PackedFloat32Array = PackedFloat32Array()
	for item: Dictionary in _cuts:
		var rect: Rect2 = item.rect
		footprint.append(Vector4(rect.position.x,rect.position.y,rect.end.x,rect.end.y))
		deck_limit.append(float(item.top)+COPLANAR_MARGIN_M)
	footprint.resize(MAX_RECTANGLES)
	deck_limit.resize(MAX_RECTANGLES)
	var trim: ShaderMaterial = ShaderMaterial.new()
	trim.shader = TERRA_SHADER
	trim.set_shader_parameter("footprint",footprint)
	trim.set_shader_parameter("deck_limit",deck_limit)
	trim.set_shader_parameter("deck_count",_cuts.size())
	var highest: float = -INF
	for item: Dictionary in _cuts: highest = maxf(highest,float(item.top)+COPLANAR_MARGIN_M)
	trim.set_shader_parameter("highest_cut",highest)
	var regional: PackedVector4Array = PackedVector4Array()
	for region: Rect2 in _regions.values():
		regional.append(Vector4(region.position.x,region.position.y,region.end.x,region.end.y))
	regional.resize(2)
	trim.set_shader_parameter("regional",regional)
	land.material_override = trim
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for group: Dictionary in _buckets.values():
		_union(group)
	_st.index()
	_st.generate_normals()
	var finish: ShaderMaterial = ShaderMaterial.new()
	finish.shader = QUAY_SHADER
	_st.set_material(finish)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "RefinedQuays"
	node.mesh = _st.commit()
	node.set_meta("port_mesh_stats",{"footprints":_cuts.size(),"groups":_buckets.size(),
		"details":_detail_count,"triangles":_triangle_count,"covered_area_m2":_covered_area_m2})
	return node

func _union(group: Dictionary) -> void:
	var xs: Array[float] = []
	var zs: Array[float] = []
	for r: Rect2 in group.rects:
		if not xs.has(r.position.x): xs.append(r.position.x)
		if not xs.has(r.end.x): xs.append(r.end.x)
		if not zs.has(r.position.y): zs.append(r.position.y)
		if not zs.has(r.end.y): zs.append(r.end.y)
	xs.sort()
	zs.sort()
	var cells: Dictionary = {}
	for i: int in range(xs.size()-1):
		for j: int in range(zs.size()-1):
			var middle: Vector2 = Vector2((xs[i]+xs[i+1])*.5,(zs[j]+zs[j+1])*.5)
			for r: Rect2 in group.rects:
				if r.has_point(middle):
					cells[Vector2i(i,j)] = true
					break
	var y: float = group.top
	var civil: bool = group.civil
	var deck: Color = Color("a29c85") if civil else Color("949e9d")
	var cap: Color = Color("b4ab91") if civil else Color("a4adab")
	var wall: Color = Color("89836f") if civil else Color("7c8989")
	var wet: Color = Color("666958") if civil else Color("536468")
	for cell: Vector2i in cells:
		var i: int = cell.x
		var j: int = cell.y
		var a: Vector3 = Vector3(xs[i],y,zs[j])
		var b: Vector3 = Vector3(xs[i+1],y,zs[j])
		var c: Vector3 = Vector3(xs[i+1],y,zs[j+1])
		var d: Vector3 = Vector3(xs[i],y,zs[j+1])
		_covered_area_m2 += (xs[i+1]-xs[i])*(zs[j+1]-zs[j])
		_quad(a,b,c,d,deck,Vector3.UP,true)
		for edge: Array in [[a,b,Vector3.FORWARD,Vector2i(0,-1)],[b,c,Vector3.RIGHT,Vector2i(1,0)],[c,d,Vector3.BACK,Vector2i(0,1)],[d,a,Vector3.LEFT,Vector2i(-1,0)]]:
			if cells.has(cell+(edge[3] as Vector2i)): continue
			var a0: Vector3 = edge[0]
			var b0: Vector3 = edge[1]
			var n: Vector3 = edge[2]
			_wall(a0,b0,n,float(group.bottom),y,cap,wall,wet)
			_edge_fittings(a0,b0,n,civil)

func _wall(a: Vector3,b: Vector3,n: Vector3,bottom: float,top: float,cap: Color,wall: Color,wet: Color) -> void:
	var levels: Array[float] = [bottom,.95,top*.43,top-.48,top]
	var palette: Array[Color] = [wet,wall.darkened(.12),wall,cap]
	for i: int in range(4):
		var low: float = levels[i]
		var high: float = levels[i+1]
		_quad(Vector3(a.x,low,a.z),Vector3(b.x,low,b.z),Vector3(b.x,high,b.z),Vector3(a.x,high,a.z),palette[i],n)

func _edge_fittings(a: Vector3,b: Vector3,n: Vector3,civil: bool) -> void:
	var length: float = a.distance_to(b)
	if length < 28.0 or a.y < 8.0: return
	var direction: Vector3 = (b-a).normalized()
	var steps: int = int(length / 34.0)
	for i: int in steps:
		var center: Vector3 = a+direction*(i+.5)*length/steps
		if TerrainQueries.land_data(_chart,center+n*3.0): continue
		if TerrainQueries.height_data(_chart,center+n*3.0,false)>1.2: continue
		# Hull-side fittings only in open-water runs, away from shore and corners.
		if _used.any(func(point: Vector3) -> bool: return point.distance_to(center)<19.0): continue
		_used.append(center)
		var contact: Vector3 = center+n*.31-Vector3.UP*(center.y*.36)
		var axis: Vector3 = Vector3(2.4,.0,1.08) if absf(direction.x)>.5 else Vector3(1.08,.0,2.4)
		_box(contact,Vector3(axis.x,center.y*.70,axis.z),Color("625143"))
		_box(contact+n*.39,Vector3(axis.x*.77,center.y*.61,axis.z*.77),Color("363d3c"))
		_box(center-n*1.73+Vector3.UP*.10,Vector3(1.70,.20,1.42),Color("555b58"))
		_box(center-n*1.73+Vector3.UP*.54,Vector3(.73,.79,.70),Color("3e494a"))
		_box(center-n*1.73+Vector3.UP*.94,Vector3(1.28,.23,.96),Color("596260"))
		var edge_mark: Vector3 = center-n*.83+Vector3.UP*.024
		var sz: Vector3 = Vector3(2.75,.036,.17) if absf(direction.x)>.5 else Vector3(.17,.036,2.75)
		_box(edge_mark,sz,Color("bbaa75") if civil else Color("bfc5b4"))
		_detail_count += 1

func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color,outward: Vector3,top: bool=false) -> void:
	var points: Array[Vector3] = [a,b,c,a,c,d]
	if (c-a).cross(b-a).dot(outward)<0:
		points = [a,c,b,a,d,c]
	for k: Vector3 in points:
		_st.set_smooth_group(-1)
		_st.set_uv(Vector2(1.0 if top else 0.0,0))
		_st.set_color(tint.srgb_to_linear())
		_st.add_vertex(k)
	_triangle_count += 2

func _box(c: Vector3,size: Vector3,tint: Color) -> void:
	var x: Vector3 = Vector3.RIGHT*size.x*.5
	var y: Vector3 = Vector3.UP*size.y*.5
	var z: Vector3 = Vector3.BACK*size.z*.5
	for axes: Array in [[x,y,z],[y,x,z],[z,x,y]]:
		var n: Vector3 = axes[0]
		var u: Vector3 = axes[1]
		var v: Vector3 = axes[2]
		for side: float in [-1.0,1.0]:
			var p: Vector3 = c+n*side
			_quad(p-u-v,p+u-v,p+u+v,p-u+v,tint,n*side)
