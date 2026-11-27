extends SceneTree

const STUDIES: Array[Dictionary] = [
	{"model":"Alaska","path":"res://scenes/ships/alaska_cb1_1944/alaska_viewer.tscn",
		"length":246.4308,"beam":27.7622,"draft":9.70,"bow_y":11.54,"stern_y":7.62,
		"layers":["Single broad funnel","Working decks and fittings"],"tag":"alaska"},
	{"model":"SanDiego","path":"res://scenes/ships/san_diego_cl53_1944/san_diego_viewer.tscn",
		"length":165.0492,"beam":16.2052,"draft":6.35,"bow_y":8.39,"stern_y":5.32,
		"layers":["Two narrow funnels and split masts","Working deck and relief detail"],"tag":"san-diego"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: bool = true
	for spec: Dictionary in STUDIES:
		var packed := load(spec.path) as PackedScene
		if packed == null:
			quit(2)
			return
		var viewer := packed.instantiate() as Node3D
		root.add_child(viewer)
		passed = _check(viewer,spec) and passed
		root.remove_child(viewer)
		viewer.queue_free()
	quit(0 if passed else 1)


func _check(viewer: Node3D,spec: Dictionary) -> bool:
	var model := viewer.get_node(spec.model) as Node3D
	var hull := model.get_node("Hull and deck")
	var edges: Dictionary = {}
	var positions := PackedVector3Array()
	var low := Vector3.INF
	var high := -Vector3.INF
	var bow: float = -INF
	var stern: float = -INF
	var count: int = 0
	var ok: bool = hull.get_child_count() == 4
	for layer: String in spec.layers:
		ok = ok and model.has_node(layer)
	for n: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh := n as MeshInstance3D
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		ok = ok and not faces.is_empty() and mesh.material_override != null
		count += faces.size()/3
		for v: Vector3 in faces:
			var p: Vector3 = mesh.global_transform*v
			ok = ok and p.is_finite()
			positions.append(p)
			if n.get_parent()==hull:
				if absf(p.z+float(spec.length)*0.5)<0.005:
					bow=maxf(bow,p.y)
				if absf(p.z-float(spec.length)*0.5)<0.005:
					stern=maxf(stern,p.y)
				low=low.min(p)
				high=high.max(p)
		if n.get_parent()==hull:
			for i: int in range(0,faces.size(),3):
				var a: Vector3 = faces[i]
				var b: Vector3 = faces[i+1]
				var c: Vector3 = faces[i+2]
				ok = ok and (b-a).cross(c-a).length_squared()>0.000000001
				for edge: String in [_edge(a,b),_edge(b,c),_edge(c,a)]:
					edges[edge]=int(edges.get(edge,0))+1
	var invalid: int = 0
	for occurrences: int in edges.values():
		if occurrences != 2:
			invalid+=1
	var dims: Vector3 = high-low
	ok=ok and invalid == 0 and absf(dims.z-float(spec.length))<0.005 and absf(dims.x-float(spec.beam))<0.005
	ok=ok and absf(low.y+float(spec.draft))<0.005 and absf(bow-float(spec.bow_y))<0.005 and absf(stern-float(spec.stern_y))<0.005
	var cam: Camera3D = root.get_camera_3d()
	var water := viewer.get("_water") as MeshInstance3D
	ok = ok and cam!=null and water!=null
	if cam!=null and water!=null:
		for mode: int in [1,2,3,4]:
			viewer.call("_set_view",mode)
			ok = ok and water.visible == (mode!=4)
			for p: Vector3 in positions:
				ok=ok and not cam.is_position_behind(p) and root.get_visible_rect().has_point(cam.unproject_position(p))
	var extra_args: PackedStringArray = OS.get_cmdline_user_args()
	if ok and not extra_args.is_empty():
		var output: String = extra_args[0].path_join(str(spec.tag)+".glb")
		var writer := GLTFDocument.new()
		var state := GLTFState.new()
		ok = writer.append_from_scene(model,state)==OK and writer.write_to_filesystem(state,output)==OK
	print("%s: %.3f x %.3f m, draft %.3f m, %d tris, %d nonmanifold hull edges, pass=%s" % [
		spec.model,dims.z,dims.x,-low.y,count,invalid,ok])
	return ok


func _edge(a: Vector3,b: Vector3) -> String:
	var p: String = str(a.snapped(Vector3.ONE*0.0001))
	var q: String = str(b.snapped(Vector3.ONE*0.0001))
	return p+"|"+q if p<q else q+"|"+p
