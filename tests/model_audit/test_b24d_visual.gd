extends SceneTree

const VIEWER: PackedScene=preload("res://aircraft/b24d/b24d_viewer.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,720)
	var viewer:=VIEWER.instantiate() as Node3D
	root.add_child(viewer)
	var model:=viewer.get_node("B24D") as Node3D
	var actual:=PackedVector3Array()
	var low:=Vector3(INF,INF,INF)
	var high:=Vector3(-INF,-INF,-INF)
	var nacelles:=0
	var blades:=0
	var panes:=0
	var tris:=0
	var bad_edges:=0
	var good:=true
	var closed_parts:=["Fuselage","Nose outer shell","Port wing","Starboard wing","Port fin","Starboard fin","Cockpit cap"]
	for raw: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh:=raw as MeshInstance3D
		var tag:=String(mesh.name)
		if tag.begins_with("Engine nacelle"):
			nacelles+=1
			var x:=absf(mesh.position.x)
			good=good and (is_equal_approx(x,3.378) or is_equal_approx(x,7.798))
		if tag.begins_with("Propeller blade"):
			blades+=1
		if tag.begins_with("Nose pane"):
			panes+=1
		var faces:=mesh.mesh.get_faces()
		good=good and not faces.is_empty()
		if tag in closed_parts:
			bad_edges+=open_edges(faces)
		for point: Vector3 in faces:
			var p:=mesh.global_transform*point
			good=good and p.is_finite()
			actual.append(p)
			low=low.min(p)
			high=high.max(p)
		tris+=faces.size()/3
	var bounds:=high-low
	var right:=model.get_node("Starboard fin") as MeshInstance3D
	var left:=model.get_node("Port fin") as MeshInstance3D
	var tail_span:=right.get_aabb().end.x-left.get_aabb().position.x
	good=good and absf(bounds.x-33.528)<0.006 and absf(bounds.z-20.2184)<0.006
	good=good and absf(tail_span-7.925)<0.12 and bounds.y>4.6 and bounds.y<5.1
	good=good and nacelles==4 and blades==12 and panes==16 and bad_edges==0 and tris<22000
	var cam:=root.get_camera_3d()
	good=good and cam!=null
	if cam!=null:
		for view: int in [1,2,3]:
			viewer.call("_set_view",view)
			for point: Vector3 in actual:
				good=good and not cam.is_position_behind(point) and root.get_visible_rect().grow(-3).has_point(cam.unproject_position(point))
	print("B-24D | span %.3f | length %.3f | display height %.3f | fin width %.3f | %d nacelles | %d blades | %d panes | %d tris | %d open edges" % [
		bounds.x,bounds.z,bounds.y,tail_span,nacelles,blades,panes,tris,bad_edges])
	if not good:
		printerr("B-24D verification failed")
		quit(1)
		return
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():
		var doc:=GLTFDocument.new()
		var state:=GLTFState.new()
		var code:=doc.append_from_scene(model,state)
		if code==OK:
			code=doc.write_to_filesystem(state,args[0])
		if code!=OK:
			printerr("B-24D export failed: ",code)
			quit(2)
			return
	quit(0)

func open_edges(faces: PackedVector3Array) -> int:
	var counts: Dictionary={}
	for i: int in range(0,faces.size(),3):
		for j: int in range(3):
			var a:=str(faces[i+j].snapped(Vector3.ONE*0.00001))
			var b:=str(faces[i+(j+1)%3].snapped(Vector3.ONE*0.00001))
			var key:=a+"|"+b if a<b else b+"|"+a
			counts[key]=int(counts.get(key,0))+1
	var result:=0
	for value: int in counts.values():
		if value!=2:
			result+=1
	return result
