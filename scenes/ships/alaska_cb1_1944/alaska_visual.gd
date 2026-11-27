extends "res://scenes/ships/visual_study/archival_cruiser_art.gd"
## CB-1 visual study frozen to the November 1944 post-shakedown photos.

const HALF: float = 123.2154
const PROFILE: Array[Vector4] = [
	Vector4(-HALF,0.035,11.54,0.018),Vector4(-121.2,0.87,11.24,0.21),Vector4(-116.8,2.54,10.83,1.11),
	Vector4(-111.5,4.06,10.35,2.52),Vector4(-104.7,5.81,9.80,4.22),Vector4(-95.5,7.49,9.27,6.42),
	Vector4(-85.0,9.13,8.79,8.25),Vector4(-74.0,10.65,8.49,9.72),Vector4(-60.0,12.13,8.37,11.43),
	Vector4(-46.0,13.32,8.24,12.79),Vector4(-30.0,13.8811,8.11,13.48),Vector4(-11.0,13.8811,8.03,13.62),
	Vector4(9.0,13.79,7.97,13.48),Vector4(27.0,13.58,7.94,13.17),Vector4(45.0,13.14,7.90,12.59),
	Vector4(62.4,12.43,7.84,11.62),Vector4(79.6,11.33,7.77,10.12),Vector4(94.3,10.10,7.68,8.69),
	Vector4(106.2,8.84,7.62,6.79),Vector4(115.2,7.32,7.58,5.61),Vector4(120.5,5.34,7.59,3.91),
	Vector4(HALF,3.46,7.62,2.26),
]


func _stations() -> Array[Vector4]:
	return PROFILE


func _half_length() -> float:
	return HALF


func _draft() -> float:
	return 9.70


func _section(r: Vector4,s: float) -> PackedVector3Array:
	return _draw_section(r,s,5.21,6.05)


func _ready() -> void:
	_steel = _paint("7d898e")
	_upper = _paint("a2aaad")
	_deck = _paint("535f66")
	_dark = _paint("273540")
	_hull_side = _paint("a1aaac")
	_underbody = _paint("704547")
	_group = _layer("Hull and deck")
	_hull()
	_disruptive_paint(_group.get_node("Hull plating") as MeshInstance3D)
	_group = _layer("Tall bridge and aft deckhouse")
	_bridge()
	_group = _layer("Single broad funnel")
	_stack_and_yards()
	_group = _layer("Inert exterior silhouettes")
	for i: int in range(3):
		var z: float = [-71.0,-56.0,56.5][i]
		_photo_case(z,0,_deck_height(z),11.55,10.5,4.02,3.62 if i == 1 else 0.77,3,Vector3.FORWARD if i<2 else Vector3.BACK)
	for z: float in [-44.85,43.72]:
		_photo_case(z,0,_deck_height(z)+2.95,5.1,4.43,2.19,0.63,2,Vector3.FORWARD if z<0 else Vector3.BACK)
	for side: float in [-1.0,1.0]:
		for z: float in [-26.8,28.0]:
			_photo_case(z,side*9.44,_deck_height(z)+2.29,5.02,4.32,2.25,0.60,2,Vector3(side,0,0))
	_group = _layer("Working decks and fittings")
	_deck_layout()
	_group = _layer("Waterline and underbody detail")
	_underbody_shapes(PackedVector3Array([Vector3(-4.38,-4.28,103),Vector3(-2.05,-4.54,108.32),Vector3(2.05,-4.54,108.32),Vector3(4.38,-4.28,103)]),115.0,1.33)


func _bridge() -> void:
	_octagon("Wide forward deckhouse",Vector3(0,10.75,-29.4),19.72,5.16,36.60,2.50,_steel,0.95)
	_octagon("Forward tower rooted volume",Vector3(0,15.50,-32.55),14.63,4.90,19.60,2.63,_steel,0.88)
	_octagon("Tower receding front volume",Vector3(0,20.32,-29.8),10.10,5.31,15.75,1.76,_steel,0.87)
	_gallery("Strong shoulder gallery",Vector3(0,22.93,-30.57),15.72,0.90,15.68,_upper)
	_octagon("Enclosed bridge volume",Vector3(0,24.76,-30.27),10.91,2.96,11.03,1.86,_steel,0.99)
	_windows_face(Vector3(0,25.19,-35.81),7,1.06,0.84,0.64)
	for side: float in [-1.0,1.0]:
		for z: float in [-31.92,-30.55,-29.21]:
			_box("Pilothouse side pane",Vector3(side*5.45,25.19,z),Vector3(0.072,0.63,1.0),_dark)
		_octagon("Outboard gallery wing",Vector3(side*6.63,23.28,-30.77),3.1,0.85,6.1,0.76,_upper)
		_spar("Oblique gallery stay",Vector3(side*4.11,19.26,-29.05),Vector3(side*7.21,22.91,-30.08),0.24,_steel)
	_gallery("Wide forward visor",Vector3(0,26.33,-30.76),13.52,0.56,13.56,_upper)
	_octagon("Lofty narrow tower crown",Vector3(0,29.22,-28.52),6.41,5.26,7.65,1.11,_steel,0.94)
	_gallery("Upper crown platform",Vector3(0,32.0,-29.6),8.84,0.56,8.37,_upper)
	_pipe("Fixed crown observatory",Vector3(0,33.18,-29.52),2.01,1.62,1.30,1.0,_steel)
	_lattice(Vector3(0,35.12,-29.42),4.10,1.72)
	_octagon("Middle broad trunk",Vector3(0,10.43,-1.0),19.60,4.87,32.13,2.76,_steel)
	_octagon("After low casing",Vector3(0,10.15,32.9),16.95,4.34,32.52,2.31,_steel)
	_octagon("After stepped observation house",Vector3(0,14.19,30.20),11.9,4.03,15.66,1.73,_steel,0.88)
	_gallery("After lookout level",Vector3(0,16.40,30.23),11.64,0.69,12.02,_upper)
	_octagon("After raised watch house",Vector3(0,18.53,31.28),6.28,3.82,7.72,0.87,_steel)


func _stack_and_yards() -> void:
	var z: float = -0.18
	_octagon("Low wide funnel foundation",Vector3(0,14.54,z),12.82,3.80,11.14,1.71,_steel)
	var stack := _pipe("Tall single broad funnel body",Vector3(0,21.65,z),12.77,5.36,4.86,1.15,_steel)
	stack.rotation.x = deg_to_rad(5.45)
	var cap := _pipe("Single rolled funnel cap",Vector3(0,28.13,z+0.59),0.91,5.07,5.13,1.18,_upper)
	cap.rotation.x = deg_to_rad(11.8)
	var lip := _pipe("Exhaust shadow only",Vector3(0,28.60,z+0.64),0.10,4.31,4.31,1.15,_dark)
	lip.rotation.x = cap.rotation.x
	for side: float in [-1.0,1.0]:
		_spar("Funnel outer down-strut",Vector3(side*4.89,14.70,z+1.73),Vector3(side*4.32,27.61,z+2.43),0.267,_steel)
		_gallery("Round stack-side observation cup",Vector3(side*7.35,14.32,z+1.86),4.20,1.13,4.44,_upper)
	_mast_silhouette(-21.34,13.0,48.31,6.12,2.65)
	_mast_silhouette(26.51,13.22,34.40,5.32,2.41)
	_spar("One long background halyard",Vector3(0,45.72,-20.62),Vector3(0,31.84,27.22),0.044,_dark)


func _deck_layout() -> void:
	_weather_rails(1.07,3.38)
	_hawse_relief(-109.7,4.23,8.01,1.30)
	_octagon("Foredeck handling cover",Vector3(0,_deck_height(-106.4)+0.66,-106.4),4.8,1.10,4.14,0.62,_steel)
	for side: float in [-1.0,1.0]:
		_spar("Bow chain silhouette",Vector3(side*1.35,_deck_height(-107.15)+0.10,-107.15),Vector3(side*1.23,_deck_height(-117.0)+0.10,-117.0),0.182,_dark)
		for z: float in [-106.5,-97.0,99.5,110.5]:
			_pipe("Deck bollard",Vector3(side*3.18,_deck_height(z)+0.30,z),0.63,0.27,0.23,1.0,_steel)
		_duty_boat(Vector3(side*7.63,13.01,-12.74),side,1.20)
		var p := Vector3(side*8.57,10.56,14.8)
		_octagon("Waist-span raised service base",p,4.70,1.61,13.2,1.07,_steel)
		_spar("Waist deck leading relief",p+Vector3(0,0.85,-6.0),p+Vector3(side*2.31,0.88,5.6),0.45,_dark)
		var base := Vector3(side*7.65,12.17,19.73)
		var elbow := base+Vector3(side*0.38,5.35,-1.18)
		var tip := base+Vector3(side*4.21,5.28,3.11)
		_spar("Waist lifting upright",base,elbow,0.293,_steel)
		_spar("Waist lifting frame",elbow,tip,0.215,_steel)
		_spar("Waist lifting diagonal",base+Vector3(0,2.6,0),tip,0.179,_upper)
		_spar("Waist lifting hang line",tip,tip-Vector3.UP*2.12,0.049,_dark)
		for z: float in [81.3,92.0,101.8,111.2]:
			_gallery("After working deck circular shield",Vector3(side*5.73,_deck_height(z)+0.40,z),3.45,0.79,3.65,_steel)
			_pipe("After working deck shadow",Vector3(side*5.73,_deck_height(z)+0.82,z),0.05,1.29,1.29,1.02,_dark)
	_spar("Bow staff",Vector3(0,_deck_height(-120.0),-120.0),Vector3(0,15.31,-120.0),0.12,_upper)
	_spar("Stern staff",Vector3(0,_deck_height(121.0),121.0),Vector3(0,12.1,121.0),0.105,_upper)


func _disruptive_paint(node: MeshInstance3D) -> void:
	# Original hand-drawn broad visual shapes inspired by NH 57213 and the 1D plates.
	# Approximate side-hull paint only, not their exact colors or every small region.
	var image := Image.create_empty(1024,256,false,Image.FORMAT_RGBA8)
	image.fill(Color("a6aeb1"))
	var ink := Color("303b44")
	for side: int in [0,1]:
		var patches: Array[PackedVector2Array] = [
			PackedVector2Array([Vector2(0.0530,0.3968),Vector2(0.1209,0.3968),Vector2(0.1221,0.0159),Vector2(0.0567,0.0159)]),
			PackedVector2Array([Vector2(0.1526,0.0159),Vector2(0.1526,0.2063),Vector2(0.1601,0.3968),Vector2(0.1838,0.4921),Vector2(0.2343,0.4762),Vector2(0.2623,0.6032),Vector2(0.3308,0.7143),Vector2(0.3882,0.6825),Vector2(0.3614,0.0317)]),
			PackedVector2Array([Vector2(0.5427,0.0159),Vector2(0.5832,0.6032),Vector2(0.6212,0.6667),Vector2(0.6935,0.6667),Vector2(0.7103,0.7619),Vector2(0.7065,0.4444),Vector2(0.6997,0.3651),Vector2(0.6517,0.3333),Vector2(0.6449,0.0317)]),
			PackedVector2Array([Vector2(0.7757,0.0317),Vector2(0.7844,0.6032),Vector2(0.8312,0.5556),Vector2(0.9103,0.4127),Vector2(0.9103,0.0317)]),
		]
		if side == 1:
			patches = [
				PackedVector2Array([Vector2(0.2610,0.7143),Vector2(0.1783,0.7143),Vector2(0.1141,0.4762),Vector2(0.0352,0.4603),Vector2(0.0160,0.5238),Vector2(0.0179,0.1587),Vector2(0.1228,0.1905),Vector2(0.1271,0.0000),Vector2(0.1733,0.0159)]),
				PackedVector2Array([Vector2(0.4183,0.6032),Vector2(0.3411,0.6508),Vector2(0.3294,0.4762),Vector2(0.3177,0.0159),Vector2(0.3979,0.0159),Vector2(0.3961,0.1905),Vector2(0.3991,0.3968),Vector2(0.4078,0.5397)]),
				PackedVector2Array([Vector2(0.8371,0.6190),Vector2(0.7353,0.6190),Vector2(0.6959,0.6032),Vector2(0.6391,0.6667),Vector2(0.5910,0.6984),Vector2(0.5848,0.5714),Vector2(0.6613,0.3492),Vector2(0.6946,0.2222),Vector2(0.7125,0.0000),Vector2(0.8149,0.0159),Vector2(0.8155,0.1746),Vector2(0.8236,0.2698),Vector2(0.8353,0.3333)]),
				PackedVector2Array([Vector2(1.0006,0.6508),Vector2(0.9143,0.7143),Vector2(0.8816,0.6667),Vector2(0.8877,0.4762),Vector2(0.9007,0.3810),Vector2(0.9321,0.3016),Vector2(0.9445,0.1905),Vector2(0.9476,0.0000),Vector2(0.9951,0.0000)]),
			]
		for i: int in range(patches.size()):
			var p: PackedVector2Array = patches[i]
			for j: int in range(p.size()):
				p[j] = Vector2(p[j].x*1024.0,float(side)*128.0+5.0+p[j].y*118.0)
			var rect := Rect2(p[0],Vector2.ZERO)
			for point: Vector2 in p:
				rect = rect.expand(point)
			for y: int in range(maxi(0,floori(rect.position.y)),mini(256,ceili(rect.end.y))):
				for x: int in range(maxi(0,floori(rect.position.x)),mini(1024,ceili(rect.end.x))):
					if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),p):
						image.set_pixel(x,y,ink)
	image.generate_mipmaps()
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var result := PackedVector2Array()
	for p: Vector3 in vertices:
		result.append(Vector2(clampf((p.z+HALF)/(2.0*HALF),0.001,0.999),(0.02 if p.x<0 else 0.52)+0.46*clampf(p.y/11.56,0.0,1.0)))
	arrays[Mesh.ARRAY_TEX_UV] = result
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	node.mesh = mesh
	var paint: StandardMaterial3D = _paint("ffffff")
	paint.albedo_texture = ImageTexture.create_from_image(image)
	node.material_override = paint
