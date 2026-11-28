extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
## New game-art reconstruction, Mikasa Memorial Museum's October 1942 view.
## Every fitting is inert. Bow: negative Z. Design waterline: Y=0.
const LOCAL_GUN_RIG = preload("res://scripts/presentation/models/archive_gun_rig.gd")

const HALF_LENGTH: float = 87.05
const DRAFT: float = 5.63
const STATIONS: Array[Vector4] = [
	Vector4(-87.05,0.035,9.24,0.019),Vector4(-86.1,0.43,9.11,0.17),Vector4(-84.6,0.98,8.96,0.41),
	Vector4(-82.5,1.80,8.73,0.81),Vector4(-79.0,2.91,8.40,1.66),Vector4(-75.5,3.87,8.08,2.45),
	Vector4(-70.8,4.73,7.71,3.30),Vector4(-66.0,5.42,7.38,4.15),Vector4(-57.0,6.29,6.97,5.48),
	Vector4(-48.0,6.92,6.76,6.40),Vector4(-37.0,7.35,6.65,6.98),Vector4(-25.0,7.60,6.54,7.45),
	Vector4(-11.0,7.60,6.43,7.45),Vector4(2.0,7.60,6.32,7.43),Vector4(11.0,7.52,5.98,7.27),
	Vector4(18.0,7.44,5.82,7.07),Vector4(33.0,7.10,5.67,6.58),Vector4(46.0,6.52,5.49,5.91),
	Vector4(58.0,5.65,5.33,4.89),Vector4(68.0,4.75,5.15,3.79),Vector4(74.0,4.01,5.05,2.93),
	Vector4(79.1,3.18,5.00,2.05),Vector4(83.3,2.23,5.01,1.09),Vector4(85.8,1.33,5.07,0.52),
	Vector4(87.05,0.41,5.15,0.20),
]
var _canvas: StandardMaterial3D


func _stations() -> Array[Vector4]:
	return STATIONS


func _half_length() -> float:
	return HALF_LENGTH


func _draft() -> float:
	return DRAFT


func _section(row: Vector4, side: float) -> PackedVector3Array:
	var pts: PackedVector3Array = super._section(row,side)
	var rake: float = 6.25*smoothstep(0.0,1.0,(-row.x-68.5)/18.55)
	var tuck: float = 4.2*smoothstep(0.0,1.0,(row.x-66.0)/21.05)
	for j: int in range(pts.size()-1):
		var p: Vector3 = pts[j]
		p.z += (rake-tuck)*(1.0-float(j)/5.0)
		if j == 1:
			var bulb: float = exp(-pow((row.x+82.0)/4.2,2.0))
			p.x *= 1.0+0.25*bulb
			p.z -= 2.6*bulb
		if j == 4:
			p.x *= 1.0-0.16*smoothstep(0.0,1.0,(-row.x-39.0)/48.05)
		pts[j] = p
	return pts


func _ready() -> void:
	_steel = _paint("72807e")
	_deck = _paint("666558")
	_upper = _paint("89948e")
	_dark = _paint("2e373a")
	_hull_side = _paint("687675")
	_underbody = _paint("784949")
	_canvas = _paint("b2aa94")
	_group = _layer("Hull and deck")
	_hull()
	_group = _layer("Bridge and trunk")
	_bridge()
	_group = _layer("Funnel and masts")
	_funnel_and_masts()
	_group = _layer("Deck and aircraft silhouette")
	_deck_layout()
	_group = _layer("Weather deck edging")
	_rails()
	_group = _layer("Submerged silhouettes")
	_underwater()


func _bridge() -> void:
	var z: float = -28.4
	_octagon("Forward deckhouse",Vector3(0,8.58,z),10.4,3.94,15.1,2.16,_steel,0.96)
	_octagon("Tapered bridge base",Vector3(0,11.56,z-1.0),7.87,3.44,9.41,1.49,_steel,0.91)
	_octagon("Overhanging wing gallery",Vector3(0,13.50,z-1.40),9.93,0.51,8.22,1.86,_upper)
	_octagon("Octagonal pilot enclosure",Vector3(0,14.58,z-1.56),7.68,1.66,6.61,1.72,_steel)
	_octagon("Visor",Vector3(0,15.54,z-1.64),8.32,0.37,6.92,1.85,_upper)
	_octagon("Upper lookout tray",Vector3(0,16.36,z-1.03),7.14,0.45,5.13,0.89,_upper)
	_octagon("Offset crown",Vector3(0,17.74,z-0.70),4.35,2.46,4.64,0.75,_steel,0.93)
	_octagon("Crown visor",Vector3(0,19.04,z-0.90),4.66,0.28,4.65,0.88,_upper)
	_pipe("Compact watch silhouette",Vector3(0,19.88,z-0.50),1.48,0.96,0.84,1.0,_steel)
	for j: int in range(7):
		var x: float = (float(j)-3.0)*0.58
		var pane := _box("Individual front pane",Vector3(x,14.63,z-4.873),Vector3(0.51,0.54,0.075),_dark)
		pane.rotation.x = deg_to_rad(-7.0)
	for side: float in [-1.0,1.0]:
		for dz: float in [-1.15,-0.4,0.36,1.12]:
			_box("Individual side pane",Vector3(side*3.856,14.63,z-1.57+dz),Vector3(0.06,0.49,0.64),_dark)
		_octagon("Outer wing shelf",Vector3(side*4.46,13.60,z-1.28),2.15,0.42,3.65,0.58,_upper)
		_spar("Diagonal wing stay",Vector3(side*2.75,11.16,z-0.92),Vector3(side*5.18,13.44,z-1.52),0.18,_steel)
		_spar("Wing rail",Vector3(side*5.48,14.20,z-2.25),Vector3(side*5.48,14.20,z-0.26),0.08,_steel)
		for dz: float in [-2.1,-1.26,-0.39]:
			_spar("Wing rail upright",Vector3(side*5.48,13.81,z+dz),Vector3(side*5.48,14.22,z+dz),0.077,_upper)
	_octagon("Forward service trunk",Vector3(0,7.88,-13.0),8.83,3.1,13.1,1.44,_steel)
	_octagon("Middle roof",Vector3(0,7.24,1.65),10.28,2.63,18.3,1.57,_steel)
	_octagon("After service trunk",Vector3(0,7.04,14.7),8.3,2.44,12.6,1.20,_steel)
	_octagon("After casing",Vector3(0,7.18,34.0),9.27,3.06,20.1,1.55,_steel,0.91)
	_octagon("After lookout",Vector3(0,9.75,34.5),5.36,2.42,5.52,0.88,_upper,0.85)
	for side: float in [-1.0,1.0]:
		for z_slot: float in [-5.4,-2.5,1.15,4.1,6.5]:
			_box("Service wall seam",Vector3(side*5.16,7.37,z_slot),Vector3(0.065,0.52,0.72),_dark)


func _funnel_and_masts() -> void:
	var z: float = -7.4
	_octagon("Funnel seat",Vector3(0,9.70,z),7.05,2.77,9.72,1.42,_steel,0.92)
	var funnel := _pipe("Single oval funnel",Vector3(0,14.23,z),8.98,2.74,2.46,1.52,_steel)
	funnel.rotation.x = deg_to_rad(7.0)
	var lip := _pipe("Dark rolled funnel lip",Vector3(0,18.72,z+0.69),0.68,2.74,2.61,1.54,_dark)
	lip.rotation.x = funnel.rotation.x
	var cap := _pipe("Recessed visual shadow",Vector3(0,19.08,z+0.72),0.068,2.20,2.20,1.54,_dark)
	cap.rotation.x = funnel.rotation.x
	for side: float in [-1.0,1.0]:
		_spar("Funnel external riser",Vector3(side*2.44,10.12,z+1.80),Vector3(side*2.20,18.32,z+2.86),0.22,_upper)
		_octagon("Funnel side service ledge",Vector3(side*4.11,9.42,z+1.7),2.92,0.45,4.85,0.60,_steel)
	_mast(-20.0,10.0,29.60,2.8)
	_mast(32.8,8.67,25.20,2.4)
	_spar("Thin inter-mast line",Vector3(0,27.66,-19.36),Vector3(0,23.6,33.44),0.049,_dark)


func _mast(z: float, foot: float, top: float, spread: float) -> void:
	_spar("Mast pole",Vector3(0,foot,z),Vector3(0,top,z+0.67),0.28,_dark)
	_octagon("Mast observation shelf",Vector3(0,top-6.15,z+0.42),2.46,0.32,2.42,0.44,_steel)
	_spar("Lower mast yard",Vector3(-3.0,top-6.03,z+0.43),Vector3(3.0,top-6.03,z+0.43),0.10,_steel)
	for side: float in [-1.0,1.0]:
		_spar("Mast brace",Vector3(side*spread,foot,z+1.98),Vector3(0,top-6.01,z+0.44),0.22,_steel)
		_spar("Swept mast yard",Vector3(0,top-3.45,z+0.56),Vector3(side*4.49,top-1.55,z+0.56),0.105,_dark)
		_spar("Raised yard stay",Vector3(0,top-5.56,z+0.48),Vector3(side*3.79,top-1.89,z+0.55),0.065,_steel)
		_spar("Thin signal line",Vector3(side*3.42,top-2.13,z+0.54),Vector3(side*1.36,foot+2.42,z-0.54),0.04,_dark)


func _deck_layout() -> void:
	for i: int in range(3):
		var z: float = [-58.0,-44.0,64.4][i]
		var deck_y: float = _deck_height(z)
		var seat: float = 2.74 if i == 1 else 0.60
		var face: float = -1.0 if i < 2 else 1.0
		var y: float = deck_y+seat
		if i == 1:
			_octagon("Raised forward seat surround",Vector3(0,deck_y+0.47,z),6.14,0.98,7.31,1.08,_steel)
		_pipe("Roofed shape seat",Vector3(0,deck_y+seat*0.5,z),seat,2.26,2.11,1.0,_steel)
		var first := _group.get_child_count()
		_octagon("Closed twin-silhouette casing",Vector3(0,y+1.12,z),5.57,2.29,5.83,0.75,_upper,0.85)
		for lane: float in [-0.73,0.73]:
			_spar("Inert display silhouette",Vector3(lane,y+1.12,z+face*2.51),Vector3(lane,y+1.30,z+face*6.13),0.17,_dark)
		var parts := _group.get_children()
		LOCAL_GUN_RIG.attach(self,"main_%02d" % (i+1),"main",Vector3(0,y,z),Vector3(0,y+1.12,z),Vector3(0,0,face),
			parts.slice(first,first+1),parts.slice(first+1))
	_octagon("After working platform",Vector3(0,7.12,27.4),10.03,1.07,25.20,1.47,_upper)
	_octagon("Aircraft display floor",Vector3(0,7.71,29.2),7.89,0.22,15.02,1.05,_deck)
	for side: float in [-1.0,1.0]:
		var boat := Vector3(side*5.15,8.33,7.80)
		_octagon("Launch cradle",boat,1.64,0.68,5.89,0.47,_dark)
		_octagon("Duty launch",boat+Vector3.UP*0.57,2.04,0.82,6.83,0.68,_steel,0.87)
		_octagon("Canvas cover",boat+Vector3.UP*0.99,1.66,0.18,5.53,0.62,_canvas)
		_spar("Duty launch davit",boat+Vector3(side*-0.68,-0.45,1.73),boat+Vector3(side*0.63,1.63,2.05),0.153,_upper)
		var rail_x: float = side*0.48
		_spar("After deck track relief",Vector3(rail_x,7.87,17.5),Vector3(rail_x,7.92,41.3),0.084,_steel)
		_octagon("After side platform",Vector3(side*5.16,7.71,31.2),2.40,0.76,3.73,0.61,_steel)
	_spar("After lifting boom exterior",Vector3(0,13.0,33.0),Vector3(-5.52,11.1,40.5),0.22,_steel)
	_spar("After lifting line",Vector3(0,17.2,33.20),Vector3(-5.49,11.1,40.5),0.076,_dark)
	_floatplane()


func _floatplane() -> void:
	# A parked aircraft outline is visible in the period image; no type assigned.
	var p := Vector3(0.5,8.12,29.82)
	_octagon("Stationary aircraft float",p+Vector3(0,0.31,0),0.53,0.59,5.29,0.25,_steel,0.90)
	_octagon("Stationary aircraft body",p+Vector3(0,1.68,0),0.75,0.72,5.40,0.36,_steel,0.89)
	_octagon("Stationary aircraft wing outline",p+Vector3(0,1.79,-0.38),7.08,0.15,1.57,0.50,_upper,0.95)
	_octagon("Stationary aircraft canopy",p+Vector3(0,2.13,0.04),0.52,0.43,1.68,0.24,_dark,0.81)
	_octagon("Stationary aircraft tail outline",p+Vector3(0,1.90,1.90),2.26,0.13,0.83,0.29,_upper)
	_octagon("Stationary aircraft fin",p+Vector3(0,2.21,1.93),0.21,0.82,0.89,0.10,_steel)
	for side: float in [-1.0,1.0]:
		_octagon("Stationary aircraft outrigger",p+Vector3(side*2.35,0.94,-0.29),0.41,0.37,1.77,0.18,_steel)
		_spar("Stationary aircraft outline stay",p+Vector3(side*2.35,0.98,-0.26),p+Vector3(side*2.24,1.73,-0.30),0.068,_steel)
		_spar("Stationary aircraft float strut",p+Vector3(0,0.49,side*0.89),p+Vector3(0,1.65,side*0.58),0.119,_steel)


func _rails() -> void:
	var ports := SurfaceTool.new()
	ports.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0,1.0]:
		var outward := Vector3(side,0,0)
		for j: int in range(2,STATIONS.size()-2):
			var a: Vector4 = STATIONS[j]
			var b: Vector4 = STATIONS[j+1]
			var p := Vector3(side*(a.y-0.16),a.z,a.x)
			var q := Vector3(side*(b.y-0.16),b.z,b.x)
			for rise: float in [0.38,0.89]:
				_spar("Longitudinal rail",p+Vector3.UP*rise,q+Vector3.UP*rise,0.070,_upper)
			var n: int = ceili(p.distance_to(q)/3.36)
			for k: int in range(n):
				var foot: Vector3 = p.lerp(q,float(k)/float(n))
				_spar("Rail stanchion",foot,foot+Vector3.UP*0.90,0.075,_steel)
			if j >= 5 and j < STATIONS.size()-5:
				var an: PackedVector3Array = _section(a,side)
				var bn: PackedVector3Array = _section(b,side)
				for t: float in [0.22,0.52,0.83]:
					for ring: int in [3,4]:
						var c: Vector3 = an[ring].lerp(an[ring+1],0.62).lerp(bn[ring].lerp(bn[ring+1],0.62),t)+outward*0.055
						for k: int in range(7):
							var angle: float = TAU*float(k)/7.0
							var next: float = angle+TAU/7.0
							_tri(ports,c,c+Vector3(0,cos(angle),sin(angle))*0.103,c+Vector3(0,cos(next),sin(next))*0.103,outward)
		var hawse := Vector3(side*2.60,6.49,-78.66)
		_octagon("Bow hawse relief",hawse,0.35,0.87,1.20,0.13,_upper)
		_octagon("Bow hawse shadow",hawse+outward*0.15,0.25,0.61,0.89,0.10,_dark)
		var foot := hawse+outward*0.38-Vector3.UP*0.98
		_spar("Anchor display shank",hawse+outward*0.37+Vector3.UP*0.32,foot,0.14,_dark)
		for direction: float in [-1.0,1.0]:
			_spar("Anchor display crown",foot,foot+Vector3(0,0.49,direction*0.50),0.13,_dark)
		for z: float in [-78.5,-70.0,69.5,77.5]:
			_pipe("Mooring bollard",Vector3(side*2.08,_deck_height(z)+0.22,z),0.49,0.19,0.18,1.0,_steel)
	_commit("Hull porthole relief",ports,_dark)
	_octagon("Foredeck windlass outline",Vector3(0,_deck_height(-73)+0.37,-73),2.57,0.74,2.35,0.40,_steel)
	_spar("Bow staff",Vector3(0,_deck_height(-83),-83),Vector3(0,11.2,-83),0.091,_upper)
	_spar("Stern staff",Vector3(0,_deck_height(83),83),Vector3(0,8.1,83),0.092,_upper)


func _underwater() -> void:
	_octagon("Stern steering display",Vector3(0,-2.1,78.45),0.54,4.01,3.62,0.24,_underbody,0.83)
	for x: float in [-3.36,-1.41,1.41,3.36]:
		var z: float = 69.4 if absf(x)>3.0 else 73.2
		var p := Vector3(x,-2.91,z)
		_spar("Underbody silhouette support",Vector3(x*0.72,-1.41,z-8.2),p,0.24,_underbody)
		var cap := _pipe("Underbody visual fitting",p,0.71,0.26,0.24,1.0,_underbody)
		cap.rotation.x = PI/2
		for j: int in range(3):
			var theta: float = TAU*float(j)/3.0
			var arm := Vector3(cos(theta),sin(theta),0)
			_spar("Underbody silhouette blade",p+arm*0.10,p+arm*1.06+Vector3.BACK*0.15,0.21,_underbody)
