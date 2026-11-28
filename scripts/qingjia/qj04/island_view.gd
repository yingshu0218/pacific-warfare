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
	var row := obj.duplicate()
	if obj.has("visual_size_m"):
		row.size_m = obj.visual_size_m
	var style := str(row.get("style",""))
	match style:
		"canvas_tent":
			_canvas_tent(row)
		"camp_one", "camp_two":
			_camp_house(row,style=="camp_two")
		"wood_hall":
			_timber_hall(row)
		_:
			if style.begins_with("shrine"):
				row.id = "shrine"
			super._object(row)
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
	# Small pedestrian/court branches use a single terrain ribbon, keeping
	# rounded junctions from sitting above their walking surface.
	if str(road.id) in ["canvas_court_walk","wood_court_walk"]:
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
	# Keep terrain-following paths and yard paving out of the geometry shadow pass.
	_surface_start()
	_small_courts()
	for road: Dictionary in terrain.source.roads:
		if str(road.id) in ["canvas_court_walk","wood_court_walk"]:
			super._road(road)
	_surface_finish("QJ04_Pedestrian_Courts",false)
	statistics["canvas_tents"] = terrain.source.objects.filter(func(o:Dictionary)->bool: return o.get("style","")=="canvas_tent").size()
	statistics["small_support"] = terrain.source.objects.filter(func(o:Dictionary)->bool: return str(o.get("style","")).begins_with("camp_")).size()
	statistics["traditional_halls"] = terrain.source.objects.filter(func(o:Dictionary)->bool: return o.get("style","")=="wood_hall").size()
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

func _footing(p: Vector3,s: Vector3,datum: float,finish: Color) -> void:
	if datum < p.y:
		_box(Vector3(p.x,(p.y+datum)*.5,p.z),Vector3(s.x,p.y-datum,s.z),finish)

func _canvas_tent(row: Dictionary) -> void:
	var p := SimData.vec3(row.position_m)
	var s := SimData.vec3(row.size_m)
	var canvas := Color(str(row.color))
	var shadow := canvas.darkened(.28)
	var rope := Color("6e624b")
	var base := float(row.get("foundation_bottom_m",p.y-.23))
	_footing(p,s,base,Color("827762"))
	var e := s.x*.5
	var a := s.z*.5
	var y := s.y*.34
	var ridge := s.y
	var lo := p+Vector3(-e,y,-a)
	var hi := p+Vector3(e,y,-a)
	var ridge_b := p+Vector3(0,ridge,-a)
	var lf := p+Vector3(-e,y,a)
	var rf := p+Vector3(e,y,a)
	var ridge_f := p+Vector3(0,ridge,a)
	_quad(lo,lf,ridge_f,ridge_b,canvas.lightened(.06))
	_quad(ridge_b,ridge_f,rf,hi,canvas)
	_quad(p+Vector3(-e,0,-a),p+Vector3(-e,0,a),lf,lo,shadow)
	_quad(hi,rf,p+Vector3(e,0,a),p+Vector3(e,0,-a),canvas.darkened(.14))
	_tri(lo,ridge_b,hi,shadow)
	_quad(lo,hi,p+Vector3(e,0,-a),p+Vector3(-e,0,-a),shadow)
	_tri(lf,rf,ridge_f,canvas.lightened(.04))
	_quad(lf,p+Vector3(-e,0,a),p+Vector3(e,0,a),rf,canvas.darkened(.16))
	# Separate dark flap and crease lines at the sight-facing entrance.
	_tri(p+Vector3(0,s.y*.83,a+.052),p+Vector3(-s.x*.136,.04,a+.052),p+Vector3(s.x*.147,.04,a+.052),shadow.darkened(.56))
	_rod(p+Vector3(0,s.y*.85,a+.07),p+Vector3(-s.x*.139,.06,a+.075),.048,canvas.lightened(.15))
	_rod(p+Vector3(0,s.y*.85,a+.07),p+Vector3(s.x*.151,.06,a+.075),.044,canvas.lightened(.13))
	for z: float in [-a*.82,-a*.24,a*.33,a*.86]:
		for sign_x: float in [-1.,1.]:
			var u := p+Vector3(sign_x*e,y+.05,z)
			var v := p+Vector3(sign_x*(e+1.34),.12,z*1.11)
			_rod(u,v,.028,rope)
			_box(v+Vector3.UP*.056,Vector3(.08,.17,.08),rope.darkened(.14))
			_rod(u,p+Vector3(0,ridge+.047,z),.019,canvas.lightened(.19))
	_rod(ridge_b+Vector3.UP*.042,ridge_f+Vector3.UP*.042,.037,canvas.lightened(.20))

func _rod(a: Vector3,b: Vector3,r: float,color_value: Color) -> void:
	var f := (b-a).normalized()
	var j := f.cross(Vector3.UP)
	if j.length_squared()<.001:
		j = f.cross(Vector3.RIGHT)
	j=j.normalized()*r
	var k := f.cross(j).normalized()*r
	for sides: Array in [[j,k],[k,-j],[-j,-k],[-k,j]]:
		var l: Vector3=sides[0]
		var m: Vector3=sides[1]
		_quad(a+l,b+l,b+m,a+m,color_value)

func _camp_house(row: Dictionary,two_storey: bool) -> void:
	super._object(row)
	var p := SimData.vec3(row.position_m)
	var s := SimData.vec3(row.size_m)
	var frame := Color("6e6655")
	var glass := Color("485653")
	var front := s.z*.505
	_box(p+Vector3(-s.x*.27,1.22,front),Vector3(1.65,2.34,.19),frame.darkened(.20))
	_box(p+Vector3(-s.x*.27,2.62,front+.57),Vector3(3.22,.16,1.44),Color("a1957f"))
	var rows: Array = [1.80,4.38] if two_storey else [1.83]
	for y: float in rows:
		for x: float in [-s.x*.03,s.x*.21,s.x*.39]:
			_box(p+Vector3(x,y,front),Vector3(1.44,1.12,.14),frame)
			_box(p+Vector3(x,y,front+.083),Vector3(1.19,.91,.08),glass)
			_box(p+Vector3(x,y,front+.132),Vector3(.074,.92,.036),Color("cec5a9"))
	for sign_x: float in [-1.,1.]:
		for z: float in [-s.z*.21,s.z*.21]:
			for y: float in rows:
				_box(p+Vector3(sign_x*s.x*.503,y,z),Vector3(.16,1.06,1.42),frame)
				_box(p+Vector3(sign_x*s.x*.513,y,z),Vector3(.11,.82,1.17),glass)
				_box(p+Vector3(sign_x*s.x*.517,y,z),Vector3(.11,.84,.077),Color("b6ac91"))
	for y: float in range(1,floori(s.y)-1):
		_box(p+Vector3(0,y,-front),Vector3(s.x*.96,.055,.09),frame.lightened(.21))

func _timber_hall(row: Dictionary) -> void:
	var p := SimData.vec3(row.position_m)
	var s := SimData.vec3(row.size_m)
	var wood := Color(str(row.color))
	var timber := Color("5e4939")
	var infill := Color("e0d1aa").darkened(.06*sin(p.x))
	var tile := Color("647271").lerp(Color("727367"),.5+sin(p.x)*.5)
	_footing(p,s,float(row.get("foundation_bottom_m",p.y-.26)),Color("929286"))
	_box(p+Vector3.UP*.48,Vector3(s.x*1.09,.70,s.z*1.11),Color("a9a394"))
	_box(p+Vector3(0,(s.y+.72)*.5,0),Vector3(s.x*.94,s.y-.72,s.z*.94),infill)
	for y: float in [1.08,s.y*.57,s.y*.90]:
		for dz: float in [-s.z*.478,s.z*.478]:
			_box(p+Vector3(0,y,dz),Vector3(s.x*.96,.24,.13),timber)
		for dx: float in [-s.x*.478,s.x*.478]:
			_box(p+Vector3(dx,y,0),Vector3(.14,.24,s.z*.96),timber)
	# Front veranda, exposed columns, transoms and shuttered screen bays.
	var veranda := s.z*.56
	_box(p+Vector3(0,.73,veranda),Vector3(s.x*1.02,.30,s.z*.23),wood.darkened(.31))
	for i: int in 9:
		var fx := (float(i)/8.0-.5)*s.x*.94
		for dz: float in [veranda+s.z*.069,-s.z*.48]:
			_box(p+Vector3(fx,s.y*.47,dz),Vector3(.29,s.y*.87,.31),timber)
		if i<8:
			var cell := fx+s.x*.058
			_box(p+Vector3(cell,s.y*.50,s.z*.479),Vector3(s.x*.096,s.y*.48,.16),wood)
			for lattice: float in [-1.,0.,1.]:
				_box(p+Vector3(cell+lattice*s.x*.022,s.y*.50,s.z*.495),Vector3(.088,s.y*.40,.09),timber.lightened(.15))
			_box(p+Vector3(cell,s.y*.57,s.z*.495),Vector3(s.x*.098,.10,.11),timber)
	var riser := .18
	for index: int in 3:
		var top := .12+index*riser
		_box(p+Vector3(0,top,veranda+s.z*.13-index*.36),Vector3(s.x*.34,.26,.48),Color("9c9785"))
	var e := s.x*.56
	var d := s.z*.66
	var crown := s.y+(.22*s.z+.52)
	var eave := s.y-.15
	var prev := Vector2(0,crown)
	for i: int in 7:
		var t := float(i+1)/7.0
		var current := Vector2(d*t,lerpf(eave,crown,pow(1.-t,1.42)))
		for sign_z: float in [-1.,1.]:
			var an := p+Vector3(-e,prev.y,sign_z*prev.x)
			var bn := p+Vector3(e,prev.y,sign_z*prev.x)
			var af := p+Vector3(-e,current.y,sign_z*current.x)
			var bf := p+Vector3(e,current.y,sign_z*current.x)
			_quad(an,bn,bf,af,tile.darkened(.045*(i%3)))
			_rod(af,bf,.045,tile.lightened(.11))
			for dx: float in [-e,e]:
				_tri(p+Vector3(dx,eave,sign_z*d),p+Vector3(dx,current.y,sign_z*current.x),p+Vector3(dx,prev.y,sign_z*prev.x),timber.lightened(.12))
			for run: int in range(-17,18):
				var x := float(run)*e/18.
				_rod(p+Vector3(x,prev.y+.035,sign_z*prev.x),p+Vector3(x,current.y+.035,sign_z*current.x),.026,tile.lightened(.09))
		prev = current
	_rod(p+Vector3(-e-.24,crown+.13,0),p+Vector3(e+.24,crown+.13,0),.18,tile.darkened(.37))
	for side: float in [-1.,1.]:
		var top := p+Vector3(side*(e+.32),crown+.22,0)
		_box(top,Vector3(.56,.23,.37),tile.darkened(.26))
		_box(p+Vector3(0,eave-.08,side*d),Vector3(e*2.,.22,.24),timber)

func _small_courts() -> void:
	var pebble := Color("a19780")
	var earthen := Color("9b8b70")
	_grade_rect(Vector2(351,328),Vector2(43,35),earthen)
	_grade_rect(Vector2(392,326),Vector2(42,37),earthen.darkened(.075))
	_grade_rect(Vector2(856,498),Vector2(52,26),pebble)
	for where: Vector2 in [Vector2(824,491),Vector2(878,493),Vector2(855,516),Vector2(409,353)]:
		var p := Vector3(where.x,0,where.y)
		p.y=TerrainQueries.height_data(terrain,p)
		_tree(p,6.2,Color("4e6843"),where.x)
	for i: int in 4:
		var x := 382.+i*2.1
		var z := 342.5
		var y := TerrainQueries.height_data(terrain,Vector3(x,0,z))
		_crate(Vector3(x,y+.87,z),1.45,Color("9d835c"))
	for x: float in [830.,841.,867.,878.]:
		var p := Vector3(x,0,507.5)
		p.y=TerrainQueries.height_data(terrain,p)
		_box(p+Vector3.UP*.17,Vector3(2.1,.43,2.0),Color("8a8c77"))
		_box(p+Vector3.UP*.45,Vector3(.26,.83,.25),Color("766d55"))
		_box(p+Vector3.UP*.87,Vector3(.46,.19,.42),Color("877b61"))

func _grade_rect(at: Vector2,s: Vector2,color_value: Color) -> void:
	for u: int in 8:
		for v: int in 6:
			var a:=at+s*Vector2(float(u)/8.-.5,float(v)/6.-.5)
			var b:=a+Vector2(s.x/8.,s.y/6.)
			var points: Array[Vector3] = [Vector3(a.x,0,a.y),Vector3(b.x,0,a.y),Vector3(b.x,0,b.y),Vector3(a.x,0,b.y)]
			for i: int in 4:
				points[i].y = TerrainQueries.height_data(terrain,points[i])+.15
			_quad(points[0],points[1],points[2],points[3],color_value.darkened(.035*sin(u*4.+v*2.)))
