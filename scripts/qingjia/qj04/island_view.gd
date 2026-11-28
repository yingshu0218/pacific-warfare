extends "res://scripts/qingjia/qj03/archipelago_view.gd"

const BAG := preload("res://scenes/qingjia/qj04_props/round_sandbags.tscn")
const FIXED := preload("res://scenes/qingjia/qj04_props/permanent_concrete.tscn")
var batch_heading := Basis.IDENTITY
var batch_origin := Vector3.ZERO
var angled := false

func _object(obj: Dictionary) -> void:
	batch_origin = SimData.vec3(obj.position_m)
	batch_heading = Basis(Vector3.UP,float(obj.get("heading_rad",0.)))
	angled = obj.has("heading_rad")
	if obj.has("visual_size_m"):
		var row := obj.duplicate()
		row.size_m = obj.visual_size_m
		super._object(row)
	elif str(obj.get("style","")).begins_with("shrine"):
		var row := obj.duplicate()
		row.id = "shrine"
		super._object(row)
	else:
		super._object(obj)
	angled = false

func _tri(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	if angled:
		super._tri(batch_origin+batch_heading*(a-batch_origin),batch_origin+batch_heading*(b-batch_origin),batch_origin+batch_heading*(c-batch_origin),color)
	else:
		super._tri(a,b,c,color)

func _road(road: Dictionary) -> void:
	# Render each centered ribbon against the same terrain queried by the viewer.
	var style: String = road.get("style","local")
	if style == "quay":
		return
	var palette := {"main":"827c69","local":"aaa089","hill":"92846e","foot":"bdad8f"}
	var base := Color(palette.get(style,"a3987e"))
	var points: Array = road.points_m
	for i: int in points.size()-1:
		var a := SimData.vec3(points[i])
		var b := SimData.vec3(points[i+1])
		var s := (b-a).cross(Vector3.UP).normalized()
		var n := maxi(1,ceili(a.distance_to(b)/2.5))
		for j: int in n:
			var p := a.lerp(b,float(j)/n)
			var q := a.lerp(b,float(j+1)/n)
			_strip(p,q,s,float(road.width_m)*.55,.14,base.darkened(.26))
			_strip(p,q,s,float(road.width_m)*.47,.22,base)
	for p: Array in points:
		var point := SimData.vec3(p)
		var radius := float(road.width_m)*.49
		point.y = TerrainQueries.height_data(terrain,point)+.25
		for x: int in 12:
			var a := point+Vector3(cos(TAU*x/12.0)*radius,0,sin(TAU*x/12.0)*radius)
			var b := point+Vector3(cos(TAU*(x+1)/12.0)*radius,0,sin(TAU*(x+1)/12.0)*radius)
			a.y = TerrainQueries.height_data(terrain,a)+.245
			b.y = TerrainQueries.height_data(terrain,b)+.245
			_tri(point,a,b,base)

func _strip(a: Vector3,b: Vector3,s: Vector3,width: float,height: float,color: Color) -> void:
	var pts: Array[Vector3] = [a-s*width,a+s*width,b+s*width,b-s*width]
	for k: int in pts.size():
		pts[k].y = _visual_grade(pts[k])+height
	_quad(pts[0],pts[1],pts[2],pts[3],color)

func _visual_grade(p: Vector3) -> float:
	var y := TerrainQueries.height_data(terrain,p)
	if p.x > 1055 and p.x < 1214 and p.z > 63 and p.z < 236:
		y = maxf(y,6.12)
	return y

func _build_civil_and_shrine_details() -> void:
	_surface_start()
	_civic_details()
	_frontages()
	_shrine_precinct()
	_port_hardscape()
	_landing_details()
	_upland_facilities()
	_surface_finish("QJ04_Precinct_And_Infrastructure",true)
	statistics["frontage_houses"] = terrain.source.objects.filter(func(o:Dictionary)->bool: return o.has("frontage_m")).size()

func _frontages() -> void:
	for o: Dictionary in terrain.source.objects:
		if not o.has("frontage_m"):
			continue
		var at := SimData.vec3(o.position_m)
		var roadside := SimData.vec3(o.frontage_m)
		var d := Vector3(roadside.x-at.x,0,roadside.z-at.z).normalized()
		var front := at+d*(float(o.size_m[2])*.5+1.)
		var side := d.cross(Vector3.UP)
		_strip(front,roadside,side,1.2,.23,Color("91836b"))
		var court := front+d*2.4
		court.y = TerrainQueries.height_data(terrain,court)+.10
		var tint := Color("b0a187").darkened(.04*sin(at.x))
		_box(court,Vector3(3.1,.15,2.2),tint)

func _shrine_precinct() -> void:
	var stone := Color("a49e8e")
	var gravel := Color("b6aa90")
	var cedar := Color("9b4d38")
	var eave := Color("554a40")
	var court := Vector3(687,49,19)
	var grade := TerrainQueries.height_data(terrain,court)
	_box(Vector3(court.x,grade+.04,court.z),Vector3(48,.16,42),gravel)
	for z: float in [1.,37.]:
		_box(Vector3(687,grade+.35,z),Vector3(47,.65,1.08),stone.darkened(.22))
	for x: float in [665.,709.]:
		_box(Vector3(x,grade+.35,19),Vector3(1.08,.65,34),stone.darkened(.22))
	# Actual footpath meshes touch the terrain and turn into short stone treads.
	for i: int in range(34):
		var z := 34.+i*1.02
		var x := 684.-clampf((z-54.)/14.,0,1)*7.7
		var at := Vector3(x,0,z)
		var level := TerrainQueries.height_data(terrain,at)
		var near := TerrainQueries.height_data(terrain,at+Vector3(0,0,.51))
		var far := TerrainQueries.height_data(terrain,at-Vector3(0,0,.51))
		var top := maxf(level,maxf(near,far))+.25
		var bottom := minf(level,minf(near,far))-.14
		_box(Vector3(x,(top+bottom)*.5,z),Vector3(5.2,top-bottom,1.03),stone.darkened(.04*(i%4)))
	for gate: Vector2 in [Vector2(683,42),Vector2(678,64)]:
		var y := TerrainQueries.height_data(terrain,Vector3(gate.x,0,gate.y))
		_torii(Vector3(gate.x,y,gate.y),cedar,eave)
	for z: float in [19.,31.,48.,59.]:
		for dx: float in [-5.5,5.5]:
			var p := Vector3(684+dx,0,z)
			p.y = TerrainQueries.height_data(terrain,p)
			_box(p+Vector3.UP*.58,Vector3(.45,1.16,.45),stone.darkened(.19))
			_box(p+Vector3.UP*1.30,Vector3(.66,.34,.66),stone)
			_box(p+Vector3.UP*1.55,Vector3(.81,.18,.76),stone.darkened(.16))
	for p: Vector3 in [Vector3(660,0,13),Vector3(712,0,50),Vector3(650,0,42),Vector3(718,0,18)]:
		p.y=TerrainQueries.height_data(terrain,p)
		_tree(p,9.0,Color("405337"),p.x)
	# A low veranda and two cedar screen panels distinguish the buildings from houses.
	_box(Vector3(684,grade+.24,35),Vector3(20,.43,4.7),eave.lightened(.15))
	for dx: float in [-9.0,9.0]:
		_box(Vector3(684+dx,grade+1.03,35),Vector3(3.2,1.17,.25),cedar.darkened(.12))

func _torii(p: Vector3,wood: Color,roof: Color) -> void:
	for side: float in [-1.,1.]:
		_box(p+Vector3(side*2.5,2.80,0),Vector3(.52,5.6,.59),wood)
		_box(p+Vector3(side*2.5,.25,0),Vector3(.73,.5,.77),roof)
	_box(p+Vector3(0,4.21,0),Vector3(6.9,.42,.67),wood.darkened(.12))
	_box(p+Vector3(0,5.46,0),Vector3(7.8,.52,.84),wood)
	_box(p+Vector3(0,5.79,0),Vector3(8.2,.22,1.),roof)
	_box(p+Vector3(0,4.86,0),Vector3(.66,.86,.17),wood.lightened(.23))

func _port_hardscape() -> void:
	# Distinct landside cargo apron and the exterior-facing concrete edge.
	var concrete := Color("92948b")
	var seam := Color("6d716d")
	for x: float in [1125,1148,1171,1194,1215]:
		_box(Vector3(x,6.148,171),Vector3(.16,.035,108),seam)
	for z: float in [119,143,166,190,212]:
		_box(Vector3(1175,6.150,z),Vector3(77,.04,.14),seam)
	for x: float in [1129,1154,1180,1205]:
		_box(Vector3(x,6.175,199),Vector3(.31,.06,17),Color("ccc3a4"))
	for z: int in range(81,230,8):
		_box(Vector3(1240,6.22,z),Vector3(.53,.70,.66),seam.darkened(.2))
	_box(Vector3(1241.4,3.1,151),Vector3(.56,.36,135),concrete.darkened(.30))
	for i: int in 16:
		_crate(Vector3(1159+(i%4)*4.8,6.84+float(i/8)*1.4,119+(i%8/4)*5.0),4.2,Color("9b7c54").lightened(.025*(i%4)))
	# Low shed, visible room for lorry circulation and paired edge cranes as art silhouettes.
	for x: float in [1186,1212]:
		_box(Vector3(x,12.4,171),Vector3(.62,12.4,.71),Color("8b7557"))
		_box(Vector3(x+5.7,18.6,171),Vector3(12.8,.53,.42),Color("877252"))
		_box(Vector3(x+10.7,16.5,171),Vector3(.15,3.72,.17),Color("646053"))

func _landing_details() -> void:
	for i: int in 21:
		_box(Vector3(856,1.4,858+i*1.9),Vector3(6,.31,1.86),Color("8b7460").darkened(float(i%4)*.04))
		if i%5==0:
			for side: float in [-1.,1.]:
				_box(Vector3(856+side*2.74,.25,858+i*1.9),Vector3(.56,3.4,.56),Color("675547"))
	_small_boat(Vector3(862,.18,887),9,2.3,Color("af926d"))

func _upland_facilities() -> void:
	for p: Vector3 in [Vector3(544,0,-229),Vector3(430,0,-219),Vector3(459,0,99)]:
		var y := TerrainQueries.height_data(terrain,p)
		_box(Vector3(p.x,y+.09,p.z),Vector3(8,.16,5),Color("a89d88"))
		for dx: float in [-3.,3.]:
			_box(Vector3(p.x+dx,y+.55,p.z-2),Vector3(.3,1.1,.36),Color("6f6452"))
		_box(Vector3(p.x,y+1.03,p.z-2),Vector3(6.7,.2,.21),Color("9a8868"))
	var at := Vector3(550,0,-239)
	var y := TerrainQueries.height_data(terrain,at)
	_box(Vector3(at.x,y+1.8,at.z),Vector3(.17,3.6,.17),Color("7e8074"))
	_box(Vector3(at.x,y+3.58,at.z),Vector3(1.12,.18,.21),Color("c5c6af"))

func _build_coastal_exhibits() -> void:
	var container := Node3D.new()
	container.name = "StaticCoastalScenery"
	add_child(container)
	# Art exhibits, intentionally not simulation entities.
	for row: Array in [[BAG,Vector3(1415,0,-150)],[FIXED,Vector3(1453,0,-183)]]:
		var p: Vector3 = row[1]
		p.y = TerrainQueries.height_data(terrain,p)
		var art: Node3D = row[0].instantiate()
		container.add_child(art)
		art.position = p
