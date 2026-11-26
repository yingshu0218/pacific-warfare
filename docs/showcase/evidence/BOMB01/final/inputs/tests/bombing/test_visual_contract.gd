extends SceneTree
const FIX: Script=preload("res://tests/bombing/fixture.gd")
const VIEW: Script=preload("res://scripts/bombing/aircraft_view.gd")
var failures: int=0
var records: Array=[]

func _initialize() -> void:call_deferred("run")

func vertices(node: Node3D, relative: Transform3D, out: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh=(node as MeshInstance3D).mesh
		for index: int in mesh.get_surface_count():
			var arrays: Array=mesh.surface_get_arrays(index)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:out.append(relative*node.global_transform*vertex)
	for child: Node in node.get_children():
		if child is Node3D:vertices(child,relative,out)

func run() -> void:
	for id: String in FIX.parameters().aircraft:
		var p: Dictionary=FIX.parameters().aircraft[id]
		var ammo: Dictionary=FIX.parameters().ammunition[p.ammo_id]
		var a: Dictionary=FIX.arena([FIX.spawn("bomber","us",Vector3(0,1800,1000),id,Vector3(0,0,-85))])
		var unit: UnitState=a.world.get_unit("bomber")
		unit.module_data.bomb_rack.bay=1.0
		unit.module_data.bomb_rack.crutch=float(p.get("required_crutch",0.0))
		var view: Node3D=VIEW.new(id);root.add_child(view);view.call("apply",unit)
		for i: int in p.slots_m.size():
			var template: Node3D=view.call("bomb_template",i)
			var points: Array[Vector3]=[]
			vertices(template,template.global_transform.affine_inverse(),points)
			var max_transverse: float=0.0;var max_length: float=0.0
			for point: Vector3 in points:
				max_transverse=maxf(max_transverse,maxf(absf(point.x),absf(point.y)))
				max_length=maxf(max_length,absf(point.z))
			var actual: Vector3=view.call("slot_position",i)
			var expected: Vector3=unit.world_transform()*BombStores.local_slot(p,unit.module_data.bomb_rack,i)
			var passed: bool=actual.distance_to(expected)<.005 and max_transverse<=float(ammo.collision_span_m)*.5+.001 and max_length<=float(ammo.collision_length_m)*.5+.001
			if not passed:failures+=1
			print("BOMB01_VISUAL ",id," slot",i," pass=",passed," marker_error=",actual.distance_to(expected)," body_halves=",max_transverse,"/",max_length)
			records.append({"type":id,"slot":i,"passed":passed,"vertex_count":points.size(),"marker_error_m":actual.distance_to(expected),"max_transverse_m":max_transverse,"max_axial_m":max_length})
		view.queue_free();FIX.dispose(a)
	await process_frame
	var file: FileAccess=FileAccess.open("res://.local/visual_contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close()
	quit(0 if failures==0 else 1)
