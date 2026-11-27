extends "res://scenes/ships/visual_study/archival_cruiser_art.gd"
## CL-53 exhibit, San Francisco, 1 January 1944. Static non-operational art.

const HALF: float = 82.5246
const PROFILE: Array[Vector4] = [
	Vector4(-HALF,0.032,8.39,0.015),Vector4(-81.4,0.66,8.24,0.21),Vector4(-78.3,1.82,7.94,0.92),
	Vector4(-74.2,2.96,7.61,1.95),Vector4(-69.0,4.08,7.24,3.07),Vector4(-62.0,5.36,6.82,4.50),
	Vector4(-53.9,6.43,6.42,5.72),Vector4(-45.2,7.15,6.07,6.61),Vector4(-35.0,7.73,5.77,7.29),
	Vector4(-23.0,8.1026,5.55,7.87),Vector4(-8.0,8.1026,5.43,7.87),
	Vector4(7.0,8.04,5.36,7.79),Vector4(21.1,7.83,5.32,7.52),Vector4(35.0,7.53,5.28,7.18),
	Vector4(48.3,7.02,5.23,6.45),Vector4(59.4,6.28,5.21,5.61),Vector4(68.5,5.48,5.18,4.77),
	Vector4(74.4,4.63,5.21,3.87),Vector4(79.0,3.66,5.25,2.89),Vector4(81.1,2.59,5.29,1.83),
	Vector4(HALF,1.24,5.32,0.76),
]
var _pale: StandardMaterial3D


func _stations() -> Array[Vector4]:
	return PROFILE


func _half_length() -> float:
	return HALF


func _draft() -> float:
	return 6.35


func _section(r: Vector4,s: float) -> PackedVector3Array:
	return _draw_section(r,s,3.85,4.21)


func _ready() -> void:
	_steel = _paint("7b868a")
	_upper = _paint("a0a7a7")
	_deck = _paint("545f63")
	_dark = _paint("313941")
	_hull_side = _paint("677a81")
	_underbody = _paint("734749")
	_pale = _paint("bec4c0")
	_group = _layer("Hull and deck")
	_hull()
	_group = _layer("Forward and after houses")
	_superstructure()
	_group = _layer("Two narrow funnels and split masts")
	_funnels()
	_group = _layer("Static casings")
	for i: int in range(6):
		var z: float = [-48.2,-38.3,-28.0,32.2,42.23,52.91][i]
		var raised: float = [0.53,2.62,4.52,4.02,2.26,0.61][i]
		_photo_case(z,0,_deck_height(z),4.77,4.67,2.13,raised,2,Vector3.FORWARD if i<3 else Vector3.BACK)
	for side: float in [-1.0,1.0]:
		_photo_case(20.12,side*5.46,_deck_height(20.12)+0.68,4.65,4.48,2.12,0.77,2,Vector3(side,0,0))
	_group = _layer("Working deck and relief detail")
	_furniture()
	_group = _layer("Submerged silhouette")
	_underbody_shapes(PackedVector3Array([Vector3(-2.46,-2.54,70.4),Vector3(2.46,-2.54,70.4)]),77.5,0.82)


func _superstructure() -> void:
	_octagon("Forward compact deckhouse",Vector3(0,7.27,-17.5),11.48,3.10,30.20,1.81,_steel,0.96)
	_octagon("Forward bridge narrowing base",Vector3(0,9.91,-19.72),8.35,2.86,12.52,1.48,_steel,0.90)
	_gallery("Wide rounded gallery",Vector3(0,11.61,-19.35),10.45,0.60,11.37,_upper)
	_octagon("Wraparound enclosure",Vector3(0,12.86,-19.47),8.76,1.92,9.64,1.55,_steel)
	_gallery("Upper rounded visor",Vector3(0,14.13,-19.55),9.75,0.56,10.55,_upper)
	_windows_face(Vector3(0,13.13,-24.31),7,0.76,0.57,0.46)
	_octagon("Compact raised crown",Vector3(0,15.87,-17.91),4.42,2.78,5.18,0.76,_steel,0.90)
	_gallery("Forward lookout tray",Vector3(0,17.44,-18.24),5.38,0.40,5.01,_upper)
	_pipe("Forward photo silhouette lookout",Vector3(0,18.50,-18.18),1.74,1.01,0.92,0.98,_steel)
	_lattice(Vector3(0,20.12,-17.93),2.46,1.12)
	_octagon("Low central open-deck trunk",Vector3(0,6.58,5.72),9.91,2.53,23.92,1.54,_steel)
	_octagon("After tiered house",Vector3(0,7.11,24.39),10.55,3.45,23.77,1.73,_steel,0.93)
	_octagon("After middle gallery pedestal",Vector3(0,9.59,24.39),7.43,2.44,10.63,1.03,_steel)
	_gallery("After observation shelf",Vector3(0,10.97,25.38),8.19,0.52,9.86,_upper)
	_octagon("After tall rounded silhouette",Vector3(0,12.62,26.23),5.62,2.92,6.02,1.15,_steel,0.91)
	_gallery("After rounded visor",Vector3(0,14.22,26.22),6.68,0.51,6.79,_upper)
	_pipe("After fixed watch outline",Vector3(0,15.73,26.27),2.75,1.21,1.14,0.92,_steel)
	_lattice(Vector3(0,17.54,26.66),2.33,1.13)
	for side: float in [-1.0,1.0]:
		for z: float in [-20.68,-19.71,-18.74]:
			_box("Side pilot pane",Vector3(side*4.38,13.14,z),Vector3(0.074,0.47,0.71),_dark)
		_gallery("Round side wing",Vector3(side*4.52,11.91,-18.45),2.46,0.69,4.63,_upper)
		_spar("Gallery wing diagonal external brace",Vector3(side*3.53,9.50,-18.28),Vector3(side*5.68,11.66,-18.71),0.18,_steel)
		for z: float in [-11.57,-2.85,25.80]:
			var p := Vector3(side*5.14,8.47,z)
			_gallery("Small occupied-deck shield silhouette",p,2.62,0.76,3.08,_steel)
			_pipe("Small platform deep visual shade",p+Vector3.UP*0.4,0.039,0.91,0.90,1.0,_dark)


func _funnels() -> void:
	for i: int in range(2):
		var z: float = [-7.56,12.90][i]
		var top: float = [19.59,18.57][i]
		_octagon("Narrow funnel root",Vector3(0,8.44,z),6.77,2.68,7.62,1.08,_steel)
		var pipe := _pipe("Tall narrow funnel",Vector3(0,(top+9.53)*0.5,z),top-9.53,2.21,1.88,1.29,_steel)
		pipe.rotation.x = deg_to_rad(4.37)
		var lip := _pipe("Narrow stack lip",Vector3(0,top,z+0.42),0.54,1.99,1.86,1.31,_upper)
		lip.rotation.x = pipe.rotation.x
		var shade := _pipe("Dark funnel top",Vector3(0,top+0.30,z+0.44),0.06,1.63,1.63,1.28,_dark)
		shade.rotation.x = pipe.rotation.x
		for side: float in [-1.0,1.0]:
			_spar("Stack exterior strut",Vector3(side*1.90,9.88,z+1.23),Vector3(side*1.69,top-0.47,z+1.83),0.140,_steel)
	_mast_silhouette(-13.18,8.73,32.84,5.86,2.28)
	_mast_silhouette(17.11,8.72,28.73,5.03,2.18)
	_spar("Mast-to-mast thin line",Vector3(0,29.84,-12.53),Vector3(0,25.51,17.79),0.039,_dark)


func _furniture() -> void:
	_weather_rails(0.92,3.13)
	_hawse_relief(-72.81,2.95,5.81,0.94)
	_octagon("Small forecastle windlass silhouette",Vector3(0,_deck_height(-70.2)+0.42,-70.2),2.60,0.80,2.34,0.45,_steel)
	for side: float in [-1.0,1.0]:
		for z: float in [-72.2,-63.1,65.3,74.2]:
			_pipe("Deck bollard pair",Vector3(side*2.21,_deck_height(z)+0.21,z),0.44,0.20,0.18,1.0,_steel)
		_duty_boat(Vector3(side*5.20,6.50,-5.92),side,0.88)
		for z: float in [-10.03,-7.82,8.22,12.41]:
			_box("Upright deckhouse panel or shadow",Vector3(side*4.96,6.79,z),Vector3(0.088,0.61,0.88),_dark)
		_spar("Side walkway relief",Vector3(side*5.02,6.79,-6.36),Vector3(side*5.21,6.70,11.86),0.23,_steel)
		for z: float in [62.6,67.3,72.41]:
			var podium := Vector3(side*2.37,_deck_height(z)+0.18,z)
			_gallery("After-deck round shield outline",podium,2.16,0.35,2.41,_steel)
			_pipe("After-deck shade",podium+Vector3.UP*0.19,0.038,0.75,0.73,1.0,_dark)
		_spar("Foredeck chain depiction",Vector3(side*1.04,_deck_height(-70.23)+0.06,-70.23),Vector3(side*0.92,_deck_height(-79.74)+0.08,-79.74),0.117,_dark)
		_hull_number(side)
	_spar("Slim bow staff",Vector3(0,_deck_height(-80.61),-80.61),Vector3(0,11.37,-80.61),0.091,_upper)
	_spar("Aft staff",Vector3(0,_deck_height(80.22),80.22),Vector3(0,8.54,80.22),0.092,_upper)


func _hull_number(side: float) -> void:
	# Small white hull number relief, photo shown; no decal resource dependencies.
	_number_at(side,4.56,-67.1)
	_number_at(side,3.41,73.4)


func _number_at(side: float, y: float, z: float) -> void:
	var exterior: PackedVector3Array = (get_node("Hull and deck/Hull plating") as MeshInstance3D).mesh.get_faces()
	var five := PackedVector2Array([Vector2(0.48,0.70),Vector2(0.04,0.70),Vector2(0.04,0.40),Vector2(0.42,0.40),Vector2(0.48,0.30),Vector2(0.48,0.08),Vector2(0.38,0.0),Vector2(0.04,0.0)])
	var three := PackedVector2Array([Vector2(0.01,0.70),Vector2(0.41,0.70),Vector2(0.48,0.62),Vector2(0.48,0.42),Vector2(0.39,0.36),Vector2(0.17,0.36),Vector2(0.39,0.36),Vector2(0.48,0.29),Vector2(0.48,0.08),Vector2(0.39,0.0),Vector2(0.01,0.0)])
	for j: int in range(2):
		var code: PackedVector2Array = [five,three][j]
		for k: int in range(code.size()-1):
			var a: Vector2 = code[k]+Vector2(float(j)*0.61,0)
			var b: Vector2 = code[k+1]+Vector2(float(j)*0.61,0)
			var aa: Vector3 = _on_side(exterior,side,y+a.y,z-a.x*side)
			var bb: Vector3 = _on_side(exterior,side,y+b.y,z-b.x*side)
			if aa.is_finite() and bb.is_finite():
				_spar("Painted hull number relief",aa,bb,0.052,_pale)


func _on_side(faces: PackedVector3Array, side: float, y: float, z: float) -> Vector3:
	for i: int in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(side*14.0,y,z),Vector3(0,y,z),faces[i],faces[i+1],faces[i+2])
		if hit is Vector3:
			return hit+Vector3(side*0.022,0,0)
	return Vector3.INF
