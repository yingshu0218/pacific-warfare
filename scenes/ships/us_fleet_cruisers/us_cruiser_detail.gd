extends "res://scenes/ships/visual_study/archival_cruiser_art.gd"
const GUN_RIG := preload("res://scripts/presentation/models/archive_gun_rig.gd")
var _main_rig_index: int = 0

## Shaded low-relief game exhibit parts shared by the two dated cruiser exteriors.
var _cream: StandardMaterial3D
var _plate_edge: StandardMaterial3D
var _side_shadow: StandardMaterial3D
var _coal: StandardMaterial3D

func _colors(body: String, upper: String, deck: String, hull: String) -> void:
	_steel = _paint(body)
	_upper = _paint(upper)
	_deck = _paint(deck)
	_dark = _paint("29343d")
	_hull_side = _paint(hull)
	_underbody = _paint("704747")
	_cream = _paint("b6bdba")
	_plate_edge = _paint("64747d")
	_side_shadow = _paint("4c5f69")
	_coal = _paint("46515a")

func _funnel(z: float, bottom: float, top: float, width: float, elongation: float, rake: float) -> void:
	_octagon("Funnel casing foot",Vector3(0,bottom-.47,z),width*2.51,1.57,width*2.59*elongation,width*.34,_steel,.91)
	var shell := _pipe("Rounded stack exterior",Vector3(0,(bottom+top)*.50,z),top-bottom,width,width*.88,elongation,_steel)
	shell.rotation.x = deg_to_rad(rake)
	var dz: float = 0.5*(top-bottom)*sin(shell.rotation.x)
	var lip := _pipe("Stack rolled cap",Vector3(0,top,z+dz),.51,width*.91,width*.96,elongation,_coal)
	lip.rotation.x = shell.rotation.x
	var shade := _pipe("Stack top relief shade",Vector3(0,top+.28,z+dz),.04,width*.78,width*.78,elongation,_dark)
	shade.rotation.x = shell.rotation.x
	for s: float in [-1.0,1.0]:
		_spar("Exterior uptake flute",Vector3(s*width*.91,bottom+.18,z+.39),Vector3(s*width*.81,top-.65,z+.39+dz),.126,_upper)

func _aft_mast(z: float, foot: float, top: float, yard: float) -> void:
	_spar("After light pole",Vector3(0,foot,z),Vector3(0,top,z+.62),.225,_steel)
	_spar("After main yard",Vector3(-yard,top-4.64,z+.54),Vector3(yard,top-4.64,z+.54),.102,_steel)
	_spar("After mid yard",Vector3(-yard*.58,top-6.75,z+.47),Vector3(yard*.58,top-6.75,z+.47),.093,_steel)
	for s: float in [-1.0,1.0]:
		_spar("After thin stay",Vector3(s*yard*.81,top-4.65,z+.53),Vector3(s*2.31,foot+2.4,z-1.06),.038,_dark)
		_spar("After pole foot brace",Vector3(s*1.51,foot,z+1.33),Vector3(0,foot+5.11,z+.20),.16,_steel)

func _watch(z: float, y: float, scale: float) -> void:
	var p := Vector3(0,y,z)
	_gallery("Raised watch balcony",p,6.32*scale,.37,5.14*scale,_upper)
	_octagon("Small watch enclosure",p+Vector3.UP*1.03*scale,3.79*scale,1.83*scale,3.35*scale,.61*scale,_steel,.94)
	_gallery("Capped watch roof",p+Vector3.UP*2.03*scale,4.06*scale,.33,3.42*scale,_upper)
	_windows_face(p+Vector3(0,1.27*scale,-1.61*scale),4,.63*scale,.42*scale,.33*scale)

func _work_platform(p: Vector3, w: float, l: float) -> void:
	_gallery("Open deck round shield silhouette",p,w,.72,l,_steel)
	_gallery("Recess represented by surface shade",p+Vector3.UP*.37,w*.81,.034,l*.83,_dark)
	_pipe("Inert central pedestal silhouette",p+Vector3.UP*.66,.75,w*.13,w*.10,1.0,_upper)

func _boat_crane(p: Vector3, end: Vector3, scale: float) -> void:
	_pipe("Crane foot",p+Vector3.UP*.31,.59,1.01*scale,.74*scale,1.0,_steel)
	var a := p+Vector3.UP*1.20*scale
	var b := end
	var basis := (b-a).cross(Vector3.UP).normalized()*0.29*scale
	var spine := Vector3.UP*.45*scale
	for side: float in [-1.0,1.0]:
		_spar("Crane outer edge",a+basis*side,b+basis*side,.14*scale,_steel)
		_spar("Crane lower edge",a+basis*side-spine,b+basis*side-spine,.12*scale,_steel)
		for i: int in range(6):
			var u: Vector3 = a.lerp(b,float(i)/6.0)+basis*side
			var v: Vector3 = a.lerp(b,float(i+1)/6.0)+basis*side
			_spar("Crane open lattice",u,v-spine,.073*scale,_upper)
	_spar("Crane suspended line",b,b-Vector3.UP*2.1*scale,.041,_dark)

func _rail_track(p: Vector3, direction: Vector3, length: float) -> void:
	var q: Vector3 = p+direction*length
	var across: Vector3 = direction.cross(Vector3.UP)
	for side: float in [-1.0,1.0]:
		_spar("Fixed outer deck rail beam",p+across*1.05*side,q+across*1.05*side,.23,_steel)
		for i: int in range(7):
			var x: Vector3 = p.lerp(q,float(i)/7.0)+across*1.03*side
			_spar("Fixed undercut deck rail shape",x,x+direction*.92-Vector3.UP*.45,.115,_upper)
	for i: int in range(10):
		var t: Vector3 = p.lerp(q,float(i)/9.0)
		_spar("Inert transverse rail brace",t+across*1.03,t-across*1.03,.123,_upper)

func _number(value: String, z: float, y: float, digit_height: float) -> void:
	# Small hull identifier only; project each stroke onto the artwork side mesh.
	var digits: Dictionary = {
		"3":[Vector2(0,.7),Vector2(.38,.7),Vector2(.47,.61),Vector2(.47,.44),Vector2(.35,.35),Vector2(.16,.35),Vector2(.35,.35),Vector2(.47,.25),Vector2(.47,.079),Vector2(.38,0),Vector2(0,0)],
		"4":[Vector2(.02,.70),Vector2(.02,.31),Vector2(.48,.31),Vector2(.35,.31),Vector2(.35,.70),Vector2(.35,0)],
		"8":[Vector2(.09,.70),Vector2(.36,.70),Vector2(.46,.61),Vector2(.46,.44),Vector2(.36,.35),Vector2(.09,.35),Vector2(.01,.26),Vector2(.01,.09),Vector2(.09,0),Vector2(.36,0),Vector2(.46,.09),Vector2(.46,.26),Vector2(.36,.35),Vector2(.09,.35),Vector2(.01,.44),Vector2(.01,.61),Vector2(.09,.70)],
	}
	var plating: MeshInstance3D = get_node("Hull and weather deck/Hull plating") as MeshInstance3D
	var face: PackedVector3Array = plating.mesh.get_faces()
	for side: float in [-1.0,1.0]:
		for letter: int in range(value.length()):
			var shape: Array = digits[value.substr(letter,1)]
			for i: int in range(shape.size()-1):
				var a: Vector2 = (shape[i]+Vector2(float(letter)*.59,0))*digit_height/.70
				var b: Vector2 = (shape[i+1]+Vector2(float(letter)*.59,0))*digit_height/.70
				var pa: Vector3 = _side_hit(face,side,y+a.y,z-side*a.x)
				var pb: Vector3 = _side_hit(face,side,y+b.y,z-side*b.x)
				if pa.is_finite() and pb.is_finite():
					_spar("Hull number paint",pa,pb,.074,_cream)

func _side_hit(faces: PackedVector3Array, side: float, y: float, z: float) -> Vector3:
	for i: int in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(side*13.0,y,z),Vector3(0,y,z),faces[i],faces[i+1],faces[i+2])
		if hit is Vector3:
			return hit+Vector3(side*.023,0,0)
	return Vector3.INF

func _bridge_side(side: float, x: float, y: float, z: float, count: int) -> void:
	for k: int in range(count):
		_box("Shadowed side bridge pane",Vector3(side*x,y,z+float(k)*.90),Vector3(.066,.56,.65),_dark)

func _deck_edges(z: float, x: float) -> void:
	for side: float in [-1.0,1.0]:
		var p := Vector3(side*x,_deck_height(z)+.16,z)
		_pipe("Closed bollard seat",p,.37,.21,.17,1.0,_steel)
		_spar("Fixed rail edge relief",p-Vector3(0,0,.6),p+Vector3(0,0,.6),.09,_upper)


func _hull_relief(panel_z: Array[float], bow_only: bool) -> void:
	var plating: MeshInstance3D = get_node("Hull and weather deck/Hull plating") as MeshInstance3D
	var face: PackedVector3Array = plating.mesh.get_faces()
	for side: float in [-1.0,1.0]:
		for i: int in range(1,_stations().size()-3):
			var a: Vector4 = _stations()[i]
			var b: Vector4 = _stations()[i+1]
			for level: float in [0.37,0.64]:
				if bow_only and level==0.37 and absf(a.x)<_half_length()*.59:
					continue
				var p: Vector3 = _side_hit(face,side,a.z*level,a.x+.04)
				var q: Vector3 = _side_hit(face,side,b.z*level,b.x-.04)
				if p.is_finite() and q.is_finite():
					_spar("Subtle hull plating line",p,q,.036,_plate_edge)
		for z: float in panel_z:
			var y: float = _deck_height(z)*.75
			var p: Vector3 = _side_hit(face,side,y,z)
			if p.is_finite():
				_pipe("Upper hull small dark relief",p,.032,.112,.112,1.0,_side_shadow).rotation.z = PI/2

func _deck_service(p: Vector3, scale: float) -> void:
	_octagon("Deck service coaming",p+Vector3.UP*.13,.94*scale,.24,1.29*scale,.17,_steel)
	_octagon("Deck service lid",p+Vector3.UP*.29,.76*scale,.16,1.04*scale,.17,_upper)

func _small_halyards(z: float, foot: float, tip: float, yard: float) -> void:
	for s: float in [-1.0,1.0]:
		for off: float in [-.61,0,.61]:
			_spar("Fan of light halyards",Vector3(s*(yard+off),tip,z+.19),Vector3(s*1.95,foot,z-1.5+off),.028,_dark)
		_spar("Light outer yard brace",Vector3(s*yard*.91,tip,z+.19),Vector3(0,tip+2.42,z+.29),.041,_steel)


func _photo_case(z: float,x: float,y: float,w: float,l: float,h: float,raised: float,bars: int,direction: Vector3) -> void:
	var start := _group.get_child_count()
	super._photo_case(z,x,y,w,l,h,raised,bars,direction)
	var housing: Array[Node3D] = []
	var barrels: Array[Node3D] = []
	for node: Node3D in _group.get_children().slice(start):
		var label := str(node.name)
		# Names receive Godot numeric disambiguation on repeated assemblies.
		if label.begins_with("Inert exterior outline strip"):
			barrels.append(node)
		elif not label.begins_with("Display housing base") and not label.begins_with("Outer plinth"):
			housing.append(node)
	_main_rig_index += 1
	var center := Vector3(x,y+raised,z)
	GUN_RIG.attach(self, "main_%02d" % _main_rig_index, "main", center,
		center+Vector3.UP*h*.53+direction*l*.40, direction, housing, barrels)
