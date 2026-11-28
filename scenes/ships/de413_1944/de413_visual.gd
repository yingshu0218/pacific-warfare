extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
## DE-413 October 1944 nonoperational game exterior, bow -Z, waterline y=0.
const HALF_LENGTH := 46.6344
const BEAM := 11.1506
const DISPLAY_DRAFT := 4.064
const HULL: Array[Vector4] = [
	Vector4(-46.6344,.024,6.42,.02), Vector4(-45.61,.45,6.36,.14),
	Vector4(-43.7,1.14,6.23,.46),Vector4(-41.4,1.92,6.08,.89),
	Vector4(-37.7,2.88,5.90,1.83),Vector4(-32.8,3.95,5.80,3.03),
	Vector4(-27.4,4.79,5.70,4.00),Vector4(-22.1,5.26,5.59,4.68),
	Vector4(-17,5.5753,5.48,5.31),Vector4(-11,5.5753,5.39,5.46),
	Vector4(-4.5,5.5753,5.29,5.48),Vector4(-.9,5.56,5.24,5.46),
	Vector4(-.40,5.55,3.85,5.44),Vector4(5.0,5.49,3.75,5.40),
	Vector4(13,5.30,3.64,5.18),Vector4(21,4.94,3.54,4.75),
	Vector4(27,4.43,3.49,4.14),Vector4(33.2,3.73,3.46,3.44),
	Vector4(39,2.91,3.44,2.46),Vector4(43,2.15,3.46,1.60),
	Vector4(45.4,1.36,3.48,.78),Vector4(46.6344,.56,3.50,.28)
]
const LOCAL_GUN_RIG = preload("res://scripts/presentation/models/archive_gun_rig.gd")

func _stations() -> Array[Vector4]: return HULL
func _half_length() -> float: return HALF_LENGTH
func _draft() -> float: return DISPLAY_DRAFT

func _section(row: Vector4, side: float) -> PackedVector3Array:
	var rail: PackedVector3Array = super._section(row,side)
	# Bow sheen and darker stern underside are visual approximations, not offsets.
	var stem: float = smoothstep(36.0,HALF_LENGTH,-row.x)
	var after: float = smoothstep(33.0,HALF_LENGTH,row.x)
	for i: int in range(rail.size()-1):
		var p: Vector3 = rail[i]
		p.z += stem*[4.90,3.68,2.31,2.06,.76][i]-after*[6.11,4.84,1.69,1.15,.40][i]
		if i<2: p.y = lerpf(-.65,-DISPLAY_DRAFT,smoothstep(0.0,42.0,HALF_LENGTH-absf(row.x)))*(1.0 if i==0 else .65)
		if i==4: p.x = side*lerpf(row.w,row.y,.70)
		rail[i] = p
	return rail

func _ready() -> void:
	_steel = _paint("74818a")
	_deck = _paint("4e5863")
	_upper = _paint("829095")
	_dark = _paint("2e3944")
	_hull_side = _paint("809399")
	_underbody = _paint("6f4141")
	_group = _layer("Hull and deck")
	_hull()
	_side_finish()
	_group = _layer("Bridge and stack")
	_bridge()
	_group = _layer("Open weather deck detail")
	_fittings()
	_group = _layer("Inert exterior silhouette details")
	_ornaments()

func _bridge() -> void:
	# Compact multi-level pilot house and exposed boxy wing over recess.
	_octagon("Low forecastle deckhouse",Vector3(0,6.6,-19.33),7.90,2.43,12.61,1.11,_steel,.99)
	_octagon("Raised pilot deck",Vector3(0,7.85,-16.22),9.33,.56,5.68,.90,_upper)
	_octagon("Broad low pilot enclosure",Vector3(0,9.26,-15.80),6.94,2.42,6.63,.88,_steel,.98)
	_octagon("Overhanging flattened bridge roof",Vector3(0,10.59,-15.74),7.22,.26,6.78,.99,_upper)
	_box("Pilot front window band",Vector3(0,9.91,-19.09),Vector3(4.60,.61,.057),_dark)
	for i: int in range(6):
		_box("Pilot front mullion",Vector3((i-2.5)*.73,9.91,-19.14),Vector3(.080,.62,.082),_upper)
	for side: float in [-1.,1.]:
		_box("Pilot cabin flank glazing",Vector3(side*3.51,9.94,-15.89),Vector3(.06,.55,3.55),_dark)
		_octagon("Low bridge wing bulwark",Vector3(side*3.83,8.71,-15.18),1.41,1.04,3.80,.41,_steel)
		_spar("Visible diagonal bridge wing brace",Vector3(side*3.39,6.64,-17.10),Vector3(side*4.31,7.73,-16.73),.19,_steel)
	_octagon("Short bridge lookout head",Vector3(0,11.06,-13.25),3.06,.86,2.50,.47,_steel,.91)
	_octagon("Waist deckhouse",Vector3(0,5.37,6.2),7.25,3.48,15.63,.98,_steel,.97)
	_octagon("Middle lower exposed step",Vector3(0,7.41,.55),6.36,1.04,8.03,.69,_steel,.95)
	_octagon("Single central flattened stack trunk",Vector3(0,9.58,-2.83),4.64,4.69,4.95,.92,_steel,.86)
	_octagon("Short stack cap",Vector3(0,12.05,-2.63),4.41,.48,4.39,.76,_dark,.97)
	_octagon("Dark uptake top silhouette",Vector3(0,12.31,-2.59),3.82,.07,3.67,.67,_dark)
	_octagon("Low aft crew deckhouse",Vector3(0,4.73,19.93),6.43,2.47,10.1,.84,_steel,.94)
	_octagon("Low aft observation desk",Vector3(0,6.34,18.89),4.16,1.03,4.68,.55,_upper)
	# The exact-ship photo has one tall, slender, aft-raked foremast.
	var root := Vector3(0,7.79,-10.51)
	var top := Vector3(0,27.18,-7.04)
	_spar("Tall single raked mast",root,top,.21,_steel)
	_spar("Slim forestay",top-Vector3.UP*1.47,Vector3(0,9.45,-20.82),.046,_dark)
	_spar("Slim backstay",top-Vector3.UP*3.05,Vector3(-2.79,7.01,9.69),.047,_dark)
	var yard := root.lerp(top,.76)
	_spar("Foremast long yard",yard+Vector3(-3.60,0,0),yard+Vector3(3.60,0,0),.10,_dark)
	_spar("Thin upper signal stick",top-Vector3.UP*2.40,top+Vector3.UP*.72,.085,_dark)
	_spar("Aft deck short staff",Vector3(0,5.99,24.14),Vector3(0,9.33,24.46),.085,_upper)

func _ornaments() -> void:
	for i: int in range(2):
		var z: float = [-33.5,29.38][i]
		var p := Vector3(0,_deck_height(z),z)
		var d: float = -1.0 if i==0 else 1.0
		_pipe("Static visual cover plinth",p+Vector3.UP*.35,.77,1.71,1.62,1.0,_steel)
		var first := _group.get_child_count()
		_octagon("Rounded single exterior cover",p+Vector3.UP*1.38,3.62,1.46,3.92,.64,_steel,.91)
		_spar("Inert frontal silhouette",p+Vector3(0,1.46,1.74*d),p+Vector3(0,1.66,4.57*d),.19,_dark)
		var parts := _group.get_children()
		LOCAL_GUN_RIG.attach(self,"main_%02d" % (i+1),"main",p+Vector3.UP*0.75,p+Vector3.UP*1.46,Vector3(0,0,d),
			parts.slice(first,first+1),parts.slice(first+1))
	for z: float in [13.55,22.3]:
		var p := Vector3(0,6.58 if z>20 else 6.82,z)
		_pipe("Low deck screen geometry",p,.63,2.16,2.10,1.05,_steel)
		_pipe("Circular platform inset shade",p+Vector3.UP*.34,.059,1.80,1.76,1.05,_dark)
		_octagon("Low exterior visual outline",p+Vector3.UP*.53,1.78,.84,1.69,.39,_upper)
	for side: float in [-1.,1.]:
		for z: float in [-24.75,-5.77,9.66,17.0]:
			var y: float = _deck_height(z)+.52
			_octagon("Low side casing",Vector3(side*3.14,y,z),1.38,1.22,2.49,.22,_steel,.88)

func _fittings() -> void:
	for side: float in [-1.,1.]:
		for index: int in range(2,HULL.size()-2):
			var a: Vector4 = HULL[index]; var b: Vector4 = HULL[index+1]
			if a.z-b.z>1.0: continue
			var p := Vector3(side*(a.y-.13), a.z+.77,a.x)
			var q := Vector3(side*(b.y-.13), b.z+.77,b.x)
			_spar("Deck thin safety rail",p,q,.055,_upper)
			var count: int = ceili(p.distance_to(q)/2.9)
			for n: int in range(count):
				var s: Vector3 = p.lerp(q,float(n)/count)
				_spar("Safety stanchion",s,s-Vector3.UP*.77,.066,_steel)
		var p := Vector3(side*4.03,6.63,-4.45)
		_octagon("Boat cradle",p,1.60,.59,4.96,.39,_dark)
		_octagon("Ship boat open-hull silhouette",p+Vector3.UP*.46,1.69,.65,5.40,.52,_upper,.95)
		_octagon("Boat visible interior shadow",p+Vector3.UP*.83,1.21,.17,4.16,.34,_deck)
		for z: float in [-1.95,1.95]:
			var heel: Vector3 = p+Vector3(-side*.3,-.58,z)
			var head: Vector3 = p+Vector3(side*.61,1.10,z)
			_spar("Boat davit",heel,head,.13,_steel)
		for z: float in [-41.9,-38.11,38.0,41.5]:
			var b := Vector3(side*(.88 if z<0 else 1.72),_deck_height(z)+.17,z)
			_pipe("Dock fitting",b,.43,.19,.17,1.0,_dark)
		var p2 := Vector3(side*1.87,-1.74,39.23)
		_spar("Stern underwater display shape",p2,p2+Vector3(-side*.51,.43,-5.80),.25,_underbody)
		var hub: MeshInstance3D = _pipe("Aft external hub",p2,.63,.25,.18,1.0,_underbody)
		hub.rotation.x = PI*.5
	_octagon("Simplified aft rudder shadow",Vector3(0,-1.34,43.0),.39,2.51,2.39,.16,_underbody)

func _side_finish() -> void:
	# NH 96011 demonstrates high-contrast swashes on the visible side. The
	# identified-shape approximation uses a fixed stock texture and is not
	# an assertion that intermediate or hidden-side panel shapes are exact.
	var node := _group.get_node("Hull plating") as MeshInstance3D
	var mesh: Mesh = node.mesh
	var a: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var tex_uv := PackedVector2Array()
	for p: Vector3 in vertices:
		tex_uv.append(Vector2((p.z+HALF_LENGTH)/(2*HALF_LENGTH),(1.0-p.y/7.0)*.5+(0.0 if p.x>=0.0 else .5)))
	a[Mesh.ARRAY_TEX_UV] = tex_uv
	var patched := ArrayMesh.new()
	patched.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	var image := Image.create_empty(1024,256,false,Image.FORMAT_RGBA8)
	for yy: int in range(256):
		for xx: int in range(1024):
			var z: float = lerpf(-HALF_LENGTH,HALF_LENGTH,float(xx)/1023.0)
			var y: float = 7.0*(1.0-float(yy%128)/127.0)
			var dark: bool = false
			if yy<128:
				dark = (z<-22.7 and y<1.07+2.21*sin((z+46.7)*PI/24.0))
				dark = dark or (z>-17.0 and z<12.6 and y>2.3+pow((z+4.0)/13.0,2)*1.55)
				dark = dark or (z>31.6 and y<.3+(z-31.6)*.15)
			else:
				# Far-side treatment plain where the October view is uninformative.
				dark = false
			image.set_pixel(xx,yy,Color("344452") if dark else Color("87999e"))
	var material := _paint("ffffff")
	material.albedo_texture = ImageTexture.create_from_image(image)
	node.mesh = patched
	node.material_override = material
