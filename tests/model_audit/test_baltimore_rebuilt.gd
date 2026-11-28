extends SceneTree

const VIEWER: PackedScene = preload("res://scenes/ships/baltimore_ca68/baltimore_viewer.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewer := VIEWER.instantiate() as Node3D
	root.add_child(viewer)
	var model := viewer.get_node("Baltimore") as Node3D
	var hull := model.get_node("Hull and deck") as Node3D
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var count: int = 0
	var valid: bool = hull.get_child_count() == 4 and root.get_camera_3d() != null
	var hull_edges: Dictionary = {}
	var silhouette := PackedVector3Array()
	# Articulated housings remain the same meshes under their own pivots.
	var mounted_shapes: int = model.find_children("Main exterior casing*", "MeshInstance3D", true, false).size()
	for item: Node in model.find_children("*","MeshInstance3D",true,false):
		var node := item as MeshInstance3D
		var faces: PackedVector3Array = node.mesh.get_faces()
		valid = valid and node.material_override != null and not faces.is_empty()
		count += faces.size() / 3
		if node.get_parent() == hull:
			for index: int in range(0,faces.size(),3):
				var a: Vector3 = faces[index]
				var b: Vector3 = faces[index+1]
				var c: Vector3 = faces[index+2]
				valid = valid and (b-a).cross(c-a).length_squared() > 0.000000001
				for key: String in [_edge(a,b),_edge(b,c),_edge(c,a)]:
					hull_edges[key] = int(hull_edges.get(key,0)) + 1
		for point: Vector3 in faces:
			var pos: Vector3 = node.global_transform * point
			valid = valid and pos.is_finite()
			silhouette.append(pos)
			if node.get_parent() == hull:
				lo = lo.min(pos)
				hi = hi.max(pos)
	var bad_edges: int = 0
	for incident_count: int in hull_edges.values():
		if incident_count != 2:
			bad_edges += 1
	valid = valid and bad_edges == 0
	var bounds: Vector3 = hi-lo
	valid = valid and absf(bounds.z-205.257) < 0.005 and absf(bounds.x-21.590) < 0.005
	valid = valid and absf(lo.y+6.248) < 0.005 and mounted_shapes == 3 and count < 19000
	var plating := hull.get_node("Hull plating") as MeshInstance3D
	var camouflage := (plating.material_override as StandardMaterial3D).albedo_texture
	valid = valid and camouflage != null and camouflage.get_width() == 1024 and camouflage.get_height() == 256
	if camouflage != null:
		var map: Image = camouflage.get_image()
		valid = valid and map.get_pixel(160,30) != map.get_pixel(160,158)
	var water := viewer.get("_water") as MeshInstance3D
	for mode: int in [1,2,3,4]:
		viewer.call("_set_view",mode)
		valid = valid and water.visible == (mode != 4)
		var camera: Camera3D = root.get_camera_3d()
		valid = valid and camera.global_position.length() > 180.0
		for point: Vector3 in silhouette:
			valid = valid and not camera.is_position_behind(point)
			valid = valid and root.get_visible_rect().has_point(camera.unproject_position(point))
	print("BALTIMORE HULL | length %.3f m | beam %.3f m | design draft %.3f m | exterior %d triangles | open/non-manifold hull edges %d" % [
		bounds.z,bounds.x,-lo.y,count,bad_edges])
	if not valid:
		printerr("BALTIMORE mesh or viewer validation failed")
		quit(1)
		return
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var status: Error = document.append_from_scene(model,state)
		if status == OK:
			status = document.write_to_filesystem(state,arguments[0])
		if status != OK:
			printerr("BALTIMORE GLB export failed: ",status)
			quit(2)
			return
	quit(0)


func _edge(a: Vector3, b: Vector3) -> String:
	var p: String = str(a.snapped(Vector3.ONE*0.0001))
	var q: String = str(b.snapped(Vector3.ONE*0.0001))
	return p+"|"+q if p<q else q+"|"+p
