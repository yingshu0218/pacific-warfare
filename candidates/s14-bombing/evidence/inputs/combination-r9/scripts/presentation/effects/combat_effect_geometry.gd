extends RefCounted

## Tiny shared meshes, built once per consumer. No runtime particle children.
static func meshes() -> Dictionary:
	var cloud: QuadMesh = QuadMesh.new()
	cloud.size = Vector2.ONE
	var foam: PlaneMesh = PlaneMesh.new()
	foam.size = Vector2.ONE
	return {"cloud":cloud,"foam":foam,"water":_water_column(),"tracer":_tracer()}

static func _water_column() -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uv: PackedVector2Array = []
	var indices: PackedInt32Array = []
	var radii: Array[float] = [.3,.24,.19,.24,.34,.3]
	const SIDES: int = 10
	for level: int in radii.size():
		var y: float = float(level)/float(radii.size()-1)
		for side: int in SIDES+1:
			var angle: float = TAU*float(side)/SIDES
			var radius: float = radii[level]*(1.+.15*sin(angle*3.+y*5.))
			vertices.append(Vector3(cos(angle)*radius,y,sin(angle)*radius))
			normals.append(Vector3(cos(angle),.05,sin(angle)).normalized())
			uv.append(Vector2(float(side)/SIDES,y))
	for level: int in radii.size()-1:
		for side: int in SIDES:
			var a: int = level*(SIDES+1)+side
			var b: int = a+SIDES+1
			indices.append_array([a,b,a+1,a+1,b,b+1])
	return _mesh(vertices,normals,uv,indices)

static func _tracer() -> ArrayMesh:
	# Crossed ribbons: the real projectile head is at local z=0; tail trails at +z.
	var vertices: PackedVector3Array = [Vector3(-.5,0,0),Vector3(.5,0,0),Vector3(-.5,0,1),Vector3(.5,0,1),Vector3(0,-.5,0),Vector3(0,.5,0),Vector3(0,-.5,1),Vector3(0,.5,1)]
	var normals: PackedVector3Array = [Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP,Vector3.RIGHT,Vector3.RIGHT,Vector3.RIGHT,Vector3.RIGHT]
	var uv: PackedVector2Array = [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]
	return _mesh(vertices,normals,uv,PackedInt32Array([0,2,1,1,2,3,4,5,6,5,7,6]))

static func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
