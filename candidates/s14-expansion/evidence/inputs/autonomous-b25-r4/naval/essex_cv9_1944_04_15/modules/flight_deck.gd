extends Node3D
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
var elevators: Dictionary = {}
var definition: Dictionary

func _ready() -> void:
	set_meta("host_id","flight_deck")
	definition = H.read_data("deck")
	var outline: PackedVector2Array = H.polygon(definition.flight_deck.boundary_xz_m)
	var xs: Array[float] = []
	var zs: Array[float] = []
	for point: Vector2 in outline:
		if not xs.has(point.x): xs.append(point.x)
		if not zs.has(point.y): zs.append(point.y)
	for elevator: Dictionary in definition.elevators:
		var center: Vector2 = Vector2(elevator.center_xz_m[0],elevator.center_xz_m[1])
		var size: Vector2 = Vector2(elevator.size_xz_m[0],elevator.size_xz_m[1])
		xs.append(center.x-size.x*.5); xs.append(center.x+size.x*.5)
		zs.append(center.y-size.y*.5); zs.append(center.y+size.y*.5)
	xs.sort(); zs.sort()
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(xs.size()-1):
		for j: int in range(zs.size()-1):
			if xs[i+1]-xs[i]<.0001 or zs[j+1]-zs[j]<.0001: continue
			var center: Vector2 = Vector2((xs[i]+xs[i+1])*.5,(zs[j]+zs[j+1])*.5)
			if _in_elevator(center): continue
			var cell: PackedVector2Array = H.rect(center,Vector2(xs[i+1]-xs[i],zs[j+1]-zs[j]))
			for poly: PackedVector2Array in Geometry2D.intersect_polygons(outline,cell):
				var ids: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
				for n: int in range(0,ids.size(),3):
					H.triangle(st,Vector3(poly[ids[n]].x,15.85,poly[ids[n]].y),Vector3(poly[ids[n+1]].x,15.85,poly[ids[n+1]].y),Vector3(poly[ids[n+2]].x,15.85,poly[ids[n+2]].y),Vector3.UP)
	st.generate_normals()
	G.mesh_node(self,"FlightDeckTopWithRealHoles",st.commit(),H.palette().deck)
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		if absf(a.x+19.2092)<.01 and absf(b.x+19.2092)<.01:
			for interval: Vector2 in [Vector2(minf(a.y,b.y),-29.144),Vector2(-10.856,maxf(a.y,b.y))]:
				if interval.x < interval.y: _edge(Vector2(a.x,interval.x),Vector2(a.x,interval.y))
		else: _edge(a,b)
	var lift_root: Node3D = H.group(self,"Elevators")
	for e: Dictionary in definition.elevators:
		var moving: Node3D = H.group(lift_root,e.id,Vector3(e.center_xz_m[0],e.upper_height_m,e.center_xz_m[1]))
		moving.set_meta("equipment_id",e.id)
		G.box(moving,"LiftPlatform",Vector3(e.size_xz_m[0],.38,e.size_xz_m[1]),Vector3(0,-.19,0),H.palette().deck)
		# Simple cross beams belong to this physical platform and move with it.
		for z: float in [-.33,.33]:
			G.box(moving,"LiftUnderBeam",Vector3(e.size_xz_m[0],.55,.24),Vector3(0,-.65,float(e.size_xz_m[1])*z),H.palette().steel)
		elevators[e.id] = moving
		if e.opening == "inboard":
			for side: float in [-1,1]:
				G.box(self,"LiftWellSide",Vector3(.16,7.924,float(e.size_xz_m[1])),Vector3(float(e.center_xz_m[0])+side*(float(e.size_xz_m[0])*.5+.08),11.888,e.center_xz_m[1]),H.palette().dark)
		for index: int in range(4):
			var a: Vector2 = H.rect(Vector2.ZERO,Vector2(e.size_xz_m[0]-.18,e.size_xz_m[1]-.18))[index]
			var b: Vector2 = H.rect(Vector2.ZERO,Vector2(e.size_xz_m[0]-.18,e.size_xz_m[1]-.18))[(index+1)%4]
			G.rod(moving,"LiftBoundary",Vector3(a.x,.016,a.y),Vector3(b.x,.016,b.y),.045,H.palette().mark,6)
		H.batch_static(moving)
	# Sparse period reference stripes, not wooden-plank texture.
	for x: float in [-9,3]:
		for z: float in range(-120,125,10):
			var at: Vector2 = Vector2(x,z)
			if Geometry2D.is_point_in_polygon(at,outline) and not _in_elevator(at):
				G.box(self,"RunwayDash",Vector3(.14,.012,4),Vector3(x,15.86,z),H.palette().mark)
	for wire: Dictionary in definition.arresting_wires:
		G.rod(self,wire.id,G.vector(wire.points_m[0]),G.vector(wire.points_m[1]),.023,H.palette().steel,6)
	for cat: Dictionary in definition.catapults:
		G.rod(self,cat.id,G.vector(cat.points_m[0]),G.vector(cat.points_m[1]),.07,H.palette().steel,6)
	H.batch_static(self,elevators.values())

func _in_elevator(point: Vector2) -> bool:
	for e: Dictionary in definition.elevators:
		if absf(point.x-float(e.center_xz_m[0])) <= float(e.size_xz_m[0])*.5 and absf(point.y-float(e.center_xz_m[1])) <= float(e.size_xz_m[1])*.5: return true
	return false

func _edge(a: Vector2,b: Vector2) -> void:
	G.rod(self,"DeckEdgeBeam",Vector3(a.x,15.62,a.y),Vector3(b.x,15.62,b.y),.21,H.palette().gray,8)
