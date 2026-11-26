extends RefCounted
## Metre-sized procedural parts; no simulation, camera or autonomous motion.
const M: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

static func palette() -> Dictionary:
	return {"paint":M.material(Color("59634b")), "steel":M.material(Color("343c35")),
		"dark":M.material(Color("1e2421")), "rubber":M.material(Color("242724")),
		"concrete":M.material(Color("929184")), "seat":M.material(Color("4c5745"))}

static func node(parent: Node3D, label: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var result: Node3D = Node3D.new()
	result.name = label
	result.position = at
	parent.add_child(result)
	return result

static func tube(parent: Node3D, label: String, front_z: float, back_z: float, front_radius: float, rear_radius: float, y: float, mat: Material) -> MeshInstance3D:
	var result: MeshInstance3D = M.cylinder(parent,label,front_radius,back_z-front_z,Vector3(0,y,(front_z+back_z)*.5),mat,24,rear_radius)
	result.rotation.x = PI*.5
	return result

static func ring(parent: Node3D, label: String, radius: float, thickness: float, at: Vector3, normal: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = maxf(.001,radius-thickness)
	mesh.outer_radius = radius+thickness
	mesh.rings = 20
	mesh.ring_segments = 8
	var result: MeshInstance3D = M.mesh_node(parent,label,mesh,mat)
	result.position = at
	result.quaternion = Quaternion(Vector3.UP,normal.normalized())
	return result

static func handwheel(parent: Node3D, label: String, at: Vector3, radius: float, mat: Material) -> void:
	ring(parent,label,radius,.014,at,Vector3.RIGHT,mat)
	for index: int in 3:
		var angle: float = TAU*index/3.0
		M.rod(parent,label+"Spoke%d"%index,at,at+Vector3(0,sin(angle),cos(angle))*radius,.011,mat)
	M.rod(parent,label+"Axle",at-Vector3(.12,0,0),at+Vector3(.07,0,0),.026,mat)

static func side_plate(parent: Node3D, label: String, points_zy: Array[Vector2], x: float, width: float, mat: Material) -> void:
	var rings: Array[PackedVector3Array] = []
	for side: float in [-.5,.5]:
		var vertices: PackedVector3Array = []
		for p: Vector2 in points_zy: vertices.append(Vector3(x+side*width,p.y,p.x))
		rings.append(vertices)
	M.mesh_node(parent,label,M.loft(rings,true),mat)
