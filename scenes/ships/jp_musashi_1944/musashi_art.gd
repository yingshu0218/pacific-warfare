extends "res://scenes/ships/visual_study/archival_cruiser_art.gd"
## Interpretive, nonfunctional October 1944 gallery exterior. No simulation dependencies.
const POSE := preload("res://scripts/presentation/models/archive_gun_rig.gd")

var rim: StandardMaterial3D
var glass: StandardMaterial3D
var seam: StandardMaterial3D

# Normalized artistic hull loft: along the ship, deck breadth, sheer, waterline breadth.
const PROFILE := [
	Vector4(-1.,.006,11.35,.004),Vector4(-.987,.069,11.04,.024),Vector4(-.960,.167,10.6,.085),
	Vector4(-.916,.323,10.04,.216),Vector4(-.839,.51,9.31,.421),Vector4(-.745,.705,8.87,.64),
	Vector4(-.636,.849,8.86,.79),Vector4(-.505,.934,9.09,.906),Vector4(-.32,.988,9.91,.979),
	Vector4(-.16,1.,10.31,1.),Vector4(.07,1.,10.38,1.),Vector4(.27,.981,10.28,.971),
	Vector4(.42,.936,10.13,.923),Vector4(.52,.882,9.68,.861),Vector4(.56,.858,7.28,.827),
	Vector4(.67,.767,6.68,.73),Vector4(.78,.643,6.24,.588),Vector4(.87,.515,6.26,.463),
	Vector4(.943,.387,6.53,.328),Vector4(.98,.251,6.70,.198),Vector4(1.,.083,6.81,.047)]
var stations: Array[Vector4] = []

func _half_length() -> float: return 131.5
func _draft() -> float: return 10.2
func _stations() -> Array[Vector4]:
	if stations.is_empty():
		for v: Vector4 in PROFILE:
			stations.append(Vector4(v.x*_half_length(),v.y*19.45,v.z,v.w*19.45))
	return stations
func _section(row: Vector4,side: float) -> PackedVector3Array:
	return _draw_section(row,side,9.65,6.05)

func _ready() -> void:
	_hull_side = _paint("5d656b")
	_steel = _paint("697279")
	_upper = _paint("7f878a")
	_deck = _paint("888069")
	_dark = _paint("353d45")
	_underbody = _paint("633d40")
	rim = _paint("818788")
	glass = _paint("26343c")
	seam = _paint("766e5c")
	_group = _layer("Musashi continuous sheer")
	_hull()
	_group = _layer("Forecastle planking and fittings")
	_weather_rails(.84,4.0)
	_draw_planks()
	_bow_and_anchors()
	_build_bridge()
	_build_waist()
	_build_aft()
	_build_exhibits()
	set_meta("visual_reference","NHHC NH 63473 / NH 73090, October 1944")
	set_meta("art_only",true)

func _draw_planks() -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := _stations()
	for i: int in range(rows.size()-1):
		var a: Vector4 = rows[i]
		var b: Vector4 = rows[i+1]
		for j: int in range(-24,25):
			var x: float = j*.76
			var w: float = absf(x)+.45
			if w>=maxf(a.y,b.y): continue
			var start: Vector4 = a
			var finish: Vector4 = b
			if w>minf(a.y,b.y):
				var cross: Vector4 = a.lerp(b,inverse_lerp(a.y,b.y,w))
				if a.y<b.y: start=cross
				else: finish=cross
			_quad(mesh,Vector3(x-.019,start.z+.019,start.x),Vector3(x+.019,start.z+.019,start.x),
				Vector3(x+.019,finish.z+.019,finish.x),Vector3(x-.019,finish.z+.019,finish.x),Vector3.UP)
	_commit("Inset longitudinal planking cues",mesh,seam)

func _beam_at(z: float) -> float:
	var rows := _stations()
	for i: int in range(1,rows.size()):
		if z<=rows[i].x:
			return lerpf(rows[i-1].y,rows[i].y,inverse_lerp(rows[i-1].x,rows[i].x,z))
	return rows[-1].y

func _bow_and_anchors() -> void:
	_hawse_relief(-115.,_beam_at(-115.)*.84,7.85,1.06)
	for side: float in [-1.,1.]:
		for i: int in range(17):
			var z: float = -123.+i*2.13
			var x: float = side*lerpf(.70,4.3,float(i)/16.)
			_box("Stowed chain links",Vector3(x,_deck_height(z)+.09,z),Vector3(.27,.12,1.12),_dark)
		for z: float in [-105.,-98.,-91.,-83.]:
			var p := Vector3(side*minf(_beam_at(z)*.70,6.5),_deck_height(z)+.31,z)
			_pipe("Fore mooring capstan",p,.62,.49,.43,1.,_steel)
			_pipe("Capstan lip",p+Vector3.UP*.34,.15,.52,.49,1.,rim)
		for z: float in [-90.,-81.,-42.,-32.,46.,56.,82.,101.]:
			var p := Vector3(side*_beam_at(z)*.72,_deck_height(z)+.22,z)
			_octagon("Folded hatch rim",p,1.76,.44,2.13,.29,_steel)
	_spar("Jackstaff",Vector3(0,11.27,-130.),Vector3(0,15.94,-130.),.14,_dark)

func _build_bridge() -> void:
	_group = _layer("Tall armored bridge and observation galleries")
	_octagon("Armored continuous superstructure plinth",Vector3(0,11.98,-3.4),27.4,4.77,64.2,4.8,_steel,.95)
	_octagon("Tall compact tower foot",Vector3(0,16.15,-24.),17.2,8.84,21.9,4.15,_steel,.82)
	_octagon("Sloped enclosed command tower",Vector3(0,28.0,-25.8),12.1,22.0,15.8,3.0,_steel,.70)
	_gallery("Rounded armored forward bridge",Vector3(0,23.45,-31.13),11.45,7.6,12.2,_steel)
	_gallery("Sheltered navigation band",Vector3(0,30.43,-27.78),15.55,3.04,13.5,_steel)
	_gallery("Broad bridge roof rim",Vector3(0,32.16,-27.13),18.14,.60,14.41,_upper)
	_octagon("Upper observation office",Vector3(0,35.0,-26.4),10.7,5.06,11.7,2.09,_steel,.82)
	_octagon("Roof below viewing crosspiece",Vector3(0,38.18,-25.7),13.64,.80,11.84,2.31,_upper)
	_gallery("Upper rounded optical head",Vector3(0,41.01,-26.1),7.18,4.64,7.23,_steel)
	_gallery("Upper optical head cap",Vector3(0,43.62,-26.1),6.67,.66,6.84,_upper)
	_disc("Long bridge optical crosspiece",Vector3(0,40.21,-26.90),.63,15.9,Vector3.RIGHT,_steel)
	for side: float in [-1.,1.]:
		_disc("Stepped viewing arm cap",Vector3(side*7.68,40.21,-26.90),.75,1.13,Vector3.RIGHT,_steel)
		_disc("Dark end of decorative viewing arm",Vector3(side*8.27,40.21,-26.90),.40,.10,Vector3.RIGHT,glass)
	_spar("Upper receiver pedestal",Vector3(0,42.8,-24.94),Vector3(0,47.4,-24.94),.43,_steel)
	_lattice(Vector3(0,47.65,-24.97),5.53,2.63)
	# Place the front window band on the curved face, not buried under it.
	for i: int in range(9):
		var x: float = (i-4)*.86
		var front_z: float = -27.78-6.77*sqrt(1.-pow(x/7.775,2.))
		var pane := _box("Curved forward bridge window",Vector3(x,30.58,front_z-.070),Vector3(.69,.58,.118),glass)
		pane.rotation.y = atan2(-x*.115,1.)
	_windows_face(Vector3(0,36.24,-31.12),6,.79,.64,.39)
	for side: float in [-1.,1.]:
		_octagon("Lower terrace wing",Vector3(side*9.18,22.87,-24.8),6.30,.57,12.2,1.25,_steel)
		_gallery("Mid bridge side lookout",Vector3(side*6.83,27.44,-24.5),4.53,2.0,7.30,_steel)
		_gallery("Shaded lookout skirt",Vector3(side*6.83,28.56,-24.5),4.83,.22,7.53,_upper)
		for i: int in range(6):
			var z: float = -30.86+i*.84
			_box("Bridge wing glazing",Vector3(side*7.06,30.53,z),Vector3(.16,.55,.60),glass)
		for level: float in [22.8,27.6,32.25]:
			var x: float = side*(11.32 if level<25. else 8.08)
			_deck_rail(Vector3(x,level,-27.),Vector3(x,level,-21.6),3)
		_spar("Bridge diagonal stabilizer",Vector3(side*9.68,15.93,-17.),Vector3(side*4.6,32.7,-21.),.58,_steel)
		_spar("Signal board yard",Vector3(0,37.46,-24.08),Vector3(side*10.4,37.46,-23.18),.13,_dark)
		for z: float in [-33.,-18.]:
			var p := Vector3(side*8.6,15.56,z)
			_box("Sheltered deck door",p,Vector3(.16,1.45,1.0),glass)

func _build_waist() -> void:
	_group = _layer("Open shoulder terraces and funnel")
	_octagon("Funnel base fairing",Vector3(0,16.15,3.40),17.3,5.1,18.3,3.4,_steel,.91)
	# The visible rear rake separates this silhouette from Nagato's upright stack.
	var base := Vector3(0,17.1,-1.0)
	var top := Vector3(0,37.35,5.2)
	var axis: Vector3 = (top-base).normalized()
	var funnel := _pipe("Canted single funnel shell",base.lerp(top,.46),base.distance_to(top)*.95,5.18,4.25,1.38,_steel)
	funnel.quaternion=Quaternion(Vector3.UP,axis)
	var lip := _pipe("Dark flared funnel crown",top,1.58,4.83,4.59,1.32,_dark)
	lip.quaternion=funnel.quaternion
	var shade := _pipe("Dark oval funnel inset",top+axis*.79,.05,3.92,3.92,1.26,glass)
	shade.quaternion=funnel.quaternion
	for side: float in [-1.,1.]:
		for i: int in range(4):
			var z: float = -19.0+11.15*i
			_octagon("Splayed weatherdeck shoulder",Vector3(side*11.95,13.12,z),9.10,3.58,10.16,2.36,_steel,.87)
			_spar("Girder supporting shoulder edge",Vector3(side*12.7,10.43,z-2.8),Vector3(side*15.8,13.9,z-2.8),.43,_steel)
			_deck_rail(Vector3(side*15.43,14.45,z-2.30),Vector3(side*15.43,14.45,z+2.25),3)
		for z: float in [-8.9,1.4,11.9]:
			var a := Vector3(side*4.1,18.8,z+2.)
			var b := Vector3(side*4.4,32.8,z+4.5)
			_spar("External ship service riser",a,b,.21,_dark)
		_gallery("Round upper lookout shelter",Vector3(side*8.35,20.50,1.),4.81,2.82,4.81,_steel)
		_disc("Closed searchlight face",Vector3(side*9.27,22.65,1.),.69,.82,Vector3(side,0,0),rim)
		_duty_boat(Vector3(side*9.37,15.32,22.9),side,.91)

func _build_aft() -> void:
	_group = _layer("Aft observation tower and handling deck")
	_octagon("Aft stepped operations house",Vector3(0,15.20,27.44),15.32,6.01,18.72,3.72,_steel,.83)
	_gallery("Rounded aft observation level",Vector3(0,20.27,27.89),10.89,3.74,10.46,_steel)
	_octagon("Aft lookout terrace",Vector3(0,22.62,27.89),13.65,.57,12.22,2.28,_upper)
	_gallery("Aft compact optical casing",Vector3(0,25.77,28.40),8.0,4.0,7.17,_steel)
	_mast_silhouette(17.,17.91,44.9,9.1,4.4)
	_octagon("Aft recessed handling platform",Vector3(0,6.65,101.8),17.87,.48,39.5,4.25,_steel,.94)
	for side: float in [-1.,1.]:
		for x: float in [2.7,5.67]:
			_spar("Handling rails",Vector3(side*x,6.97,80.1),Vector3(side*x,6.97,123.2),.18,_dark)
		for i: int in range(16):
			var z: float = 82.+i*2.55
			_spar("Flush retaining tie",Vector3(side*2.40,6.95,z),Vector3(side*5.97,6.95,z),.115,_dark)
		var p := Vector3(side*9.02,6.75,96.05)
		_octagon("Raised angled stern rail platform",p,3.63,.78,20.38,1.05,_steel)
		_spar("Platform outboard rim",p+Vector3(side*1.52,.43,-8.3),p+Vector3(side*1.52,.43,8.32),.16,rim)
		for z: float in [87.,104.5,111.8]:
			var q := Vector3(side*minf(7.65,_beam_at(z)*.69),_deck_height(z)+.16,z)
			_octagon("Recessed aft service cover",q,2.58,.47,2.86,.50,_upper)
	var anchor := Vector3(0,7.00,117.62)
	_pipe("Aft crane base",anchor+Vector3.UP*.35,.68,1.65,1.49,1.,_steel)
	var top := anchor+Vector3.UP*9.29
	_spar("Crane tower",anchor,top,.53,_steel)
	var tip := top+Vector3(3.2,3.8,-12.76)
	for x: float in [-.65,.65]:
		var offset := Vector3(x,0.,0.)
		_spar("Upper crane chord",top+offset,tip+offset*.16,.19,_steel)
		_spar("Lower crane chord",top+offset-Vector3.UP*.96,tip+offset*.16,.17,_steel)
		for i: int in range(6):
			var a: Vector3 = (top+offset).lerp(tip+offset*.16,float(i)/6.0)
			var b: Vector3 = (top+offset).lerp(tip+offset*.16,float(i+1)/6.0)
			_spar("Crane cross lace",a-Vector3.UP*.77,b,.102,_dark)
	_spar("Moored crane line",tip,tip-Vector3.UP*4.28,.058,_dark)
	_spar("Stern staff",Vector3(0,6.82,130.),Vector3(0,11.7,130.),.129,_dark)

func _deck_rail(a: Vector3,b: Vector3,posts: int) -> void:
	_spar("Upper weather rail",a+Vector3.UP*.82,b+Vector3.UP*.82,.068,rim)
	_spar("Mid weather rail",a+Vector3.UP*.40,b+Vector3.UP*.40,.056,rim)
	for i: int in range(posts+1):
		var f: Vector3 = a.lerp(b,float(i)/posts)
		_spar("Weather rail post",f,f+Vector3.UP*.82,.067,_steel)

func _disc(label: String,p: Vector3,r: float,depth: float,axis: Vector3,mat: Material) -> void:
	var item := _pipe(label,p,depth,r,r,1.,mat)
	item.quaternion = Quaternion(Vector3.UP,axis.normalized())

func _build_exhibits() -> void:
	_group = _layer("Independent closed display silhouettes")
	var z: Array[float] = [-82.,-60.4,65.]
	for i: int in range(z.size()):
		var y: float = _deck_height(z[i])
		_exhibit("Main%02d" % (i+1),"main",Vector3(0,y,z[i]),
			Vector3(14.85,4.06,13.8),4.10 if i==1 else 1.55,Vector3.FORWARD if i<2 else Vector3.BACK,3,false)
	# Put the forward exhibit on an independent deck terrace, not in the bridge block.
	var forward_z: float = -43.8
	var deck_y: float = _deck_height(forward_z)
	var terrace: float = 3.78
	_octagon("Independent forward secondary terrace",Vector3(0,deck_y+terrace*.5,forward_z),
		9.67,terrace,10.33,1.74,_steel,.87)
	_exhibit("SecondaryForward","secondary",Vector3(0,deck_y+terrace,forward_z),
		Vector3(7.55,2.87,7.73),2.09,Vector3.FORWARD,3,false)
	_octagon("Fixed aft secondary terrace",Vector3(0,11.16,47.60),9.8,2.39,10.8,1.68,_steel,.93)
	_exhibit("SecondaryAft","secondary",Vector3(0,12.24,47.6),Vector3(7.55,2.87,7.73),1.38,Vector3.BACK,3,false)
	for side: float in [-1.,1.]:
		var tag := "P" if side<0. else "S"
		for i: int in range(6):
			var p := Vector3(side*(12.18 if i%2==0 else 14.92),17.14 if i%2==0 else 14.77,-15.5+i*6.81)
			_support_display_platform(p,side,3.8,3.7)
			_exhibit("Shoulder%s%02d" % [tag,i+1],"dedicated_aa",p,Vector3(3.32,1.32,2.79),.40,Vector3(side,0,0),2,i in [2,3,4])
		for i: int in range(4):
			var p := Vector3(side*(15.5 if i<3 else 12.66),13.88 if i<3 else _deck_height(26.0+i*8.81)+.31,26.0+i*8.81)
			_support_display_platform(p,side,2.87,2.54)
			_exhibit("Light%s%02d" % [tag,i+1],"dedicated_aa",p,Vector3(1.86,.67,1.76),.23,Vector3(side,0,0),3,true)

func _support_display_platform(p: Vector3,side: float,w: float,l: float) -> void:
	var foot: float = _deck_height(p.z)
	_octagon("Fixed deck-side display shelf",p-Vector3.UP*.23,w,.46,l,.46,_steel)
	if p.y-foot>1.:
		_octagon("Shelf root fairing",Vector3(p.x-side*w*.19,(foot+p.y-.28)*.50,p.z),
			w*.68,p.y-.28-foot,l*.84,.34,_hull_side,.85)
		for offset: float in [-.89,.89]:
			_spar("Deck-supported shelf brace",Vector3(p.x-side*w*.27,foot+.10,p.z+offset),
				p+Vector3(side*w*.27,-.28,offset),.27,_steel)

func _exhibit(id: String, role: String, p: Vector3, shape: Vector3, rise: float, front: Vector3,bars: int,open: bool) -> void:
	_pipe("Static display collar",p+Vector3.UP*rise*.50,rise,shape.x*.43,shape.x*.42,1.,_dark)
	var c := GCase.new()
	c.center=p+Vector3.UP*(rise+shape.y*.5)
	c.width=shape.x
	c.height=shape.y
	c.length=shape.z
	c.front=front
	var lateral := Vector3(front.z,0,-front.x)
	var start: int = _group.get_child_count()
	if not open:
		_dated_enclosure(c)
	else:
		_gallery("Open display tray",c.center-Vector3.UP*shape.y*.27,shape.x,shape.y*.45,shape.z,_steel)
		_box("Decorative open yoke",c.center,Vector3(shape.z*.56,shape.y*.82,shape.x*.49),_upper)
	var faces: Array = _group.get_children().slice(start)
	start = _group.get_child_count()
	var pivot := c.center+front*shape.z*.24
	for i: int in range(bars):
		var a: Vector3 = pivot+lateral*shape.x*.21*(i-(bars-1)*.5)
		var b: Vector3 = a+front*shape.z*(1.0 if role=="main" else .73)+Vector3.UP*shape.y*.11
		var d: Vector3 = b-a
		var item := _pipe("Closed tapered art outline",a.lerp(b,.50),d.length(),shape.x*.058,shape.x*.041,1.,_steel)
		item.quaternion=Quaternion(Vector3.UP,d.normalized())
		_disc("Closed outline end",b,shape.x*.040,.08,d,_dark)
	var lines: Array = _group.get_children().slice(start)
	POSE.attach(self,id,role,p+Vector3.UP*rise,pivot,front,faces,lines)

func _dated_enclosure(c: GCase) -> void:
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	body.set_smooth_group(-1)
	var s := Vector3(c.front.z,0,-c.front.x)
	var low := PackedVector2Array([Vector2(-.40,-.51),Vector2(.40,-.51),Vector2(.5,-.40),Vector2(.5,.33),
		Vector2(.39,.51),Vector2(-.39,.51),Vector2(-.5,.33),Vector2(-.5,-.40)])
	var high := PackedVector2Array([Vector2(-.37,-.46),Vector2(.37,-.46),Vector2(.45,-.36),Vector2(.45,.11),
		Vector2(.33,.25),Vector2(-.33,.25),Vector2(-.45,.11),Vector2(-.45,-.36)])
	for i: int in range(low.size()):
		var j: int = (i+1)%low.size()
		var a: Vector3 = c.center+s*low[i].x*c.width+c.front*low[i].y*c.length-Vector3.UP*c.height*.50
		var b: Vector3 = c.center+s*low[j].x*c.width+c.front*low[j].y*c.length-Vector3.UP*c.height*.50
		var d: Vector3 = c.center+s*high[i].x*c.width+c.front*high[i].y*c.length+Vector3.UP*c.height*.50
		var e: Vector3 = c.center+s*high[j].x*c.width+c.front*high[j].y*c.length+Vector3.UP*c.height*.50
		_quad(body,a,b,e,d,(a+b)*.5-c.center)
		_tri(body,c.center+Vector3.UP*c.height*.5,d,e,Vector3.UP)
		_tri(body,c.center-Vector3.UP*c.height*.5,a,b,Vector3.DOWN)
	_commit("Faceted closed exhibit enclosure",body,_steel)
