extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
## Hand-shaped 1942 exhibit exteriors. No systems, internal volumes or moving parts.
@export var hornet := false
var flight_y: float
var _glass: StandardMaterial3D
var _wood: StandardMaterial3D
var _edge: StandardMaterial3D
var _mark: StandardMaterial3D

func _half_length() -> float:
	return 123.4059 if hornet else 135.3312

func _draft() -> float:
	return 8.4 if hornet else 7.3533

func _stations() -> Array[Vector4]:
	if hornet:
		return [Vector4(-123.4059,.13,10.8,.13),Vector4(-121,1.45,10.5,.34),Vector4(-115,3.25,10.0,1.18),Vector4(-106,6.0,9.38,3.4),Vector4(-94,8.9,8.65,6.72),Vector4(-80,10.65,8.15,9.44),Vector4(-65,11.8,7.89,11.31),Vector4(-42,12.6,7.78,12.4),Vector4(-16,12.6619,7.63,12.58),Vector4(25,12.6619,7.6,12.55),Vector4(63,12.48,7.56,12.23),Vector4(85,11.37,7.5,10.92),Vector4(105,8.98,7.4,7.22),Vector4(117,5.53,7.25,2.19),Vector4(121.7,2.9,7.12,.4),Vector4(123.4059,.41,7.06,.12)]
	return [Vector4(-135.3312,.12,12.1,.10),Vector4(-133,1.49,11.6,.33),Vector4(-127,3.33,10.8,1.25),Vector4(-118,6.4,9.97,3.36),Vector4(-107,9.5,9.43,6.0),Vector4(-92,12.4,8.98,9.76),Vector4(-74,14.4,8.54,12.43),Vector4(-56,15.56,8.35,14.76),Vector4(-30,16.1544,8.24,16.0),Vector4(24,16.1544,8.2,16.02),Vector4(68,15.88,8.15,15.62),Vector4(94,14.04,8.11,13.17),Vector4(116,10.77,8.04,8.60),Vector4(127,7.1,7.90,3.57),Vector4(133,4.1,7.76,.63),Vector4(135.3312,.50,7.67,.14)]

func _section(row: Vector4, side: float) -> PackedVector3Array:
	var result := super._section(row,side)
	var rake := smoothstep(_half_length()-27.0,_half_length(),absf(row.x))
	for i in range(5):
		result[i].z -= signf(row.x)*rake * [7.8,6.9,4.6,3.1,1.2][i]
	return result

func _ready() -> void:
	flight_y = 14.1 if hornet else 14.326
	_steel = _paint("70838a" if hornet else "6a7a86")
	_hull_side = _paint("657780" if hornet else "586779")
	_upper = _paint("9ba5a7" if hornet else "7e8a96")
	_underbody = _paint("744a43")
	_dark = _paint("343e48")
	_edge = _paint("4b5b64")
	_deck = _paint("687682")
	_wood = _paint("526a79" if hornet else "657c87")
	_glass = _paint("293d47")
	_mark = _paint("82919a")
	_group = _layer("CurvedWaterlineHull")
	_hull()
	_group = _layer("HangarAndGallery")
	_hangar()
	_group = _layer("FlightDeckAndCenterlineElevators")
	_flight_deck()
	_group = _layer("HornetIsland" if hornet else "SaratogaIsland")
	if hornet: _hornet_island()
	else: _saratoga_island()
	_group = _layer("FixedExteriorFittings")
	_fittings()

func _deck_plan() -> Array[Vector2]:
	if hornet:
		return [Vector2(-117.8,3.1),Vector2(-114,9.2),Vector2(-104,13.8),Vector2(-88,15.47),Vector2(-70,16.0),Vector2(-34,16.83),Vector2(-14,17.3736),Vector2(37,17.3736),Vector2(73,16.9),Vector2(93,16.3),Vector2(111,14.7),Vector2(119.8,12.0),Vector2(121.2,8.9)]
	return [Vector2(-128,3.8),Vector2(-126,10.15),Vector2(-119,14.5),Vector2(-106,18.05),Vector2(-83,18.82),Vector2(-50,19.17),Vector2(50,19.17),Vector2(80,18.95),Vector2(101,17.76),Vector2(118,15.42),Vector2(127,12.0),Vector2(130.6,9.6)]

func _deck_half(z: float) -> float:
	var plan := _deck_plan()
	for i in range(plan.size()-1):
		if z <= plan[i+1].x:
			return lerpf(plan[i].y,plan[i+1].y,clampf(inverse_lerp(plan[i].x,plan[i+1].x,z),0,1))
	return plan[-1].y

func _surface() -> SurfaceTool:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	s.set_smooth_group(-1)
	return s

func _flight_deck() -> void:
	var top := _surface()
	var edge := _surface()
	var deck := _deck_plan()
	for i in range(deck.size()-1):
		var a := deck[i]
		var b := deck[i+1]
		_quad(top,Vector3(-a.y,flight_y,a.x),Vector3(a.y,flight_y,a.x),Vector3(b.y,flight_y,b.x),Vector3(-b.y,flight_y,b.x),Vector3.UP)
		_quad(edge,Vector3(-a.y+.22,flight_y-.64,a.x),Vector3(a.y-.22,flight_y-.64,a.x),Vector3(b.y-.22,flight_y-.64,b.x),Vector3(-b.y+.22,flight_y-.64,b.x),Vector3.DOWN)
		for side: float in [-1,1]:
			_quad(edge,Vector3(side*a.y,flight_y,a.x),Vector3(side*b.y,flight_y,b.x),Vector3(side*(b.y-.22),flight_y-.64,b.x),Vector3(side*(a.y-.22),flight_y-.64,a.x),Vector3(side,0,0))
	for end: int in [0,deck.size()-1]:
		var s := deck[end]
		_quad(edge,Vector3(-s.y,flight_y,s.x),Vector3(s.y,flight_y,s.x),Vector3(s.y-.22,flight_y-.64,s.x),Vector3(-s.y+.22,flight_y-.64,s.x),Vector3.FORWARD if end == 0 else Vector3.BACK)
	_commit("Continuous thin timber flight deck outline",top,_wood)
	_commit("Rolled flight deck belt and underside",edge,_edge)
	var seams := _surface()
	for x: float in range(-18,19):
		var start := 0.0
		var end := 0.0
		for z: float in range(int(ceilf(deck[0].x))+1,int(floorf(deck[-1].x))-1):
			if _deck_half(z)-.18>absf(x):
				if start == 0.0: start=z
				end=z
		if end>start:
			_quad(seams,Vector3(x-.014,flight_y+.005,start),Vector3(x+.014,flight_y+.005,start),Vector3(x+.014,flight_y+.005,end),Vector3(x-.014,flight_y+.005,end),Vector3.UP)
	_commit("Fine stagger field of longitudinal plank seams",seams,_paint("435e6a" if hornet else "59717d"))
	if hornet:
		_lift("Forward", -79.5,12.5,14.35)
		_lift("Midships", -3.8,12.5,14.35)
		_lift("After", 78.0,12.5,14.35)
	else:
		_lift("Forward", -84.1,13.4,14.4)
		_lift("After", 81.5,13.4,14.4)
	for i in range(3,deck.size()-2):
		for side: float in [-1,1]:
			var a := deck[i-1]
			var b := deck[i]
			_spar("Inset side deck edge stripe",Vector3(side*(a.y-.43),flight_y+.025,a.x),Vector3(side*(b.y-.43),flight_y+.025,b.x),.048,_mark)

func _lift(label: String, z: float, w: float, d: float) -> void:
	_box(label+" centerline lift dark frame",Vector3(0,flight_y+.011,z),Vector3(w,.022,d),_edge)
	_box(label+" centerline lift flush timber panel",Vector3(0,flight_y+.023,z),Vector3(w-.22,.023,d-.22),_wood)
	for x: float in range(-6,7):
		_box("Lift timber seam",Vector3(x,flight_y+.037,z),Vector3(.025,.005,d-.27),_edge)

func _hangar() -> void:
	var y := flight_y-.61
	var n := 19 if hornet else 23
	var step := 10.2 if hornet else 10.0
	var span := Vector3(0,(y+8.05)/2,0)
	_octagon("Common enclosed hangar core",span,18.2 if hornet else 23.8,y-8.05,n*step,2.7,_edge)
	for j in range(n):
		var z := (j-(n-1)*.5)*step
		var wide := minf(_deck_half(z)-1.65, (13.6 if hornet else 16.4)-pow(absf(z)/115,3)*(3.3 if hornet else 4.4))
		var lower := _deck_height(z)-.16
		for side: float in [-1,1]:
			var x := side*wide
			var shutter := (j in [0,3,4,7,10,12,16,18]) if hornet else (j%3 != 1)
			_box("Hangar support separated bay pier",Vector3(x,(y+lower)*.5,z-step*.47),Vector3(.78,y-lower,1.02),_steel)
			_box("Fixed recessed side bay backing",Vector3(x-side*.49,(y+lower)*.5,z),Vector3(.27,y-lower,step-.78),_hull_side if shutter else _dark)
			_box("Hangar exterior weather sill",Vector3(x,(lower+.28),z),Vector3(1.55,.45,step),_steel)
			_box("Long deck carrier girder",Vector3(x,y-.24,z),Vector3(1.72,.48,step),_steel)
			if shutter:
				for k in [1,2,3]:
					_box("Shutter shadow fold",Vector3(x-side*.34,lerpf(lower,y,k*.23),z),Vector3(.13,.047,step-.9),_edge)
			if not shutter:
				_spar("Gallery underdeck knee",Vector3(x-side*1.1,lower+.45,z-step*.43),Vector3(side*(_deck_half(z)-.75),y-.04,z-step*.43),.42,_steel)
			if j>1 and j<n-2 and (j%4!=0 or not hornet):
				var wx := side*(_deck_half(z)-.62)
				_box("Footwalk gallery plate",Vector3(wx,y-.41,z),Vector3(1.1,.18,step-.09),_steel)
				_rail(Vector3(wx+side*.56,y-.34,z-step*.47),Vector3(wx+side*.56,y-.34,z+step*.47),3)
	for direction: float in [-1,1]:
		for j in range(3 if hornet else 2):
			var z := direction*((99.3 if hornet else 111.0)+j*(7.2 if hornet else 7.0))
			var w := minf(_side_at(z,_deck_height(z))-1.05,_deck_half(z)-2.0)
			var y0 := _deck_height(z)-.06
			for side: float in [-1,1]:
				var x := side*w
				_box("Flight deck tapered end stanchion",Vector3(x,(y+y0)*.5,z),Vector3(.53,y-y0,.70),_steel)
				_spar("Outer end cantilever brace",Vector3(x,y0,z),Vector3(side*(_deck_half(z)-.59),y,z),.33,_steel)
				_spar("End deck longitudinals",Vector3(x,y-.28,z-3.7),Vector3(x*.82,y-.28,z+3.7),.30,_steel)
			_box("Shallow exposed end crossbeam",Vector3(0,y-.33,z),Vector3(_deck_half(z)*1.83,.60,.57),_steel)
	for row in _deck_plan():
		for side: float in [-1,1]:
			var x := side * (row.y-.59)
			if absf(row.x)>104.0:
				_box("Edge rim visual tie-off",Vector3(x,y-.08,row.x),Vector3(.35,.48,.21),_steel)

func _rail(a: Vector3,b: Vector3,count: int) -> void:
	for h: float in [.35,.75]:
		_spar("Exterior gallery rails",a+Vector3.UP*h,b+Vector3.UP*h,.052,_upper)
	for i in range(count+1):
		var p := a.lerp(b,float(i)/float(count))
		_box("Gallery stanchion",p+Vector3.UP*.38,Vector3(.085,.78,.085),_upper)

func _panes(x: float, y: float, z: float, w: float, d: float, n: int) -> void:
	for side: float in [-1,1]:
		for i in range(n):
			_box("Glazed wheelhouse frames",Vector3(x+side*(w*.5+.01),y,z+((i+.5)/n-.5)*d*.77),Vector3(.11,.65,d*.59/n),_glass)
	for i in range(5):
		_box("Bridge forward glazing",Vector3(x+(i-2)*w*.126,y,z-d*.5-.022),Vector3(w*.102,.65,.115),_glass)

func _yard(x: float,y: float,z: float,span: float) -> void:
	_spar("Foremast crosstree",Vector3(x-span,y,z),Vector3(x+span,y,z),.23,_steel)
	for side: float in [-1,1]:
		_spar("Crosstree bracing",Vector3(x,y-1.45,z),Vector3(x+side*span,y,z),.12,_steel)
		_spar("Small fixed signal staff",Vector3(x+side*(span-.37),y,z),Vector3(x+side*(span-.37),y+1.35,z),.075,_dark)

func _screen(x: float,y: float,z: float,w: float,h: float) -> void:
	for i in range(5):
		var xx := x+(i/4.0-.5)*w
		_spar("Display-only antenna lattice",Vector3(xx,y-h*.5,z),Vector3(xx,y+h*.5,z),.085,_steel)
	for i in range(4):
		var yy := y+(i/3.0-.5)*h
		_spar("Display-only antenna lattice",Vector3(x-w*.5,yy,z),Vector3(x+w*.5,yy,z),.096,_steel)

func _funnel(x: float,z: float,b: float,h: float,w: float,d: float, cut: float) -> void:
	_octagon("Slab stack exterior",Vector3(x,b+h*.5,z),w,h,d,cut,_steel,.98)
	_octagon("Dark stack cap lip",Vector3(x,b+h+.25,z),w+.37,.61,d+.46,cut,_dark)
	_octagon("Soot-dark stack crown",Vector3(x,b+h+.575,z),w-.48,.06,d-.51,cut,_glass)
	for side: float in [-1,1]:
		for j in range(5):
			_box("Stack surface seam",Vector3(x+side*w*.496,b+h*.49,z+(j-2)*d*.15),Vector3(.07,h*.78,.092),_edge)

func _hornet_island() -> void:
	var x := 11.9
	var y := flight_y
	_octagon("Starboard lower island footprint",Vector3(x,y+1.21,-1.3),8.45,2.42,29.7,1.74,_steel)
	_octagon("Forward rounded island",Vector3(x,y+3.9,-11.2),7.55,4.1,13.6,2.28,_upper,.93)
	_octagon("Bridge overhanging wings",Vector3(x,y+5.49,-12.1),10.55,.50,12.75,2.45,_steel)
	_octagon("Enclosed wheelhouse",Vector3(x,y+6.37,-12.1),8.5,1.72,9.06,1.51,_upper)
	_panes(x,y+6.62,-12.1,8.5,9.06,6)
	_octagon("Bridge roof cap",Vector3(x,y+7.28,-12.1),8.94,.25,9.48,1.62,_steel)
	_octagon("Open short upper platform",Vector3(x,y+7.68,-11.73),6.65,.42,6.92,1.7,_steel)
	_funnel(x,7.75,y+2.24,6.15,6.15,13.7,1.5)
	_pipe("Foremast center tube",Vector3(x,y+12.7,-5.65),13.9,.31,.19,1,_steel)
	for side: float in [-1,1]:
		_spar("Tripod outer legs",Vector3(x+side*3.30,y+4.0,.15),Vector3(x,y+14.38,-5.65),.52,_steel)
		_spar("Stack-side pole appearance",Vector3(x+side*2.98,y+3,9.25),Vector3(x+side*2.62,y+10.2,9.25),.22,_upper)
	for i in range(2):
		_octagon("Tiered foretop",Vector3(x,y+10.83+i*4.4,-5.65),3.50-i*.86,.59,4.52-i*1.07,.77,_upper)
	_yard(x,y+16.3,-5.65,4.15)
	_screen(x,y+19.5,-5.65,4.12,1.37)
	_pipe("After standing spar",Vector3(x,y+5.78,17.0),8.6,.15,.12,1,_steel)
	_box("Aft enclosed island end",Vector3(x,y+1.5,16.4),Vector3(5.95,3.0,7.7),_steel)
	for i in range(5):
		_box("Small black side hatches",Vector3(16.12,y+1.2,-13+i*4.25),Vector3(.12,.89,.61),_dark)
	var ax := x
	for j in range(3):
		var ay := y+2.55+j*1.47
		_octagon("After island stacked catwalk",Vector3(ax,ay,16.25),6.82,.21,4.6,.86,_steel)
		_rail(Vector3(ax-2.36,ay+.14,18.40),Vector3(ax+2.36,ay+.14,18.40),4)
		for sx: float in [-2.89,2.89]:
			_box("After platform corner vertical",Vector3(ax+sx,ay+.60,17.65),Vector3(.10,1.19,.10),_upper)
	_spar("Inset after island diagonal stair profile",Vector3(ax+2.49,y+2.55,18.33),Vector3(ax-2.44,y+5.48,18.33),.34,_steel)
	_crane(15.5,42.0)

func _saratoga_island() -> void:
	var x := 15.35
	var y := flight_y
	_octagon("Long starboard island skirt",Vector3(x,y+1.25,2.7),8.63,2.5,38.6,1.68,_steel)
	_octagon("Rounded forward bridge foundation",Vector3(x-.43,y+3.73,-11.2),7.53,3.74,13.05,2.22,_steel)
	_octagon("1942 chart level",Vector3(x-.35,y+5.58,-12.23),8.72,1.67,10.48,2.40,_upper)
	_panes(x-.35,y+5.83,-12.23,8.72,10.48,7)
	_octagon("Bridge overhang",Vector3(x-.35,y+6.51,-12.23),9.32,.34,10.93,2.24,_steel)
	_octagon("Open upper forward bridge",Vector3(x-.3,y+7.68,-12.10),7.98,.82,7.70,1.72,_steel)
	_rail(Vector3(x-3.18,y+7.97,-15.44),Vector3(x+3.18,y+7.97,-15.44),5)
	_box("Stack base lengthwise casing",Vector3(x,y+2.25,8.7),Vector3(8.10,4.5,23.0),_steel)
	_funnel(x,9.8,y+2.28,10.44,7.12,24.75,1.75)
	_pipe("Post-refit slender pole mast",Vector3(x-.7,y+13.6,-7.4),13.0,.35,.15,1,_steel)
	_octagon("Mast platform",Vector3(x-.7,y+11.88,-7.4),3.7,.51,3.5,.7,_upper)
	_yard(x-.7,y+16.0,-7.4,4.79)
	_pipe("Signal tip",Vector3(x-.7,y+20.75,-7.4),2.6,.146,.056,1,_steel)
	_box("Small aft platform",Vector3(x,y+1.66,25.4),Vector3(6.77,3.32,8.34),_steel)
	_pipe("Aft antenna pole",Vector3(x,y+5.44,24.68),6.68,.26,.13,1,_steel)
	_screen(x,y+9.09,24.68,4.97,1.38)
	for i in range(6):
		_box("Stack base side access cap",Vector3(x+4.08,y+1.23,-3+i*4),Vector3(.16,.88,.69),_edge)
	for j in range(7):
		var zz := 1.2 + 2.61*j
		_oval_recess(x+3.54,y+6.57,zz,1.62,1.69)
		_oval_recess(x-3.54,y+6.57,zz,1.62,1.69,-1)
	for j in [1,3,5,6]:
		_oval_recess(x+3.54,y+9.10,1.2+2.61*j,1.45,1.49)
		_oval_recess(x-3.54,y+9.10,1.2+2.61*j,1.45,1.49,-1)
	for i in range(2):
		_octagon("Forward wheelhouse bridge curved fascia",Vector3(x-.39,y+4.91-i*.39,-12.4),8.0-i*.28,.17,11.4-i*.27,1.73,_upper)
	_octagon("Small squared canopy on open bridge",Vector3(x+.44,y+8.63,-12.30),6.83,.33,5.73,.99,_steel)
	_crane(17.4,52.0)

func _oval_recess(x: float,y: float,z: float,w: float,h: float,side: float = 1) -> void:
	var backing := _surface()
	var rims := _surface()
	var at := Vector3(x,y,z)
	for i in range(14):
		var a := TAU*i/14.0
		var b := TAU*(i+1)/14.0
		var u := Vector3(0,sin(a)*h*.5,cos(a)*w*.5)
		var v := Vector3(0,sin(b)*h*.5,cos(b)*w*.5)
		_tri(backing,at,at+u,at+v,side*Vector3.RIGHT)
		var lip := side*.10*Vector3.RIGHT
		_quad(rims,at+u*.87+lip,at+u+lip,at+v+lip,at+v*.87+lip,side*Vector3.RIGHT)
	_commit("Inset oval stack air grille shade",backing,_edge)
	_commit("Perforated grille housing rim",rims,_upper)
	for i in range(-2,3):
		_spar("Recessed dark grille visual",at+Vector3(side*.067,-h*.32,i*w*.143),at+Vector3(side*.067,h*.32,i*w*.143),.045,_steel)


func _crane(x: float,z: float) -> void:
	var p := Vector3(x,flight_y,z)
	_pipe("Fixed starboard crane pedestal",p+Vector3.UP*.8,1.6,.63,.52,1,_steel)
	var base := p+Vector3.UP*1.7
	var tip := base+Vector3(-3.1,4.4,6.4)
	for k: float in [-.39,.39]:
		_spar("Static crane truss profile",base+Vector3(k,0,0),tip+Vector3(k,0,0),.18,_steel)
	for i in range(5):
		var a := base.lerp(tip,i/5.0)
		var b := base.lerp(tip,(i+1)/5.0)
		_spar("Crane lattice",a+Vector3(-.39,0,0),b+Vector3(.39,0,0),.11,_steel)
	_spar("Fixed crane top silhouette",base+Vector3.UP*1.5,tip,.10,_steel)

func _fittings() -> void:
	for side: float in [-1,1]:
		for j in range(17):
			var z := -83.0+j*10.3
			var y := minf(6.48,_deck_height(z)-1.1)
			var w := _side_at(z,y)+.03
			_box("Rows of exterior service scuttles",Vector3(side*w,y,z),Vector3(.15,.39,.60),_dark)
		for z: float in ([-54,-27,68,90] if hornet else [-46,40,63,93]):
			var x := side*(_deck_half(z)-1.53)
			_octagon("Exterior side sponson cap",Vector3(x,flight_y-2.08,z),3.34,.81,5.95,1.09,_steel)
			_spar("Sponson exterior knee",Vector3(x-side*2.35,flight_y-4.85,z),Vector3(x,flight_y-2.52,z),.57,_steel)
			_rail(Vector3(x+side*1.58,flight_y-1.67,z-1.72),Vector3(x+side*1.58,flight_y-1.67,z+1.72),3)
		for z: float in [-103.0,100.4]:
			var sw := _deck_half(z)-5.5
			var y := _deck_height(z)
			_octagon("Fixed davit boat exterior",Vector3(side*sw,y+.43,z),1.86,.88,6.75,.72,_upper,.90)
			_spar("Static davit arm",Vector3(side*(sw-2.7),y,z-1.5),Vector3(side*(sw+.48),y+2.47,z-.58),.24,_steel)
	for z: float in [-_half_length()+7,_half_length()-6.4]:
		var y := _deck_height(z)
		for side: float in [-1,1]:
			_pipe("Fore/aft deck mooring silhouettes",Vector3(side*1.62,y+.34,z),.68,.29,.32,1,_dark)
	if hornet:
		_camo()

func _camo() -> void:
	# Chart major broad tonal fields from February imagery, not fabricated paint IDs.
	var stations := _stations()
	var dark := _paint("465c68")
	for side: float in [-1,1]:
		var surface := _surface()
		for j in range(1,stations.size()-2):
			if j in [3,7,10,13]: continue
			var a := _section(stations[j],side)
			var b := _section(stations[j+1],side)
			var al := a[3].lerp(a[4],.10 if j%2==0 else .63)
			var bl := b[3].lerp(b[4],.42 if j%3==0 else .16)
			var ah := a[4].lerp(a[5],.56 if j%2==0 else .11)
			var bh := b[4].lerp(b[5],.15 if j%2==0 else .46)
			var p := Vector3(side*.025,0,0)
			_quad(surface,al+p,bl+p,b[4]+p,a[4]+p,Vector3(side,0,0))
			_quad(surface,a[4]+p,b[4]+p,bh+p,ah+p,Vector3(side,0,0))
		_commit("Approximate 1942 low-contrast disruption",surface,dark)

func _side_at(z: float,y: float) -> float:
	var rows := _stations()
	for j in range(rows.size()-1):
		if z <= rows[j+1].x:
			var t := inverse_lerp(rows[j].x,rows[j+1].x,z)
			var a := _section(rows[j],1)
			var b := _section(rows[j+1],1)
			var p := a[4].lerp(b[4],t)
			var q := a[5].lerp(b[5],t)
			return lerpf(p.x,q.x,clampf(inverse_lerp(p.y,q.y,y),0,1))
	return rows[-1].y
