extends Node3D
## Shared harbor-town visual mesh, grounded on the frozen MAP02 chart.
const MAIN: Array[Vector2] = [Vector2(1990,-4930),Vector2(2110,-4943),Vector2(2240,-4920),Vector2(2365,-4930),Vector2(2455,-4920),Vector2(2500,-4890)]
const TERRACE: Array[Vector2] = [Vector2(2220,-4924),Vector2(2192,-5005),Vector2(2155,-5080),Vector2(2150,-5160),Vector2(2110,-5240),Vector2(2080,-5310)]
const TO_PIER: Array[Vector2] = [Vector2(2315,-4926),Vector2(2314,-4840),Vector2(2336,-4770),Vector2(2340,-4709),Vector2(2322,-4660),Vector2(2275,-4626),Vector2(2300,-4590),Vector2(2290,-4572)]
const HIGH_WALK: Array[Vector2] = [Vector2(2080,-5310),Vector2(2040,-5343),Vector2(2067,-5375),Vector2(2110,-5379),Vector2(2160,-5390)]
const WEST_LANE: Array[Vector2] = [Vector2(2155,-5080),Vector2(2111,-5060),Vector2(2075,-5060),Vector2(2040,-5072)]
const HILL_LANE: Array[Vector2] = [Vector2(2150,-5160),Vector2(2194,-5150),Vector2(2235,-5150),Vector2(2273,-5155)]
const MARKET_LANE: Array[Vector2] = [Vector2(2230,-4919),Vector2(2230,-4882),Vector2(2233,-4857)]
const ROADS: Array[Array] = [[MAIN,13.0],[TERRACE,7.5],[TO_PIER,6.0],[HIGH_WALK,3.1],[WEST_LANE,4.3],[HILL_LANE,4.0],[MARKET_LANE,5.0]]
const SHOP: Color = Color("bca78d")
const SHOP_PALETTE: Array[Color] = [Color("cbb99b"),Color("b88972"),Color("bbb7a5"),Color("9a8272"),Color("d7c7a7")]
const HOME_PALETTE: Array[Color] = [Color("b7ad95"),Color("b3b2a3"),Color("aaa68a"),Color("a19a83"),Color("ced1b9")]
const ROOF_PALETTE: Array[Color] = [Color("596263"),Color("55575a"),Color("625b51"),Color("776051")]
const WINDOWS: Color = Color("425454")
const TRIM: Color = Color("776d57")
const SALE_PALETTE: Array[Color] = [Color("596d69"),Color("9b5d4d"),Color("b6a379"),Color("657561")]
const HOUSING: Color = Color("a8b2a7")
const CIVIC: Color = Color("ddd4bd")
const FOUNDATION: Color = Color("7a8178")
const PATH: Color = Color("8b9290")
var _chart: Dictionary
var _surface: SurfaceTool
var _footprints: Array[Rect2] = []
var metrics: Dictionary = {"shops":0,"homes":0,"rejected":0,"seafront_y":0.0,"hill_y":0.0,
	"waterfront":0,"landings":0,"yard_pads":0,"max_main_grade":0.0,"market_y":0.0,"ferry_top":3.1,"foundations":0}

func build(chart: Dictionary) -> void:
	_chart = chart
	_begin()
	for i: int in ROADS.size():
		var row: Array = ROADS[i]
		_street(row[0],row[1],PATH.lightened(.20) if i==0 else PATH,i==0)
	_commit("DrapedStreets",true)
	_begin()
	# Rows face the lower road, with explicit breaks for the market and access lane.
	for x: int in [2025,2055,2085,2115,2150,2250,2280,2355,2385,2415]:
		_lot(Vector2(x,-4889 if x < 2240 else -4882),Vector2(19,23),7.3,"shops",true)
	for x: int in [2034,2064,2094,2124,2154,2245,2274,2310,2348,2383,2415]:
		_lot(Vector2(x,-4970),Vector2(19,21),6.9,"shops",true)
	_lot(Vector2(2259,-4814),Vector2(40,24),8.7,"shops",true,CIVIC)
	# Offset rows along the existing terraces, opening up towards the upper slope.
	for z: int in [-5037,-5080,-5124,-5170,-5209]:
		for x: int in [2086,2131,2218,2262,2306]:
			_lot(Vector2(x+(z%3)*5,z),Vector2(15,19),5.0+absf(float((x+z)%4))*.45,"homes",true)
	for spot: Vector2 in [Vector2(2035,-5252),Vector2(2075,-5270),Vector2(2119,-5291),Vector2(2174,-5284),Vector2(2062,-5313),Vector2(2122,-5330),Vector2(2020,-5275),Vector2(2086,-5353),Vector2(2132,-5355),Vector2(2170,-5360)]:
		_lot(spot,Vector2(13,15),5.2,"homes",true)
	for spot: Vector2 in [Vector2(2006,-5361),Vector2(2029,-5378),Vector2(2052,-5396),Vector2(2086,-5361),Vector2(2091,-5403),Vector2(2118,-5358)]:
		_lot(spot,Vector2(9.0,11.0),4.8,"homes",true)
	_waterfront()
	_market()
	_yard(Vector2(2925,-4755),Vector2(85,74))
	_yard(Vector2(3375,-4765),Vector2(102,74))
	_ferry()
	_commit("TownVolumes")
	metrics["seafront_y"]=_height(Vector2(2290,-4572))
	metrics["hill_y"]=_height(HIGH_WALK[-1])
	metrics["triangles"] = 0
	for part: MeshInstance3D in get_children():
		metrics.triangles += int(part.mesh.surface_get_array_index_len(0)/3)

func _height(p: Vector2) -> float:
	return TerrainQueries.height_data(_chart,Vector3(p.x,0,p.y),false)

func _point(p: Vector2,y: float) -> Vector3:
	return Vector3(p.x,y,p.y)

func _lot(p: Vector2, size: Vector2, h: float, tag: String, roof: bool, tint: Color=Color.TRANSPARENT) -> void:
	var rect: Rect2 = Rect2(p-size*.5,size)
	var samples: Array[Vector2] = [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y),p]
	var low: float = INF
	var high: float = -INF
	for q: Vector2 in samples:
		if not TerrainQueries.land_data(_chart,_point(q,0)):
			metrics.rejected += 1
			return
		var fy: float = _height(q)
		low = minf(low,fy)
		high = maxf(high,fy)
	if high-low > (8.0 if tag in ["homes","waterfront"] else 5.5):
		metrics.rejected += 1
		return
	for prior: Rect2 in _footprints:
		if prior.grow(2).intersects(rect): metrics.rejected += 1; return
	for row: Array in ROADS:
		var spine: Array[Vector2] = row[0]
		for i: int in range(spine.size()-1):
			var delta: Vector2 = Geometry2D.get_closest_point_to_segment(p,spine[i],spine[i+1])-p
			if delta.length() < float(row[1])*.5+maxf(size.x,size.y)*.71+1.2: metrics.rejected += 1; return
	_footprints.append(rect)
	var variant: int = posmod(roundi(p.x)*17+roundi(p.y),5)
	var chosen: Color = tint if tint.a>0.0 else (HOME_PALETTE[variant] if tag=="homes" else SHOP_PALETTE[variant])
	var facade_side: float = 1.0 if p.y < -4933.0 else -1.0
	if tag == "waterfront":
		facade_side = 1.0
	var slab: float = high + .14
	_box(_point(p,(slab+low-.45)*.5),Vector3(size.x+.55,slab-low+.45,size.y+.55),FOUNDATION)
	_box(_point(p,slab+h*.5),Vector3(size.x,h,size.y),chosen)
	_facade(p,size,slab,h,facade_side,tag,variant)
	if roof:
		var e: float = size.x*.515
		var f: float = size.y*.515
		var y: float = slab+h
		var top: float = y+2.7 if tag=="shops" else y+1.9
		var a: Vector3 = _point(p+Vector2(-e,-f),y)
		var b: Vector3 = _point(p+Vector2(e,-f),y)
		var c: Vector3 = _point(p+Vector2(e,f),y)
		var d: Vector3 = _point(p+Vector2(-e,f),y)
		var ridge_a: Vector3 = _point(p+Vector2(0,-f),top)
		var ridge_b: Vector3 = _point(p+Vector2(0,f),top)
		var lid: Color = ROOF_PALETTE[variant%4]
		_face([a,d,ridge_b,ridge_a],lid,Vector3.UP)
		_face([b,c,ridge_b,ridge_a],lid,Vector3.UP)
		_face([a,b,ridge_a],chosen,Vector3.FORWARD)
		_face([c,d,ridge_b],chosen,Vector3.BACK)
		var chimney: Vector2 = p+Vector2(-size.x*.18,size.y*.26)
		_box(_point(chimney,y+1.6),Vector3(.85,3.3,1.02),chosen.darkened(.28))
		_box(_point(chimney,y+3.24),Vector3(1.05,.22,1.20),lid)
	metrics[tag] += 1
	metrics.foundations += 1

func _facade(p: Vector2,size: Vector2,slab: float,h: float,side: float,tag: String,variant: int) -> void:
	var z: float = p.y+size.y*.5*side
	var eave: float = slab+h-.10
	_box(Vector3(p.x,eave,p.y),Vector3(size.x+.54,.25,size.y+.55),TRIM)
	var door: Vector3 = Vector3(p.x,slab+1.25,z+side*.08)
	_box(door,Vector3(1.55,2.5,.16),TRIM.darkened(.26))
	if tag == "homes":
		for x: float in [-.27,.27]:
			_window(Vector3(p.x+x*size.x,slab+2.55,z),side,1.45,1.22)
	else:
		for x: float in [-.28,.28]:
			_window(Vector3(p.x+x*size.x,slab+1.8,z),side,2.32,1.40)
		var canopy_y: float = slab+2.98
		var a: Vector3 = Vector3(p.x-size.x*.35,canopy_y,z+side*.15)
		var b: Vector3 = Vector3(p.x+size.x*.35,canopy_y,z+side*.15)
		var c: Vector3 = b+Vector3(0,-.28,side*1.72)
		var d: Vector3 = a+Vector3(0,-.28,side*1.72)
		var paint: Color = SALE_PALETTE[variant%4]
		_face([a,b,c,d],paint,Vector3.UP)
		_face([a,d,c,b],paint.darkened(.15),Vector3.DOWN)
		_box((c+d)*.5-Vector3.UP*.19,Vector3(size.x*.70,.38,.14),paint.darkened(.14))
		if h>5.25:
			for x: float in [-.24,0.0,.24]:
				_window(Vector3(p.x+x*size.x,slab+h*.73,z),side,1.34,1.08)
	# Side panes keep close spectator views from seeing blank blocks.
	for x_side: float in [-1.0,1.0]:
		_box(Vector3(p.x+x_side*(size.x*.5+.06),slab+h*.58,p.y+size.y*.13),Vector3(.13,1.12,1.36),WINDOWS)

func _window(p: Vector3,side: float,w: float,h: float) -> void:
	_box(p+Vector3.BACK*side*.075,Vector3(w+.27,h+.24,.16),Color("d3c4a3"))
	_box(p+Vector3.BACK*side*.17,Vector3(w,h,.065),WINDOWS)
	_box(p+Vector3.BACK*side*.21,Vector3(.07,h,.058),TRIM.lightened(.17))

func _waterfront() -> void:
	# The lower landing, intermediate terrace and upper storefronts follow the
	# same town-to-quay route; no imported modification to naval navigation.
	for spec: Array in [
		[Vector2(2331,-4619),Vector2(8,9),4.4],
		[Vector2(2347,-4672),Vector2(10,10),4.8],
		[Vector2(2313,-4667),Vector2(12,13),4.9],
		[Vector2(2305,-4696),Vector2(12,14),5.6],
		[Vector2(2319,-4734),Vector2(13,12),5.4],
		[Vector2(2362,-4738),Vector2(12,14),5.0],
		[Vector2(2309,-4777),Vector2(14,15),6.15],
		[Vector2(2363,-4772),Vector2(15,14),6.1],
		[Vector2(2361,-4804),Vector2(14,14),6.6],
		[Vector2(2290,-4810),Vector2(14,13),5.65],
		[Vector2(2345,-4838),Vector2(15,12),5.5],
	]:
		_lot(spec[0],spec[1],spec[2],"waterfront",true)
	_landing(Vector2(2337,-4649),Vector2(14,10),1)
	_landing(Vector2(2355,-4756),Vector2(15,10),-1)
	_landing(Vector2(2336,-4824),Vector2(15,10),1)

func _landing(p: Vector2,size: Vector2,rail_side: int) -> void:
	var a: Vector2 = p-size*.5
	var b: Vector2 = p+size*.5
	var points: Array[Vector2] = [a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]
	var nearest: Vector2 = TO_PIER[0]
	for i: int in range(TO_PIER.size()-1):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p,TO_PIER[i],TO_PIER[i+1])
		if p.distance_to(q)<p.distance_to(nearest): nearest=q
	var clearance: float = p.distance_to(nearest)-size.length()*.5-3.0
	if clearance<=.30: return
	for footprint: Rect2 in _footprints:
		if footprint.grow(.4).intersects(Rect2(a,size)): return
	var low: float = INF
	var high: float = -INF
	for q: Vector2 in points:
		if not TerrainQueries.land_data(_chart,_point(q,0.0)): return
		var y: float = _height(q)
		low = minf(low,y)
		high = maxf(high,y)
	# Broad apron top aligns to the adjacent route at its anchor, with a
	# retaining face on the downhill edge; no full-slope flattening.
	var top: float = high+.48
	_box(_point(p,(top+low-.30)*.5),Vector3(size.x,top-low+.30,size.y),Color("929183"))
	_box(_point(p,top+.065),Vector3(size.x+.20,.13,size.y+.20),Color("b4aa92"))
	var z: float = p.y+float(rail_side)*size.y*.48
	for u: float in [-.45,-.15,.15,.45]:
		_box(Vector3(p.x+u*size.x,top+.62,z),Vector3(.20,1.22,.23),TRIM)
	_box(Vector3(p.x,top+1.07,z),Vector3(size.x*.94,.16,.20),TRIM)
	var border: Vector2 = nearest.clamp(a,b)
	var vec: Vector2 = (border-nearest).normalized()
	var start: Vector2 = nearest+vec*2.72
	var side: Vector2 = Vector2(-vec.y,vec.x)*1.50
	var ramp_start: float = _height(start)+.31
	var ramp_end: float = top+.132
	_face([_point(start-side,ramp_start),_point(border-side,ramp_end),_point(border+side,ramp_end),_point(start+side,ramp_start)],Color("b4aa92"),Vector3.UP)
	metrics.landings += 1
	metrics["landing_clearance"] = minf(float(metrics.get("landing_clearance",INF)),clearance)

func _street(spine: Array[Vector2], width: float, tint: Color, main: bool=false) -> void:
	# One shared cross section at each bend, so there are no overlapping slab ends.
	var samples: Array[Vector2] = []
	for i: int in range(spine.size()-1):
		var count: int = maxi(1,ceili(spine[i].distance_to(spine[i+1])/3.4))
		for j: int in count: samples.append(spine[i].lerp(spine[i+1],float(j)/count))
	samples.append(spine[-1])
	var last: Array[Vector3] = []
	for i: int in samples.size():
		var p: Vector2 = samples[i]
		var t: Vector2 = (samples[mini(i+1,samples.size()-1)]-samples[maxi(i-1,0)]).normalized()
		var normal: Vector2 = Vector2(-t.y,t.x)*width*.5
		var q: Array[Vector3] = [_point(p-normal,_height(p-normal)+.26),_point(p,_height(p)+.26),_point(p+normal,_height(p+normal)+.26)]
		if not last.is_empty():
			_face([last[0],q[0],q[1],last[1]],tint,Vector3.UP)
			_face([last[1],q[1],q[2],last[2]],tint,Vector3.UP)
			if main:
				metrics.max_main_grade = maxf(float(metrics.max_main_grade),absf(q[1].y-last[1].y)/samples[i-1].distance_to(p))
		last=q

func _market() -> void:
	var p: Vector2 = Vector2(2253,-4848)
	var h: float = _height(p)
	metrics.market_y = h
	_box(_point(p,h-.19),Vector3(53.0,1.0,34.0),Color("bdb6a7"))
	for t: Vector2 in [Vector2(-16,-8),Vector2(-1,-8),Vector2(14,-8)]:
		_box(_point(p+t,h+1.05),Vector3(8.5,2.4,5.5),CIVIC)
		_box(_point(p+t,h+2.38),Vector3(10.0,.35,6.8),SHOP)

func _yard(p: Vector2,s: Vector2) -> void:
	# Diagrammatic working aprons, deliberately beside the existing workshops.
	var land_y: float = _height(p)
	var r: Rect2 = Rect2(p-s*.5,s)
	for xy: Vector2 in [r.position,r.end,Vector2(r.position.x,r.end.y),Vector2(r.end.x,r.position.y)]:
		if absf(_height(xy)-land_y)>.5: return
	_box(_point(p,land_y-.22),Vector3(s.x,1.12,s.y),Color("9ba6a3"))
	for z: float in [-.26,0.0,.26]:
		_box(_point(p+Vector2(s.x*.18,z*s.y),land_y+1.6),Vector3(s.x*.33,2.5,10.0),Color("7b8682"))
	metrics.yard_pads += 1

func _ferry() -> void:
	var p: Vector2 = Vector2(2290,-4501)
	_box(_point(p,2.68),Vector3(16,.84,73),Color("a59a7c"))
	for z: float in [-4530,-4512,-4494,-4476]:
		for x: float in [-7.5,7.5]:
			_box(Vector3(p.x+x,3.50,z),Vector3(.37,.91,.42),TRIM)
		for x: float in [-5.8,5.8]:
			_box(_point(Vector2(p.x+x,z),.85),Vector3(1.75,3.5,1.75),FOUNDATION)
	# Shallow step sequence wraps the last 37 metres down to the ferry deck.
	var a: Vector2 = Vector2(2290,-4572)
	var b: Vector2 = Vector2(2290,-4536.9)
	for i: int in 12:
		var t: float = float(i)/11
		var q: Vector2 = a.lerp(b,t)
		var top: float = maxf(_height(q)+.30,lerpf(_height(a)+.28,3.12,t))
		_box(_point(q,top-1.1),Vector3(5.5,2.2,2.99),Color("b0afa5"))
	var kiosk: Vector2 = Vector2(2310,-4551)
	var deck: float = _height(kiosk)
	_box(_point(kiosk,deck+1.05),Vector3(7.4,2.4,7.0),CIVIC)
	_box(_point(kiosk,deck+2.35),Vector3(8.3,.44,7.9),Color("62716f"))
	_box(_point(kiosk+Vector2(0,3.51),deck+1.31),Vector3(3.0,.95,.12),WINDOWS)

func _begin() -> void:
	_surface=SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func _commit(label: String, paint: bool=false) -> void:
	_surface.index()
	_surface.generate_normals()
	var mat: Material
	if paint:
		mat = ShaderMaterial.new()
		(mat as ShaderMaterial).shader=preload("res://scripts/map02/quay_road_paint.gdshader")
	else:
		mat=StandardMaterial3D.new()
		(mat as StandardMaterial3D).vertex_color_use_as_albedo=true
		(mat as StandardMaterial3D).roughness=.95
	_surface.set_material(mat)
	var model: MeshInstance3D = MeshInstance3D.new()
	model.name=label
	model.mesh=_surface.commit()
	if paint: model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)

func _face(points: Array[Vector3], tint: Color, outward: Vector3) -> void:
	if (points[2]-points[0]).cross(points[1]-points[0]).dot(outward)<0.0: points.reverse()
	for i: int in range(1,points.size()-1):
		for p: Vector3 in [points[0],points[i],points[i+1]]:
			_surface.set_color(tint.srgb_to_linear())
			_surface.set_smooth_group(-1)
			_surface.add_vertex(p)

func _box(c: Vector3,s: Vector3,tint: Color) -> void:
	var x: Vector3=Vector3.RIGHT*s.x*.5
	var y: Vector3=Vector3.UP*s.y*.5
	var z: Vector3=Vector3.BACK*s.z*.5
	for axes: Array in [[x,y,z],[y,x,z],[z,x,y]]:
		var n: Vector3=axes[0]
		var u: Vector3=axes[1]
		var v: Vector3=axes[2]
		for sign_value: float in [-1.0,1.0]:
			var p: Vector3=c+n*sign_value
			_face([p-u-v,p+u-v,p+u+v,p-u+v],tint,n*sign_value)
