extends "res://scenes/ships/us_carrier_1942_visual/carrier.gd"
## Interpretive static models. Decorative poses do not represent any real mechanism.
const GUN_RIG := preload("res://scripts/presentation/models/archive_gun_rig.gd")
@export var kaga := true
var _canvas: StandardMaterial3D

func _half_length() -> float:
	return 124.48 if kaga else 113.65

func _draft() -> float:
	return 9.3 if kaga else 7.7

func _stations() -> Array[Vector4]:
	if kaga:
		return [Vector4(-124.48,.1,10.6,.12),Vector4(-120,1.72,10.2,.9),Vector4(-110,5.4,9.86,3.6),Vector4(-94,10.1,9.32,8.0),Vector4(-72,14.26,8.91,12.4),Vector4(-48,15.75,8.59,14.7),Vector4(-22,16.20,8.35,15.43),Vector4(20,16.23,8.22,15.53),Vector4(57,16,8.15,15.12),Vector4(81,14.5,8.04,13.54),Vector4(102,11.0,8.02,9.0),Vector4(116,7.7,8.03,4.2),Vector4(123,4.4,8.08,1.31),Vector4(124.48,3.12,8.12,.46)]
	return [Vector4(-113.65,.1,10.44,.13),Vector4(-109,1.9,10.16,.88),Vector4(-101,4.8,9.8,2.76),Vector4(-89,7.5,9.45,5.6),Vector4(-67,10.9,8.7,9.40),Vector4(-47,11.9,8.38,10.80),Vector4(-25,12.39,8.03,11.78),Vector4(16,12.34,7.89,11.91),Vector4(47,11.84,7.73,11.37),Vector4(72,10.44,7.65,8.91),Vector4(89,7.92,7.62,5.82),Vector4(102,5.2,7.67,2.7),Vector4(111,3.6,7.74,.82),Vector4(113.65,2.32,7.81,.35)]

func _deck_plan() -> Array[Vector2]:
	if kaga:
		return [Vector2(-121,3.8),Vector2(-118.3,7.4),Vector2(-112,10.65),Vector2(-97,13.65),Vector2(-72,15.35),Vector2(-46,15.38),Vector2(27,15.39),Vector2(64,15.13),Vector2(84,14.51),Vector2(108,12.45),Vector2(119,9.64),Vector2(122,7.9)]
	return [Vector2(-105.2,3.3),Vector2(-102.5,6.0),Vector2(-94,8.63),Vector2(-80,10.67),Vector2(-63,12.98),Vector2(-37,13.76),Vector2(16,13.72),Vector2(48,13.16),Vector2(76,12.08),Vector2(95,10.23),Vector2(103.1,7.75),Vector2(105.4,6.25)]

func _ready() -> void:
	flight_y = 15.65 if kaga else 13.8
	_steel = _paint("6d797a")
	_hull_side = _paint("586769" if kaga else "617271")
	_upper = _paint("8e9691")
	_underbody = _paint("694842")
	_dark = _paint("364245")
	_deck = _paint("667270")
	_edge = _paint("454e50")
	_wood = _paint("858678" if kaga else "919080")
	_glass = _paint("283739")
	_mark = _paint("c0bfb1")
	_canvas = _paint("9a9480")
	_group = _layer("WaterlineHull")
	_hull()
	_group = _layer("HangarDeckAndWeatherWalks")
	_hangar_art()
	_group = _layer("TimberFlightDeck")
	_flat_deck_art()
	_deck_details()
	_group = _layer("StarboardBridge" if kaga else "PortBridge")
	_bridge_art()
	_group = _layer("DownturnedExhaustHousing")
	_exhaust_art()
	_hull_details()
	_group = _layer("MuseumDisplayStations")
	if kaga:
		_kaga_exhibit()
	else:
		_hiryu_exhibit()

func _hangar_art() -> void:
	var step := 9.0
	var n := 21 if kaga else 19
	var low := 8.45 if kaga else 8.03
	var high := flight_y-.66
	_octagon("Recessed hangar mass",Vector3(0,(low+high)*.5,0),23.1 if kaga else 17.9,high-low,n*step,2.4,_dark)
	for side: float in [-1.0,1.0]:
		for j: int in n:
			var z: float = (j-(n-1)*.5)*step
			var x := side*(_deck_half(z)-(1.92 if kaga else 1.75))
			var foot := _deck_height(z)
			var shutter := (j%5!=2) if kaga else (j%4!=1 and j%6!=0)
			_box("Outer hangar upright",Vector3(x,(high+foot)*.5,z-step*.42),Vector3(.84,high-foot,.87),_steel)
			_box("Weather-tight hangar wall" if shutter else "Inset shaded bay",Vector3(x-side*.46,(high+foot)*.5,z+.41),Vector3(.33,high-foot-.25,step-.90),_hull_side if shutter else _dark)
			_box("Full-length catwalk sill",Vector3(x+side*.68,foot+.12,z),Vector3(1.66,.35,step-.25),_steel)
			if j>0 and j<n-1:
				_rail(Vector3(x+side*1.41,foot+.25,z-step*.47),Vector3(x+side*1.41,foot+.25,z+step*.37),3)
			if shutter:
				for k: int in range(1,4):
					_box("Weather skin seam",Vector3(x-side*.28,lerpf(foot,high,.20*k),z+.5),Vector3(.06,.055,step*.8),_edge)
		for z: float in ([-105.,-97.,98.,109.] if kaga else [-94.,-86.,88.,98.]):
			var x := (_deck_half(z)-2.25)*side
			var foot := _deck_height(z)
			_box("Visible end stanchion",Vector3(x,(high+foot)*.5,z),Vector3(.45,high-foot,.60),_steel)
			_spar("Visible fore and aft deck bracing",Vector3(x-side*1.35,foot+.11,z),Vector3(x,high,z+1.0),.46,_steel)
			_spar("Edge underslung girder",Vector3(x-side*.62,foot+.26,z-2.8),Vector3(x+side*.85,high,z+1.9),.28,_steel)

func _flat_deck_art() -> void:
	var top := _surface()
	var rim := _surface()
	var plan := _deck_plan()
	for i: int in range(plan.size()-1):
		var a := plan[i]
		var b := plan[i+1]
		_quad(top,Vector3(-a.y,flight_y,a.x),Vector3(a.y,flight_y,a.x),Vector3(b.y,flight_y,b.x),Vector3(-b.y,flight_y,b.x),Vector3.UP)
		_quad(rim,Vector3(-a.y,flight_y-.55,a.x),Vector3(a.y,flight_y-.55,a.x),Vector3(b.y,flight_y-.55,b.x),Vector3(-b.y,flight_y-.55,b.x),Vector3.DOWN)
		for side: float in [-1.,1.]:
			_quad(rim,Vector3(side*a.y,flight_y,a.x),Vector3(side*b.y,flight_y,b.x),Vector3(side*b.y,flight_y-.55,b.x),Vector3(side*a.y,flight_y-.55,a.x),Vector3(side,0,0))
	for i: int in [0,plan.size()-1]:
		var e := plan[i]
		_quad(rim,Vector3(-e.y,flight_y,e.x),Vector3(e.y,flight_y,e.x),Vector3(e.y,flight_y-.55,e.x),Vector3(-e.y,flight_y-.55,e.x),Vector3.FORWARD if i == 0 else Vector3.BACK)
	_commit("Clean timber deck",top,_wood)
	_commit("Rolled deck perimeter edge",rim,_edge)
	var stripe := _surface()
	for x: float in [-9.,-7.,-5.,-3.,-1.,1.,3.,5.,7.,9.]:
		var start: float = -96.0 if kaga else -84.0
		var end: float = 96.0 if kaga else 85.0
		_quad(stripe,Vector3(x-.04,flight_y+.054,start),Vector3(x+.048,flight_y+.054,start),Vector3(x+.048,flight_y+.054,end),Vector3(x-.04,flight_y+.054,end),Vector3.UP)
	_commit("Soft staggered longitudinal plank seams",stripe,_paint("777968" if kaga else "838473"))
	var lifts: Array = [-77.,-8.,74.] if kaga else [-76.,1.,74.]
	for z: float in lifts:
		_box("Flush lift outline",Vector3(0,flight_y+.068,z),Vector3(12.3,.098,13.94),_edge)
		_box("Lift timber surface",Vector3(0,flight_y+.130,z),Vector3(11.9,.06,13.55),_wood)
		for x: int in range(-5,6):
			_box("Inset plank joint",Vector3(x,flight_y+.167,z),Vector3(.079,.012,13.22),_canvas)

func _deck_details() -> void:
	var stripe := _surface()
	for j: int in 20:
		var z: float = -71.0+j*7.3
		_quad(stripe,Vector3(-.15,flight_y+.105,z),Vector3(.15,flight_y+.105,z),Vector3(.15,flight_y+.105,z+4.15),Vector3(-.15,flight_y+.105,z+4.15),Vector3.UP)
	for z: float in ([-110.,109.] if kaga else [-96.,95.]):
		_quad(stripe,Vector3(-4.6,flight_y+.11,z),Vector3(4.6,flight_y+.11,z),Vector3(4.6,flight_y+.11,z+.42),Vector3(-4.6,flight_y+.11,z+.42),Vector3.UP)
	_commit("Subdued interpretive deck stripes",stripe,_mark)
	for s: float in [-1.,1.]:
		for z: float in [-55.0,55.0]:
			var x := s*(_deck_half(z)-.95)
			_box("Canvas-covered deck-edge detail",Vector3(x,flight_y+.20,z),Vector3(.84,.42,1.65),_canvas)

func _bridge_art() -> void:
	var side := 1.0 if kaga else -1.0
	var p := Vector3(side*(12.1 if kaga else 10.9),flight_y,-32.5 if kaga else 1.0)
	var len := 12.7 if kaga else 11.0
	var wid := 5.1 if kaga else 4.74
	_octagon("Long low bridge plinth",p+Vector3.UP*.64,wid+.8,1.28,len+1.9,.67,_steel)
	_octagon("Island lower skin",p+Vector3.UP*2.20,wid,3.18,len,.80,_steel)
	_octagon("Angular bridge gallery",p+Vector3(0,4.15,-1.11),wid+.36,1.22,len*.84,.60,_upper)
	_panes(p.x,p.y+4.21,p.z-1.30,wid+.2,len*.85,6 if kaga else 5)
	_octagon("Bridge eyebrow roof",p+Vector3(0,4.97,-1.12),wid+.62,.52,len*.91,.59,_steel)
	if kaga:
		_octagon("Compact forward viewing cupola",p+Vector3(0,5.91,-3.0),wid*.66,1.56,5.05,.55,_upper)
		_octagon("Kaga stepped rear signal office",p+Vector3(0,3.08,4.72),4.28,2.82,4.68,.65,_steel)
		_box("Kaga island lower forward glazing",p+Vector3(0,2.81,-6.41),Vector3(3.26,.43,.095),_glass)
		_box("Short navigation shadow inset",p+Vector3(0,5.84,-5.55),Vector3(wid*.48,.56,.09),_glass)
	else:
		_octagon("Boxed upper bridge on port island",p+Vector3(-.11,6.10,-1.81),wid*.77,1.77,6.15,.52,_steel)
		_box("Upper bridge windows",p+Vector3(-.1,6.30,-4.90),Vector3(wid*.53,.46,.075),_glass)
		_box("Raised glasshouse cap",p+Vector3(-.11,7.16,-1.81),Vector3(wid*.83,.45,6.26),_upper)
		_octagon("Hiryu angular aft island shoulder",p+Vector3(-.08,2.77,3.95),4.39,3.92,4.91,.72,_steel,.87)
		_octagon("Hiryu forward outboard catwalk",p+Vector3(-wid*.56,3.35,-3.6),1.23,.23,5.83,.38,_steel)
		_rail(p+Vector3(-wid*.66,3.47,-6.11),p+Vector3(-wid*.66,3.47,-.91),4)
		for z: float in [-4.26,-3.45,-2.64,-1.83]:
			_box("Hiryu island port upper window",p+Vector3(-wid*.39,6.24,z),Vector3(.095,.42,.48),_glass)
	var m := p+Vector3(0,5.1,2.8)
	var mast_top := 12.8 if kaga else 13.9
	_spar("Slender mast spine",m,m+Vector3(0,mast_top-4.1,1.53),.42,_steel)
	for d: float in [-1.,1.]:
		_spar("Triangular mast brace",m+Vector3(d*1.22,-1.6,2.53),m+Vector3(0,5.9,.98),.23,_steel)
	_yard(m.x,m.y+5.6,m.z+.95,6.45 if kaga else 5.5)
	_yard(m.x,m.y+7.7,m.z+1.21,3.9)
	_rail(p+Vector3(-wid*.46,5.01,3),p+Vector3(wid*.46,5.01,3),4)

func _exhaust_art() -> void:
	if kaga:
		# Large unified housing to starboard, pitched outboard below the flight-deck line.
		_octagon("Broad exterior starboard exhaust casing",Vector3(14.70,12.04,-3),5.8,5.4,16.0,1.2,_steel)
		_octagon("Lower outward turn of exhaust silhouette",Vector3(17.27,10.72,-2),5.12,3.80,15.0,1.1,_hull_side)
		_box("Exhaust shadow strip",Vector3(19.10,9.13,-2),Vector3(1.30,.64,13.7),_dark)
	else:
		for z: float in [2.,26.]:
			_octagon("Separate starboard exhaust outer housing",Vector3(13.88,10.45,z),4.4,4.2,12.25,.8,_steel)
			_octagon("Outboard and downward exhaust lip",Vector3(15.35,9.41,z+.27),3.7,2.88,11.8,.71,_hull_side)
			_box("Exhaust lip shadow",Vector3(16.85,8.22,z+.33),Vector3(1.06,.51,9.2),_dark)

func _hull_details() -> void:
	var stern := 98.0 if kaga else 86.2
	for side: float in [-1.,1.]:
		var x := side*(_deck_half(stern)-.18)
		_box("Aft outer weather balcony",Vector3(x,flight_y-2.52,stern),Vector3(1.92,.35,10.3 if kaga else 8.0),_steel)
		_rail(Vector3(x+side*.92,flight_y-2.3,stern-4.0),Vector3(x+side*.92,flight_y-2.3,stern+4.0),4)
		_rail(Vector3(x+side*.92,flight_y-2.3,stern+4.0),Vector3(x-side*.80,flight_y-2.3,stern+4.0),2)
		for z: float in [-84.,-80.,-76.]:
			for dy: float in [0.0,.85]:
				var keel_edge := _side_at(z,5.55+dy)
				_box("Sunk shadow at bowside service panel",Vector3(side*(keel_edge+.025),5.55+dy,z),Vector3(.09,.31,.61),_dark)
		var m := Vector3(side*(_deck_half(stern)-1.0),flight_y-2.14,stern-2.9)
		var q := m+Vector3(side*.16,5.8 if kaga else 7.6,1.8)
		_spar("Aft thin signal mast",m,q,.23,_steel)
		_spar("Aft signal crosspiece",q+Vector3(-1.5,-1.17,-.18),q+Vector3(1.5,-1.17,-.18),.11,_steel)

func _kaga_exhibit() -> void:
	# Broadside low galleries and separate raised twin exhibits; closed art only.
	for side: float in [-1.,1.]:
		var name_side := "Port" if side < 0.0 else "Starboard"
		var front := Vector3(side,0,0)
		for i: int in range(5):
			var z: float = 50. + float(i)*8.2
			var y: float = _deck_height(z)-1.18
			var p := Vector3(side*(_side_at(z,y)+.08),y,z)
			_octagon("Kaga inset hull casemate",p-front*.48,1.32,2.19,3.49,.48,_hull_side)
			_box("Kaga dark casemate face",p+front*.21,Vector3(.12,1.49,2.29),_glass)
			var pivot: Vector3 = p+front*.28
			var start: int = _group.get_child_count()
			var shield := _pipe("Kaga round casemate insert",pivot,.34,.61,.61,1.0,_steel)
			shield.rotation.z = -side*PI*.5
			var body: Array = _group.get_children().slice(start)
			var spar := _pipe("Kaga closed single outline",pivot+front*1.59,3.29,.18,.13,1.,_steel)
			spar.rotation.z = -side*PI*.5
			GUN_RIG.attach(self,"Kaga_%s_Casemate_%02d" % [name_side,i+1],
				"secondary",pivot,pivot,front,body,[spar])
		var heavy: Array[float] = [-74.,-59.,59.,73.]
		for i: int in range(heavy.size()):
			var z: float = heavy[i]
			_carrier_gallery_piece("Kaga_%s_Twin_%02d" % [name_side,i+1],side,z,
				flight_y-(2.64 if i<2 else 3.38),1.0,"dedicated_aa",true,2)
		for i: int in range(3):
			var z: float = [-41.0,39.5,87.2][i]
			_carrier_gallery_piece("Kaga_%s_Light_%02d" % [name_side,i+1],side,z,
				flight_y-2.19,.57,"dedicated_aa",false,2)

func _carrier_gallery_piece(id: String,side: float,z: float,y: float,scale_art: float,role: String,shielded: bool,bars: int) -> void:
	var edge_x: float = _deck_half(z)
	var p := Vector3(side*(edge_x+1.06*scale_art),y,z)
	var front := Vector3(side,0,0)
	_octagon("Fixed side platform",p-front*.43-Vector3.UP*.28,5.2*scale_art,.51,5.9*scale_art,.79*scale_art,_steel)
	for d: float in [-1.,1.]:
		_spar("Visible platform bracket",Vector3(side*(edge_x-1.6),y-1.95*scale_art,z+d*1.40),
			p+Vector3(side*.66*scale_art,-.37,d*1.40),.24*scale_art,_steel)
	_pipe("Permanent circular plinth",p+Vector3.UP*.23,.42,.75*scale_art,.70*scale_art,1.,_edge)
	var start: int = _group.get_child_count()
	if shielded:
		_octagon("Enclosed slanted display hood",p+Vector3.UP*(.24+.63*scale_art),
			2.63*scale_art,1.11*scale_art,2.61*scale_art,.43*scale_art,_steel,.85)
	else:
		_pipe("Open tub deck insert",p+Vector3.UP*.39,.27,.94*scale_art,.92*scale_art,1.,_steel)
		_box("Visible open mounting bracket",p+Vector3.UP*(.44+.52*scale_art),Vector3(.79,.71,1.25)*scale_art,_upper)
	var body: Array = _group.get_children().slice(start)
	var parts: Array = []
	var pivot := p+Vector3.UP*(.44+.50*scale_art)
	for n: int in range(bars):
		var dz: float = (float(n)-(float(bars)-1.)*.5)*.87*scale_art
		var item := _pipe("Closed decorative twin outline",pivot+front*1.34*scale_art+Vector3(0,0,dz),
			2.81*scale_art,.15*scale_art,.10*scale_art,1.,_steel)
		item.rotation.z = -side*PI*.5
		parts.append(item)
	GUN_RIG.attach(self,id,role,p,pivot,front,body,parts)

func _hiryu_exhibit() -> void:
	# Raised optical silhouettes only; no Kaga-style lower hull casemates.
	for side: float in [-1.,1.]:
		var name_side := "Port" if side < 0.0 else "Starboard"
		var positions: Array = [-57.,-41.,68.] if side < 0. else [-59.,-43.,65.]
		for i: int in range(positions.size()):
			var z: float = positions[i]
			_carrier_gallery_piece("Hiryu_%s_DualPurpose_%02d" % [name_side,i+1],side,z,
				flight_y-(1.84 if i<2 else 2.43),.87,"secondary",false,2)
		var light: Array[float] = [-72.,45.,84.]
		for i: int in range(light.size()):
			_carrier_gallery_piece("Hiryu_%s_Light_%02d" % [name_side,i+1],side,light[i],
				flight_y-2.65,.48,"dedicated_aa",false,3)
