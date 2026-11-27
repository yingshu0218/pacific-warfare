extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
## Rebuilt standalone exterior, late 1930s. Nothing moves or functions.
const HALF:float = 111.0
const BEAM:float = 15.5
const DRAFT:float = 9.6
const B: Array[Vector4] = [
	Vector4(-HALF,.02,10.8,.012),Vector4(-109,1.14,10.54,.54),Vector4(-105,2.84,10.13,1.55),
	Vector4(-100,4.24,9.65,2.57),Vector4(-92,6.23,9.07,4.52),Vector4(-82,8.63,8.37,6.90),
	Vector4(-71,11.17,7.9,9.73),Vector4(-57,13.32,7.65,12.18),Vector4(-42,14.71,7.58,13.93),
	Vector4(-24,BEAM,7.53,15.23),Vector4(-7,BEAM,7.48,15.31),Vector4(12,BEAM,7.43,15.35),
	Vector4(28,15.45,7.34,15.12),Vector4(43,15.16,7.09,14.68),Vector4(59,14.21,6.86,13.82),
	Vector4(70,13.23,6.64,12.60),Vector4(82,11.77,6.36,10.98),Vector4(94,9.32,6.21,8.35),
	Vector4(101,7.67,6.27,6.83),Vector4(107,5.16,6.33,4.56),Vector4(HALF,2.42,6.38,1.92),
]

func _stations()->Array[Vector4]:
	return B

func _half_length()->float:
	return HALF

func _draft()->float:
	return DRAFT

func _section(row:Vector4,side:float)->PackedVector3Array:
	var p: PackedVector3Array = super._section(row,side)
	var rake: float = 6.57*smoothstep(0.0,1.0,(-row.x-81)/(HALF-81.0))
	var tuck: float = 5.23*smoothstep(0.0,1.0,(row.x-91)/(HALF-91))
	for i:int in p.size()-1:
		p[i].z += (rake-tuck)*(1.0-float(i)/5.0)
	return p

func _ready()->void:
	_steel = _paint("727b7a")
	_upper = _paint("929b96")
	_deck = _paint("877960")
	_dark = _paint("333e40")
	_underbody = _paint("774b47")
	_hull_side = _paint("687474")
	_group = _layer("Hull and deck")
	_hull()
	_group = _layer("Stepped bridge and deckhouses")
	_pagoda()
	_group = _layer("Funnels and tripod")
	_masts()
	_group = _layer("Fixed deck silhouettes")
	_silhouettes()
	_group = _layer("Rails and weather deck")
	_details()

func _pagoda()->void:
	_octagon("Broad stepped midships base",Vector3(0,9.47,-11.4),25.13,4.31,60.85,3.52,_steel,.96)
	_octagon("Forward enclosed foot",Vector3(0,13.13,-26.7),17.2,4.85,22.39,2.13,_steel,.83)
	_octagon("Tall tower core",Vector3(0,23.1,-29.3),7.33,22.4,9.63,1.15,_steel,.82)
	# Asymmetric ledges, gaps and glazed belts, not identical concentric discs.
	for r:Array in [[15.8,-30.2,15.96,15.0,.75],[18.17,-30.9,12.81,12.15,.72],
		[20.81,-31.1,14.1,13.5,1.09],[23.75,-31.50,12.13,11.77,.71],
		[26.14,-31.82,11.01,11.08,.84],[28.58,-32.01,8.93,10.1,.67],
		[31.02,-32.08,8.11,8.38,.74],[33.42,-31.67,6.64,7.49,.68]]:
		var y:float=r[0];var z:float=r[1];var w:float=r[2];var l:float=r[3];var h:float=r[4]
		var pole:=Vector3(0,y,z)
		_octagon("Exterior platform tier",pole,w,h,l,minf(w,l)*.20,_upper)
		_octagon("Tier backing",pole-Vector3.UP*.80,w*.74,1.32,l*.71,minf(w,l)*.13,_steel,.88)
		var face:float=z-l/2.0-.035
		_spar("Profile glass ribbon",Vector3(-w*.25,y+.40,face),Vector3(w*.25,y+.40,face),.36,_dark)
		for j:int in range(-2,3):
			var x:float=float(j)*w*.095
			_spar("Glazing rhythm mullion",Vector3(x,y+.23,face-.043),Vector3(x,y+.56,face-.043),.05,_upper)
		for s:float in [-1.0,1.0]:
			var start:=Vector3(s*w*.31,y+.35,face)
			var end:=Vector3(s*w*.49,y+.35,face+l*.20)
			_spar("Angled end of window ribbon",start,end,.32,_dark)
			if y<28.0:
				_spar("External bridge terrace brace",Vector3(s*w*.46,y-.18,z-.41*l),Vector3(s*2.5,y-1.46,z-.28*l),.24,_steel)
	_octagon("Crowded observation head",Vector3(0,35.03,-31.33),6.57,2.98,6.98,1.16,_steel,.97)
	_octagon("Final dark overhang",Vector3(0,36.71,-31.65),7.04,.59,7.48,1.26,_dark)
	_spar("Bridge top slender staff",Vector3(0,36.77,-31.22),Vector3(0,40.12,-31.1),.14,_dark)
	_octagon("After control rooms",Vector3(0,10.3,30.47),17.56,6.46,18.83,2.73,_steel,.91)
	_octagon("Aft raised platform",Vector3(0,14.38,30.68),12.77,1.37,13.92,2.46,_upper)
	_octagon("Aft stepped enclosure",Vector3(0,16.30,31.87),7.88,3.03,7.6,1.40,_steel,.94)
	for s:float in [-1.0,1.0]:
		for z:float in [-16,1.77,15.20,21.57]:
			var p:=Vector3(s*9.63,12.2,z)
			_octagon("Scalloped gallery edge",p,5.48,2.21,11.00,1.74,_steel,.98)
			_spar("Gallery edge shadow",p+Vector3(s*2.74,-.37,-2.65),p+Vector3(s*2.74,-.37,2.65),.125,_dark)

func _masts()->void:
	for r:Array in [[-9.31,22.99,9.38,3.49,1.44],[9.84,23.78,10.56,3.18,1.27]]:
		var stem:=Vector3(0,r[1],r[0])
		var e:float=r[4]
		# The archive profile shows the trunks descending into enclosed midship blocks.
		var footing:=Vector3(0,14.60,stem.z-.68)
		_octagon("Enclosed funnel footing",footing,11.41,7.04,13.46,1.98,_steel,.91)
		_octagon("Funnel block crown",footing+Vector3.UP*3.54,10.91,.57,12.72,1.84,_upper,.94)
		var h:float=r[2]
		var rad:float=r[3]
		var stack:=_pipe("Raked funnel shell",stem,h,rad,rad*.87,e,_steel)
		stack.rotation.x=deg_to_rad(10.0)
		var top:=stem+Vector3(0,h*.5,.086*h)
		_pipe("Funnel lip",top,.43,rad*.91,rad*.88,e,_upper)
		_pipe("Deep funnel top shadow",top+Vector3.UP*.25,.066,rad*.77,rad*.76,e,_dark)
	var z:float=16.68
	_spar("Tripod tall spar",Vector3(0,14.79,z),Vector3(0,42.3,z+1.15),.26,_dark)
	for s:float in [-1.0,1.0]:
		_spar("Tripod side legs",Vector3(s*4.16,11.39,z+3.29),Vector3(0,33.91,z+.48),.29,_dark)
		_spar("Yard terrace supports",Vector3(s*4.30,36.77,z+.97),Vector3(0,34.5,z+.82),.145,_steel)
	_spar("Tripod top lengthwise",Vector3(-5.8,36.93,z+1),Vector3(5.8,36.93,z+1),.105,_upper)
	_spar("Tripod top yard",Vector3(-3.25,40.9,z+1.10),Vector3(3.25,40.9,z+1.10),.080,_dark)
	_spar("Inert aft handling boom",Vector3(0,25.47,z+.22),Vector3(-7.13,19.44,39.75),.36,_steel)
	for j:int in 4:
		var t:float=float(j)/3.0
		_spar("Aft handling line",Vector3(-7.13*t,25.47-6.03*t,lerpf(z+.22,39.75,t)),Vector3(0,30.41,z+.35),.036,_dark)

func _silhouettes()->void:
	for i:int in 4:
		var z:float=[-70.7,-48.7,49.90,70.4][i]
		var rise:float=[.95,4.61,3.59,.74][i]
		var y:float=_deck_height(z)
		var dir:float=-1.0 if i<2 else 1.0
		_pipe("Static housing riser",Vector3(0,y+rise*.5-.06,z),rise,4.91,4.57,1.0,_steel)
		_octagon("Static deck housing",Vector3(0,y+rise+1.28,z),9.86,2.63,11.28,1.24,_upper,.91)
		_octagon("Sloped cover profile",Vector3(0,y+rise+2.64,z+dir*.28),9.45,.45,9.86,1.42,_steel,.83)
		for x:float in [-1.12,1.12]:
			_spar("Inert photo silhouette spar",Vector3(x,y+rise+1.52,z+dir*4.75),Vector3(x,y+rise+1.98,z+dir*10.4),.40,_dark)
	for s:float in [-1.0,1.0]:
		for z:float in [-22.10,-9.65,2.61,13.1]:
			var p:=Vector3(s*12.18,8.04,z)
			_octagon("Outer shell dark recess",p,3.58,1.55,3.74,.41,_dark,.93)
			_octagon("Outer casing edge",p+Vector3.UP*.81,3.78,.27,4.04,.52,_upper)
		for z:float in [39.70,43.92,82.93]:
			var p:=Vector3(s*8.48,_deck_height(z)+.65,z)
			_octagon("Deck service cover",p,4.02,1.24,5.71,.68,_steel,.88)

func _details()->void:
	for s:float in [-1.0,1.0]:
		for i:int in range(2,B.size()-1):
			var a:Vector4=B[i]
			var b:Vector4=B[i+1]
			var p:=Vector3(s*(a.y-.29),a.z,a.x)
			var q:=Vector3(s*(b.y-.29),b.z,b.x)
			_spar("Main deck perimeter top",p+Vector3.UP*.97,q+Vector3.UP*.97,.071,_upper)
			_spar("Main deck perimeter mid",p+Vector3.UP*.47,q+Vector3.UP*.47,.044,_steel)
			var count:int=maxi(1,ceili(p.distance_to(q)/3.71))
			for j:int in count:
				var r:Vector3=p.lerp(q,float(j)/count)
				_spar("Deck stanchion",r,r+Vector3.UP*.97,.073,_steel)
		for z:float in [-96.80,-88.81,-76.93,54.11,80.5,90.54,98.18]:
			_octagon("Deck fixtures",Vector3(s*4.29,_deck_height(z)+.41,z),1.43,.84,3.19,.31,_steel)
		var boat:=Vector3(s*7.34,10.49,36.65)
		_octagon("Utility launch",boat,2.81,1.21,9.53,.83,_upper,.83)
		_octagon("Utility launch dark interior",boat+Vector3.UP*.66,2.17,.16,7.52,.64,_dark)
		_spar("Bow equipment leads",Vector3(s*.95,_deck_height(-94)+.07,-94),Vector3(s*1.10,_deck_height(-104)+.07,-104),.16,_dark)
	var foot:=Vector3(0,_deck_height(-108.1),-108.1)
	_spar("Foredeck signal staff",foot,foot+Vector3.UP*3.74,.12,_dark)
