extends SceneTree
## Instantiates the actual independent Godot viewers and audits only static artwork.
const VIEWS: Array[PackedScene] = [
	preload("res://scenes/ships/bb38_guam/bb38_viewer.tscn"),
	preload("res://scenes/ships/de413_1944/de413_viewer.tscn")
]
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_audit(VIEWS[0],"BB38","bb38",Vector3(32.385,8.79,185.3184),[40.12,-17.51],"Static deck silhouettes","Large closed exterior cover",4)
	_audit(VIEWS[1],"DE413","de413",Vector3(11.1506,4.064,93.2688),[27.90,-7.04],"Inert exterior silhouette details","Rounded single exterior cover",2)
	quit(1 if failures else 0)

func _audit(packed: PackedScene, id: String, file_id: String, target: Vector3, mast: Array,
		props: String, prop_name: String, prop_count: int) -> void:
	var before: int = failures
	var viewer: Node3D = packed.instantiate() as Node3D
	root.add_child(viewer)
	var ship: Node3D = viewer.get_node(id)
	var hull: Node3D = ship.get_node("Hull and deck")
	var lo := Vector3(INF,INF,INF)
	var hi := -lo
	var edges: Dictionary = {}
	var tris: int = 0
	var props_seen: int = 0
	for node: Node in ship.get_node(props).get_children():
		if str(node.name).begins_with(prop_name): props_seen += 1
	_check(props_seen==prop_count,id+" historical separated exterior volume count")
	for node: MeshInstance3D in ship.find_children("*","MeshInstance3D",true,false):
		var pts: PackedVector3Array = node.mesh.get_faces()
		_check(not pts.is_empty() and node.material_override!=null,id+" renderable surface")
		tris += pts.size()/3
		if node.get_parent()!=hull: continue
		for p: Vector3 in pts:
			lo = lo.min(p)
			hi = hi.max(p)
		for i: int in range(0,pts.size(),3):
			var a: Vector3 = pts[i]; var b: Vector3 = pts[i+1]; var c: Vector3 = pts[i+2]
			_check((b-a).cross(c-a).length_squared()>1e-10,id+" nondegenerate hull triangle")
			for k: String in [_edge(a,b),_edge(a,c),_edge(b,c)]:
				edges[k] = int(edges.get(k,0))+1
	var bad: int = 0
	for value: int in edges.values():
		if value!=2: bad += 1
	_check(bad==0,id+" closed hull")
	var bounds := hi-lo
	_check(absf(bounds.z-target.z)<.002 and absf(bounds.x-target.x)<.002 and absf(lo.y+target.y)<.002,id+" silhouette scale")
	_check(tris<20000,id+" static geometry budget")
	var plating := hull.get_node("Hull plating") as MeshInstance3D
	var paint := plating.material_override as StandardMaterial3D
	_check(paint.albedo_texture!=null and plating.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]!=null,id+" source-guided finish survives mesh")
	var water := viewer.get("_water") as MeshInstance3D
	for view: int in [1,2,3,4]:
		viewer.call("_set_view",view)
		var cam: Camera3D = root.get_camera_3d()
		_check(cam.global_transform.is_finite() and water.visible==(view!=4),id+" camera and water")
		for p: Vector3 in [Vector3(0,7,lo.z),Vector3(0,4,hi.z),Vector3(0,mast[0],mast[1])]:
			_check(root.get_visible_rect().has_point(cam.unproject_position(p)),id+" silhouette entirely framed mode %d"%view)
	var output: String = OS.get_environment("PAIR_GLB_DIR")
	if failures==before and not output.is_empty():
		var g := GLTFDocument.new()
		var state := GLTFState.new()
		var status: Error = g.append_from_scene(ship,state)
		_check(status==OK,id+" actual mesh GLB gather")
		if status==OK:
			_check(g.write_to_filesystem(state,output.path_join(file_id+".glb"))==OK,id+" actual mesh GLB write")
	print("%s | length %.4f | beam %.4f | draft %.4f | tris %d | bad hull edges %d | failures %d"%[
		id,bounds.z,bounds.x,-lo.y,tris,bad,failures-before])
	viewer.free()

func _check(passed: bool, desc: String) -> void:
	if not passed:
		failures += 1
		push_error(desc)

func _edge(a: Vector3,b: Vector3) -> String:
	var p := str(a.snapped(Vector3.ONE*.0001)); var q := str(b.snapped(Vector3.ONE*.0001))
	return p+"|"+q if p<q else q+"|"+p
