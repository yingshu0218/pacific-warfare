extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
## Dated static game exhibit, not a technical scan. Bow -Z and design waterline y=0.

const HALF_LENGTH: float = 101.88
const HALF_BEAM: float = 10.365
const DRAFT: float = 6.32
const CONTOUR: Array[Vector4] = [
	Vector4(-HALF_LENGTH,0.02,9.45,0.02),Vector4(-100,1.23,9.26,0.36),
	Vector4(-97,2.46,8.99,1.26),Vector4(-92,3.94,8.50,2.70),
	Vector4(-85,5.34,7.95,4.09),Vector4(-75,7.20,7.44,6.23),
	Vector4(-63,8.50,7.11,7.82),Vector4(-50,9.45,6.96,8.98),
	Vector4(-36,10.13,6.89,9.92),Vector4(-19,HALF_BEAM,6.86,10.16),
	Vector4(0,HALF_BEAM,6.79,10.18),Vector4(18,10.29,6.68,10.01),
	Vector4(34,9.96,6.47,9.61),Vector4(48,9.40,6.18,8.84),
	Vector4(60,8.58,5.87,7.85),Vector4(73,7.28,5.35,6.35),
	Vector4(84,5.92,5.02,4.90),Vector4(93,4.35,4.92,3.38),
	Vector4(98,2.90,4.93,1.75),Vector4(100.5,1.57,4.96,0.85),
	Vector4(HALF_LENGTH,0.25,4.98,0.14),
]


func _stations() -> Array[Vector4]:
	return CONTOUR


func _half_length() -> float:
	return HALF_LENGTH


func _draft() -> float:
	return DRAFT


func _section(row: Vector4, side: float) -> PackedVector3Array:
	var section: PackedVector3Array = super._section(row,side)
	var forward_rake: float = 5.4*smoothstep(0.0,1.0,(-row.x-80.0)/(HALF_LENGTH-80.0))
	var tuck: float = 2.5*smoothstep(0.0,1.0,(row.x-91.0)/(HALF_LENGTH-91.0))
	for index: int in range(section.size() - 1):
		var p: Vector3 = section[index]
		p.z += (forward_rake-tuck)*(1.0-float(index)/5.0)
		section[index] = p
	return section


func _ready() -> void:
	_steel = _paint("6e7a80")
	_deck = _paint("666964")
	_upper = _paint("849094")
	_dark = _paint("2e373b")
	_hull_side = _paint("67747a")
	_underbody = _paint("764748")
	_group = _layer("Hull and deck")
	_hull()
	_group = _layer("Bridge and deckhouses")
	_bridge()
	_group = _layer("Funnels and masts")
	_funnels()
	_group = _layer("Static exterior silhouettes")
	_silhouettes()
	_group = _layer("Deck furniture and railings")
	_deck_details()
	_group = _layer("Underwater fittings")
	_underwater()


func _bridge() -> void:
	_octagon("Bridge lower deckhouse",Vector3(0,9.0,-24.6),15.2,4.6,23.6,2.4,_steel,0.9)
	_octagon("Bridge sloped front volume",Vector3(0,14.2,-27.6),12.6,7.1,16.9,2.2,_steel,0.72)
	_octagon("Bridge wraparound platform",Vector3(0,17.48,-28.9),12.4,0.75,13.6,1.65,_upper)
	_octagon("Bridge middle enclosure",Vector3(0,19.1,-29.6),9.0,3.0,10.2,1.36,_steel,0.95)
	_octagon("Window surround",Vector3(0,21.1,-30.0),10.3,1.72,8.0,1.13,_upper)
	_box("Front viewing strip",Vector3(0,21.31,-34.04),Vector3(7.6,0.78,0.1),_dark)
	for i: int in range(6):
		_box("Window divider",Vector3((i-2.5)*1.11,21.31,-34.11),Vector3(0.14,0.78,0.10),_steel)
	for side: float in [-1.0,1.0]:
		_box("Side viewing strip",Vector3(side*5.16,21.32,-29.7),Vector3(0.12,0.72,3.7),_dark)
		_octagon("Bridge wing",Vector3(side*5.7,17.68,-28.6),2.5,0.9,4.2,0.5,_steel)
		_spar("Bridge wing brace",Vector3(side*4.05,15.4,-28.6),Vector3(side*5.61,17.39,-28.6),0.44,_steel)
	_octagon("High lookout platform",Vector3(0,22.21,-29.7),8.4,0.70,7.3,1.1,_upper)
	_octagon("Upper bridge cabinet",Vector3(0,23.5,-29.9),5.8,2.0,5.8,0.9,_steel,0.91)
	_octagon("Bridge crown",Vector3(0,25.02,-29.4),4.8,1.27,4.8,0.75,_upper)
	_pipe("Top lookout silhouette",Vector3(0,26.36,-29.4),1.65,1.88,1.68,1.0,_steel)
	_octagon("Long center deckhouse",Vector3(0,8.49,3.9),16.25,3.5,35,1.8,_steel,0.94)
	_octagon("After deckhouse",Vector3(0,7.79,25.5),14.3,3.3,24,2.3,_steel)
	_octagon("After overlook",Vector3(0,11.13,24.5),8.4,3.6,8.9,1.1,_upper,0.83)


func _funnels() -> void:
	# Front trunk visibly bends toward the stern; aft stack is slimmer and straighter.
	var trunk := _pipe("Raked forward funnel",Vector3(0,15.17,-9.12),11.2,3.62,3.04,1.31,_steel)
	trunk.rotation.x = deg_to_rad(19.0)
	var rim := _pipe("Broad forward funnel lip",Vector3(0,20.45,-7.30),0.55,3.3,3.2,1.27,_steel)
	rim.rotation.x = trunk.rotation.x
	var dark := _pipe("Front stack interior",Vector3(0,20.74,-7.20),0.09,2.87,2.87,1.24,_dark)
	dark.rotation.x = trunk.rotation.x
	_pipe("After funnel seat",Vector3(0,10.5,4.1),1.65,3.05,2.84,1.23,_steel)
	_pipe("Straight after funnel",Vector3(0,15.05,4.1),9.05,2.67,2.32,1.25,_steel)
	_pipe("After funnel lip",Vector3(0,19.67,4.1),0.54,2.46,2.37,1.25,_steel)
	_pipe("After stack interior",Vector3(0,19.99,4.1),0.09,2.04,2.04,1.20,_dark)
	_mast(-16.85,10.1,35.5,2.45)
	_mast(40.0,8.21,34.2,3.5)
	_octagon("After mast deck seat",Vector3(0,7.36,40.5),9.1,2.1,5.8,0.74,_steel)


func _mast(z: float, start: float, tip: float, root_spread: float) -> void:
	_spar("Mast vertical",Vector3(0,start,z),Vector3(0,tip,z+1.2),0.35,_dark)
	for side: float in [-1.0,1.0]:
		_spar("Mast lateral brace",Vector3(side*root_spread,start,z+2.1),Vector3(0,tip-6.2,z+1),0.27,_steel)
	_spar("Mast forward brace",Vector3(0,start,z-2.5),Vector3(0,tip-7,z+0.8),0.27,_steel)
	_spar("Mast crossbar",Vector3(-5.1,tip-5.4,z+0.83),Vector3(5.1,tip-5.4,z+0.83),0.15,_dark)
	_spar("Mast upper crossbar",Vector3(-2.5,tip-1.6,z+1.16),Vector3(2.5,tip-1.6,z+1.16),0.10,_dark)
	_octagon("Mast lookout platform",Vector3(0,tip-8.3,z+0.8),3.0,0.45,3.6,0.63,_steel)


func _silhouettes() -> void:
	for index: int in range(5):
		var z: float = [-62.0,-52.8,-44.9,47.0,58.1][index]
		var rise: float = [0.71,3.64,0.82,3.36,0.69][index]
		var y: float = _deck_height(z)
		_pipe("Main visual seat",Vector3(0,y+rise*0.5-0.09,z),rise,3.05,2.82,1.0,_steel)
		_octagon("Large enclosed silhouette",Vector3(0,y+rise+1.23,z),6.5,2.55,7.75,0.95,_upper,0.92)
		var facing: float = -1.0 if index < 2 else 1.0
		for lateral: float in [-0.88,0.88]:
			_spar("Inert silhouette spar",Vector3(lateral,y+rise+1.35,z+facing*3.42),Vector3(lateral,y+rise+1.60,z+facing*(5.75 if index == 2 else 7.65)),0.27,_dark)
	for side: float in [-1.0,1.0]:
		for z: float in [-11,12]:
			var p := Vector3(side*7.38,9.46,z)
			_pipe("Outboard silhouette platform",p-Vector3.UP*1.28,2.8,1.79,1.58,1.06,_steel)
			_octagon("Small exterior cover",p,3.5,1.55,4.4,0.62,_upper)
		_octagon("Aviation deck rail seat",Vector3(side*4.78,7.11,30.6),2.45,1.53,8.85,0.65,_steel)
		_spar("Aviation deck handling beam",Vector3(side*3.25,7.93,24.6),Vector3(side*6.26,7.93,33.0),0.41,_dark)
	_octagon("Raised aft aviation deck",Vector3(0,7.78,30.4),12.9,1.84,15.1,1.9,_steel)
	_spar("After mast handling boom",Vector3(0,16.0,40.7),Vector3(-4.99,13.4,22.7),0.35,_dark)


func _deck_details() -> void:
	for side: float in [-1.0,1.0]:
		for index: int in range(2,CONTOUR.size()-2):
			var a: Vector4 = CONTOUR[index]
			var b: Vector4 = CONTOUR[index+1]
			var start := Vector3(side*(a.y-0.22),a.z,a.x)
			var finish := Vector3(side*(b.y-0.22),b.z,b.x)
			_spar("Top deck rail",start+Vector3.UP*0.99,finish+Vector3.UP*0.99,0.10,_upper)
			_spar("Lower deck rail",start+Vector3.UP*0.48,finish+Vector3.UP*0.48,0.07,_steel)
			var count: int = ceili(start.distance_to(finish)/3.32)
			for i: int in range(count):
				var v: Vector3 = start.lerp(finish,float(i)/count)
				_spar("Deck stanchion",v,v+Vector3.UP,0.10,_steel)
		for z: float in [-1.6,7.2]:
			var p := Vector3(side*6.14,10.08,z)
			_octagon("Boat cradle",p,2.08,0.51,6.78,0.47,_dark)
			_octagon("Ship launch",p+Vector3.UP*0.64,2.15,0.91,7.28,0.74,_upper)
			_octagon("Launch shadow",p+Vector3.UP*1.14,1.38,0.18,5.56,0.51,_dark)
		_spar("Foredeck chain silhouette",Vector3(side*0.81,_deck_height(-87)+0.08,-87),Vector3(side*1.03,_deck_height(-97)+0.08,-97),0.16,_dark)
		for z: float in [-87.0,-81.0,87.0,93.0]:
			var p := Vector3(side*2.25,_deck_height(z)+0.30,z)
			_pipe("Deck bollard",p,0.70,0.25,0.23,1.0,_dark)
	_octagon("Foredeck windlass cover",Vector3(0,_deck_height(-87)+0.40,-87),3.25,0.84,2.65,0.46,_steel)
	_spar("Stern staff",Vector3(0,4.95,98.7),Vector3(0,8.85,98.7),0.12,_steel)
	_spar("Bow staff",Vector3(0,9.23,-94.1),Vector3(0,12.4,-94.1),0.095,_steel)


func _underwater() -> void:
	# Simplified attached display details, not surveyed mechanical parts.
	_octagon("Stern rudder silhouette",Vector3(0,-2.17,94.2),0.61,4.25,4.65,0.24,_underbody)
	for x: float in [-3.55,-1.79,1.79,3.55]:
		var z: float = 83.7 if absf(x) > 3.0 else 88.5
		var p := Vector3(x,-2.63,z)
		_spar("Underbody fitting support",Vector3(x*0.72,-1.3,z-8.8),p,0.32,_underbody)
		var hub: MeshInstance3D = _pipe("Underbody silhouette hub",p,0.9,0.31,0.28,1.0,_underbody)
		hub.rotation.x = PI/2
		for i: int in range(3):
			var a: float = TAU*float(i)/3.0
			var dir := Vector3(cos(a),sin(a),0)
			_spar("Underbody blade silhouette",p+dir*0.14,p+dir*1.15+Vector3.BACK*0.12,0.27,_underbody)
