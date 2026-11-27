extends SceneTree
const VIEWER: PackedScene=preload("res://aircraft/us_archive/us_archive_viewer.tscn")
var checks: int=0
var failures: int=0
func _initialize() -> void: call_deferred("_check")
func ck(v: bool,m: String) -> void:
	checks+=1
	if not v:
		failures+=1
		push_error(m)
func _check() -> void:
	var viewer: Node3D=VIEWER.instantiate() as Node3D
	root.add_child(viewer)
	var output: String=OS.get_environment("AIRFRAME_EXPORT_DIR")
	for index: int in 2:
		viewer.select_model(index)
		var model: Node3D=viewer.model
		var bounds: AABB=AABB()
		var vertices: int=0
		var nodes: Array[Node]=model.find_children("*","MeshInstance3D",true,false)
		for mesh: MeshInstance3D in nodes:
			ck(mesh.mesh!=null and mesh.global_transform.is_finite(),str(mesh.name)+" valid mesh")
			var box: AABB=mesh.global_transform*mesh.get_aabb()
			bounds=box if vertices==0 else bounds.merge(box)
			for k: int in mesh.mesh.get_surface_count():
				vertices+=mesh.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX].size()
		ck(absf(bounds.size.x-float(model.SPAN_M))<.075,"wing span")
		ck(absf(bounds.size.z-float(model.LENGTH_M))<.095,"length")
		ck(vertices<175000 and nodes.size()<200,"asset budget")
		ck(not model.is_processing() and not model.is_physics_processing(),"display-only asset")
		for view: int in 4:
			viewer.view=view
			viewer.frame()
			ck(viewer.camera.transform.is_finite(),"viewer camera")
		if index==0:
			var p: Array=model.WING
			ck(p[4][3]<p[0][3]-.4 and p[-1][3]>p[4][3]+.7,"distinct gull breaks")
			ck(model.has_node("RaisedCockpit/CanopyGlass") and model.has_node("Cowling/Propeller"),"single cowl and raised cockpit")
		else:
			ck(model.has_node("PortBoom/RudderAndFin") and model.has_node("StarboardBoom/RudderAndFin"),"two separate booms and fins")
			ck(model.has_node("CentralCockpitPod/SingleSeatCanopy"),"central cockpit")
			ck(model.has_node("PortBoom/LowerIntakeFairing") and model.has_node("StarboardBoom/LowerIntakeFairing"),"late J chin signature")
		if not output.is_empty():
			var doc:=GLTFDocument.new()
			var state:=GLTFState.new()
			ck(doc.append_from_scene(model,state)==OK,"mesh extraction")
			ck(doc.write_to_filesystem(state,output.path_join(["f4u1a","p38j"][index]+".glb"))==OK,"GLB write")
		print(model.LABEL," dimensions xyz=",bounds.size," mesh_nodes=",nodes.size()," vertices=",vertices)
	print("EARLY_US checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
