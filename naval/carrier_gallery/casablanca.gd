extends Node3D
## USS Casablanca CVE-55 at Astoria, 15 August 1944. Static art asset.
## Waterline datum, metres, -Z forward, +X starboard. Not a simulation unit.
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const LENGTH: float = 156.1338
const BEAM: float = 19.8628
const DRAFT: float = 6.3246
const DECK_LENGTH: float = 144.4752
const DECK_WIDTH: float = 24.384
const DECK_Y: float = 14.48
const DECK_Z: float = 3.5
const SHELL_TOP: float = 10.23
# Normalized longitudinal stations, expressed in overall length; comparable
# to the reference side profile, not lofted from real construction drawings.
const STATIONS: Array = [[-1.0,0.013],[-.971,.12],[-.928,.245],[-.856,.40],[-.714,.64],[-.55,.84],[-.373,.96],[-.20,1.0],[.00,1.0],[.25,1.0],[.48,.98],[.65,.91],[.80,.82],[.90,.71],[.967,.56],[1.0,.37]]
const DECK_PLAN: Array = [[-1.,.80],[-.97,.89],[-.91,.96],[-.81,1.],[-.35,1.],[.10,1.],[.56,1.],[.83,1.],[.95,.96],[1.,.92]]
const LIFTS: Array = [[-33.0,10.29,12.77],[39.4,12.72,11.56]]
var ship_id: String = "casablanca"
var spec: Dictionary = {"label":"USS Casablanca CVE-55","year":"1944-08","length":LENGTH,"beam":BEAM,"draft":DRAFT,"deck_y":DECK_Y,"deck_length":DECK_LENGTH,"deck_width":DECK_WIDTH,"elevators":[-33.0,39.4]}
var mats: Dictionary

func _ready() -> void:
	for key: String in ["metal","medium","dark","under","boot","deck","grain","trim","window","white","canvas"]:
		var codes: Dictionary = {"metal":"879299","medium":"5c7280","dark":"2d393e","under":"794840","boot":"303735","deck":"505861","grain":"59626a","trim":"535c62","window":"253f46","white":"c7cab8","canvas":"9d9c88"}
		mats[key] = G.material(Color(codes[key]))
	_hull(_group(self,"Hull"))
	_hangar(_group(self,"Hangar"))
	_deck(_group(self,"FlightDeck"))
	_island(_group(self,"Superstructure"))
	_equipment(_group(self,"Equipment"))

func _group(root: Node3D,id: String) -> Node3D:
	var n := Node3D.new()
	n.name = id
	root.add_child(n)
	return n

func _ring(y: float,z_scale: float,x_scale: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for side: float in [-1.0,1.0]:
		var ordered: Array = STATIONS.duplicate()
		if side < 0.0: ordered.reverse()
		for row: Array in ordered:
			var t: float = row[0]
			points.append(Vector3(side*row[1]*BEAM*.5*x_scale,y,t*LENGTH*.5*z_scale))
	return points

func _hull(root: Node3D) -> void:
	var lower: Array[PackedVector3Array] = [_ring(-DRAFT,.79,.39),_ring(-DRAFT*.77,.88,.65),_ring(-DRAFT*.44,.96,.89),_ring(-.54,.99,.99)]
	G.mesh_node(root,"UnderwaterShell",G.loft(lower,true),mats.under)
	var boot: Array[PackedVector3Array] = [_ring(-.54,.99,.99),_ring(.52,1.,1.)]
	G.mesh_node(root,"WaterlineBand",G.loft(boot,true),mats.boot)
	var upper: Array[PackedVector3Array] = [_ring(.52,1.,1.),_ring(SHELL_TOP,1.,1.)]
	G.mesh_node(root,"UpperShell",G.loft(upper,true),mats.metal)
	for side: float in [-1.,1.]:
		# Geometrically clipped surface patches. Long, slanted color breaks based
		# on the August photo/BuShips scheme; not evidence of paint color values.
		var patches: Array = []
		if side > 0.0:
			# Starboard: two large dark groups on midships and the aft quarter.
			patches = [
				[[[-77.,5.6],[-70.,7.9],[-58.,9.45],[-39.,11.1],[-31.,9.15],[-50.,4.27],[-72.,.53],[-77.,.53]],mats.medium,.017],
				[[[-22.,.53],[-31.,3.25],[-34.,5.7],[-18.,8.4],[3.,10.3],[10.,10.3],[5.,9.2],[-6.,8.74],[-18.,6.9],[-4.,4.9],[-20.,2.32]],mats.dark,.026],
				[[[18.,.53],[25.,6.9],[34.,10.6],[48.,10.6],[57.,8.1],[63.,5.42],[61.,2.10],[59.,.53]],mats.medium,.017],
				[[[30.,.53],[28.,2.58],[28.8,6.32],[32.4,9.65],[55.4,10.53],[60.,8.36],[62.7,5.64],[62.4,2.57],[59.6,.53]],mats.dark,.035]
			]
		else:
			# Port: much larger forward dark crescent and narrow aft breaks.
			patches = [
				[[[-77.,.53],[-77.,1.55],[-66.1,5.58],[-65.9,1.62]],mats.dark,.023],
				[[[-63.,.53],[-63.8,4.54],[-59.3,8.31],[-50.,10.65],[-32.,11.3],[-23.,9.86],[-12.,7.34],[-14.,4.16],[-17.8,1.3],[-20.,.53]],mats.dark,.032],
				[[[13.1,.53],[17.25,2.97],[19.05,7.6],[16.9,10.6],[25.,10.6],[24.9,4.79],[22.8,1.49],[21.2,.53]],mats.dark,.026],
				[[[28.4,.53],[31.1,3.4],[31.2,10.6],[38.5,10.6],[37.8,4.0],[36.5,.53]],mats.medium,.017],
				[[[59.4,.53],[65.3,3.08],[69.3,7.75],[76.7,7.75],[77.,.53]],mats.dark,.033]
			]
		for row: Array in patches:
			_paint_hull(root,side,G.polygon(row[0]),row[1],row[2])
		for z: float in [-58.,-52.,-44.,-34.,-28.,-22.,-12.,-6.,2.,12.,20.,26.,36.,42.,54.,60.]:
			var x: float = _hull_width_at(z)
			G.rod(root,"HullScuttle",Vector3(side*(x-.13),8.36,z),Vector3(side*(x+.088),8.36,z),.14,mats.dark,8)
		for z: float in [-67.8,-65.8]:
			var x: float = _hull_width_at(z)
			G.rod(root,"HawseRecess",Vector3(side*(x-.23),8.80,z),Vector3(side*(x+.16),8.80,z),.37,mats.dark,12)
	for x: float in [-2.6,2.6]:
		G.rod(root,"StemFitting",Vector3(x,7.39,-72.),Vector3(x,9.68,-72.),.13,mats.trim,8)

func _hull_width_at(z: float) -> float:
	var t: float = z / (LENGTH*.5)
	for i: int in range(1,STATIONS.size()):
		if t <= STATIONS[i][0]:
			return BEAM*.5*lerpf(STATIONS[i-1][1],STATIONS[i][1],inverse_lerp(STATIONS[i-1][0],STATIONS[i][0],t))
	return BEAM*.5*STATIONS[-1][1]

func _paint_hull(root: Node3D,side: float,patch: Array[Vector2],mat: Material,offset: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var poly := PackedVector2Array(patch)
	for i: int in range(1,STATIONS.size()):
		var a: float = STATIONS[i-1][0]*LENGTH*.5
		var b: float = STATIONS[i][0]*LENGTH*.5
		var clip := PackedVector2Array([Vector2(a,.52),Vector2(b,.52),Vector2(b,SHELL_TOP),Vector2(a,SHELL_TOP)])
		for shape: PackedVector2Array in Geometry2D.intersect_polygons(poly,clip):
			var indices: PackedInt32Array = Geometry2D.triangulate_polygon(shape)
			for k: int in range(0,indices.size(),3):
				var tri: Array[Vector3] = []
				for j: int in range(3):
					var p: Vector2 = shape[indices[k+j]]
					tri.append(Vector3(side*(_hull_width_at(p.x)+offset),p.y,p.x))
				if (tri[1]-tri[0]).cross(tri[2]-tri[0]).x*side>0.0:
					var temp: Vector3 = tri[1]
					tri[1] = tri[2]
					tri[2] = temp
				for point: Vector3 in tri: st.add_vertex(point)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	if mesh != null: G.mesh_node(root,"Camouflage",mesh,mat)

func _block(root: Node3D,id: String,x: float,z: float,y: float,w: float,l: float,h: float,mat: Material) -> void:
	var shape: Array[Vector2] = G.beveled_rect(w,l)
	for i: int in shape.size(): shape[i] += Vector2(x,z)
	G.prism(root,id,shape,y,y+h,mat)

func _hangar(root: Node3D) -> void:
	var contour: Array[Vector2] = G.polygon([[-4.1,-59.],[4.1,-59.],[7.85,-48.],[9.2,-32.],[9.2,57.],
		[7.2,66.],[5.0,68.],[-5.0,68.],[-7.2,66.],[-9.2,57.],[-9.2,-32.],[-7.85,-48.]])
	G.prism(root,"HangarEnclosure",contour,9.50,DECK_Y-.30,mats.metal)
	for side: float in [-1.,1.]:
		for idx: int in range(7):
			var z: float = -27.+idx*12.3
			G.box(root,"InsetHangarBay",Vector3(.19,2.52,7.2),Vector3(side*9.20,11.58,z),mats.dark if idx%3!=1 else mats.medium)
			for dz: float in [-3.62,3.62]:
				G.box(root,"BayJamb",Vector3(.27,3.0,.34),Vector3(side*9.32,11.58,z+dz),mats.trim)
			G.box(root,"Sill",Vector3(.67,.19,7.8),Vector3(side*9.35,10.22,z),mats.medium)
		for z: float in [-48.5,-33.5,1.0,27.0,52.0,65.0]:
			var hull_x: float = _hull_width_at(z)*.85
			var edge_x: float = 9.9 if z< -45.0 else 11.3
			G.rod(root,"OpenGalleryBracket",Vector3(side*hull_x,9.68,z),Vector3(side*edge_x,DECK_Y-.50,z),.15,mats.trim,8)
	# Dark openings under each overhanging deck end, with separate contour supports.
	_block(root,"BowRecess",0.,-60.4,9.78,7.7,3.8,2.1,mats.medium)
	_block(root,"SternOpenShelter",0.,68.9,9.88,9.7,4.,2.8,mats.dark)
	for side: float in [-1.,1.]:
		G.rod(root,"BowDeckPier",Vector3(side*2.1,SHELL_TOP,-66.0),Vector3(side*4.8,DECK_Y-.32,-65.6),.30,mats.medium,10)
		G.rod(root,"SternDeckPier",Vector3(side*2.65,SHELL_TOP,73.2),Vector3(side*4.7,DECK_Y-.32,74.4),.29,mats.medium,10)

func _plan() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for side: float in [1.,-1.]:
		var ordered: Array = DECK_PLAN.duplicate()
		if side < 0.0: ordered.reverse()
		for row: Array in ordered:
			result.append(Vector2(side*row[1]*DECK_WIDTH*.5,DECK_Z+row[0]*DECK_LENGTH*.5))
	return result

func _deck(root: Node3D) -> void:
	var plan: Array[Vector2] = _plan()
	G.prism(root,"FlightDeckStructure",plan,DECK_Y-.81,DECK_Y-.12,mats.trim)
	G.prism(root,"DeckSurface",plan,DECK_Y-.12,DECK_Y,mats.deck)
	for i: int in plan.size():
		var a: Vector2 = plan[i]
		var b: Vector2 = plan[(i+1)%plan.size()]
		G.rod(root,"EdgeFascia",Vector3(a.x,DECK_Y-.35,a.y),Vector3(b.x,DECK_Y-.35,b.y),.12,mats.medium,6)
	for i: int in range(-17,18):
		var length: float = (DECK_LENGTH-3.)*(1.-.0045*absf(i))
		G.box(root,"TimberStripe",Vector3(.035,.012,length),Vector3(.48*i,DECK_Y+.012,DECK_Z),mats.grain)
	for i: int in LIFTS.size():
		var row: Array = LIFTS[i]
		G.box(root,"ElevatorRim",Vector3(row[1],.041,row[2]),Vector3(0.,DECK_Y+.026,row[0]),mats.dark)
		G.box(root,"ElevatorSurface",Vector3(row[1]-.32,.04,row[2]-.32),Vector3(0.,DECK_Y+.046,row[0]),mats.grain)
		var marker := Marker3D.new()
		marker.name = "Lift_%02d" % i
		marker.position = Vector3(0.,DECK_Y+.067,row[0])
		root.add_child(marker)
	for z: float in [-59.,-52.,-44.,-23.,-16.,-9.,-2.,5.,12.,19.,26.,53.,61.,68.]:
		G.box(root,"DeckCenterPaint",Vector3(.27,.018,3.8),Vector3(0.,DECK_Y+.033,z),mats.white)
	for z: float in [70.9,72.2]:
		G.box(root,"AftPaint",Vector3(15.2,.018,.30),Vector3(0.,DECK_Y+.033,z),mats.white)
	var end: float = DECK_Z+DECK_LENGTH*.5
	G.box(root,"SternTransverseFascia",Vector3(20.90,1.12,1.31),Vector3(0.,DECK_Y-1.07,end-1.25),mats.metal)
	for i: int in range(-8,9):
		var x: float = i*1.12
		G.rod(root,"AftBeamOpening",Vector3(x,DECK_Y-1.02,end-.688),Vector3(x,DECK_Y-1.02,end-.538),.27 if abs(i)<7 else .20,mats.dark,12)
	# Crisp restrained painted ship number; artistic acceptance target only.
	for x: float in [-1.3,1.3]:
		_deck_five(root,x,-59.8)
	for z: float in [-57.8,-55.6,-53.4,-51.2,-49.]:
		G.box(root,"ForwardDeckGuide",Vector3(.10,.017,1.8),Vector3(-4.85,DECK_Y+.035,z),mats.trim)

func _deck_five(root: Node3D,x: float,z: float) -> void:
	for dz: float in [-1.9,0.,1.9]:
		G.box(root,"FiveStroke",Vector3(1.75,.018,.31),Vector3(x,DECK_Y+.040,z+dz),mats.white)
	for direction: float in [-1.,1.]:
		G.box(root,"FiveStem",Vector3(.31,.018,1.80),Vector3(x+direction*.71,DECK_Y+.040,z+direction*.95),mats.white)

func _island(root: Node3D) -> void:
	var bridge: Node3D = _group(root,"Bridge")
	bridge.position=Vector3(0,2.58,-23.45)
	_block(bridge,"IslandFoundation",9.94,-1.0,8.75,5.5,15.5,3.54,mats.medium)
	_block(bridge,"IslandBase",11.53,-1.7,11.68,4.26,14.0,3.15,mats.metal)
	_block(bridge,"LowerGallery",11.64,-2.05,14.78,5.55,14.1,.32,mats.trim)
	_block(bridge,"Pilothouse",11.92,-4.03,15.06,4.0,6.84,2.64,mats.medium)
	_block(bridge,"PilothouseGlazing",11.92,-4.07,16.38,4.12,6.89,.66,mats.window)
	_block(bridge,"PilothouseRoof",11.92,-4.03,17.58,4.62,7.26,.32,mats.trim)
	_block(bridge,"OpenSignalPlatform",11.6,-2.9,17.85,4.37,7.0,.24,mats.dark)
	for side: float in [-1.,1.]:
		for i: int in range(4):
			G.box(bridge,"WindowPost",Vector3(.14,.73,.11),Vector3(11.92+side*1.96,16.70,-6.5+i*1.50),mats.medium)
		_guard(bridge,11.6+side*2.09,17.92,-5.25,1.2,5)
	var mast: Node3D = _group(root,"Masts")
	mast.position=bridge.position
	var foot := Vector3(12.43,15.02,2.83)
	var tip := Vector3(12.68,33.10,3.65)
	G.rod(mast,"MainMast",foot,tip,.24,mats.trim,12)
	for from: Vector3 in [Vector3(11.2,15.,1.7),Vector3(13.99,15.,4.8),Vector3(12.65,15.,6.1)]:
		G.rod(mast,"MastLeg",from,tip,.14,mats.medium,8)
	G.rod(mast,"SignalYard",Vector3(9.04,23.2,3.52),Vector3(16.18,23.2,3.52),.113,mats.trim,8)
	for y: float in [26.8,27.57]:
		G.rod(mast,"AerialCrossbar",Vector3(9.5,y,3.65),Vector3(15.9,y,3.65),.07,mats.dark,6)
	for i: int in range(11):
		var x: float = 9.50+i*.64
		G.rod(mast,"AerialRib",Vector3(x,26.76,3.65),Vector3(x,27.64,3.65),.037,mats.dark,6)
	# Discreet edge outlets below the flight deck rather than a fleet-carrier stack.
	var funnel: Node3D = _group(root,"Funnel")
	for z: float in [5.4,10.2]:
		G.rod(funnel,"OutboardTrunk",Vector3(8.4,11.08,z),Vector3(11.25,12.13,z),.63,mats.medium,12)
		G.rod(funnel,"LowRakedHousing",Vector3(11.25,12.13,z),Vector3(13.18,12.75,z+.38),.54,mats.dark,12)

func _guard(root: Node3D,x: float,y: float,start: float,end: float,posts: int) -> void:
	for i: int in posts:
		var z: float = lerpf(start,end,float(i)/(posts-1))
		G.rod(root,"GuardPost",Vector3(x,y,z),Vector3(x,y+1.03,z),.058,mats.medium,6)
	for height: float in [.47,.97]:
		G.rod(root,"GuardRail",Vector3(x,y+height,start),Vector3(x,y+height,end),.047,mats.medium,6)

func _equipment(root: Node3D) -> void:
	for side: float in [-1.,1.]:
		for z: float in [-39.6,20.3,52.0]:
			var x: float = side*(12.7 if z!=52.0 else 11.9)
			_block(root,"Catwalk",x,z,DECK_Y-1.08,1.63,11.1,.31,mats.trim)
			_guard(root,x+side*.73,DECK_Y-.84,z-5.0,z+5.0,7)
		for z: float in [-23.2,42.4]:
			var x: float = side*11.36
			_block(root,"Sponson",x,z,DECK_Y-2.55,3.5,7.15,.40,mats.medium)
			for dz: float in [-2.,2.]:
				G.rod(root,"SponsonJoin",Vector3(side*8.60,9.72,z+dz),Vector3(side*11.2,DECK_Y-2.42,z+dz),.19,mats.trim,8)
		var boat_z: float = 23.8 if side>0.0 else 7.6
		var boat_x: float = side*10.60
		var boat: Array[Vector2] = G.ellipse(2.22,6.3,18)
		for i: int in boat.size(): boat[i] += Vector2(boat_x,boat_z)
		G.prism(root,"UtilityBoat",boat,9.52,10.30,mats.canvas,.92,Vector2(boat_x,boat_z)*.08)
		for dz: float in [-2.15,2.15]:
			G.rod(root,"Davit",Vector3(side*9.45,9.70,boat_z+dz),Vector3(side*11.39,11.85,boat_z+dz),.12,mats.trim,8)
