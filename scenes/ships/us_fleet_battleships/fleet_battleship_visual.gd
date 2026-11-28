extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
const GUN_RIG := preload("res://scripts/presentation/models/archive_gun_rig.gd")

## Hand-authored wartime game silhouettes; no operational or internal geometry.
@export_enum("North Carolina BB-55", "West Virginia BB-48") var exhibit: int = 0

const NC_STATIONS: Array[Vector4] = [
	Vector4(-.5,.004,9.35,.002),Vector4(-.487,.080,9.26,.015),Vector4(-.469,.180,9.05,.058),
	Vector4(-.438,.322,8.72,.144),Vector4(-.398,.475,8.40,.293),Vector4(-.352,.633,8.02,.460),
	Vector4(-.306,.775,7.78,.631),Vector4(-.25,.893,7.66,.800),Vector4(-.194,.967,7.57,.933),
	Vector4(-.129,.998,7.54,.994),Vector4(-.065,.994,7.45,1.),Vector4(0,.981,7.37,1.),
	Vector4(.066,.958,7.30,.988),Vector4(.129,.926,7.26,.947),Vector4(.179,.893,7.25,.910),
	Vector4(.1796,.881,5.03,.905),Vector4(.225,.835,5.0,.864),Vector4(.286,.748,4.92,.769),
	Vector4(.336,.645,4.81,.666),Vector4(.387,.520,4.72,.523),Vector4(.423,.417,4.69,.364),
	Vector4(.455,.306,4.71,.217),Vector4(.478,.223,4.75,.122),Vector4(.492,.145,4.79,.063),
	Vector4(.5,.055,4.85,.033),
]
const WV_STATIONS: Array[Vector4] = [
	Vector4(-.5,.005,8.95,.002),Vector4(-.486,.086,8.82,.012),Vector4(-.463,.201,8.54,.064),
	Vector4(-.428,.335,8.27,.155),Vector4(-.388,.478,8.05,.277),Vector4(-.337,.619,7.89,.480),
	Vector4(-.269,.740,7.74,.748),Vector4(-.202,.829,7.64,.916),Vector4(-.155,.866,7.58,.988),
	Vector4(-.088,.885,7.53,1.),Vector4(0,.887,7.44,1.),Vector4(.078,.882,7.40,1.),
	Vector4(.144,.858,7.36,.984),Vector4(.189,.824,7.32,.917),Vector4(.204,.808,7.30,.879),
	Vector4(.205,.800,5.65,.876),Vector4(.259,.758,5.61,.800),Vector4(.324,.680,5.52,.689),
	Vector4(.378,.596,5.50,.565),Vector4(.423,.466,5.50,.423),Vector4(.457,.349,5.53,.287),
	Vector4(.482,.221,5.56,.162),Vector4(.495,.111,5.59,.079),Vector4(.5,.037,5.61,.020)
]

var _profile: Array[Vector4] = []
var _gun_finish: StandardMaterial3D
var _glass: StandardMaterial3D
var _wood: StandardMaterial3D
var _trunk_dark: StandardMaterial3D
var _trunk_light: StandardMaterial3D

func _stations() -> Array[Vector4]: return _profile
func _half_length() -> float: return 111.0615 if exhibit == 0 else 95.10
func _draft() -> float: return 8.1 if exhibit == 0 else 9.15

func _section(row: Vector4, side: float) -> PackedVector3Array:
	var section: PackedVector3Array = super._section(row,side)
	var fore: float = smoothstep(.34,.5,-row.x / (_half_length()*2.0))
	var aft: float = smoothstep(.31,.5,row.x / (_half_length()*2.0))
	for i: int in section.size()-1:
		var p: Vector3 = section[i]
		p.z += fore * [7.5,4.3,1.5,1.2,.63][i] - aft * [10.7,7.4,4.0,3.7,2.18][i]
		if exhibit == 1:
			p.x *= [1.29,1.10,1.022,1.022,1.013][i]
		section[i] = p
	return section

func _ready() -> void:
	var beam: float = 33.02 if exhibit == 0 else 34.75
	var rows: Array[Vector4] = NC_STATIONS if exhibit == 0 else WV_STATIONS
	for row: Vector4 in rows:
		_profile.append(Vector4(row.x*_half_length()*2.0,row.y*beam*.5,row.z,row.w*beam*.5))
	_steel = _paint("697783" if exhibit == 0 else "64717c")
	_deck = _paint("5b6871" if exhibit == 0 else "5b676e")
	_upper = _paint("84919a")
	_dark = _paint("303841")
	_wood = _paint("646967")
	_glass = _paint("23303a")
	_gun_finish = _paint("6d7980")
	_trunk_dark = _paint("505d68")
	_trunk_light = _paint("95a4ab")
	_hull_side = _paint("ffffff")
	_underbody = _paint("684547")
	_group = _layer("Hull and weather deck")
	_hull()
	_group = _layer("Individual fore and aft superstructures")
	if exhibit == 0:
		_north_carolina()
	else:
		_west_virginia()
	_group = _layer("Inert deck silhouettes")
	_battery()
	_group = _layer("Open balconies and deck detail")
	_detail_pass()
	_group = _layer("Visible maritime fittings")
	_fittings()

func _commit(label: String, surface: SurfaceTool, material: Material) -> void:
	if material != _hull_side:
		super._commit(label,surface,material)
		return
	surface.index()
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = []
	for p: Vector3 in verts:
		var port_offset: float = .5 if p.x < 0.0 else 0.0
		uvs.append(Vector2(.001 + .498*(.5 + p.z/(2.0*_half_length()))+port_offset,.02+.96*clampf(1.0-p.y/9.8,0.0,1.0)))
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var uv_mesh := ArrayMesh.new()
	uv_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_hull_side.albedo_texture = _hull_pattern()
	_hull_side.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_instance(label,uv_mesh,_hull_side)

func _hull_pattern() -> ImageTexture:
	# Broad artistic dazzle boundaries transcribed from aligned broadside photos.
	# Points are coordinates on a normalized two-dimensional paint map, not hull plans.
	var image: Image = Image.create_empty(1024,80,true,Image.FORMAT_RGB8)
	image.fill(Color("76848c"))
	for side: int in range(2):
		var panels: Array = _panels(side)
		for j: int in range(80):
			for i: int in range(512):
				var point := Vector2(float(i)/511.0,float(j)/79.0)
				for panel: Array in panels:
					if Geometry2D.is_point_in_polygon(point,panel[1]):
						image.set_pixel(i+side*512,j,panel[0])
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _panels(side: int) -> Array:
	var pale := Color("99a8af")
	var blue := Color("566a79")
	var charcoal := Color("323e49")
	var entries: Array
	if exhibit == 0 and side == 0:
		entries = [
			[pale,[[0,.2],[.23,.25],[.33,.98],[.03,.98]]],
			[charcoal,[[0,0],[.19,0],[.275,.48],[.18,.65],[.055,.76],[0,.75]]],
			[blue,[[.23,.24],[.43,.32],[.59,1],[.29,1]]],
			[charcoal,[[.32,0],[.61,0],[.68,.8],[.60,1],[.48,.76]]],
			[pale,[[.63,.48],[.74,.37],[.83,.77],[.84,1],[.64,1]]],
			[charcoal,[[.88,.05],[1,0],[1,1],[.94,1]]]
		]
	elif exhibit == 0:
		entries = [
			[pale,[[0,0],[.23,0],[.25,.61],[.38,1],[0,1]]],
			[charcoal,[[.28,0],[.45,0],[.64,.68],[.62,.87],[.43,.74],[.36,1],[.30,.94]]],
			[blue,[[.54,0],[.72,0],[.84,.88],[.8,1],[.65,.96]]],
			[pale,[[.76,.3],[.84,.48],[1,.70],[1,1],[.79,1]]],
			[charcoal,[[.86,.20],[.98,.22],[.95,.49],[.87,.63],[.81,.58]]]
		]
	elif side == 0:
		entries = [
			[pale,[[0,.03],[.20,.22],[.37,.57],[.43,1],[0,1]]],
			[charcoal,[[.035,0],[.25,0],[.38,.27],[.32,.61],[.224,.74],[.117,.62]]],
			[blue,[[.31,.42],[.44,.45],[.56,1],[.27,1]]],
			[charcoal,[[.37,0],[.63,0],[.79,.82],[.77,1],[.61,.84],[.50,.53]]],
			[pale,[[.63,.44],[.72,.30],[.81,.36],[.90,1],[.96,1],[.83,.63]]],
			[charcoal,[[.81,.05],[1,0],[1,1],[.92,.99]]]
		]
	else:
		entries = [
			[blue,[[0,0],[.145,0],[.26,1],[0,1]]],
			[pale,[[.05,1],[.135,.34],[.264,.30],[.35,1]]],
			[charcoal,[[.48,.0],[.76,.0],[.66,.82],[.56,1],[.46,1],[.52,.59]]],
			[pale,[[.28,0],[.53,0],[.52,.43],[.56,.72],[.49,1],[.25,1],[.37,.78]]],
			[blue,[[.62,.72],[.92,.26],[1,.08],[1,1],[.72,1]]]
		]
	for entry: Array in entries:
		var poly := PackedVector2Array()
		for p: Array in entry[1]:
			poly.append(Vector2(p[0],p[1]))
		entry[1] = poly
	return entries

func _deckhouse(label: String, z: float, floor_y: float, width: float, height: float, length: float, bevel: float, mat: Material = null) -> void:
	_octagon(label,Vector3(0,floor_y+height*.5,z),width,height,length,bevel,_steel if mat==null else mat,.98)

func _bridge_ring(label: String, z: float, y: float, width: float, length: float) -> void:
	_deckhouse(label+" wing",z,y,width,.81,length,1.70,_upper)
	_deckhouse(label+" cabin",z-.84,y+.8,width*.73,2.10,length*.75,1.65)
	var front: float = z-.84-length*.75*.49
	var span: float = width*.59
	_box(label+" glazing",Vector3(0,y+2.18,front-.046),Vector3(span,.71,.13),_glass)
	for i in range(1,8):
		var x: float = (float(i)/8.0-.5)*span
		_box("Window mullion",Vector3(x,y+2.18,front-.117),Vector3(.089,.74,.10),_upper)
	for side: float in [-1.0,1.0]:
		_box("Return glazing",Vector3(side*width*.361,y+2.18,z-1.25),Vector3(.14,.62,length*.35),_glass)
	_deckhouse(label+" overhanging canopy",z-.64,y+2.9,width*.81,.35,length*.85,1.86,_upper)

func _stack(label: String, z: float, y: float, height: float, width: float, depth: float) -> void:
	_pipe(label+" oval uptake",Vector3(0,y+height*.5,z),height,width*.52,width*.48,depth/width,_steel)
	var bezel: MeshInstance3D = _pipe(label+" raised lip",Vector3(0,y+height+.02,z),.54,width*.52,width*.51,depth/width,_upper)
	var inset: MeshInstance3D = _pipe(label+" cap shade",Vector3(0,y+height+.30,z),.08,width*.433,width*.433,depth/width,_dark)
	bezel.rotation.x = -.073
	inset.rotation.x = -.073
	for k: float in [-.26,.0,.26]:
		var pos: Vector3 = inset.position+Vector3(width*k,.035,0)
		_spar(label+" top cover grate",pos+Vector3.FORWARD*depth*.285,pos+Vector3.BACK*depth*.285,.11,_steel)
	for side: float in [-1.0,1.0]:
		_spar(label+" slender side riser",Vector3(side*width*.43,y,z+depth*.35),Vector3(side*width*.44,y+height-.34,z+depth*.35),.28,_upper)

func _north_carolina() -> void:
	_deckhouse("Long narrow center casing",-.4,7.14,24.0,2.12,73.1,3.7)
	_deckhouse("Forward bridge foundation",-19.9,9.06,21.14,3.6,24.5,3.02)
	_deckhouse("Broad lower pilot house",-20.05,12.56,15.35,2.0,17.8,3.20)
	_bridge_ring("Lower rounded forward bridge",-20.35,14.41,18.6,13.0)
	_deckhouse("Lower forward tower trunk",-17.9,16.9,8.55,10.28,8.4,2.31,_trunk_dark)
	_deckhouse("Upper forward tower trunk",-17.65,26.83,7.13,8.77,7.06,2.30,_trunk_light)
	_deckhouse("Trunk middle transition",-17.76,26.65,8.79,.39,8.09,1.50,_upper)
	_deckhouse("Projecting boat-shaped upper balcony",-16.81,32.56,11.9,.53,7.99,1.81,_upper)
	_bridge_ring("Tower collar",-18.02,21.8,11.35,8.45)
	_deckhouse("High foremast collar",-17.91,29.72,9.83,1.02,8.27,1.22,_upper)
	_deckhouse("Tall enclosed fire-control silhouette",-18.01,35.10,7.51,3.08,7.34,1.36,_trunk_dark)
	_deckhouse("Wide crown shelf",-18.61,37.83,13.38,.48,5.91,1.05,_upper)
	_pipe("Crown at mast foot",Vector3(0,39.63,-18.28),2.56,2.95,2.51,.96,_steel)
	_pipe("Crown cap",Vector3(0,41.00,-18.28),.33,2.57,2.57,.96,_upper)
	_spar("Forepole",Vector3(0,39.8,-16.6),Vector3(0,55.0,-16.6),.22,_steel)
	_spar("High yard",Vector3(-6.1,47.3,-16.6),Vector3(6.1,47.3,-16.6),.22,_upper)
	_spar("Tower yard",Vector3(-8.2,34.0,-17.4),Vector3(8.2,34.0,-17.4),.22,_upper)
	_spar("After forepole bracing",Vector3(2.1,34.0,-12.3),Vector3(0,50.4,-16.6),.17,_steel)
	_round_screen(Vector3(0,46.8,-19.15),3.38)
	_stack("Forward separate funnel",1.2,10.96,13.89,6.32,7.70)
	_stack("Aft separate funnel",17.6,10.29,13.88,5.91,7.1)
	_deckhouse("After reduced deckhouse",34.65,7.14,20.1,3.35,26.25,2.81)
	_deckhouse("After low control body",34.1,10.25,10.9,6.35,12.9,1.75)
	_bridge_ring("Aft local bridge",30.7,16.61,11.15,8.45)
	_spar("After fine mast",Vector3(0,13,27),Vector3(0,43.0,27),.22,_steel)
	_spar("After mast yard",Vector3(-5.1,35.0,27),Vector3(5.1,35.0,27),.22,_upper)
	_spar("Mast brace",Vector3(-3.8,15.3,32),Vector3(0,32,27),.16,_steel)
	_spar("Mast brace",Vector3(3.8,15.3,32),Vector3(0,32,27),.16,_steel)
	for side: float in [-1.0,1.0]:
		_octagon("Exposed fore bridge wing",Vector3(side*10.3,13.1,-21.4),5.17,.62,8.,1.05,_upper)
		_octagon("Side deckhouse ledge",Vector3(side*8.8,11.39,9.7),6.25,1.52,19.5,1.43,_steel)
		_pipe("Raised side lookout",Vector3(side*10.8,15.0,27.7),3.41,2.10,1.77,1.20,_steel)

func _west_virginia() -> void:
	_deckhouse("Rebuild broad continuous casing",-1.9,7.23,27.0,3.16,73.0,3.5)
	_deckhouse("Rebuilt bridge base",-15.3,10.13,22.8,3.2,23.5,3.8)
	_deckhouse("Forward sloping armored cabin",-14.95,12.16,16.13,4.65,15.7,2.46)
	_bridge_ring("Rebuilt wide forward bridge",-15.36,16.75,20.1,13.1)
	_deckhouse("Bridge tapered upper layers",-13.65,19.6,13.5,4.35,9.4,2.05,_trunk_dark)
	_bridge_ring("Short upper deck",-14.1,23.81,15.25,9.45)
	_deckhouse("Compact top enclosure",-13.9,26.28,8.2,3.70,7.77,1.57,_trunk_light)
	_deckhouse("Wide horizontal top terrace",-13.99,29.85,13.9,.69,6.75,1.43,_upper)
	_pipe("Small lookout silhouette",Vector3(0,32.23,-14.07),3.55,2.99,2.41,1.13,_steel)
	_spar("Forward pole",Vector3(0,30.37,-12.71),Vector3(0,43.9,-12.71),.24,_steel)
	_spar("Fore mast yard",Vector3(-7.65,35.2,-12.71),Vector3(7.65,35.2,-12.71),.23,_upper)
	_rect_screen(Vector3(0,39.72,-14.27))
	for side: float in [-1.,1.]:
		_spar("Forepole triangle strut",Vector3(side*3.99,30.44,-10.72),Vector3(0,40.1,-12.71),.155,_upper)
		_spar("Forepole beam stay",Vector3(side*1.92,35.25,-12.71),Vector3(0,37.66,-12.71),.106,_steel)
	_octagon("Only funnel, slab-sided modernized uptake",Vector3(0,17.2,1.55),8.9,12.3,10.1,1.25,_steel,.91)
	_octagon("Wide stepped funnel cap",Vector3(0,23.55,1.49),10.26,.96,10.82,1.45,_upper,.96)
	_octagon("Obscured interior of funnel cap",Vector3(0,24.04,1.49),8.32,.10,9.24,1.38,_dark)
	for x: float in [-2.14,0.,2.14]:
		_spar("Uptake cap stiffener",Vector3(x,24.19,-2.36),Vector3(x,24.19,5.60),.16,_trunk_dark)
	for side: float in [-1.0,1.0]:
		_spar("Outside single-funnel support",Vector3(side*4.62,14.95,4.84),Vector3(side*4.12,22.93,4.89),.29,_upper)
	_deckhouse("Lower raised aft center casing",19.06,9.35,18.58,3.96,17.29,2.52)
	_deckhouse("Short blocky aft control tower",20.63,13.06,8.3,6.42,8.9,1.12)
	_bridge_ring("Aft sighting platform",21.0,19.18,10.51,7.02)
	_spar("Fine aft pole",Vector3(0,10.11,13.1),Vector3(0,36.9,13.1),.25,_steel)
	_spar("Yardarm",Vector3(-5.75,32.7,13.1),Vector3(5.75,32.7,13.1),.19,_upper)
	_spar("Triangulated aft mast prop",Vector3(-4.2,14.1,19.1),Vector3(0,29,13.1),.19,_steel)
	_spar("Triangulated aft mast prop",Vector3(4.2,14.1,19.1),Vector3(0,29,13.1),.19,_steel)
	for side: float in [-1.0,1.0]:
		_octagon("Broad side gallery",Vector3(side*10.89,11.02,0),6.68,2.49,27.5,1.33,_steel)
		_octagon("Bridge wing balcony",Vector3(side*9.9,17.0,-13.8),4.1,.52,7.8,.79,_upper)
		_pipe("Raised aft side pedestal",Vector3(side*7.32,14.26,10.9),4.55,1.89,1.51,1.05,_steel)
		_pipe("Rebuilt side control outline",Vector3(side*7.32,17.59,10.9),2.24,1.67,1.36,1.08,_steel)

func _round_screen(p: Vector3, radius: float) -> void:
	var last: Vector3 = p + Vector3(radius,0,0)
	for i: int in range(1,21):
		var a: float = TAU*float(i)/20
		var point: Vector3 = p+Vector3(cos(a)*radius,sin(a)*radius,0)
		_spar("Circular open aerial frame",last,point,.101,_steel)
		last=point
	for j: int in range(-4,5):
		var h: float = radius*.205*j
		var x: float = sqrt(radius*radius-h*h)
		_spar("Circular aerial grid",p+Vector3(-x,h,0),p+Vector3(x,h,0),.065,_steel)
		_spar("Circular aerial grid",p+Vector3(h,-x,0),p+Vector3(h,x,0),.065,_steel)
	_spar("Circular frame bracket",p+Vector3(0,-radius,0),p+Vector3(0,0,2.9),.19,_steel)

func _rect_screen(p: Vector3) -> void:
	for i: int in range(-4,5):
		var x: float = i*.68
		_spar("Open grid aerial vertical",p+Vector3(x,-1.82,0),p+Vector3(x,1.82,0),.09,_steel)
	for i: int in range(-3,4):
		var y: float = i*.606
		_spar("Open grid aerial lateral",p+Vector3(-2.72,y,0),p+Vector3(2.72,y,0),.089,_steel)
	_spar("Diagonal open aerial stiffener",p+Vector3(-2.72,-1.82,0),p+Vector3(2.72,1.82,0),.104,_upper)
	_spar("Diagonal open aerial stiffener",p+Vector3(-2.72,1.82,0),p+Vector3(2.72,-1.82,0),.104,_upper)
	for side: float in [-1.0,1.0]:
		_spar("Grid projection support",p+Vector3(side*2.7,0,0),p+Vector3(0,-1,2.4),.12,_steel)

func _inert_tube(label: String, p: Vector3, q: Vector3, start: float, finish: float) -> void:
	var ray: Vector3 = q-p
	var tube := CylinderMesh.new()
	tube.radial_segments = 10
	tube.height = ray.length()
	tube.bottom_radius = start
	tube.top_radius = finish
	var extra: MeshInstance3D = _instance(label,tube,_gun_finish,(p+q)*.5)
	extra.quaternion = Quaternion(Vector3.UP,ray.normalized())

func _battery() -> void:
	var places: Array = [-57.4,-39.08,56.7] if exhibit == 0 else [-52.35,-39.04,36.47,50.05]
	for i: int in places.size():
		var z: float = places[i]
		var p := Vector3(0,_deck_height(z),z)
		var rise: float = (4.02 if i==1 else .95) if exhibit==0 else (3.56 if i in [1,2] else .86)
		var d: float = -1.0 if i<2 else 1.0
		var w: float = 13.43 if exhibit == 0 else 11.98
		var l: float = 12.1 if exhibit == 0 else 10.3
		_pipe("Visible deck seating",p+Vector3.UP*(rise*.5-.04),rise,w*.47,w*.46,.94,_steel)
		var housing_start := _group.get_child_count()
		_octagon("External turret cover",p+Vector3.UP*(rise+1.80),w,3.60,l,1.75,_gun_finish,.81)
		_octagon("Upper plate on inert cover",p+Vector3(0,rise+3.64,-d*1.04),w*.44,.13,l*.42,.53,_steel)
		if i == 0:
			var plate_z: float = -49.5 if exhibit == 0 else -46.4
			for face: float in [-1.0,1.0]:
				_box("Turret-side inspection plate",Vector3(face*(6.1 if exhibit==0 else 5.39),_deck_height(plate_z)+2.36,plate_z-7.8),Vector3(.19,1.0,2.51),_steel)
		var barrel_start := _group.get_child_count()
		var tubes: Array = [-2.55,0,2.55] if exhibit == 0 else [-2.13,2.13]
		for x: float in tubes:
			var b: Vector3 = p+Vector3(x,rise+1.70,d*l*.385)
			_inert_tube("Closed barrel silhouette",b,b+Vector3(0,1.06,d*(10.54 if exhibit == 0 else 9.22)),.42,.22)
		GUN_RIG.attach(self, "main_%02d" % (i+1), "main", p+Vector3.UP*rise,
			p+Vector3(0,rise+1.70,d*l*.385), Vector3(0,0,d),
			_group.get_children().slice(housing_start,barrel_start), _group.get_children().slice(barrel_start))
	for side: float in [-1.0,1.0]:
		var side_rows: Array = [Vector3(11.0,9.13,-27.2),Vector3(11.31,12.14,-13.8),Vector3(12.0,9.22,-1.97),Vector3(11.09,12.10,10.16),Vector3(11.2,9.25,24.47)] if exhibit == 0 else [Vector3(12.41,10.6,-20.9),Vector3(10.53,13.2,-10.7),Vector3(10.71,13.17,1.92),Vector3(12.30,10.6,11.9)]
		for k: int in range(side_rows.size()):
			var row: Vector3 = side_rows[k]
			var p := Vector3(side*row.x,row.y,row.z)
			_pipe("Fixed gallery mounting surround",p+Vector3.DOWN*.38,1.15,2.30,2.24,.99,_steel)
			var housing_start := _group.get_child_count()
			_octagon("Enclosed side-gallery shape",p+Vector3.UP*.84,4.36,2.19,4.82,.72,_gun_finish,.85)
			var barrel_start := _group.get_child_count()
			for dz: float in [-.69,.69]:
				_inert_tube("Closed side-barrel silhouette",p+Vector3(side*1.76,.83,dz),p+Vector3(side*5.04,.98,dz),.155,.092)
			GUN_RIG.attach(self, "secondary_%s_%02d" % ["port" if side<0 else "starboard", k+1], "secondary", p,
				p+Vector3(side*1.76,.83,0), Vector3(side,0,0),
				_group.get_children().slice(housing_start,barrel_start), _group.get_children().slice(barrel_start))
		for z: float in ([-41.4,-17.1,32.8,49.7,77.0] if exhibit==0 else [-36.4,-24.6,26.6,57.7,66.70]):
			var x: float = 11.3 if z < 55 else 8.1
			var y: float = _deck_height(z)+.61
			_tub(Vector3(x*side,y,z),1.68 if z<55. else 1.52)
	for z: float in ([-74.2,86.] if exhibit==0 else [-73.4,79.3]):
		_tub(Vector3(0,_deck_height(z)+.55,z),2.18)

func _tub(p: Vector3, radius: float) -> void:
	var hull := TorusMesh.new()
	hull.inner_radius = radius-.20
	hull.outer_radius = radius
	hull.rings = 22
	hull.ring_segments = 8
	var ring: MeshInstance3D = _instance("Rolled splinter tub rim",hull,_upper,p+Vector3.UP*.22)
	ring.scale.y = 3.24
	_pipe("Tub solid base",p-Vector3.UP*.11,.54,radius-.09,radius-.09,1,_steel)
	_octagon("Small optical-stand silhouette",p+Vector3.UP*.53,1.18,1.28,1.52,.36,_gun_finish)

func _fittings() -> void:
	# Fairleads, closures, hull plating doors and access ladders are nonfunctional detail.
	for side: float in [-1.0,1.0]:
		for j: int in range(1,_profile.size()-1):
			var a: Vector4 = _profile[j]
			var b: Vector4 = _profile[j+1]
			if b.x-a.x < .25:
				continue
			var rail_a := Vector3(side*(a.y-.11),a.z+.94,a.x)
			var rail_b := Vector3(side*(b.y-.11),b.z+.94,b.x)
			_spar("Weather-deck rail wire",rail_a,rail_b,.067,_upper)
			_spar("Weather-deck rail middle wire",rail_a-Vector3.UP*.37,rail_b-Vector3.UP*.37,.046,_upper)
			var posts: int = maxi(1,ceili((b.x-a.x)/3.15))
			for i: int in posts:
				var p: Vector3 = rail_a.lerp(rail_b,float(i)/posts)
				_spar("Weather-deck upright",p,p-Vector3.UP*.93,.067,_steel)
		for z: float in ([-83.,-70.,-55.,64.,77.,94.] if exhibit==0 else [-75.,-63.,-50.,54.,74.,84.]):
			var p := Vector3(side*(.79*_width_at(z)),_deck_height(z)+.32,z)
			_pipe("Round mooring fitting",p,.48,.32,.35,.98,_dark)
		for z: float in ([23.7,31.7] if exhibit==0 else [13.9,21.4]):
			var p := Vector3(side*8.09,_deck_height(z)+3.05,z)
			_octagon("Stowed boat hull",p,2.82,1.21,7.12,.98,_upper,.72)
			_octagon("Dark recessed boat cover",p+Vector3.UP*.58,2.14,.07,5.97,.82,_wood)
			for dz: float in [-2.30,2.3]:
				_spar("Boat cradle rail",p+Vector3(side*1.32,-1.75,dz),p+Vector3(side*1.69,.71,dz),.16,_steel)
		_ladder(Vector3(side*(7.08 if exhibit==0 else 7.22),10.26,-17.5),Vector3(side*(6.42 if exhibit==0 else 7.22),15.77,-11.51))
		_ladder(Vector3(side*4.5,17.56,-17.57),Vector3(side*4.17,24.17,-17.57))
		for z: float in [-35.5,33.85]:
			var p = Vector3(side*(_width_at(z)-.72),_deck_height(z)+.36,z)
			_octagon("Low weather-deck locker",p,1.05,.72,3.28,.22,_steel)
		_stacked_anchor(side)
		var marking_z: float = -_half_length()*.69
		var marking := Label3D.new()
		marking.name = "Bow Hull Number"
		marking.text = "55" if exhibit == 0 else "48"
		marking.font_size = 47
		marking.pixel_size = .0171
		marking.outline_size = 0
		marking.modulate = Color("c0c8cb")
		var band_x: float = _surface_at(marking_z,4.73)
		marking.position = Vector3(side*(band_x+.05),4.73,marking_z)
		marking.rotation.y = side * deg_to_rad(68.0)
		_group.add_child(marking)
		var stern_z: float = _half_length()*.795
		var crane_at := Vector3(side*(5.55 if exhibit==0 else 3.82),_deck_height(stern_z),stern_z)
		_crane(crane_at,side)
		for z: float in ([-90.,80.,93.] if exhibit==0 else [-80.,68.,80.]):
			_box("Inset deck panel",Vector3(side*2.55,_deck_height(z)+.043,z),Vector3(3.85,.09,2.12),_wood)
	for z: float in [-_half_length()+2.78,_half_length()-4.83]:
		_spar("Slim flag staff",Vector3(0,_deck_height(z),z),Vector3(0,_deck_height(z)+5.14,z),.13,_steel)

func _width_at(z: float) -> float:
	for i in range(1,_profile.size()):
		if z <= _profile[i].x:
			var a: Vector4 = _profile[i-1]
			var b: Vector4 = _profile[i]
			return lerpf(a.y,b.y,inverse_lerp(a.x,b.x,z))
	return _profile[-1].y

func _stacked_anchor(side: float) -> void:
	var z: float = -_half_length()*(.878 if exhibit == 0 else .873)
	var p := Vector3(side*(_surface_at(z,6.2)+.053),6.2,z)
	var aperture := TorusMesh.new()
	aperture.inner_radius = .63
	aperture.outer_radius = .82
	aperture.rings = 16
	aperture.ring_segments = 8
	var collar: MeshInstance3D = _instance("Bow hawse collar",aperture,_dark,p)
	collar.rotation_degrees = Vector3(0,-side*27,90)
	_spar("Cast anchor outline",p+Vector3(side*.44,-1.32,0),p+Vector3(side*.38,.42,0),.28,_gun_finish)
	for dz: float in [-1.0,1.0]:
		_spar("Cast anchor flange",p+Vector3(side*.40,-1.44,0),p+Vector3(side*.37,-.92,dz*.80),.30,_gun_finish)

func _ladder(a: Vector3,b: Vector3) -> void:
	for dz: float in [-.25,.25]:
		_spar("Inclined walkway handrail",a+Vector3(0,0,dz),b+Vector3(0,0,dz),.079,_upper)
	var count: int = ceili(a.distance_to(b)/.34)
	for j: int in count:
		var p: Vector3 = a.lerp(b,float(j)/count)
		_spar("Walkway step",p+Vector3(0,0,-.25),p+Vector3(0,0,.25),.068,_upper)

func _crane(p: Vector3,side: float) -> void:
	_pipe("Aft handling crane stump",p+Vector3.UP*.94,1.92,.59,.40,1,_steel)
	var a := p+Vector3(0,1.78,0)
	var b := p+Vector3(side*.91,6.69,5.84)
	var c := p+Vector3(side*1.23,5.85,8.59)
	_spar("Folded aft handling crane arm",a,b,.23,_steel)
	_spar("Folded aft handling crane arm",b,c,.17,_steel)
	_spar("Crane reinforcing brace",a+Vector3.BACK*.67,b+Vector3.DOWN*.56,.13,_upper)
	_spar("Stowed crane tie down",c,c+Vector3.DOWN*4.78,.054,_dark)

func _surface_at(z: float, y: float) -> float:
	for i: int in range(1,_profile.size()):
		if z > _profile[i].x:
			continue
		var a: PackedVector3Array = _section(_profile[i-1],1.0)
		var b: PackedVector3Array = _section(_profile[i],1.0)
		var sampled: PackedVector3Array = []
		for j: int in a.size():
			sampled.append(a[j].lerp(b[j],clampf(inverse_lerp(a[j].z,b[j].z,z),0.0,1.0)))
		for j: int in range(1,sampled.size()):
			if y <= sampled[j].y:
				return lerpf(sampled[j-1].x,sampled[j].x,inverse_lerp(sampled[j-1].y,sampled[j].y,y))
	return _width_at(z)

func _lookout(p: Vector3, r: float, h: float) -> void:
	_pipe("Optical housing support",p+Vector3.UP*h*.40,h*.80,r*.73,r*.59,1.0,_steel)
	_octagon("Inert rectangular optical outline",p+Vector3.UP*h*.91,2.16*r,h*.31,1.80*r,r*.42,_gun_finish,.88)
	_box("Optical housing face plate",p+Vector3(0,h*.94,-r*.77),Vector3(r*1.47,h*.13,.08),_glass)

func _detail_pass() -> void:
	if exhibit == 0:
		_lookout(Vector3(0,13.62,-28.0),2.11,5.1)
		_lookout(Vector3(0,18.6,29.55),1.60,4.83)
		_lookout(Vector3(0,11.12,44.10),1.73,5.57)
		_deckhouse("Shouldered aft platform base",44.1,7.32,11.7,4.15,9.9,1.33)
	else:
		_lookout(Vector3(0,12.88,-26.02),1.90,7.33)
		_deckhouse("Aft spotter stepped platform",28.1,7.79,11.74,5.2,7.29,1.10)
		_lookout(Vector3(0,12.88,28.1),1.75,7.36)
	for side: float in [-1.0,1.0]:
		for i: int in range(8):
			var z: float = float(i)*5.79-20.26
			var h: float = float([9.73,10.02,10.4,10.4,10.4,10.4,10.4,9.77][i])
			var x: float = (11.3 if exhibit==0 else 12.3) - .21*float(i % 3)
			_box("Open gallery rectangular door",Vector3(side*x,h+.59,z),Vector3(.14,1.26,.81),_glass)
			_box("Open gallery lower threshold",Vector3(side*(x+.08),h-.095,z),Vector3(.31,.13,1.05),_upper)
			if i % 2 == 0:
				var p := Vector3(side*(_width_at(z)-1.70),_deck_height(z),z)
				_pipe("Vent cowl vertical shell",p+Vector3.UP*.54,1.0,.42,.33,1.,_steel)
				_box("Cowl horizontal mouth",p+Vector3(.14*side,.96,.06),Vector3(.89,.31,.67),_steel)
		for z: float in [-77.,-65.,62.,72.]:
			var x: float = _width_at(z)*.62
			_octagon("Low oblong ventilator trunk",Vector3(side*x,_deck_height(z)+.38,z),1.5,.76,2.02,.32,_steel)
			_box("Vent dark flap",Vector3(side*x,_deck_height(z)+.55,z-1.),Vector3(.95,.19,.10),_glass)
		var collar_heights: Array = [14.85,22.19,30.04,33.04,38.29] if exhibit==0 else [17.18,24.15,30.30]
		var collar_depth: Array = [5.38,3.44,3.45,3.18,2.89] if exhibit==0 else [5.45,3.90,2.95]
		var collar_half: Array = [8.06,4.72,4.32,5.10,5.91] if exhibit==0 else [8.59,6.62,5.95]
		for i: int in collar_heights.size():
			var z: float = -18.07 if exhibit == 0 else -14.1
			var a := Vector3(side*collar_half[i],collar_heights[i]+.85,z-collar_depth[i])
			var b := Vector3(a.x,a.y,z+collar_depth[i])
			_spar("Bridge platform wire",a,b,.057,_upper)
			for j: int in range(5):
				var p: Vector3 = a.lerp(b,float(j)*.25)
				_spar("Bridge balcony post",p,p-Vector3.UP*.84,.063,_steel)
			_spar("Balcony support",Vector3(a.x*.78,a.y-1.72,z),Vector3(a.x*.99,a.y-.85,z),.12,_steel)
		var chain_z: float = -_half_length()*.903
		var chain_p := Vector3(side*1.38,_deck_height(chain_z)+.09,chain_z)
		var end_p := Vector3(side*1.2,_deck_height(chain_z+11.)+.09,chain_z+11.)
		_spar("Painted deck anchor chain silhouette",chain_p,end_p,.091,_dark)
		_pipe("Bow capstan",end_p+Vector3.UP*.31,.63,.42,.36,1.,_steel)
		var boat_cradle_z: float = 28 if exhibit == 0 else 18
		_spar("Boat handling outrigger",Vector3(side*9.5,_deck_height(boat_cradle_z)+1.1,boat_cradle_z),Vector3(side*13.22,_deck_height(boat_cradle_z)+4.49,boat_cradle_z+1.15),.19,_steel)
