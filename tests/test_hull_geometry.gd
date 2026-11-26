extends SceneTree

const BUILDER: Script = preload("res://scripts/ship_geometry.gd")
const MAIN_HOUSING: PackedScene = preload("res://assets/naval/weapons/jp_type94_46cm_triple/turret_housing.tscn")
var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var builder: Node3D = BUILDER.new() as Node3D
	root.add_child(builder)
	builder.hull()
	var hull: MeshInstance3D = builder.get_node("HullShell") as MeshInstance3D
	var bounds: AABB = hull.mesh.get_aabb()
	_check(absf(bounds.size.z-263.0)<0.01,"Hull LOA must remain263m")
	_check(absf(bounds.position.y+10.4)<0.1,"Draft geometry must reach10.4m")
	_check(absf(bounds.size.x-38.9)<0.1,"Hull maximum envelope must remain38.9m")
	var vertices: PackedVector3Array = hull.mesh.get_faces()
	_check(vertices.size()>7000,"Full hull fixture must contain its generated surface")
	for vertex: Vector3 in vertices:
		_check(vertex.is_finite(),"Hull contains a nonfinite vertex")
	for index: int in range(0,vertices.size(),3):
		var area: float = (vertices[index+1]-vertices[index]).cross(vertices[index+2]-vertices[index]).length()
		_check(area>0.000001,"Degenerate hull triangle")
	# Armor now belongs to the reusable housing module, not the whole-ship builder.
	var housing: Node3D = MAIN_HOUSING.instantiate() as Node3D
	root.add_child(housing)
	var armor: MeshInstance3D
	for child: Node in housing.get_children():
		if child is MeshInstance3D:
			var part: MeshInstance3D = child as MeshInstance3D
			if part.mesh is ArrayMesh and part.mesh.get_aabb().size.x>10.0 and part.mesh.get_aabb().size.z>10.0:
				armor = part
				break
	_check(armor!=null,"Actual reusable main gunhouse must contain its custom armor shell")
	if armor != null:
		var arrays: Array = armor.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		_check(points.size()==normals.size(),"Armor vertices and normals must correspond")
		var roof_y: float = armor.mesh.get_aabb().end.y
		var roof_triangles: int = 0
		for index: int in range(0,points.size(),3):
			var geometric: Vector3 = (points[index+1]-points[index]).cross(points[index+2]-points[index]).normalized()
			_check(geometric.dot(normals[index]) < -0.99,"Custom armor winding must match Godot front faces")
			if absf(points[index].y-roof_y)<0.0001 and absf(points[index+1].y-roof_y)<0.0001 and absf(points[index+2].y-roof_y)<0.0001:
				roof_triangles += 1
				for offset: int in range(3):
					_check(normals[index+offset].y>0.99,"Every turret roof face must point upward")
		_check(roof_triangles>=4,"Main gunhouse roof must retain its complete non-port top surface")
	housing.free()
	builder.free()
	if failures.is_empty():
		print("PASS: hull dimensions, finite/nondegenerate triangles and actual modular armor roof/winding")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
