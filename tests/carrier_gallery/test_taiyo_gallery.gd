extends SceneTree
## Visual-only gallery regression with optional GLB export through the actual scene.
const VIEW: PackedScene = preload("res://naval/carrier_gallery/taiyo_viewer.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _run() -> void:
	var viewer: Node3D = VIEW.instantiate() as Node3D
	root.add_child(viewer)
	var ship: Node3D = viewer.get_node("Taiyo")
	var h: Node3D = ship.get_node("Hull and deck")
	var lower := Vector3(INF,INF,INF)
	var upper := -lower
	var edges: Dictionary = {}
	for index: int in range(4):
		var shell: MeshInstance3D = h.get_child(index) as MeshInstance3D
		var outline: PackedVector3Array = shell.mesh.get_faces()
		for p: Vector3 in outline:
			lower = lower.min(p)
			upper = upper.max(p)
		for i: int in range(0,outline.size(),3):
			var a: Vector3 = outline[i]; var b: Vector3 = outline[i+1]; var c: Vector3 = outline[i+2]
			_check((b-a).cross(c-a).length_squared() > 1e-10,"Hull triangle area is nonzero")
			for k: String in [_edge(a,b),_edge(a,c),_edge(b,c)]:
				edges[k] = int(edges.get(k,0))+1
	var nonmanifold: int = 0
	for count: int in edges.values():
		if count != 2: nonmanifold += 1
	_check(nonmanifold==0,"Hull and deck are closed, with no non-manifold edges")
	_check(absf(upper.z-lower.z-180.2)<0.001,"Hull length")
	_check(absf(upper.x-lower.x-22.5)<0.001,"Hull moulded beam")
	_check(absf(lower.y+7.7)<0.001,"Display draught")
	var d: MeshInstance3D = ship.get_node("FlightDeck/DeckSurface") as MeshInstance3D
	var deck: AABB = d.mesh.get_aabb()
	_check(absf(deck.size.x-23.5)<0.001 and absf(deck.size.z-162.0)<0.001,"Pre-1944 deck outline")
	_check(deck.position.z > lower.z+15.0 and deck.end.z < upper.z-1.90,"Separate exposed weather bow and rounded stern")
	var bridge: MeshInstance3D = ship.get_node("Superstructure/Islandless bridge under deck") as MeshInstance3D
	_check(bridge.position.y+bridge.mesh.get_aabb().end.y < deck.position.y,"No above-deck island")
	_check(ship.get_node("FlightDeck").find_children("Static lift cover*","MeshInstance3D",false,false).size()==2,"Two inert elevator outlines")
	_check(_clear_horizontal_at(ship,Vector3(12.5,13.1,77.0),Vector3(-12.5,13.1,77.0)),"Source-visible high aft corridor stays open from side to side")
	_check(_clear_horizontal_at(ship,Vector3(12.5,13.1,-69.0),Vector3(-12.5,13.1,-69.0)),"Source-visible clear fore support gap is not a dark painted panel")
	_check(not _clear_horizontal_at(ship,Vector3(12.5,13.1,2.0),Vector3(-12.5,13.1,2.0)),"Central hangar wall is actually enclosed")
	var camera: Camera3D = root.get_camera_3d()
	var water: MeshInstance3D = viewer.get("_water") as MeshInstance3D
	for n: int in [1,2,3,4]:
		viewer.call("_set_view",n)
		_check(camera.global_transform.is_finite(),"View %d camera transform"%n)
		_check(water.visible==(n!=4),"View %d water setting"%n)
		for p: Vector3 in [Vector3(0,12.17,lower.z),Vector3(0,8.28,upper.z),Vector3(10.71,24.58,-15.84)]:
			_check(root.get_visible_rect().has_point(camera.unproject_position(p)),"View %d full silhouette in frame"%n)
	var triangles: int = 0
	var full_min_z := INF
	var full_max_z := -INF
	var ship_inverse: Transform3D = ship.global_transform.affine_inverse()
	for child: MeshInstance3D in ship.find_children("*","MeshInstance3D",true,false):
		var faces: PackedVector3Array = child.mesh.get_faces()
		_check(not faces.is_empty() and child.material_override!=null,"Renderable member "+str(child.name))
		triangles += faces.size()/3
		var local_to_ship: Transform3D = ship_inverse*child.global_transform
		for p: Vector3 in faces:
			var z: float = (local_to_ship*p).z
			full_min_z = minf(full_min_z,z)
			full_max_z = maxf(full_max_z,z)
	_check(full_min_z >= lower.z-.4 and full_max_z <= upper.z+.4,"Fitted details do not extend past the physical bow or stern")
	_check(triangles <= 20000,"Exterior triangle budget")
	var output: String = OS.get_environment("TAIYO_GLB")
	if failures==0 and not output.is_empty():
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var success: Error = document.append_from_scene(ship,state)
		_check(success==OK,"Gather actual Godot mesh")
		if success==OK:
			_check(document.write_to_filesystem(state,output)==OK,"Write inspected exterior to GLB")
	print("TAIYO | length %.3f | beam %.3f | draft %.3f | deck %.3f x %.3f | %d triangles | %d bad hull edges | %d checks, %d failures"%[
		upper.z-lower.z,upper.x-lower.x,-lower.y,deck.size.z,deck.size.x,triangles,nonmanifold,checks,failures])
	quit(0 if failures==0 else 1)

func _clear_horizontal_at(ship: Node3D,start: Vector3,finish: Vector3) -> bool:
	for item: MeshInstance3D in ship.find_children("*","MeshInstance3D",true,false):
		var mesh_xform: Transform3D = item.global_transform
		var points: PackedVector3Array = item.mesh.get_faces()
		for i: int in range(0,points.size(),3):
			var result: Variant = Geometry3D.segment_intersects_triangle(start,finish,mesh_xform*points[i],mesh_xform*points[i+1],mesh_xform*points[i+2])
			if result != null:
				return false
	return true

func _edge(a: Vector3,b: Vector3) -> String:
	var p: String = str(a.snapped(Vector3.ONE*.0001)); var q: String = str(b.snapped(Vector3.ONE*.0001))
	return p+"|"+q if p<q else q+"|"+p
