extends Node3D
## Shared static game display geometry. No dynamics or engineering geometry.

var _steel: StandardMaterial3D
var _deck: StandardMaterial3D
var _upper: StandardMaterial3D
var _dark: StandardMaterial3D
var _hull_side: StandardMaterial3D
var _underbody: StandardMaterial3D
var _group: Node3D


func _stations() -> Array[Vector4]:
	return []


func _half_length() -> float:
	return 0.0


func _draft() -> float:
	return 0.0


func _paint(hex: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.76
	return mat


func _layer(label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	add_child(node)
	return node


func _instance(label: String, shape: Mesh, material: Material, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = shape
	node.material_override = material
	node.position = position
	_group.add_child(node, true)
	return node


func _hull() -> void:
	# Work through the drawn outer silhouette, from keel to deck (no internal geometry).
	var below := SurfaceTool.new()
	var stripe := SurfaceTool.new()
	var sides := SurfaceTool.new()
	var deck := SurfaceTool.new()
	for surface: SurfaceTool in [below, stripe, sides, deck]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(_stations().size() - 1):
		var a: Vector4 = _stations()[i]; var b: Vector4 = _stations()[i + 1]
		for direction: float in [-1.0, 1.0]:
			var rail_a: PackedVector3Array = _section(a,direction); var rail_b: PackedVector3Array = _section(b,direction)
			var outward := Vector3(direction,0,0)
			for ring: int in range(rail_a.size() - 1):
				var surface: SurfaceTool = below if ring < 2 else (stripe if ring == 2 else sides)
				_quad(surface,rail_a[ring],rail_b[ring],rail_b[ring+1],rail_a[ring+1],outward)
		_quad(deck,Vector3(-a.y,a.z,a.x),Vector3(a.y,a.z,a.x),Vector3(b.y,b.z,b.x),Vector3(-b.y,b.z,b.x),Vector3.UP)
		var bottom_a := _section(a,1)[0]; var bottom_b := _section(b,1)[0]
		_quad(below,Vector3(-bottom_a.x,bottom_a.y,bottom_a.z),bottom_a,bottom_b,Vector3(-bottom_b.x,bottom_b.y,bottom_b.z),Vector3.DOWN)
	for end: int in [0,_stations().size()-1]:
		var left: PackedVector3Array = _section(_stations()[end],-1); var right: PackedVector3Array = _section(_stations()[end],1)
		for ring: int in range(left.size()-1):
			var surface: SurfaceTool = below if ring < 2 else (stripe if ring == 2 else sides)
			_quad(surface,left[ring],right[ring],right[ring+1],left[ring+1],Vector3.FORWARD if end == 0 else Vector3.BACK)
	_commit("Keel and underwater hull",below,_underbody)
	_commit("Boot stripe",stripe,_dark)
	_commit("Hull plating",sides,_hull_side)
	_commit("Continuous weather deck",deck,_deck)


func _section(row: Vector4, side: float) -> PackedVector3Array:
	var fullness: float = smoothstep(0.0,48.0,_half_length()-absf(row.x))
	var keel: float = lerpf(-0.65,-_draft(),fullness)
	return PackedVector3Array([
		Vector3(side * row.w * 0.28,keel,row.x),
		Vector3(side * row.w * 0.82,keel * 0.65,row.x),
		Vector3(side * row.w * 0.98,-0.30,row.x),
		Vector3(side * lerpf(row.w,row.y,0.08),0.40,row.x),
		Vector3(side * lerpf(row.w,row.y,0.49),row.z*0.54,row.x),
		Vector3(side * row.y,row.z,row.x),
	])


func _tri(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,out: Vector3) -> void:
	s.add_vertex(a)
	if (b-a).cross(c-a).dot(out) > 0.0:
		s.add_vertex(c); s.add_vertex(b)
	else:
		s.add_vertex(b); s.add_vertex(c)


func _quad(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,out: Vector3) -> void:
	_tri(s,a,b,c,out); _tri(s,a,c,d,out)


func _commit(label: String, surface: SurfaceTool, material: Material) -> void:
	surface.index()
	surface.generate_normals()
	_instance(label,surface.commit(),material)


func _box(label: String, p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _instance(label,shape,material,p)


func _octagon(label: String, p: Vector3, width: float, height: float, length: float, cut: float, material: Material, taper: float = 1.0) -> void:
	var x: float = width*0.5
	var z: float = length*0.5
	var path := PackedVector2Array([
		Vector2(-x+cut,-z),Vector2(x-cut,-z),Vector2(x,-z+cut),Vector2(x,z-cut),
		Vector2(x-cut,z),Vector2(-x+cut,z),Vector2(-x,z-cut),Vector2(-x,-z+cut),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i: int in range(path.size()):
		var a: Vector2 = path[i]; var b: Vector2 = path[(i+1)%path.size()]
		var low_a := Vector3(a.x,-height*0.5,a.y)
		var low_b := Vector3(b.x,-height*0.5,b.y)
		var top_a := Vector3(a.x*taper,height*0.5,a.y*taper)
		var top_b := Vector3(b.x*taper,height*0.5,b.y*taper)
		_quad(surface,low_a,low_b,top_b,top_a,Vector3(a.x+b.x,0,a.y+b.y))
		_tri(surface,Vector3(0,-height*0.5,0),low_a,low_b,Vector3.DOWN)
		_tri(surface,Vector3(0,height*0.5,0),top_a,top_b,Vector3.UP)
	surface.generate_normals()
	_instance(label,surface.commit(),material,p)


func _pipe(label: String, p: Vector3, h: float, lower: float, upper: float, extent_z: float, material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.radial_segments = 14
	shape.height = h
	shape.bottom_radius = lower
	shape.top_radius = upper
	var item := _instance(label,shape,material,p)
	item.scale.z = extent_z
	return item


func _spar(label: String, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var diff: Vector3 = b-a
	var item := _box(label,(a+b)*0.5,Vector3(width,width,diff.length()),material)
	item.quaternion = Quaternion(Vector3.BACK,diff.normalized())


func _deck_height(z: float) -> float:
	for i: int in range(_stations().size() - 1):
		var a: Vector4 = _stations()[i]
		var b: Vector4 = _stations()[i + 1]
		if z <= b.x:
			return lerpf(a.z, b.z, inverse_lerp(a.x, b.x, z))
	return _stations()[-1].z
