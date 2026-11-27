extends SceneTree
## Verify the two standalone exterior exhibits without a simulation dependency.
const CASES: Array = [
	["res://scenes/ships/south_dakota_bb57/bb57_viewer.tscn", "SouthDakota", "bb57", 207.264,32.9692,8.69,3,"Fixed octagonal exterior housing", Vector3(0,34.28,-17.42)],
	["res://scenes/ships/kongo_1938/kongo_viewer.tscn", "Kongo", "kongo", 222.0,31.0,9.6,4,"Static deck housing", Vector3(0,42.30,17.83)],
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for row: Array in CASES:
		if not _verify(row,args[0] if not args.is_empty() else ""):
			quit(1)
			return
	quit(0)

func _verify(row: Array, path: String) -> bool:
	var packed := load(row[0]) as PackedScene
	var viewer := packed.instantiate() as Node3D
	root.add_child(viewer)
	var model := viewer.get_node(row[1]) as Node3D
	var hull := model.get_node("Hull and deck") as Node3D
	var lo := Vector3(INF,INF,INF)
	var hi := Vector3(-INF,-INF,-INF)
	var edges: Dictionary = {}
	var mounted: int = 0
	var faces_count: int = 0
	var valid: bool = hull.get_child_count() == 4
	for item: Node in model.find_children("*","MeshInstance3D",true,false):
		var instance := item as MeshInstance3D
		var points: PackedVector3Array = instance.mesh.get_faces()
		valid = valid and instance.material_override != null and not points.is_empty()
		faces_count += points.size() / 3
		if str(instance.name).begins_with(row[7]):
			mounted += 1
		if instance.get_parent() == hull:
			for i: int in range(0,points.size(),3):
				var a: Vector3 = points[i]
				var b: Vector3 = points[i+1]
				var c: Vector3 = points[i+2]
				valid = valid and (b-a).cross(c-a).length_squared() > 0.000000001
				for k: String in [_edge(a,b),_edge(b,c),_edge(c,a)]:
					edges[k] = int(edges.get(k,0))+1
			for p: Vector3 in points:
				valid = valid and p.is_finite()
				lo = lo.min(p)
				hi = hi.max(p)
	var manifold: bool = not edges.is_empty()
	for count: int in edges.values():
		manifold = manifold and count == 2
	valid = valid and manifold and mounted == row[6] and faces_count < 22000
	var dims: Vector3 = hi-lo
	valid = valid and absf(dims.z-row[3]) < 0.005 and absf(dims.x-row[4]) < 0.005
	valid = valid and absf(lo.y+row[5]) < 0.005
	var points_to_check: Array[Vector3] = [Vector3(0,hi.y,lo.z),Vector3(0,7,hi.z),row[8],Vector3(-hi.x,7,0),Vector3(hi.x,7,10)]
	var water := viewer.get("_water") as MeshInstance3D
	for mode: int in [1,2,3,4]:
		viewer.call("_set_view",mode)
		var camera: Camera3D = root.get_camera_3d()
		valid = valid and camera != null and water.visible == (mode != 4)
		for p: Vector3 in points_to_check:
			valid = valid and root.get_visible_rect().has_point(camera.unproject_position(p))
	print("%s: %.3f × %.3f m, reference depth %.3f m, %d triangles, closed=%s, 4-camera verified=%s" % [row[2],dims.z,dims.x,-lo.y,faces_count,manifold,valid])
	if valid and not path.is_empty():
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		valid = doc.append_from_scene(model,state)==OK and doc.write_to_filesystem(state,path.path_join(row[2]+".glb"))==OK
	root.remove_child(viewer)
	viewer.free()
	return valid

func _edge(a: Vector3,b: Vector3)->String:
	var x: String = str(a.snapped(Vector3.ONE*.0001))
	var y: String = str(b.snapped(Vector3.ONE*.0001))
	return x+"|"+y if x<y else y+"|"+x
