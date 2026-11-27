extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
## Taiyō on 1943-09-30, before the longer deck. Static exterior only, -Z bow.

const HALF_LENGTH := 90.10
const HALF_BEAM := 11.25
const DISPLAY_DRAFT := 7.70
const DECK_TOP := 17.13
const DECK_FORE := -74.0
const DECK_AFT := 88.0
const DECK_WIDTH := 23.50

# Outer ramped hull plan estimated against the Yokosuka broadside. Retains
# passenger-liner sides and more buoyant cruiser stern, not a copy of Zuihō.
const CONTOUR: Array[Vector4] = [
	Vector4(-90.10,.045,12.17,.035),Vector4(-89.10,.43,12.10,.10),
	Vector4(-87.4,1.12,11.98,.35),Vector4(-85.2,1.86,11.83,.72),
	Vector4(-81.5,3.26,11.53,1.65),Vector4(-77.0,4.92,11.25,3.16),
	Vector4(-70.5,7.09,11.01,5.63),Vector4(-62.1,8.84,10.88,7.80),
	Vector4(-52.0,10.17,10.78,9.28),Vector4(-40,10.95,10.72,10.39),
	Vector4(-29,HALF_BEAM,10.70,10.91),Vector4(-17,HALF_BEAM,10.70,10.97),
	Vector4(-4,HALF_BEAM,10.66,10.97),Vector4(10,11.25,10.63,10.92),
	Vector4(23,11.19,10.55,10.84),Vector4(34,11.06,10.49,10.63),
	Vector4(46,10.87,10.39,10.28),Vector4(56,10.65,10.26,9.81),
	Vector4(63,10.24,10.17,9.40),Vector4(63.75,10.18,8.08,9.36),
	Vector4(68.5,9.91,8.00,9.05),Vector4(75,9.20,7.94,8.30),
	Vector4(81.0,7.88,7.92,6.95),Vector4(84.6,6.78,7.98,5.82),
	Vector4(87.1,5.36,8.08,4.32),Vector4(89.1,3.53,8.21,2.79),
	Vector4(90.10,1.54,8.28,1.23)
]

var spec := {"label":"IJN Taiyo", "year":"1943-09-30", "length":180.20,
	"beam":22.50,"draft":7.70,"deck_length":162.00,"deck_width":23.50,"deck_y":DECK_TOP}
var ship_id := "taiyo"

var light_gray: StandardMaterial3D
var canvas: StandardMaterial3D
var wet_wood: StandardMaterial3D
var pale_mark: StandardMaterial3D
var rim: StandardMaterial3D

func _stations() -> Array[Vector4]:
	return CONTOUR

func _half_length() -> float:
	return HALF_LENGTH

func _draft() -> float:
	return DISPLAY_DRAFT

func _section(row: Vector4, side: float) -> PackedVector3Array:
	var cross_section: PackedVector3Array = super._section(row,side)
	var fwd: float = smoothstep(69.0,HALF_LENGTH,-row.x)
	var aft: float = smoothstep(72.0,HALF_LENGTH,row.x)
	for i: int in range(cross_section.size()-1):
		var p: Vector3 = cross_section[i]
		p.z += fwd*[8.7,6.82,4.42,4.00,2.05][i]-aft*[9.9,6.13,2.82,2.05,0.71][i]
		if i == 4:
			p.x = side*lerpf(row.w,row.y,0.70)
		if i == 1:
			p.x *= 1.0 + 0.085*(1.0-smoothstep(40.0,77.0,absf(row.x)))
		cross_section[i] = p
	return cross_section

func _ready() -> void:
	_steel = _paint("596367")
	_deck = _paint("646260")
	_upper = _paint("6d7576")
	_dark = _paint("292e31")
	_hull_side = _paint("555e61")
	_underbody = _paint("654646")
	light_gray = _paint("7a8280")
	canvas = _paint("aaa599")
	wet_wood = _paint("827363")
	pale_mark = _paint("999387")
	rim = _paint("454c4d")
	_group = _layer("Hull and deck")
	_hull()
	_liner_side()
	_group = _layer("Hangar")
	_hangar()
	_group = _layer("FlightDeck")
	_flight_deck()
	_group = _layer("Superstructure")
	_bridge_and_outlet()
	_group = _layer("Equipment")
	_platforms_and_boats()
	_underwater()

func _hull_half_width(z: float) -> float:
	for i: int in range(CONTOUR.size()-1):
		var a: Vector4 = CONTOUR[i]
		var b: Vector4 = CONTOUR[i+1]
		if z <= b.x:
			return lerpf(a.y,b.y,inverse_lerp(a.x,b.x,z))
	return CONTOUR[-1].y

func _liner_side() -> void:
	# Ship's upper exposed shell, not the overhanging flight deck's underside.
	var side_plate := _group.get_node("Hull plating") as MeshInstance3D
	var skin: PackedVector3Array = side_plate.mesh.get_faces()
	for side: float in [-1.0,1.0]:
		for idx: int in range(2,CONTOUR.size()-2):
			var a: Vector4 = CONTOUR[idx]
			var b: Vector4 = CONTOUR[idx+1]
			if absf(b.z-a.z)>1.7:
				continue
			var p := Vector3(side*a.y,a.z-.17,a.x)
			var q := Vector3(side*b.y,b.z-.17,b.x)
			_spar("Continuous liner sheer trim",p,q,0.155,_upper)
		for z: float in [-60,-55,-50,-44,-39,-34,-29,-24,-19,-14,-9,-4,1,6,11,16,21,26,31,36,41,46,51,56,61,68,73,79]:
			var p: Vector3 = _side_surface(skin,side,_deck_height(z)-2.57,z)
			_scuttle(p+Vector3(side*.015,0,0),0.18)
			if z>=-51 and z<=49 and int(round(z+4))%10==0:
				var lower: Vector3 = _side_surface(skin,side,_deck_height(z)-4.59,z+.38)
				_scuttle(lower+Vector3(side*.015,0,0),0.14)
		var anchor_z: float = -83.4
		var p: Vector3 = _side_surface(skin,side,_deck_height(anchor_z)-2.01,anchor_z)
		var shadow := _pipe("Forward housing exterior recess",p,.15,.65,.65,1.08,_dark)
		shadow.rotation.z = PI*.5
		_spar("Exterior anchor silhouette",p,p+Vector3(side*.23,-1.01,.33),.24,rim)

func _side_surface(skin: PackedVector3Array,side: float,y: float,z: float) -> Vector3:
	var start := Vector3(side*15.0,y,z)
	var end := Vector3(0,y,z)
	for n: int in range(0,skin.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start,end,skin[n],skin[n+1],skin[n+2])
		if hit is Vector3:
			return hit
	return Vector3(side*_hull_half_width(z),y,z)

func _scuttle(p: Vector3,radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.rings = 0
	mesh.radial_segments = 8
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = .12
	var node: MeshInstance3D = _instance("Passenger hull scuttle",mesh,_dark,p)
	node.rotation.z = PI*.5

func _plan(half_width: float, z_begin: float,z_end: float, fore_taper: float,aft_taper: float) -> Array[Vector2]:
	return [Vector2(-half_width*fore_taper,z_begin),Vector2(half_width*fore_taper,z_begin),
		Vector2(half_width*.93,z_begin+5.0),Vector2(half_width,z_begin+14.0),
		Vector2(half_width,z_end-11.0),Vector2(half_width*.89,z_end-3.2),
		Vector2(half_width*aft_taper,z_end),Vector2(-half_width*aft_taper,z_end),
		Vector2(-half_width*.89,z_end-3.2),Vector2(-half_width,z_end-11.0),
		Vector2(-half_width,z_begin+14.0),Vector2(-half_width*.93,z_begin+5.0)]

func _plate(label: String, outline: Array[Vector2], bottom: float, top: float, mat: Material) -> void:
	var faces := SurfaceTool.new()
	faces.begin(Mesh.PRIMITIVE_TRIANGLES)
	faces.set_smooth_group(-1)
	var center := Vector2.ZERO
	for p: Vector2 in outline:
		center += p
	center /= outline.size()
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var al := Vector3(a.x,bottom,a.y)
		var bl := Vector3(b.x,bottom,b.y)
		var ah := Vector3(a.x,top,a.y)
		var bh := Vector3(b.x,top,b.y)
		var normal := Vector3(b.y-a.y,0,a.x-b.x)
		_quad(faces,al,bl,bh,ah,normal)
		_tri(faces,Vector3(center.x,bottom,center.y),al,bl,Vector3.DOWN)
		_tri(faces,Vector3(center.x,top,center.y),ah,bh,Vector3.UP)
	faces.generate_normals()
	_instance(label,faces.commit(),mat)

func _hangar() -> void:
	_plate("Long enclosed middle hangar",_plan(9.68,-64.0,66.25,.70,.63),10.05,16.43,_steel)
	_plate("Recessed after entrance wall",_plan(8.28,50.0,68.40,.91,.72),8.23,15.79,rim)
	_octagon("After hangar opening shade",Vector3(0,12.2,68.32),10.36,6.5,.43,.12,_dark)
	for side: float in [-1.0,1.0]:
		# Photograph shows appreciable daylight both at the overhanging bow and at the aft well.
		for z: float in [-71.7,-66.1]:
			var x: float = _hull_half_width(z)
			var rake: float = 0.46 if z<-68.0 else -0.31
			_spar("Sculpted fore opening column",Vector3(side*x*.72,_deck_height(z)-.09,z),Vector3(side*(x*.76+.31),16.43,z+rake),.73,_steel)
			_spar("Fore support diagonal",Vector3(side*x*.74,_deck_height(z)+.23,z+1.0),Vector3(side*(x*.78+.3),16.37,z-2.14),.32,rim)
		for z: float in [71.4,83.56]:
			var x: float = _hull_half_width(z)*.72
			_spar("Tall after bay deck support",Vector3(side*x,7.93,z),Vector3(side*(x+.55),16.52,z-.40),.89,_steel)
			_spar("Angular aft shoulder brace",Vector3(side*x,11.15,z),Vector3(side*(x+2.43),16.46,z-.39),.41,rim)
		_spar("After bay visible upper girder",Vector3(side*8.28,15.74,66.5),Vector3(side*7.44,15.6,86.3),.66,_steel)
		_spar("Raised passenger-side longitudinal line",Vector3(side*10.26,10.74,-44.1),Vector3(side*10.26,10.74,49.6),.14,_upper)
		for z: float in [-48.3,-36.3,-24.3,-12.3,-.3,11.7,23.7,35.7,47.7,59.6]:
			var x: float = side*(9.81 if z<56 else 8.91)
			_box("Recessed exterior bay shade",Vector3(x,13.06,z),Vector3(.29,1.34,5.3),rim)
			_box("Shallow hangar relief plate",Vector3(x+side*.17,14.66,z),Vector3(.24,2.05,7.14),_steel)
			_spar("Hangar face vertical seam",Vector3(x+side*.29,11.11,z-5.27),Vector3(x+side*.29,16.09,z-5.27),.11,_upper)

func _flight_deck() -> void:
	var outline: Array[Vector2] = _plan(DECK_WIDTH*.5,DECK_FORE,DECK_AFT,.61,.66)
	_plate("FlightDeckStructure",outline,DECK_TOP-1.01,DECK_TOP-.18,rim)
	_plate("DeckSurface",outline,DECK_TOP-.18,DECK_TOP,wet_wood)
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		_spar("Steel outer deck edge",Vector3(a.x,DECK_TOP-.13,a.y),Vector3(b.x,DECK_TOP-.13,b.y),.11,_upper)
	for i: int in range(-13,14):
		var split: float = i*.774
		var length: float = 154.0-float(absi(i))*2.45
		_box("Subtle long plank seams",Vector3(split,DECK_TOP+.007,7.0),Vector3(.038,.016,length),pale_mark)
	# Two fixed covers denote visually distinct elevator footprints only.
	for i: int in range(2):
		var z: float = [-47.7,44.6][i]
		_octagon("Static Lift Rim "+str(i+1),Vector3(0,DECK_TOP+.024,z),12.56,.054,12.35,.63,rim)
		_octagon("Static lift cover "+str(i+1),Vector3(0,DECK_TOP+.04,z),12.29,.055,12.09,.56,wet_wood)
	# Symbol-free and speculative markings are deliberately withheld.

func _bridge_and_outlet() -> void:
	_octagon("Forward low shelf support",Vector3(0,12.16,-62.26),12.88,2.68,10.14,1.66,_steel,.92)
	_octagon("Islandless bridge under deck",Vector3(0,14.32,-62.90),12.24,2.36,7.63,1.40,_steel,.95)
	_box("Under-deck front glazing",Vector3(0,14.81,-66.77),Vector3(8.36,.62,.09),_dark)
	for i: int in range(8):
		_box("Narrow glazing divider",Vector3((i-3.5)*1.02,14.81,-66.83),Vector3(.10,.63,.12),_upper)
	_octagon("Low crossing bridge strip",Vector3(0,15.65,-62.90),13.75,.39,8.60,1.51,_upper)
	# On the photographed side the prominent outlet housing stays below deck level.
	_octagon("Starboard shallow exterior uptake housing",Vector3(10.04,14.85,-19.62),3.75,2.89,9.16,.99,_steel,.87)
	_octagon("Starboard downward outlet facade",Vector3(11.55,13.44,-18.55),2.20,1.60,6.31,.64,rim)
	_octagon("Dark outside mouth silhouette",Vector3(11.72,12.72,-18.62),1.64,.15,5.72,.57,_dark)
	for side: float in [-1.0,1.0]:
		for z: float in [-56.2,13.9,38.3]:
			var base := Vector3(side*11.25,16.3,z)
			var tip := base+Vector3(side*.26,6.10,.36)
			_spar("Thin edge signal staff",base,tip,.105,_steel)
			_spar("Staff light crosstree",tip+Vector3(-.81,-1.15,0),tip+Vector3(.81,-1.15,0),.075,_upper)
	for p: Vector3 in [Vector3(10.71,16.23,-15.42),Vector3(-10.56,16.17,-29.1)]:
		_spar("Local thin mast shaft",p,p+Vector3(0,8.35,-.42),.17,_steel)
		_spar("Signal mast stay",p+Vector3(0,7.36,-.38),p+Vector3(-signf(p.x)*.75,.9,-12.65),.066,rim)

func _platforms_and_boats() -> void:
	for side: float in [-1.0,1.0]:
		_octagon("Liner side boat gallery",Vector3(side*9.55,10.74,-46.13),3.34,.81,24.2,1.41,_steel)
		_octagon("Short aft handling gallery",Vector3(side*8.93,10.76,53.19),3.34,.70,13.21,1.17,_steel)
		for z: float in [-51.0,-42.6,52.0]:
			var x: float = side*(9.92 if z<0 else 8.84)
			var y: float = 11.25
			_octagon("Boat exterior hull",Vector3(x,y+.41,z),2.11,.68,6.33,.72,_upper,.94)
			_octagon("Recessed boat interior colour",Vector3(x,y+.77,z),1.51,.18,4.90,.48,rim)
			for delta: float in [-2.2,2.2]:
				var a := Vector3(x-side*.43,y,z+delta)
				var b := Vector3(x+side*.41,y+2.18,z+delta)
				_spar("Boat davit lower leg",a,b,.18,_steel)
				_spar("Boat davit curved head cue",b,b+Vector3(side*.57,-.16,-.47),.16,_steel)
		for z: float in [-86.0,-80.6,81.2,86.0]:
			var y: float = _deck_height(z)
			var x: float = side*_hull_half_width(z)*.56
			_pipe("Deck bollard",Vector3(x,y+.32,z),.65,.30,.22,1.0,rim)
		for a: Vector2 in [Vector2(-87.6,-76.7),Vector2(65.6,87.8)]:
			var count := ceili((a.y-a.x)/3.25)
			for i: int in range(count):
				var pz := lerpf(a.x,a.y,float(i)/count)
				var qz := lerpf(a.x,a.y,float(i+1)/count)
				var p := Vector3(side*(_hull_half_width(pz)-.28),_deck_height(pz),pz)
				var q := Vector3(side*(_hull_half_width(qz)-.28),_deck_height(qz),qz)
				_spar("Weather deck rail",p+Vector3.UP*.96,q+Vector3.UP*.96,.074,_upper)
				_spar("Weather deck stanchion",p,p+Vector3.UP*.96,.075,_upper)
		var anchor_point := Vector3(side*.87,_deck_height(-86.6)+.08,-86.6)
		_spar("Static bow chain silhouette",anchor_point,Vector3(side*1.20,_deck_height(-79.0)+.12,-79.0),.17,rim)
	_octagon("Small under-deck elevated stern terrace",Vector3(0,10.84,86.62),10.66,.83,5.83,1.23,_steel)
	for side: float in [-1.0,1.0]:
		_spar("Stern terrace outer post",Vector3(side*3.83,8.02,88.64),Vector3(side*4.18,10.91,88.53),.33,_steel)
	_octagon("Small foredeck raised casing",Vector3(0,_deck_height(-82.60)+.45,-82.60),3.90,.88,3.67,.63,_steel)

func _underwater() -> void:
	# Only approximate visible-envelope display shapes, not propulsive hardware.
	_octagon("Simplified rudder silhouette",Vector3(0,-2.59,83.55),.67,4.52,5.59,.26,_underbody)
	for side: float in [-1.0,1.0]:
		var p := Vector3(side*3.20,-3.75,77.71)
		_spar("Stern visual shaft outline",p,p+Vector3(-side*.72,.93,-7.50),.46,_underbody)
		var hub := _pipe("Stern pod silhouette",p,1.07,.43,.29,1.0,_underbody)
		hub.rotation.x = PI*.5
		for i: int in range(3):
			var a: float = TAU*float(i)/3
			var v := Vector3(cos(a),sin(a),0)
			_spar("Nonfunctional blade silhouette",p+v*.22,p+v*1.34+Vector3.BACK*.14,.31,_underbody)
