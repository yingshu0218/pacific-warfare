extends Node3D
## Static model gallery. Metres, -Z forward, +X starboard; no simulation state.
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

# Each vessel has a separate plan and longitudinal hull station curve.
# Values other than referenced overall lengths are estimates from imagery.
const PRESETS: Dictionary = {
	"enterprise": {"label":"USS Enterprise CV-6", "year":"1942-03", "length":246.7356, "beam":25.32, "draft":8.53, "deck_y":16.8, "deck_length":242.0, "deck_width":33.4, "hangar":[-90.0,96.0,21.8], "island":[12.2,-9.0,6.3,39.0], "elevators":[-76.0,-14.0,63.0], "funnels":1, "plan":[[-1.0,.63],[-.96,.84],[-.86,.89],[-.46,.94],[.00,1.0],[.34,.95],[.79,.90],[.94,.80],[1.0,.67]], "hull":[[-1.0,.01],[-.83,.43],[-.60,.77],[-.27,.98],[.12,1.0],[.44,.95],[.73,.71],[.92,.45],[1.0,.12]], "colors":["53626e","4c5a6b","424c58"]},
	"independence": {"label":"USS Independence CVL-22", "year":"1943-07", "length":185.928, "beam":21.8, "draft":7.4, "deck_y":14.2, "deck_length":168.3, "deck_width":22.4, "hangar":[-68.0,69.0,16.1], "island":[8.5,-11.0,4.7,14.0], "elevators":[-43.0,42.0], "funnels":4, "plan":[[-1.0,.6],[-.91,.9],[-.69,.98],[-.42,1.0],[.47,1.0],[.79,.89],[.92,.75],[1.0,.61]], "hull":[[-1.0,.01],[-.83,.42],[-.55,.78],[-.19,.99],[.25,1.0],[.55,.85],[.79,.62],[.94,.36],[1.0,.13]], "colors":["555e67","505764","3d444d"]},
	"akagi": {"label":"IJN Akagi", "year":"1941", "length":260.67, "beam":31.32, "draft":8.71, "deck_y":20.0, "deck_length":249.2, "deck_width":30.5, "hangar":[-86.0,88.0,24.1], "island":[-12.1,-7.0,6.2,23.0], "elevators":[-76.0,-2.0,67.0], "funnels":2, "plan":[[-1.0,.60],[-.96,.77],[-.75,.83],[-.50,.92],[-.19,1.0],[.24,.99],[.59,.88],[.78,.81],[1.0,.78]], "hull":[[-1.0,.01],[-.84,.41],[-.57,.82],[-.24,.99],[.20,1.0],[.49,.93],[.72,.74],[.92,.48],[1.0,.13]], "colors":["595f61","876b4c","514e48"]},
	"zuiho": {"label":"IJN Zuiho", "year":"1944-10", "length":205.5, "beam":18.2, "draft":6.58, "deck_y":14.6, "deck_length":180.0, "deck_width":23.0, "hangar":[-70.0,70.0,16.7], "island":[], "elevators":[-47.0,43.0], "funnels":1, "plan":[[-1.0,.67],[-.93,.90],[-.65,.94],[-.29,1.0],[.41,.98],[.75,.87],[1.0,.79]], "hull":[[-1.0,.01],[-.83,.36],[-.49,.77],[-.20,.94],[.16,1.0],[.48,.92],[.73,.59],[.94,.32],[1.0,.10]], "colors":["59614d","7a8264","434b42"]}
}
@export_enum("enterprise","independence","akagi","zuiho") var ship_id: String = "enterprise"
var spec: Dictionary
var mats: Dictionary

func _ready() -> void:
	spec = PRESETS[ship_id]
	var cols: Array = spec.colors
	mats = {"hull":G.material(Color(cols[0])),"deck":G.material(Color(cols[1])),"steel":G.material(Color(cols[2])),
		"shadow":G.material(Color("252d32")),"glass":G.material(Color("293b42")),"white":G.material(Color("dad4b5")),
		"red":G.material(Color("7d423a")),"black":G.material(Color("22262a")),"edge":G.material(Color("948a76")),
		"green":G.material(Color("464e40")),
		"plank":G.material(Color(cols[1]).lightened(.032))}
	_build_hull(_group(self,"Hull"))
	_build_hangar(_group(self,"Hangar"))
	_build_deck(_group(self,"FlightDeck"))
	_build_superstructure(_group(self,"Superstructure"))
	_build_equipment(_group(self,"Equipment"))

func _group(parent: Node3D, id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	parent.add_child(root)
	return root

func _hull_ring(width: float, length: float, y: float, sheer: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for sign_x: float in [-1.0,1.0]:
		var rows: Array = spec.hull.duplicate()
		if sign_x < 0.0: rows.reverse()
		for row: Array in rows:
			var z: float = float(row[0])
			pts.append(Vector3(sign_x*width*float(row[1])*0.5,y+sheer*(pow(absf(z),4.0))*(1.0 if z < 0 else 0.36), length*z*0.5))
	return pts

func _build_hull(root: Node3D) -> void:
	var length: float = spec.length
	var width: float = spec.beam
	var draft: float = spec.draft
	var main_y: float = float(spec.deck_y)*0.56
	var lower: Array[PackedVector3Array] = [_hull_ring(width*.36,length*.72,-draft,0),_hull_ring(width*.75,length*.90,-draft*.73,0),_hull_ring(width*.94,length*.97,-draft*.42,0),_hull_ring(width,length*.981,0,0)]
	var upper: Array[PackedVector3Array] = [_hull_ring(width,length*.981,0,0),_hull_ring(width*.997,length*.987,1.0,0),_hull_ring(width*.98,length,main_y,2.4)]
	G.mesh_node(root,"UnderwaterShell",G.loft(lower,true),mats.red)
	G.mesh_node(root,"UpperShell",G.loft(upper,true),mats.hull)
	for s: float in [-1.0,1.0]:
		for row: Array in spec.hull:
			if absf(float(row[0])) > .44: continue
			var next_z: float = length*float(row[0])*.5
			var x_line: float = width*float(row[1])*.489
			for i: int in range(-2,3):
				G.rod(root,"SideScuttle",Vector3(s*(x_line-.19),main_y-2.32,next_z+i*2.42),Vector3(s*(x_line+.16),main_y-2.32,next_z+i*2.42),.19,mats.shadow,10)
		for z: float in [-.32,-.25,-.18,.26,.34]:
			var x: float = width*(.492 if absf(z)<.30 else .448)
			G.box(root,"HullVent",Vector3(.22,.72,2.2),Vector3(s*x,main_y-1.35,length*z),mats.shadow)

func _build_hangar(root: Node3D) -> void:
	var hs: Array = spec.hangar
	var aft: float = hs[1]
	var fwd: float = hs[0]
	var hw: float = hs[2]
	var top: float = float(spec.deck_y)-.15
	var bottom: float = float(spec.deck_y)*.55
	var plan: Array[Vector2] = G.polygon([[-hw*.36,fwd],[hw*.36,fwd],[hw*.5,fwd+11.0],[hw*.5,aft-12.0],[hw*.34,aft],[-hw*.34,aft],[-hw*.5,aft-12.0],[-hw*.5,fwd+11.0]])
	G.prism(root,"HangarEnclosure",plan,bottom,top,mats.hull)
	for side: float in [-1.0,1.0]:
		for i: int in range(6 if ship_id in ["enterprise","akagi"] else 5):
			var z: float = lerpf(fwd+18.0,aft-18.0,float(i)/5.0)
			G.box(root,"Recess",Vector3(.22,2.55,5.4),Vector3(side*(hw*.5+.11),top-3.5,z),mats.shadow)
			G.box(root,"RecessSill",Vector3(.48,.28,5.6),Vector3(side*(hw*.5+.20),top-4.8,z),mats.steel)
		if ship_id in ["akagi","zuiho"]:
			G.rod(root,"ForwardDeckStanchion",Vector3(side*hw*.28,bottom,fwd-9.0),Vector3(side*hw*.32,top,fwd-12.5),.41,mats.steel,12)
			G.rod(root,"AfterDeckStanchion",Vector3(side*hw*.25,bottom,aft+8.0),Vector3(side*hw*.35,top,aft+11.0),.40,mats.steel,12)
		for z: float in [fwd+10.0,aft-11.0]:
			G.rod(root,"DeckEdgeBrace",Vector3(side*hw*.32,bottom,z),Vector3(side*float(spec.deck_width)*.42,top,z),.32,mats.steel,8)

func _deck_outline() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for side: float in [1.0,-1.0]:
		var rows: Array = spec.plan.duplicate()
		if side < 0.0: rows.reverse()
		for row: Array in rows:
			pts.append(Vector2(side*float(row[1])*float(spec.deck_width)*.5,float(row[0])*float(spec.deck_length)*.5))
	return pts

func _build_deck(root: Node3D) -> void:
	var y: float = spec.deck_y
	var d: float = spec.deck_length
	var w: float = spec.deck_width
	var outline: Array[Vector2] = _deck_outline()
	G.prism(root,"FlightDeckStructure",outline,y-1.05,y-.12,mats.steel)
	G.prism(root,"DeckSurface",outline,y-.12,y,mats.deck)
	for i: int in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		G.rod(root,"DeckPerimeter",Vector3(a.x,y-.30,a.y),Vector3(b.x,y-.30,b.y),.13,mats.edge,6)
	var camo: bool = ship_id == "zuiho"
	if not camo:
		for i: int in range(-8,9):
			var plank_x: float = w*.043*i
			var plank_span: float = d*(.955-.016*absf(i))
			G.box(root,"LongDeckGrain",Vector3(.048,.014,plank_span),Vector3(plank_x,y+.008,0),mats.plank)
	if camo:
		G.prism(root,"CamouflageBand",G.polygon([[-w*.43,-26],[w*.42,-43],[w*.47,28],[w*.41,52],[-w*.42,33]]),y+.006,y+.026,mats["green"])
		G.prism(root,"BowCamouflage",G.polygon([[-w*.30,-d*.49],[w*.31,-d*.49],[w*.39,-d*.35],[0,-d*.30],[-w*.39,-d*.36]]),y+.006,y+.026,mats.steel)
		G.prism(root,"SternCamouflage",G.polygon([[-w*.37,d*.42],[0,d*.38],[w*.38,d*.41],[w*.34,d*.49],[-w*.33,d*.49]]),y+.006,y+.026,mats.steel)
	for z: float in spec.elevators:
		var width: float = minf(w*.50,14.1)
		G.box(root,"ElevatorRim",Vector3(width,.044,12.3),Vector3(0,y+.024,z),mats.shadow)
		G.box(root,"ElevatorPlatform",Vector3(width-.44,.06,11.85),Vector3(0,y+.026,z),mats.deck)
		var point := Marker3D.new()
		point.name = "Lift_%02d"%root.get_child_count()
		point.position = Vector3(0,y+.058,z)
		root.add_child(point)
	for i: int in range(18):
		var z: float = lerpf(-d*.44,d*.44,float(i)/17)
		var over_lift: bool = false
		for lift: float in spec.elevators:
			if absf(z-lift) < 9.5: over_lift = true
		if not over_lift:
			G.box(root,"Centerline",Vector3(.27,.036,d*.025),Vector3(0,y+.062,z),mats.white)
	for t: float in [.44,.46]:
		G.box(root,"AftStripe",Vector3(w*.51,.04,.35),Vector3(0,y+.061,d*t),mats.white)
	if camo:
		for s: float in [-1,1]:
			var stripe: MeshInstance3D = G.box(root,"SternOutlineMark",Vector3(.48,.045,15.2),Vector3(s*5.1,y+.075,d*.40),mats.white)
			stripe.rotation.y = s*.25

func _block(root: Node3D, id: String, x: float, bottom: float, z: float, w: float, h: float, l: float, mat: Material) -> void:
	var shape: Array[Vector2] = G.beveled_rect(w,l)
	for i: int in shape.size(): shape[i] += Vector2(x,z)
	G.prism(root,id,shape,bottom,bottom+h,mat)

func _build_superstructure(root: Node3D) -> void:
	var y: float = spec.deck_y
	var island: Array = spec.island
	var bridge := _group(root,"Bridge")
	var funnels := _group(root,"Funnel")
	var mast := _group(root,"Masts")
	if not island.is_empty():
		var x: float = island[0]
		var z: float = island[1]
		var w: float = island[2]
		var l: float = island[3]
		_block(bridge,"IslandBase",x,y-.95,z,w,4.95,l,mats.hull)
		_block(bridge,"PilotHouse",x,y+4.0,z-l*.23,w*.95,3.15,l*.43,mats.hull)
		_block(bridge,"GlazingBand",x,y+5.91,z-l*.237,w*.966,.67,l*.431,mats.glass)
		_block(bridge,"BridgeRoof",x,y+7.15,z-l*.23,w*1.06,.42,l*.47,mats.steel)
		_block(bridge,"SignalHouse",x,y+7.57,z-l*.26,w*.69,2.1,l*.25,mats.hull)
		_block(bridge,"UpperBridgeRoof",x,y+9.67,z-l*.26,w*.73,.26,l*.27,mats.steel)
		var walk_y: float = y+3.93
		for side: float in [-1,1]:
			for i: int in range(5):
				var rail_z: float = z-l*.42+float(i)*l*.098
				G.rod(bridge,"WalkwayStanchion",Vector3(x+side*w*.49,walk_y,rail_z),Vector3(x+side*w*.49,walk_y+1.10,rail_z),.07,mats.steel,6)
			G.rod(bridge,"WalkwayRail",Vector3(x+side*w*.49,walk_y+1.1,z-l*.42),Vector3(x+side*w*.49,walk_y+1.1,z-l*.03),.072,mats.steel,6)
		for i: int in range(5):
			G.box(bridge,"WindowMullion",Vector3(.1,.71,.1),Vector3(x+w*.46,y+6.24,z-l*.42+i*l*.086),mats.hull)
		var mast_z: float = z+(l*.22 if ship_id=="enterprise" else -l*.11)
		var mast_x: float = x
		var mast_height: float = 13.0 if ship_id in ["enterprise","akagi"] else 8.0
		var base := Vector3(mast_x,y+8.5,mast_z)
		var tip := base+Vector3(0,mast_height,2.0)
		G.rod(mast,"MainMast",base,tip,.29,mats.steel)
		G.rod(mast,"MastStay",Vector3(x+w*.32,y+4.0,mast_z+5.2),base.lerp(tip,.73),.18,mats.steel)
		G.rod(mast,"SignalYard",tip+Vector3(-4,-2.4,-.15),tip+Vector3(4,-2.4,-.15),.12,mats.steel)
		if ship_id == "independence":
			var aerial_center: Vector3 = tip+Vector3(0,.1,0)
			for side: float in [-1,1]:
				G.rod(mast,"AntennaCrossbar",aerial_center+Vector3(-3,side*.82,0),aerial_center+Vector3(3,side*.82,0),.08,mats.steel)
			for i: int in range(-3,4):
				G.rod(mast,"AntennaWire",aerial_center+Vector3(i,-.82,0),aerial_center+Vector3(i,.82,0),.06,mats.steel)
	if ship_id == "enterprise":
		var x: float = island[0]
		var z: float = float(island[1])+9.8
		_block(funnels,"FunnelTrunk",x,y+3.8,z,5.4,9.3,12.6,mats.hull)
		_block(funnels,"FunnelCap",x,y+13.10,z,5.55,1.12,12.72,mats.black)
	elif ship_id == "independence":
		for i: int in range(int(spec.funnels)):
			var z: float = 3.6+float(i)*7.0
			var low := Vector3(7.7,y-4.0,z)
			var bend := Vector3(11.4,y+1.4,z+.4)
			var tip := Vector3(13.0,y+9.1,z+1.6)
			G.rod(funnels,"OffsetTrunk_%d"%i,low,bend,1.68,mats.steel,14)
			G.rod(funnels,"RakedStack_%d"%i,bend,tip,1.57,mats.hull,16)
			G.rod(funnels,"DarkStackLip_%d"%i,tip-.68*(tip-bend).normalized(),tip+.14*(tip-bend).normalized(),1.62,mats.black,16)
	else:
		for i: int in range(int(spec.funnels)):
			var x: float = float(spec.hangar[2])*.5-.40
			var z: float = 6.0+float(i)*12.4
			var high := Vector3(x,y-2.7,z)
			var mid := Vector3(float(spec.deck_width)*.5+1.0,y-3.4,z+.5)
			var tip := Vector3(mid.x+2.65,y-7.6,z+1)
			var radius: float = (3.3 if i==0 else 1.46) if ship_id=="akagi" else 2.25
			G.rod(funnels,"SideTrunk_%d"%i,high,mid,radius,mats.hull,18)
			G.rod(funnels,"TurnedDownOutlet_%d"%i,mid,tip,radius*.89,mats.steel,18)
			G.rod(funnels,"OutletLip_%d"%i,tip-.42*(tip-mid).normalized(),tip+.18*(tip-mid).normalized(),radius*.94,mats.black,18)
	if ship_id == "zuiho":
		var z: float = 44.0
		G.box(bridge,"UnderDeckBridge",Vector3(6.9,2.6,5.0),Vector3(0,y-2.25,-70.5),mats.hull)
		G.box(bridge,"BridgeWindows",Vector3(5.7,.48,.19),Vector3(0,y-1.65,-73.04),mats.glass)
		G.rod(mast,"StarboardEdgeMast",Vector3(10,y-1,z),Vector3(11.6,y+10.2,z+1.8),.20,mats.steel)

func _build_equipment(root: Node3D) -> void:
	var y: float = spec.deck_y
	var w: float = spec.deck_width
	var hs: Array = spec.hangar
	if ship_id in ["enterprise","akagi"]:
		for side: float in [-1.0,1.0]:
			var x: float = side*(float(hs[2])*.5+.7)
			for z: float in [-66,62]:
				_block(root,"WeatherGallery",x,y-5.0,z,4.2,1.1,16.0,mats.hull)
	for side: float in [-1.0,1.0]:
		var x: float = side*(float(hs[2])*.5+.18)
		var z: float = 38.0 if side < 0.0 else 52.0
		var boat: Array[Vector2] = G.ellipse(2.55,8.2,22)
		for i: int in boat.size(): boat[i] += Vector2(x,z)
		G.prism(root,"BoatPlatform",boat,y-5.9,y-5.52,mats.steel)
		G.prism(root,"Boat",boat,y-5.53,y-4.6,mats.edge,.87,Vector2(x,z)*.13)
		for delta: float in [-2.4,2.4]:
			G.rod(root,"BoatDavit",Vector3(x-side*1.3,y-5.7,z+delta),Vector3(x+side*.5,y-2.4,z+delta),.17,mats.steel)
		for offset: float in [-.29,.29]:
			G.rod(root,"EdgeSafetyRail",Vector3(w*.43*side,y+.30,float(spec.deck_length)*offset-7),Vector3(w*.43*side,y+.30,float(spec.deck_length)*offset+7),.074,mats.steel,6)
