extends RefCounted
## CV02 primitives and source-reconstructed hull stations. Metres, -Z forward.
const BASE: String = "res://naval/shokaku_1941_08_23/"
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

static func read_data(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/"+id+".json")) as Dictionary

static func palette() -> Dictionary:
	return {"gray":G.material(Color("62696a")),"deck":G.material(Color("9c8866")),
		"steel":G.material(Color("40494e")),"dark":G.material(Color("262e32")),
		"glass":G.material(Color("253b45")),"mark":G.material(Color("c7c7b7")),
		"red":G.material(Color("653c35")),"waterline":G.material(Color("383d3f"))}

static func group(parent: Node3D, id: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var result: Node3D = Node3D.new()
	result.name = id
	result.position = at
	parent.add_child(result)
	return result

static func polygon(points: Array) -> PackedVector2Array:
	var result: PackedVector2Array = []
	for point: Array in points:
		result.append(Vector2(float(point[0]),float(point[1])))
	return result

static func rect(center: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([center+Vector2(-size.x,-size.y)*.5,center+Vector2(size.x,-size.y)*.5,
		center+size*.5,center+Vector2(-size.x,size.y)*.5])

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b-a).cross(c-a).dot(normal)>0:
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
	else:
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

static func slab(parent: Node3D, id: String, outline: PackedVector2Array, bottom: float, top: float, material: Material) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	for y: float in [bottom,top]:
		for i: int in range(0,indices.size(),3):
			triangle(st,Vector3(outline[indices[i]].x,y,outline[indices[i]].y),
				Vector3(outline[indices[i+1]].x,y,outline[indices[i+1]].y),
				Vector3(outline[indices[i+2]].x,y,outline[indices[i+2]].y),Vector3.UP if y==top else Vector3.DOWN)
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var normal: Vector3 = Vector3(b.y-a.y,0,a.x-b.x).normalized()
		triangle(st,Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),normal)
		triangle(st,Vector3(a.x,bottom,a.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y),normal)
	st.generate_normals()
	return G.mesh_node(parent,id,st.commit(),material)

static func loft(rings: Array[PackedVector3Array], caps: bool, smooth: bool = true, skip_edges: PackedInt32Array = []) -> ArrayMesh:
	# Winding is derived from ring centres, so left/right sponsons and ducts
	# with different longitudinal axes cannot silently turn their faces inward.
	var st: SurfaceTool = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0 if smooth else -1)
	var centers: Array[Vector3] = []
	for ring: PackedVector3Array in rings:
		var center: Vector3=Vector3.ZERO
		for point: Vector3 in ring: center+=point/float(ring.size())
		centers.append(center)
	for j: int in range(rings.size()-1):
		for i: int in range(rings[j].size()):
			if i in skip_edges: continue
			var n: int=(i+1)%rings[j].size()
			var a: Vector3=rings[j][i]; var b: Vector3=rings[j+1][n]
			var c: Vector3=rings[j+1][i]; var d: Vector3=rings[j][n]
			var origin: Vector3=(centers[j]+centers[j+1])*.5
			triangle(st,a,b,c,(a+b+c)/3-origin)
			triangle(st,a,d,b,(a+d+b)/3-origin)
	if caps:
		st.set_smooth_group(-1)
		for end: int in [0,rings.size()-1]:
			var outward: Vector3=centers[0]-centers[1] if end==0 else centers[-1]-centers[-2]
			for i: int in range(rings[end].size()): triangle(st,centers[end],rings[end][i],rings[end][(i+1)%rings[end].size()],outward)
	st.generate_normals()
	return st.commit()

static func surface(parent: Node3D, station: String, at: Vector3, radius: float) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	marker.name = "Mount_"+station
	marker.position = at
	marker.set_meta("station_id",station)
	marker.set_meta("host_id",parent.get_meta("host_id",""))
	marker.set_meta("surface_radius_m",radius)
	parent.add_child(marker)
	return marker

static func collect_meshes(node: Node, result: Array[MeshInstance3D], stops: Array) -> void:
	for child: Node in node.get_children():
		if child in stops or (child is Node3D and not child.visible): continue
		if child is MeshInstance3D: result.append(child as MeshInstance3D)
		collect_meshes(child,result,stops)

static func batch_static(node: Node3D, stops: Array = []) -> void:
	# Only within one module / one movement axis; never joins independent mounts.
	var meshes: Array[MeshInstance3D] = []
	collect_meshes(node,meshes,stops)
	var groups: Dictionary = {}
	for part: MeshInstance3D in meshes:
		if part.mesh==null or part.mesh.get_surface_count()!=1 or part.get_child_count()>0: continue
		var mat: Material = part.material_override if part.material_override!=null else part.mesh.surface_get_material(0)
		if mat==null or (mat is BaseMaterial3D and mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED): continue
		var key: int = mat.get_instance_id()
		if not groups.has(key): groups[key] = {"mat":mat,"parts":[]}
		groups[key].parts.append(part)
	for record: Dictionary in groups.values():
		if record.parts.size()<2: continue
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in record.parts:
			var expanded: SurfaceTool = SurfaceTool.new()
			expanded.create_from(part.mesh,0); expanded.deindex()
			st.append_from(expanded.commit(),0,node.global_transform.affine_inverse()*part.global_transform)
		G.mesh_node(node,"StaticBatch_"+str(record.mat.get_instance_id()),st.commit(),record.mat)
		for part: MeshInstance3D in record.parts:
			part.get_parent().remove_child(part); part.free()

static func hull_stations() -> Array:
	# [z, upper-deck half beam, weather-deck y]. S01/M01 reconstruction;
	# hidden underwater sections approximate, not shipyard body-plan ordinates.
	return [[-128.75,.06,8.45],[-126,1.5,8.4],[-122,3.9,8.3],[-115,6.6,8.05],
		[-105,9.3,7.75],[-90,11.65,7.6],[-70,13.05,7.6],[-45,13.55,7.6],
		[-15,13.65,7.6],[20,13.60,7.6],[50,13.15,7.6],[78,12.5,7.6],
		[99,11.4,7.45],[113,9.5,6.2],[121,7.6,5.7],[126,5.3,5.6],[128.75,2.2,5.6]]

static func station_at(z: float) -> Vector2:
	var stations: Array = hull_stations()
	for i: int in range(stations.size()-1):
		if z<=float(stations[i+1][0]):
			var t: float = clampf(inverse_lerp(float(stations[i][0]),float(stations[i+1][0]),z),0,1)
			return Vector2(lerpf(float(stations[i][1]),float(stations[i+1][1]),t),lerpf(float(stations[i][2]),float(stations[i+1][2]),t))
	return Vector2(stations.back()[1],stations.back()[2])
