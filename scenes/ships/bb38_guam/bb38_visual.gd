extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"

const DISPLAY_GUN := preload("res://scripts/presentation/models/archive_gun_rig.gd")
## USS Pennsylvania, 1944-07-21 Guam visual exhibit; no moving equipment.
const HALF_LENGTH := 92.6592
const BEAM := 32.385
const DISPLAY_DRAFT := 8.79
const HULL: Array[Vector4] = [
	Vector4(-92.6592,.04,8.39,.03),Vector4(-91.2,1.14,8.34,.31),
	Vector4(-88,3.06,8.17,1.45),Vector4(-83,5.63,7.89,3.47),
	Vector4(-77,8.34,7.68,6.32),Vector4(-69,10.68,7.58,8.62),
	Vector4(-60,12.61,7.48,11.55),Vector4(-50,13.94,7.42,13.19),
	Vector4(-40,14.76,7.39,15.05),Vector4(-29,15.39,7.35,16.1925),
	Vector4(-15,15.58,7.28,16.1925),Vector4(0,15.51,7.21,16.1925),
	Vector4(15,15.37,7.11,16.02),Vector4(27,15.09,7.01,15.50),
	Vector4(36,14.63,6.91,14.80),Vector4(40,14.32,6.85,14.47),
	Vector4(40.42,14.29,5.36,14.43),Vector4(48,13.57,5.25,13.65),
	Vector4(58,12.17,5.09,12.43),Vector4(68,9.98,4.96,9.80),
	Vector4(77,7.80,4.82,7.58),Vector4(83,5.78,4.87,5.28),
	Vector4(87.7,3.7,4.93,2.9),Vector4(91.2,2.02,5.0,1.19),
	Vector4(92.6592,.58,5.08,.30)
]

func _stations() -> Array[Vector4]: return HULL
func _half_length() -> float: return HALF_LENGTH
func _draft() -> float: return DISPLAY_DRAFT

func _section(row: Vector4, side: float) -> PackedVector3Array:
	var section: PackedVector3Array = super._section(row,side)
	var bore: float = smoothstep(72.0,HALF_LENGTH,-row.x)
	var tuck: float = smoothstep(67.0,HALF_LENGTH,row.x)
	for i: int in range(section.size()-1):
		var p: Vector3 = section[i]
		p.z += bore*[5.2,3.89,2.74,2.49,1.15][i]-tuck*[10.3,6.05,3.2,2.6,.60][i]
		if i==1:
			p.x *= 1.08-.08*smoothstep(25.0,67.0,absf(row.x))
		elif i==2:
			p.x = side*row.w
		elif i==3:
			p.x = side*lerpf(row.w,row.y,.04)
		section[i] = p
	return section

func _ready() -> void:
	_steel = _paint("4f5e68")
	_deck = _paint("566374")
	_upper = _paint("687982")
	_dark = _paint("252c35")
	_hull_side = _paint("75909b")
	_underbody = _paint("78484a")
	_group = _layer("Hull and deck")
	_hull()
	_side_tone()
	_group = _layer("Main structures")
	_structure()
	_group = _layer("Static deck silhouettes")
	_display_ornaments()
	_group = _layer("Weather fittings")
	_fittings()

func _structure() -> void:
	_octagon("Wide armor-deck step",Vector3(0,8.69,-8.2),27.30,3.00,72.5,3.1,_steel,.96)
	_octagon("Broad lower fore deckhouse",Vector3(0,12.34,-17.5),23.52,4.34,38.45,3.1,_steel,.91)
	_octagon("Forward bridge taper foot",Vector3(0,16.08,-17.8),13.60,3.27,17.50,1.6,_steel,.91)
	_octagon("Bridge wing terrace",Vector3(0,18.18,-19.42),19.7,1.06,11.74,2.2,_upper)
	_octagon("Rounded bridge face",Vector3(0,19.76,-19.3),13.19,2.4,11.37,2.37,_steel,.95)
	_box("Dark broad bridge glaze front",Vector3(0,20.40,-24.77),Vector3(7.44,.61,.14),_dark)
	for x: float in [-3.1,-2.02,-.98,0,.98,2.02,3.10]:
		_box("Bridge glaze vertical dividers",Vector3(x,20.4,-24.86),Vector3(.092,.61,.13),_upper)
	_octagon("Lower observation roof",Vector3(0,21.02,-19.0),15.82,.86,12.02,2.21,_upper)
	var foot: float = -17.0
	for x: float in [-3.18,3.18]:
		_spar("Tall angular fore tripod leg",Vector3(x,20.45,foot+3.56),Vector3(0,33.62,foot-.64),.59,_steel)
	_spar("Fore tripod upright",Vector3(0,20.58,foot-3.14),Vector3(0,35.61,foot-.54),.58,_steel)
	_octagon("High projecting tripod platform",Vector3(0,28.12,foot-.25),10.64,.91,7.06,1.09,_steel)
	_octagon("Raised forward observation enclosure",Vector3(0,31.79,foot-.36),5.65,2.77,5.68,.81,_upper,.91)
	_octagon("High square lookout cap",Vector3(0,33.36,foot-.50),5.03,.45,5.26,.77,_steel)
	_spar("Wide cross spar below high lookouts",Vector3(-11.7,28.45,foot),Vector3(11.7,28.45,foot),.26,_steel)
	_spar("Thin crown mast",Vector3(0,32.7,foot-.49),Vector3(0,40.12,foot-.51),.26,_dark)
	for dx: float in [-3.9,3.9]:
		_spar("Crown yawing silhouette bar",Vector3(0,38.9,foot-.67),Vector3(dx,38.9,foot-.67),.13,_dark)
	for z: float in [-5.6]:
		_pipe("Single wide oval stack",Vector3(0,17.37,z),10.92,3.67,3.43,1.26,_steel)
		_pipe("Wide funnel rim",Vector3(0,22.94,z),.54,3.62,3.48,1.27,_dark)
		_pipe("Funnel top shade",Vector3(0,23.21,z),.054,3.26,3.26,1.27,_dark)
	_octagon("Aft block deckhouse",Vector3(0,9.56,15.1),18.44,4.70,24.2,2.47,_steel,.96)
	_octagon("Aft center lookout",Vector3(0,14.48,20.2),10.1,5.31,10.21,1.73,_steel,.83)
	_octagon("Aft lookout lip",Vector3(0,17.26,20.2),10.20,.69,7.99,1.66,_upper)
	_octagon("Aft elevated look shoulder",Vector3(0,19.31,20.2),6.2,3.15,6.84,1.13,_steel,.91)
	_spar("Aft slender mast",Vector3(0,12.4,13.9),Vector3(0,32.1,13.58),.29,_dark)
	_spar("Aft open mast border",Vector3(-3.5,30.58,13.61),Vector3(3.5,30.58,13.61),.24,_steel)
	for side: float in [-1.,1.]:
		_spar("Aft mast strut",Vector3(side*3.9,13.0,15.8),Vector3(0,23.10,13.81),.31,_steel)
		_octagon("Open wing platform",Vector3(side*9.67,16.87,-14.2),6.30,.63,8.15,1.02,_steel)
		_octagon("Side wing housing",Vector3(side*10.59,18.5,-14.3),3.65,3.02,4.12,.70,_upper,.88)

func _display_ornaments() -> void:
	for i: int in range(4):
		var z: float = [-48.8,-35.2,36.4,50.5][i]
		var p := Vector3(0,_deck_height(z),z)
		var rise: float = [0.91,3.85,3.54,.84][i]
		_pipe("Main inert envelope seat",p+Vector3.UP*(rise*.5-.09),rise,5.63,5.53,1.04,_steel)
		var first: int = _group.get_child_count()
		_octagon("Large closed exterior cover",p+Vector3.UP*(rise+1.75),11.82,3.54,11.20,1.46,_steel,.88)
		var d: float = -1.0 if i<2 else 1.0
		for x: float in [-2.55,0,2.55]:
			var b := p+Vector3(x,rise+1.85,d*5.06)
			_spar("Fixed dark frontal silhouette",b,b+Vector3(0,.48,d*9.16),.61,_dark)
		var pieces: Array[Node] = _group.get_children().slice(first)
		DISPLAY_GUN.attach(self,"main_%02d" % (i+1),"main",p+Vector3.UP*rise,p+Vector3(0,rise+1.85,d*5.06),Vector3(0,0,d),[pieces[0]],pieces.slice(1))
	var secondary: int = 0
	for side: float in [-1.0,1.0]:
		for i: int in range(4):
			var z: float = [-22.2,-12.1,-2.42,7.43][i]
			var h: float = [1.58,2.18,1.94,1.15][i]
			var p := Vector3(side*12.12,8.62+h,z)
			var first: int = _group.get_child_count()
			_octagon("Shallow side gallery cover",p,5.03,2.15,5.4,.69,_steel,.87)
			_pipe("Side gallery seat",p-Vector3.UP*1.03,1.46,2.31,2.24,1.04,_upper)
			for dz: float in [-.84,.84]:
				_spar("Inert side silhouette",p+Vector3(side*2.2,.2,dz),p+Vector3(side*4.36,.39,dz),.19,_dark)
			secondary += 1
			var pieces: Array[Node] = _group.get_children().slice(first)
			DISPLAY_GUN.attach(self,"secondary_%02d" % secondary,"secondary",p,p+Vector3(side*2.2,.2,0),Vector3(side,0,0),[pieces[0]],pieces.slice(2))
		for z: float in [-34.6,-18.6,15.33,28.6]:
			var y: float = 9.25 if z>-25 and z<18 else 7.88
			var p := Vector3(side*11.6,y,z)
			_pipe("Round splinter-screen silhouette",p,.83,2.05,1.96,1.02,_steel)
			_pipe("Dark platform inset",p+Vector3.UP*.44,.08,1.70,1.72,1.0,_dark)

func _fittings() -> void:
	for sign_x: float in [-1.0,1.0]:
		for i: int in range(2,HULL.size()-2):
			var a: Vector4 = HULL[i]; var b: Vector4 = HULL[i+1]
			if a.z-b.z>1.1: continue
			var p := Vector3(sign_x*(a.y-.21),a.z+.89,a.x)
			var q := Vector3(sign_x*(b.y-.21),b.z+.89,b.x)
			_spar("High continuous rail edge",p,q,.088,_upper)
			for j: int in range(ceili(p.distance_to(q)/4)):
				var v: Vector3 = p.lerp(q,float(j)/ceili(p.distance_to(q)/4))
				_spar("Rail stanchion",v,v-Vector3.UP*.90,.095,_steel)
		for z: float in [-83.2,-77.0,75.0,82.4]:
			var p := Vector3(sign_x*2.51,_deck_height(z)+.20,z)
			_pipe("Weather-deck bollard",p,.59,.24,.23,1.0,_dark)
		for z: float in [-62.7,68.2]:
			_octagon("Low boat shade",Vector3(sign_x*6.8, _deck_height(z)+.51,z),2.55,.73,6.42,.42,_upper)
		_spar("Bow line silhouette",Vector3(sign_x*.93,8.07,-86.9),Vector3(sign_x*1.24,7.93,-81.7),.178,_dark)
		_spar("Aft deck beam",Vector3(sign_x*9.3,6.72,60.2),Vector3(sign_x*1.74,6.72,68.1),.36,_steel)
	_octagon("Stern deck handling pedestal",Vector3(0,5.42,81.93),5.10,1.04,5.52,.83,_steel)
	_spar("Stern visual crane heel",Vector3(.4,5.70,82.6),Vector3(.2,10.9,80.0),.47,_steel)
	_spar("Stern visual boom",Vector3(.2,10.9,80.0),Vector3(-2.8,14.75,69.7),.45,_steel)
	_spar("Thin stern boom stay",Vector3(.40,7.12,82.65),Vector3(-2.8,14.75,69.7),.08,_dark)
	_octagon("External stern rudder silhouette",Vector3(0,-2.87,85.22),.95,5.19,4.84,.36,_underbody)

func _side_tone() -> void:
	# A fixed, source-guided exterior colour-field inspired by Measure 32/3D.
	# Broad bands are derived from the wartime plan and drydock image; this
	# is deliberately an interpretive period palette, not a pigment survey.
	var polygons: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-91,.3),Vector2(-79,8.4),Vector2(-72,8.2),Vector2(-78,.3)]),
		PackedVector2Array([Vector2(-64,3.2),Vector2(-51,7.1),Vector2(-12,5.5),Vector2(-13,1.75)]),
		PackedVector2Array([Vector2(-27,.3),Vector2(-11,7.6),Vector2(3.9,7.3),Vector2(-9,.3)]),
		PackedVector2Array([Vector2(7,5.7),Vector2(40.8,6.9),Vector2(76,1.54),Vector2(70.1,.3),Vector2(50.9,2.55),Vector2(12.2,3.1)])
	]
	_paint_plating(polygons,"313e4c","6b8591")

func _paint_plating(polygons: Array[PackedVector2Array], ink: String, base: String) -> void:
	var node := _group.get_node("Hull plating") as MeshInstance3D
	var mesh: Mesh = node.mesh
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	for p: Vector3 in vertices:
		uv.append(Vector2((p.z+HALF_LENGTH)/(HALF_LENGTH*2.0), 1.0-p.y/9.3))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var patched := ArrayMesh.new()
	patched.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var image := Image.create_empty(1280,256,false,Image.FORMAT_RGBA8)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var sample := Vector2(lerpf(-HALF_LENGTH,HALF_LENGTH,float(x)/1279.0),9.3*(1.0-float(y)/255.0))
			var color := Color(base)
			for poly: PackedVector2Array in polygons:
				if Geometry2D.is_point_in_polygon(sample,poly): color = Color(ink); break
			image.set_pixel(x,y,color)
	var painted: StandardMaterial3D = _paint("ffffff")
	painted.albedo_texture = ImageTexture.create_from_image(image)
	node.mesh = patched
	node.material_override = painted
