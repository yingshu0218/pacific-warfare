extends Node3D
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

func _ready() -> void:
	set_meta("host_id","hull")
	var p: Dictionary = H.palette()
	var rings: Array[PackedVector3Array] = []
	# Dense longitudinal sampling gives the long rounded carrier body a smooth
	# silhouette without extra plates, fine surface details or fake gun supports.
	for index: int in range(145):
		var z: float = lerpf(-128.75,128.75,float(index)/144)
		var station: Vector2 = H.station_at(z)
		var w: float = station.x
		var top: float = station.y
		var depth: float = 8.87*clampf((128.8-absf(z))/24.0,.03,1.0)
		var ring: PackedVector3Array = []
		var points: Array[Vector2] = [Vector2(0,-depth),Vector2(w*.45,-depth*.98),Vector2(w*.77,-depth*.80),
			Vector2(w*.94,-depth*.45),Vector2(w*(13.0/13.65),0),Vector2(w*.985,top*.55),Vector2(w,top),
			Vector2(-w,top),Vector2(-w*.985,top*.55),Vector2(-w*(13.0/13.65),0),Vector2(-w*.94,-depth*.45),
			Vector2(-w*.77,-depth*.80),Vector2(-w*.45,-depth*.98)]
		for point: Vector2 in points:
			var rake: float = (3.86 if z<0 else 3.95)*clampf((absf(z)-105)/23.75,0,1)
			var dz: float = -signf(z)*rake*clampf((top-point.y)/(top+depth),0,1)
			ring.append(Vector3(point.x,point.y,z+dz))
			rings.append(ring)
	# Top face is built separately with the same three elevator apertures.
	# A closed loft roof at y=7.6 would block the lower-hangar lift position.
	G.mesh_node(self,"ContinuousHullShell",H.loft(rings,true,true,PackedInt32Array([6])),p.gray)
	var top_mesh: SurfaceTool=SurfaceTool.new(); top_mesh.begin(Mesh.PRIMITIVE_TRIANGLES); top_mesh.set_smooth_group(-1)
	var deck: Dictionary=H.read_data("deck")
	for index: int in range(rings.size()-1):
		var a: Vector3=rings[index][6]; var b: Vector3=rings[index+1][6]
		var left_a: Vector3=rings[index][7]; var left_b: Vector3=rings[index+1][7]
		var parts: Array[PackedVector2Array]=[PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(left_b.x,left_b.z),Vector2(left_a.x,left_a.z)])]
		for e: Dictionary in deck.elevators:
			var opening: PackedVector2Array=H.rect(Vector2(e.center_xz_m[0],e.center_xz_m[1]),Vector2(e.size_xz_m[0],e.size_xz_m[1]))
			var remainder: Array[PackedVector2Array]=[]
			for poly: PackedVector2Array in parts: remainder.append_array(Geometry2D.clip_polygons(poly,opening))
			parts=remainder
		for poly: PackedVector2Array in parts:
			var vertices: PackedVector3Array=[]
			for point: Vector2 in poly: vertices.append(Vector3(point.x,lerpf(a.y,b.y,inverse_lerp(a.z,b.z,point.y)),point.y))
			var ids: PackedInt32Array=Geometry2D.triangulate_polygon(poly)
			for i: int in range(0,ids.size(),3): H.triangle(top_mesh,vertices[ids[i]],vertices[ids[i+1]],vertices[ids[i+2]],Vector3.UP)
	top_mesh.generate_normals(); G.mesh_node(self,"WeatherDeckWithLiftOpenings",top_mesh.commit(),p.gray)
	# Source-visible rounded forecastle and fantail remain below the open ends.
	# A subtle boot stripe uses the same body geometry; no second oversized hull.
	# Underwater body is intentionally the same continuous mesh, not a block
	# added at the waterline. Hull is hidden below sea only in inspection scene.
	for side: float in [-1,1]:
		G.rod(self,"BowAnchorShank",Vector3(side*3.8,6.9,-122),Vector3(side*4.2,5.6,-121),.14,p.steel,8)
		G.rod(self,"BowAnchorFlukes",Vector3(side*4.2-.6,5.6,-121),Vector3(side*4.2+.6,5.6,-121),.13,p.steel,8)
	H.batch_static(self)
