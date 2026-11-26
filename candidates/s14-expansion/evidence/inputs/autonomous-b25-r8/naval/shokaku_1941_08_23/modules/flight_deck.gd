extends Node3D
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
var definition: Dictionary = {}
var elevators: Dictionary = {}

func _ready() -> void:
	set_meta("host_id","flight_deck")
	definition=H.read_data("deck")
	var p: Dictionary = H.palette()
	var outline: PackedVector2Array = H.polygon(definition.flight_deck.boundary_xz_m)
	var y: float = float(definition.flight_deck.height_m)
	var thick: float = float(definition.flight_deck.thickness_m)
	var xs: Array[float] = []
	var zs: Array[float] = []
	for point: Vector2 in outline:
		if not xs.has(point.x): xs.append(point.x)
		if not zs.has(point.y): zs.append(point.y)
	# Split at both steel/wood transitions and at every physical hole boundary.
	zs.append(-102.0); zs.append(115.5)
	for e: Dictionary in definition.elevators:
		xs.append(float(e.center_xz_m[0])-float(e.size_xz_m[0])*.5)
		xs.append(float(e.center_xz_m[0])+float(e.size_xz_m[0])*.5)
		zs.append(float(e.center_xz_m[1])-float(e.size_xz_m[1])*.5)
		zs.append(float(e.center_xz_m[1])+float(e.size_xz_m[1])*.5)
	xs.sort(); zs.sort()
	for i: int in range(xs.size()-1):
		for j: int in range(zs.size()-1):
			if xs[i+1]-xs[i]<.0001 or zs[j+1]-zs[j]<.0001: continue
			var center: Vector2 = Vector2((xs[i]+xs[i+1])*.5,(zs[j]+zs[j+1])*.5)
			if _in_elevator(center): continue
			var cell: PackedVector2Array = H.rect(center,Vector2(xs[i+1]-xs[i],zs[j+1]-zs[j]))
			for poly: PackedVector2Array in Geometry2D.intersect_polygons(outline,cell):
				H.slab(self,"FixedDeckWithLiftHoles",poly,y-thick,y,p.gray if center.y< -102 or center.y>115.5 else p.deck)
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]; var b: Vector2 = outline[(i+1)%outline.size()]
		G.rod(self,"DeckEdgeGirder",Vector3(a.x,y-thick,a.y),Vector3(b.x,y-thick,b.y),.18,p.gray,8)
	var lift_root: Node3D = H.group(self,"Elevators")
	for e: Dictionary in definition.elevators:
		var moving: Node3D = H.group(lift_root,e.id,Vector3(e.center_xz_m[0],y,e.center_xz_m[1]))
		moving.set_meta("equipment_id",e.id)
		G.box(moving,"LiftPlatform",Vector3(e.size_xz_m[0],thick,e.size_xz_m[1]),Vector3(0,-thick*.5,0),p.gray)
		var outline_lift: PackedVector2Array = H.rect(Vector2.ZERO,Vector2(e.size_xz_m[0]-.16,e.size_xz_m[1]-.16))
		for i: int in range(4):
			G.rod(moving,"LiftPerimeter",Vector3(outline_lift[i].x,.012,outline_lift[i].y),Vector3(outline_lift[(i+1)%4].x,.012,outline_lift[(i+1)%4].y),.035,p.steel,6)
		for z: float in [-.32,.32]:
			G.box(moving,"PlatformUnderBeam",Vector3(e.size_xz_m[0],.48,.26),Vector3(0,-thick-.24,float(e.size_xz_m[1])*z),p.steel)
		elevators[e.id]=moving
		H.batch_static(moving)
		# Physical well side walls stop at the lower limit; no invisible fixed
		# deck, roof, floor or plank surface left at the top of a lowered lift.
		var travel: float = y-float(e.lower_height_m)
		for side: float in [-1,1]:
			G.box(self,"LiftWellSideWall",Vector3(.18,travel,float(e.size_xz_m[1])),Vector3(float(e.center_xz_m[0])+side*(float(e.size_xz_m[0])*.5+.09),y-travel*.5,e.center_xz_m[1]),p.dark)
			G.box(self,"LiftWellEndWall",Vector3(float(e.size_xz_m[0]),travel,.18),Vector3(e.center_xz_m[0],y-travel*.5,float(e.center_xz_m[1])+side*(float(e.size_xz_m[1])*.5+.09)),p.dark)
	# Wire coordinates and visible segments share the same candidate data.
	# Exact historical count/stations are unverified; this is explicitly a V1
	# functional reconstruction, not a completed arrestment simulation.
	for wire: Dictionary in definition.arresting_wires:
		G.rod(self,wire.id,G.vector(wire.points_m[0]),G.vector(wire.points_m[1]),.025,p.steel,6)
	for barrier: Dictionary in definition.barriers:
		G.rod(self,barrier.id,G.vector(barrier.points_m[0]),G.vector(barrier.points_m[1]),.04,p.steel,6)
	# Sparse axial markings have no mechanics.
	for x: float in [-10,0,10]:
		for z: float in range(-110,116,9):
			if not _in_elevator(Vector2(x,z)):
				G.box(self,"DeckReferenceDash",Vector3(.12,.012,3),Vector3(x,y+.008,z),p.mark)
	H.batch_static(self,elevators.values())

func _in_elevator(point: Vector2) -> bool:
	for e: Dictionary in definition.elevators:
		if absf(point.x-float(e.center_xz_m[0]))<=float(e.size_xz_m[0])*.5 and absf(point.y-float(e.center_xz_m[1]))<=float(e.size_xz_m[1])*.5: return true
	return false
