extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
## Standalone game exhibit. Above-water contours adapted from the 21 August
## 1944 yard photos; submerged surfaces and fittings are display approximations.
const HALF: float = 103.632 # DANFS public 680 ft envelope, converted only
const BEAM: float = 16.4846
const DRAFT: float = 8.69  # study waterline, not an archive photo loading condition
const B: Array[Vector4] = [
	Vector4(-HALF,.030,10.48,.021),Vector4(-102.1,1.97,10.13,.63),Vector4(-99,3.69,9.74,1.71),
	Vector4(-95,5.37,9.21,3.27),Vector4(-89,7.79,8.72,5.76),Vector4(-80,10.63,8.03,8.65),
	Vector4(-69,13.13,7.64,11.91),Vector4(-57,15.05,7.40,14.12),Vector4(-43,16.05,7.23,15.42),
	Vector4(-26,BEAM,7.15,16.03),Vector4(-10,BEAM,7.14,16.12),Vector4(9,BEAM,7.15,16.02),
	Vector4(25,BEAM,7.12,15.90),Vector4(42,16.26,7.02,15.61),Vector4(56,15.30,6.94,14.21),
	Vector4(69,13.84,6.86,12.72),Vector4(81,12.12,6.77,10.73),Vector4(91,10.34,6.72,8.71),
	Vector4(98,8.7,6.78,7.35),Vector4(101,7.04,6.81,6.03),Vector4(HALF,4.23,6.85,4.01),
]

func _stations() -> Array[Vector4]:
	return B

func _half_length() -> float:
	return HALF

func _draft() -> float:
	return DRAFT

func _section(row: Vector4, side: float) -> PackedVector3Array:
	var points: PackedVector3Array = super._section(row,side)
	var bow: float = 5.32*smoothstep(0.0,1.0,(-row.x-76.0)/(HALF-76.0))
	var stern: float = 4.10*smoothstep(0.0,1.0,(row.x-89)/(HALF-89))
	for i: int in points.size()-1:
		points[i].z += (bow-stern)*(1.0-float(i)/5.0)
	return points

func _ready() -> void:
	_steel = _paint("768082")
	_upper = _paint("8a9494")
	_deck = _paint("657278")
	_dark = _paint("303a40")
	_underbody = _paint("78494a")
	_hull_side = _paint("708083")
	_group = _layer("Hull and deck")
	_hull()
	_group = _layer("Compact superstructure")
	_superstructure()
	_group = _layer("Single funnel and masts")
	_uprights()
	_group = _layer("Fixed deck silhouettes")
	_silhouettes()
	_group = _layer("Exterior edges and furnishings")
	_edges()

func _superstructure() -> void:
	_octagon("Citadel footprint",Vector3(0,8.94,0.9),27.2,3.82,75.0,5.23,_steel)
	_octagon("Compact forward galleries lower body",Vector3(0,13.11,-15.8),20.0,4.63,31.0,3.3,_steel,.92)
	_octagon("Forward raised base",Vector3(0,17.02,-18.2),16.15,4.35,22.72,2.64,_steel,.89)
	_octagon("First broad bridge shelf",Vector3(0,19.32,-20.6),18.3,1.27,17.8,3.09,_upper)
	_octagon("Pilot enclosure",Vector3(0,21.0,-22.1),12.72,2.55,12.08,2.38,_steel,.93)
	_octagon("Sight deck crown",Vector3(0,22.47,-22.25),14.21,1.07,12.86,2.49,_upper)
	_octagon("Upper tower",Vector3(0,24.29,-19.85),8.65,3.31,9.66,1.66,_steel,.93)
	_pipe("Rounded upper visible crown",Vector3(0,27.03,-19.8),2.91,2.77,2.44,1.02,_steel)
	_octagon("Lookout top",Vector3(0,29.43,-19.53),5.64,2.14,5.10,.91,_upper,.73)
	_octagon("After fixed casing",Vector3(0,12.96,24.23),19.1,4.12,21.3,2.92,_steel)
	_octagon("Aft navigation shelf",Vector3(0,15.52,25.28),13.0,1.31,11.1,2.42,_upper)
	for s:float in [-1.0,1.0]:
		_spar("Forward bridge wraparound glass",Vector3(s*3.91,21.45,-28.16),Vector3(s*6.14,21.45,-25.97),.60,_dark)
		_spar("Bridge lateral glass",Vector3(s*6.11,21.45,-25.94),Vector3(s*6.11,21.45,-23.35),.59,_dark)
		for x:float in [1.45,2.87,4.09]:
			_spar("Bridge window mullion",Vector3(s*x,21.15,-28.46),Vector3(s*x,21.77,-28.46),.106,_upper)
		for z:float in [-10.6,1.99,14.45,28.45]:
			var p := Vector3(s*10.78,11.8,z)
			_octagon("Terraced side sponson",p,5.55,2.53,10.43,1.78,_steel)
			_octagon("Side gallery cap",p+Vector3.UP*1.45,5.9,.55,9.88,1.69,_upper)
			_spar("Slanted side gallery skirt",p+Vector3(s*3.0,-1.22,1.69),p+Vector3(s*1.67,-2.59,1.17),.65,_steel)
		for z:float in [-30.8,-2.8,5.08,30.9]:
			_octagon("Stowage trunk silhouette",Vector3(s*7.05,11.43,z),2.37,1.22,4.2,.55,_upper)
		_spar("Bridge terrace rail",Vector3(s*8.01,20.53,-26.7),Vector3(s*8.01,20.53,-18.6),.11,_upper)
	_spar("Continuous front glass strip",Vector3(-3.95,21.45,-28.17),Vector3(3.95,21.45,-28.17),.60,_dark)

func _uprights() -> void:
	_octagon("Funnel support enclosure",Vector3(0,15.19,4.49),12.9,4.29,15.3,2.18,_steel)
	_pipe("Single broad rounded stack",Vector3(0,21.01,4.84),8.60,4.42,3.99,1.47,_steel)
	_pipe("Funnel lip",Vector3(0,25.28,4.84),.43,4.21,4.06,1.48,_upper)
	_pipe("Funnel opening shadow",Vector3(0,25.52,4.84),.065,3.52,3.46,1.47,_dark)
	_mast(-17.42,20.0,34.28,4.72)
	_mast(18.30,15.4,31.69,4.9)

func _mast(z:float, foot:float, top:float, half_span:float) -> void:
	_spar("Mast slender main spar",Vector3(0,foot,z),Vector3(0,top,z+.45),.24,_dark)
	for s:float in [-1.0,1.0]:
		_spar("Mast brace",Vector3(s*2.84,foot,z+1.39),Vector3(0,top-4.96,z+.2),.22,_steel)
		_spar("Uneven mast platform brace",Vector3(s*half_span,top-4.5,z),Vector3(0,top-6.79,z+.2),.14,_steel)
	_spar("Cross yard",Vector3(-half_span,top-4.5,z),Vector3(half_span,top-4.5,z),.12,_dark)
	for x:float in [-2.1,-1.06,0,1.06,2.1]:
		_spar("Open aerial silhouette",Vector3(x,top-2.0,z+.39),Vector3(x,top-3.19,z+.39),.065,_dark)
	_spar("Open aerial outline",Vector3(-2.1,top-2.0,z+.40),Vector3(2.1,top-2.0,z+.40),.062,_dark)

func _silhouettes() -> void:
	# Large inert deck shapes establish appearance only; no functional interfaces.
	for i:int in 3:
		var z:float = [-66.2,-47.7,60.9][i]
		var rise:float = [1.10,4.91,1.31][i]
		var y:float = _deck_height(z)
		var dir:float = -1 if i < 2 else 1
		_pipe("Fixed primary deck housing base",Vector3(0,y+rise*.5-.06,z),rise,5.58,5.31,1.0,_steel)
		_octagon("Fixed octagonal exterior housing",Vector3(0,y+rise+1.81,z),11.9,3.74,12.1,1.92,_upper,.88)
		_octagon("Faceted roof contour",Vector3(0,y+rise+3.74,z+dir*.52),9.68,.65,9.29,1.65,_steel,.88)
		for x:float in [-1.52,0,1.52]:
			_spar("Inert silhouette feature",Vector3(x,y+rise+1.94,z+dir*5.05),Vector3(x,y+rise+2.33,z+dir*11.4),.49,_dark)
	for s:float in [-1.0,1.0]:
		for z:float in [-17.68,-3.6,11.32,25.8]:
			_octagon("Fixed small side silhouette",Vector3(s*12.7,13.93,z),4.48,1.8,4.86,.67,_upper,.89)
		for z:float in [44.9,77.9,88.3]:
			_pipe("Round exterior platform",Vector3(s*8.7,_deck_height(z)+.58,z),1.18,2.15,2.06,1.02,_steel)
			_pipe("Recessed platform shadow",Vector3(s*8.7,_deck_height(z)+1.2,z),.06,1.75,1.72,1.0,_dark)
		var a := Vector3(s*6.13,7.18,84.2)
		var b := Vector3(s*10.19,7.88,92.92)
		_spar("Fixed stern deck cradle",a,b,1.13,_steel)
		_spar("Raised stern handling rail",a+Vector3.UP*.55,b+Vector3.UP*.55,.19,_dark)
	_spar("Stern handling crane leg",Vector3(0,7.33,91.11),Vector3(0,13.64,88.81),.77,_steel)
	_spar("Stern handling crane top",Vector3(0,13.64,88.81),Vector3(-2.72,13.04,82.49),.44,_steel)

func _edges() -> void:
	for s:float in [-1.0,1.0]:
		for i:int in range(2,B.size()-1):
			var a:Vector4 = B[i]
			var b:Vector4 = B[i+1]
			var p := Vector3(s*(a.y-.44),a.z,a.x)
			var q := Vector3(s*(b.y-.44),b.z,b.x)
			_spar("Sheerline upper rail",p+Vector3.UP*.91,q+Vector3.UP*.91,.070,_upper)
			_spar("Sheerline lower rail",p+Vector3.UP*.44,q+Vector3.UP*.44,.047,_steel)
			var n:int = maxi(1,ceili(p.distance_to(q)/3.84))
			for j:int in n:
				var w:Vector3 = p.lerp(q,float(j)/n)
				_spar("Rail upright",w,w+Vector3.UP*.92,.080,_steel)
		for z:float in [-94.7,-90.1,-81.4,43.5,73.4,82.5,94.5]:
			_octagon("Deck fittings",Vector3(s*4.21,_deck_height(z)+.36,z),1.52,.74,2.54,.2,_steel)
		_spar("Anchor deck lead",Vector3(s*.87,_deck_height(-90)+.11,-90),Vector3(s*1.43,_deck_height(-100)+.11,-100),.18,_dark)
		for z:float in [-69.5,-61.9,-54.4,-43.8,53.95,61.9,72.85]:
			_box("Visible narrow walkway stripe",Vector3(s*5.63,_deck_height(z)+.046,z),Vector3(.17,.085,4.06),_steel)
	var p := Vector3(0,_deck_height(-101.2),-101.2)
	_spar("Foredeck signal staff",p,p+Vector3.UP*3.51,.12,_dark)
