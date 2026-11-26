extends RefCounted
## CV01 construction helpers. Native meshes/materials; no image resources at runtime.
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const BASE: String = "res://naval/essex_cv9_1944_04_15/"
static var _palette: Dictionary = {}

static func palette() -> Dictionary:
	if _palette.is_empty():
		for key: String in {"gray":"838c93", "deck":"455764", "steel":"505b62", "dark":"222a31", "glass":"344952", "red":"563a37", "mark":"a9b0ad", "light":"acb3b6"}:
			_palette[key] = G.material(Color({"gray":"838c93", "deck":"455764", "steel":"505b62", "dark":"222a31", "glass":"344952", "red":"563a37", "mark":"a9b0ad", "light":"acb3b6"}[key]))
	return _palette

static func read_data(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BASE + "data/" + name + ".json")) as Dictionary

static func group(parent: Node3D, node_name: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = node_name
	parent.add_child(node)
	node.position = at
	return node

static func surface(parent: Node3D, station_id: String, at: Vector3, radius: float) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	marker.name = "Surface_" + station_id
	parent.add_child(marker)
	marker.position = at
	marker.set_meta("station_id", station_id)
	marker.set_meta("surface_radius_m", radius)
	return marker

static func polygon(values: Array) -> PackedVector2Array:
	var output: PackedVector2Array = []
	for value: Array in values:
		output.append(Vector2(float(value[0]),float(value[1])))
	return output

static func rect(center: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-size.x,-size.y)*0.5,center + Vector2(size.x,-size.y)*0.5,center + size*0.5,center + Vector2(-size.x,size.y)*0.5])

static func triangulated_slab(parent: Node3D, node_name: String, outline: PackedVector2Array, bottom: float, top: float, material: Material) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ids: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	for h: float in [bottom,top]:
		for i: int in range(0,ids.size(),3):
			var a: Vector3 = Vector3(outline[ids[i]].x,h,outline[ids[i]].y)
			var b: Vector3 = Vector3(outline[ids[i+1]].x,h,outline[ids[i+1]].y)
			var c: Vector3 = Vector3(outline[ids[i+2]].x,h,outline[ids[i+2]].y)
			triangle(st,a,b,c,Vector3.UP if h == top else Vector3.DOWN)
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var normal: Vector3 = Vector3(b.y-a.y,0,a.x-b.x).normalized()
		triangle(st,Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),normal)
		triangle(st,Vector3(a.x,bottom,a.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y),normal)
	st.generate_normals()
	return G.mesh_node(parent,node_name,st.commit(),material)

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot's front faces are clockwise, opposite cross-product outward normal.
	if (b-a).cross(c-a).dot(normal) > 0:
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
	else:
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

static func collect_meshes(node: Node, result: Array[MeshInstance3D], stops: Array) -> void:
	for child: Node in node.get_children():
		if child in stops or (child is Node3D and not child.visible): continue
		if child is MeshInstance3D and child.visible:
			result.append(child as MeshInstance3D)
		collect_meshes(child,result,stops)

static func batch_static(node: Node3D, stops: Array = []) -> void:
	var meshes: Array[MeshInstance3D] = []
	collect_meshes(node,meshes,stops)
	var groups: Dictionary = {}
	for part: MeshInstance3D in meshes:
		if part.mesh == null or part.mesh.get_surface_count() != 1 or part.get_child_count() > 0: continue
		var mat: Material = part.material_override if part.material_override != null else part.mesh.surface_get_material(0)
		if mat == null or (mat is BaseMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED): continue
		var key: int = mat.get_instance_id()
		if not groups.has(key): groups[key] = {"mat":mat,"parts":[]}
		groups[key].parts.append(part)
	for record: Dictionary in groups.values():
		if record.parts.size() < 2: continue
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in record.parts:
			var expanded: SurfaceTool = SurfaceTool.new()
			expanded.create_from(part.mesh,0)
			expanded.deindex()
			st.append_from(expanded.commit(),0,node.global_transform.affine_inverse()*part.global_transform)
		G.mesh_node(node,"StaticBatch_" + str(record.mat.get_instance_id()),st.commit(),record.mat)
		for part: MeshInstance3D in record.parts:
			part.get_parent().remove_child(part)
			part.free()

static func hull_stations() -> Array:
	# One CV01 hull source also bounds the hangar-floor overhang; no duplicated coplanar floor.
	return [[-132.8928,.05,9.6],[-130,1.9,9.5],[-124,4.5,9.2],[-114,7.5,8.8],[-100,10.4,7.926],[-80,12.8,7.926],[-55,14.05,7.926],[-28,14.1732,7.926],[0,14.1732,7.926],[35,14.0,7.926],[65,13.5,7.926],[90,12.2,7.926],[111,9.6,7.926],[123,7.3,7.926],[130,5.3,7.926],[132.8928,3.7,7.926]]
