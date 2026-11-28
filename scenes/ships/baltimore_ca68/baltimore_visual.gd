extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"

const DISPLAY_GUN := preload("res://scripts/presentation/models/archive_gun_rig.gd")
## New visually reconstructed CA-68, Mare Island, October 1944.
## Bow -Z, y=0 design waterline. Inert game-exhibit shells only.

const HALF_LENGTH: float = 102.6287
const DRAFT: float = 6.2484
const PROFILE: Array[Vector4] = [
	Vector4(-102.6287,0.049,9.70,0.027),Vector4(-101.0,0.83,9.52,0.29),
	Vector4(-97.6,2.36,9.22,1.26),Vector4(-93.0,3.88,8.84,2.62),
	Vector4(-86.5,5.37,8.33,4.27),Vector4(-79.0,6.58,7.95,5.74),
	Vector4(-70.0,7.85,7.63,7.12),Vector4(-60.0,9.04,7.48,8.44),
	Vector4(-48.0,9.92,7.35,9.35),Vector4(-35.0,10.55,7.27,10.01),
	Vector4(-19.0,10.795,7.19,10.42),Vector4(0,10.795,7.12,10.47),
	Vector4(17.0,10.72,7.05,10.41),Vector4(33.0,10.46,7.03,10.00),
	Vector4(48.0,9.98,7.03,9.42),Vector4(64.0,9.37,7.06,8.64),
	Vector4(78.0,8.77,7.11,7.73),Vector4(89.0,8.10,7.20,6.70),
	Vector4(96.0,7.37,7.29,5.34),Vector4(100.0,6.52,7.37,4.23),
	Vector4(102.6287,4.58,7.40,3.22),
]
var _light: StandardMaterial3D


func _stations() -> Array[Vector4]:
	return PROFILE


func _half_length() -> float:
	return HALF_LENGTH


func _draft() -> float:
	return DRAFT


func _section(row: Vector4, side: float) -> PackedVector3Array:
	var pts: PackedVector3Array = super._section(row,side)
	var rake: float = 3.26*smoothstep(0.0,1.0,(-row.x-78.0)/24.6287)
	var tuck: float = 4.77*smoothstep(0.0,1.0,(row.x-77.0)/25.6287)
	for i: int in range(pts.size()-1):
		var p: Vector3 = pts[i]
		p.z += (rake-tuck)*(1.0-float(i)/5.0)
		if i == 4:
			p.x *= 1.0-0.11*smoothstep(0.0,1.0,(-row.x-32.0)/70.6287)
		pts[i] = p
	return pts


func _ready() -> void:
	_hull_side = _paint("7c8a93")
	_steel = _paint("77858c")
	_upper = _paint("9ba5a8")
	_deck = _paint("506371")
	_dark = _paint("283644")
	_underbody = _paint("784746")
	_light = _paint("bbc0bb")
	_group = _layer("Hull and deck")
	_hull()
	_camo(_group.get_node("Hull plating"))
	_group = _layer("Bridge and deckhouses")
	_bridge()
	_group = _layer("Funnels and mast silhouettes")
	_uptakes()
	_group = _layer("Inert external casings")
	_casings()
	_group = _layer("Forecastle and after work deck")
	_deck_furniture()
	_group = _layer("Submerged exterior approximations")
	_below()


func _bridge() -> void:
	_octagon("Lower forward body",Vector3(0,9.30,-28.22),15.0,4.23,24.90,2.13,_steel,0.92)
	_octagon("Forward stepped body",Vector3(0,12.7,-31.12),11.80,3.38,17.32,2.68,_steel,0.93)
	_octagon("Forward gallery",Vector3(0,14.59,-32.02),13.45,0.53,15.51,2.8,_upper)
	_octagon("Pilot enclosure",Vector3(0,15.61,-33.12),9.72,1.67,10.51,1.46,_steel)
	_octagon("Forward upper visor",Vector3(0,16.59,-33.13),11.04,0.51,11.50,1.72,_upper)
	_octagon("Raised observation crown",Vector3(0,18.15,-31.70),6.59,2.65,6.51,1.08,_steel,0.90)
	_octagon("Crown transverse deck",Vector3(0,19.55,-31.76),7.23,0.37,5.81,0.97,_upper)
	_pipe("Forward fixed watch silhouette",Vector3(0,21.04,-31.76),2.62,1.50,1.21,0.94,_steel)
	for i: int in range(7):
		_box("Separate front glazing",Vector3((i-3)*0.87,15.69,-38.403),Vector3(0.76,0.45,0.07),_dark)
	for side: float in [-1.0,1.0]:
		for z: float in [-34.6,-33.5,-32.4]:
			_box("Side glazing",Vector3(side*4.86,15.72,z),Vector3(0.068,0.44,0.87),_dark)
		_octagon("Overhanging bridge wing",Vector3(side*5.72,14.65,-30.92),2.70,0.64,5.92,0.65,_upper)
		_spar("Bridge wing support",Vector3(side*4.63,12.67,-29.58),Vector3(side*6.52,14.31,-31.32),0.31,_steel)
		_spar("Bridge wing guard",Vector3(side*6.94,15.70,-32.48),Vector3(side*6.94,15.70,-29.64),0.087,_upper)
		for z: float in [-32.41,-31.04,-29.68]:
			_spar("Bridge wing upright",Vector3(side*6.94,14.94,z),Vector3(side*6.94,15.70,z),0.077,_steel)
	_octagon("Forward central casing",Vector3(0,9.25,-5.2),15.47,4.31,22.77,2.61,_steel)
	_octagon("Lower open passage casing",Vector3(0,8.42,11.3),15.10,2.88,14.3,2.14,_steel)
	_octagon("After main deckhouse",Vector3(0,9.02,28.05),14.58,3.96,29.71,1.96,_steel,0.97)
	_octagon("After bridge balcony",Vector3(0,11.49,29.03),11.11,0.80,10.20,1.53,_upper)
	_octagon("After closed lookout",Vector3(0,13.29,32.70),7.87,2.91,7.83,1.17,_steel)
	_octagon("After lookout canopy",Vector3(0,14.92,32.92),7.94,0.54,7.62,1.19,_upper)
	for side: float in [-1.0,1.0]:
		for z: float in [-9.5,-6.8,-3.9,11.5,14.3]:
			_box("Amidship side seam",Vector3(side*7.70,8.91,z),Vector3(0.12,0.61,0.91),_dark)
		for z: float in [-14.5,4.8,23.8]:
			var eye := Vector3(side*6.04,10.91,z)
			_pipe("Round observation platform",eye,0.67,1.76,1.63,1.02,_upper)
			_pipe("Observation gallery shade",eye+Vector3.UP*0.35,0.049,1.31,1.33,1.02,_dark)


func _uptakes() -> void:
	for i: int in range(2):
		var z: float = [-12.82,10.85][i]
		var top: float = [22.31,20.96][i]
		var lower: float = [3.28,3.01][i]
		_octagon("Funnel seating block",Vector3(0,11.02,z),8.09,1.92,9.65,1.26,_steel)
		var funnel := _pipe("Raked funnel case",Vector3(0,(top+11.66)*0.5,z),top-11.66,lower,lower*0.89,1.32,_steel)
		funnel.rotation.x = deg_to_rad(5.5)
		var lip := _pipe("Funnel rolled upper edge",Vector3(0,top,z+0.52),0.59,lower*0.90,lower*0.94,1.32,_upper)
		lip.rotation.x = funnel.rotation.x
		var shadow := _pipe("Dark stack top",Vector3(0,top+0.32,z+0.53),0.074,lower*0.78,lower*0.78,1.32,_dark)
		shadow.rotation.x = funnel.rotation.x
		for side: float in [-1.0,1.0]:
			_spar("Stack exterior conduit",Vector3(side*lower*0.93,11.73,z+1.25),Vector3(side*lower*0.88,top-0.49,z+2.11),0.16,_upper)
	_mast(-21.14,10.9,40.05,3.2,true)
	_mast(20.1,10.8,36.83,2.58,false)
	_spar("Inter-mast halyard",Vector3(0,37.8,-20.52),Vector3(0,34.66,20.68),0.046,_dark)


func _mast(z: float,foot: float,top: float,span: float,fore: bool) -> void:
	_spar("Mast main upright",Vector3(0,foot,z),Vector3(0,top,z+0.65),0.34,_steel)
	for side: float in [-1.0,1.0]:
		_spar("Mast diagonal",Vector3(side*span,foot,z+1.49),Vector3(0,top-8.09,z+0.52),0.22,_steel)
		_spar("Yard hanging line",Vector3(side*5.41,top-7.15,z+0.50),Vector3(side*3.04,foot+2.17,z-0.49),0.044,_dark)
	_spar("Main flared yard",Vector3(-5.54,top-7.16,z+0.48),Vector3(5.54,top-7.16,z+0.48),0.116,_steel)
	_octagon("Yard inspection seat",Vector3(0,top-8.15,z+0.48),3.44,0.37,2.84,0.52,_steel)
	var width: float = 4.61 if fore else 2.40
	var height: float = 1.95 if fore else 0.99
	for rise: float in [-0.48,0.0,0.48]:
		_spar("Inert lattice transverse",Vector3(-width*0.49,top-1.32+rise*height,z+0.65),Vector3(width*0.49,top-1.32+rise*height,z+0.65),0.084,_dark)
	for i: int in range(7):
		var x: float = lerpf(-width*0.49,width*0.49,float(i)/6.0)
		_spar("Inert lattice upright",Vector3(x,top-1.32-height*0.48,z+0.65),Vector3(x,top-1.32+height*0.48,z+0.65),0.069,_dark)


func _casings() -> void:
	for i: int in range(3):
		var z: float = [-60.91,-45.87,53.14][i]
		var face: float = -1.0 if i < 2 else 1.0
		var seat: float = [0.75,3.57,0.81][i]
		var y: float = _deck_height(z)
		if i==1:
			_octagon("Raised closed outer support",Vector3(0,y+0.66,z),9.60,1.40,9.51,1.27,_steel)
		_pipe("Inert casing seat",Vector3(0,y+seat*0.5,z),seat,3.72,3.44,1.0,_steel)
		var first: int = _group.get_child_count()
		_octagon("Main exterior casing",Vector3(0,y+seat+1.69,z),8.86,3.40,8.81,1.63,_upper,0.79)
		for x: float in [-1.37,0.0,1.37]:
			_spar("Solid photo silhouette strip",Vector3(x,y+seat+1.31,z+face*3.54),Vector3(x,y+seat+1.87,z+face*8.87),0.267,_dark)
		for side: float in [-1.0,1.0]:
			_box("Raised casing side panel",Vector3(side*3.79,y+seat+1.42,z),Vector3(0.086,0.43,0.67),_steel)
		var pieces: Array[Node] = _group.get_children().slice(first)
		DISPLAY_GUN.attach(self,"main_%02d" % (i+1),"main",Vector3(0,y+seat,z),Vector3(0,y+seat+1.31,z+face*3.54),Vector3(0,0,face),[pieces[0],pieces[4],pieces[5]],pieces.slice(1,4))
	var secondary: int = 0
	for z: float in [-38.1,43.15]:
		_octagon("Center small enclosed housing",Vector3(0,_deck_height(z)+2.02,z),4.70,2.49,4.31,0.78,_steel,0.86)
	for side: float in [-1.0,1.0]:
		for z: float in [-16.57,3.91,19.82]:
			var p := Vector3(side*7.76,9.11,z)
			_pipe("Fixed outboard support",p-Vector3.UP*0.86,1.76,1.81,1.61,1.06,_steel)
			var first: int = _group.get_child_count()
			_octagon("Outboard casing outer cover",p+Vector3.UP*0.95,3.81,2.07,4.40,0.71,_upper,0.89)
			for offset: float in [-0.54,0.54]:
				_spar("Short inert outboard silhouette strip",p+Vector3(side*1.44,0.95,offset),p+Vector3(side*3.85,1.04,offset),0.166,_dark)
			secondary += 1
			var pieces: Array[Node] = _group.get_children().slice(first)
			DISPLAY_GUN.attach(self,"secondary_%02d" % secondary,"secondary",p,p+Vector3(side*1.44,.95,0),Vector3(side,0,0),[pieces[0]],pieces.slice(1))


func _deck_furniture() -> void:
	for side: float in [-1.0,1.0]:
		for i: int in range(2,PROFILE.size()-2):
			var a: Vector4 = PROFILE[i]
			var b: Vector4 = PROFILE[i+1]
			var p := Vector3(side*(a.y-0.22),a.z,a.x)
			var q := Vector3(side*(b.y-0.22),b.z,b.x)
			for up: float in [0.37,0.96]:
				_spar("Weather deck rail",p+Vector3.UP*up,q+Vector3.UP*up,0.081,_upper)
			var count: int = ceili(p.distance_to(q)/3.19)
			for n: int in range(count):
				var pt: Vector3 = p.lerp(q,float(n)/float(count))
				_spar("Rail upright",pt,pt+Vector3.UP*0.97,0.081,_steel)
		for z: float in [-87.2,-80.35,87.0,95.31]:
			var px: float = 2.14 if z < 0 else 4.49
			_pipe("Bollard",Vector3(side*px,_deck_height(z)+0.29,z),0.55,0.24,0.22,1.0,_steel)
		var anchor := Vector3(side*3.61,6.76,-91.00)
		_octagon("Hawse plate relief",anchor,0.30,1.12,1.43,0.13,_steel)
		_spar("Anchor outline",anchor+Vector3(side*0.23,0.21,0),anchor+Vector3(side*0.22,-1.05,0),0.187,_dark)
		for dir: float in [-1.0,1.0]:
			_spar("Anchor fork relief",anchor+Vector3(side*0.22,-1.05,0),anchor+Vector3(side*0.22,-0.62,dir*0.65),0.159,_dark)
		var y: float = _deck_height(82.5)
		for track: float in [-0.40,0.40]:
			_spar("After deck side track silhouette",Vector3(side*5.17+track,y+0.65,73.32),Vector3(side*5.17+track,y+0.65,92.55),0.122,_steel)
		for z: float in [75.73,80.5,85.42,90.1]:
			_box("Side track foot",Vector3(side*5.17,_deck_height(z)+0.30,z),Vector3(1.33,0.60,0.58),_steel)
		_crane(side)
		_octagon("Launch cradle",Vector3(side*5.44,11.22,-0.63),2.41,0.43,7.15,0.54,_dark)
		_octagon("Ship's launch",Vector3(side*5.44,11.73,-0.63),2.49,0.75,7.69,0.86,_upper,0.87)
		_octagon("Launch interior cover",Vector3(side*5.44,12.14,-0.63),1.91,0.18,6.79,0.62,_deck)
	_octagon("Flush stern hatch",Vector3(0,_deck_height(83)+0.106,83.0),7.90,0.19,11.59,0.58,_steel)
	_box("Hatch longitudinal seam",Vector3(0,_deck_height(83)+0.239,83.0),Vector3(0.09,0.041,10.3),_dark)
	_octagon("Foredeck gear outline",Vector3(0,_deck_height(-87)+0.47,-87),4.0,0.94,3.47,0.56,_steel)
	_spar("Foredeck staff",Vector3(0,_deck_height(-99.8),-99.8),Vector3(0,12.75,-99.8),0.105,_upper)
	_spar("Stern staff",Vector3(0,_deck_height(96.7),96.7),Vector3(0,10.81,96.7),0.098,_upper)


func _crane(side: float) -> void:
	var foot := Vector3(side*4.13,7.43,96.94)
	var elbow := Vector3(side*4.73,13.45,94.24)
	var tip := Vector3(side*3.02,13.94,87.43)
	_octagon("Crane seat",foot,2.12,0.48,2.58,0.43,_steel)
	for sign: float in [-1.0,1.0]:
		_spar("Raised crane frame",foot+Vector3(sign*0.56,0.0,0),elbow+Vector3(sign*0.30,0.0,0),0.233,_upper)
		_spar("Crane boom lattice top",elbow+Vector3(sign*0.30,0.0,0),tip+Vector3(sign*0.13,0.0,0),0.181,_upper)
		_spar("Crane boom lattice return",elbow+Vector3(sign*0.31,-0.58,0),tip+Vector3(sign*0.12,0.0,0),0.131,_steel)
	_spar("Crane hanging line",tip,tip-Vector3.UP*2.22,0.053,_dark)


func _below() -> void:
	_octagon("Steering silhouette",Vector3(0,-2.17,95.25),0.62,4.12,5.14,0.27,_underbody,0.81)
	for x: float in [-4.01,-1.69,1.69,4.01]:
		var z: float = 84.01 if absf(x)>3.0 else 88.05
		var p := Vector3(x,-2.71,z)
		_spar("Underbody fitting silhouette",Vector3(x*0.78,-1.63,z-7.48),p,0.29,_underbody)
		var hub := _pipe("Inert underbody hub",p,0.70,0.31,0.29,1.0,_underbody)
		hub.rotation.x = PI/2
		for i: int in range(3):
			var angle: float = TAU*float(i)/3.0
			var dir := Vector3(cos(angle),sin(angle),0)
			_spar("Underbody blade outline",p+dir*0.115,p+dir*1.08+Vector3.BACK*0.16,0.246,_underbody)


func _camo(mesh_node: MeshInstance3D) -> void:
	# Two opposing design-plate traces, not a photographic paint sample.
	var img := Image.create_empty(1024,256,false,Image.FORMAT_RGBA8)
	img.fill(Color("9ea9ad"))
	_pattern(img,false,PackedVector2Array([Vector2(108,507),Vector2(345,467),Vector2(370,518),Vector2(108,520)]),Color("667984"))
	_pattern(img,false,PackedVector2Array([Vector2(185,502),Vector2(331,465),Vector2(359,465),Vector2(358,486),Vector2(193,507)]),Color("334350"))
	_pattern(img,false,PackedVector2Array([Vector2(349,470),Vector2(405,472),Vector2(509,520),Vector2(455,520)]),Color("334350"))
	_pattern(img,false,PackedVector2Array([Vector2(529,472),Vector2(742,466),Vector2(557,520)]),Color("334350"))
	_pattern(img,false,PackedVector2Array([Vector2(557,520),Vector2(782,471),Vector2(825,472),Vector2(731,520)]),Color("667984"))
	_pattern(img,false,PackedVector2Array([Vector2(721,520),Vector2(804,473),Vector2(852,473),Vector2(893,520)]),Color("334350"))
	_pattern(img,false,PackedVector2Array([Vector2(1062,472),Vector2(1209,473),Vector2(1226,497),Vector2(1117,520)]),Color("334350"))
	_pattern(img,false,PackedVector2Array([Vector2(1300,473),Vector2(1399,468),Vector2(1399,520),Vector2(1216,520)]),Color("667984"))
	_pattern(img,true,PackedVector2Array([Vector2(103,466),Vector2(196,466),Vector2(229,515),Vector2(102,518)]),Color("667984"))
	_pattern(img,true,PackedVector2Array([Vector2(197,463),Vector2(280,463),Vector2(335,516),Vector2(228,516)]),Color("334350"))
	_pattern(img,true,PackedVector2Array([Vector2(294,464),Vector2(345,465),Vector2(399,518),Vector2(345,518)]),Color("334350"))
	_pattern(img,true,PackedVector2Array([Vector2(545,469),Vector2(628,466),Vector2(712,464),Vector2(937,470),Vector2(936,485),Vector2(710,516),Vector2(653,516)]),Color("334350"))
	_pattern(img,true,PackedVector2Array([Vector2(830,516),Vector2(982,483),Vector2(978,516)]),Color("334350"))
	_pattern(img,true,PackedVector2Array([Vector2(982,463),Vector2(1265,475),Vector2(1260,494),Vector2(1167,516),Vector2(978,516)]),Color("667984"))
	_pattern(img,true,PackedVector2Array([Vector2(982,463),Vector2(1265,501),Vector2(1241,516),Vector2(982,487)]),Color("334350"))
	_pattern(img,true,PackedVector2Array([Vector2(1309,484),Vector2(1403,498),Vector2(1403,514),Vector2(1300,499)]),Color("334350"))
	img.generate_mipmaps()
	var a: Array = mesh_node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	for p: Vector3 in verts:
		uv.append(Vector2(clampf((p.z+HALF_LENGTH)/(2.0*HALF_LENGTH),0.001,0.999),
			(0.01 if p.x < 0 else 0.51)+0.48*clampf(p.y/10.50,0.0,1.0)))
	a[Mesh.ARRAY_TEX_UV] = uv
	var updated := ArrayMesh.new()
	updated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	mesh_node.mesh = updated
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = ImageTexture.create_from_image(img)
	paint.roughness = 0.86
	mesh_node.material_override = paint


func _pattern(img: Image,starboard: bool,plate: PackedVector2Array,color: Color) -> void:
	var poly := PackedVector2Array()
	for p: Vector2 in plate:
		var along: float = (1397.0-p.x)/1295.0 if starboard else (p.x-108.0)/1290.0
		var up: float = (519.0-p.y)/70.0
		poly.append(Vector2(along*1024.0,(130.56 if starboard else 2.56)+up*122.88))
	var bound := Rect2(poly[0],Vector2.ZERO)
	for p: Vector2 in poly:
		bound = bound.expand(p)
	for y: int in range(maxi(0,floori(bound.position.y)),mini(256,ceili(bound.end.y))):
		for x: int in range(maxi(0,floori(bound.position.x)),mini(1024,ceili(bound.end.x))):
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),poly):
				img.set_pixel(x,y,color)
