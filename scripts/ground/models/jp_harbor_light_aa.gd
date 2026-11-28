extends RefCounted
## Stylized naval shore mount for the fictional Qingjia scene.
const P: Script = preload("res://scripts/ground/models/parts.gd")
const M: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const GUN: PackedScene = preload("res://scenes/weapons/type96_25mm_single.tscn")

static func build(root: Node3D, spec: Dictionary) -> Dictionary:
	var colors: Dictionary = P.palette()
	var triple: bool = spec.mount.muzzle_positions_m.size() == 3
	var foundation: Node3D = P.node(root,"HarborEmplacement")
	var masonry: Material = M.material(Color("6b7171"))
	var trim: Material = M.material(Color("8d8e83"))
	var deck: Material = M.material(Color("797b73"))
	var naval: Material = M.material(Color("4e5759"))
	M.cylinder(foundation,"ChamferedApron",2.44,.18,Vector3(0,.045,0),masonry,8,2.32)
	M.cylinder(foundation,"OctagonalFloor",1.69,.09,Vector3(0,.145,0),deck,8)
	M.cylinder(foundation,"ShorePlinth",.48,.20,Vector3(0,.25,0),masonry,10,.41)
	M.cylinder(foundation,"NavalPedestal",.38,.60,Vector3(0,.60,0),naval,12,.25)
	M.cylinder(foundation,"MountCollar",.36,.08,Vector3(0,.85,0),naval,12)
	if triple:
		_add_sandbag_ring(foundation)
	else:
		for i: int in 8:
			if i == 0 or i == 4: continue
			var bank: Node3D = P.node(foundation,"Rim%d"%i)
			bank.rotation.y = TAU*i/8.0
			M.box(bank,"Masonry",Vector3(.83,.42,.19),Vector3(0,.30,1.83),masonry)
			M.box(bank,"Cap",Vector3(.87,.055,.25),Vector3(0,.533,1.83),trim)
	for side: float in [-1.0,1.0]:
		M.box(foundation,"SteelChest",Vector3(.57,.37,.49),Vector3(side*1.10,.37,1.08),naval)
		M.box(foundation,"ChestLid",Vector3(.62,.065,.53),Vector3(side*1.10,.583,1.08),trim)
	var train: Node3D = P.node(root,"TrainPivot",SimData.vec3(spec.mount.position_m))
	M.box(train,"TurningFrame",Vector3(1.48 if triple else .84,.23,.81 if triple else .68),Vector3(0,.12,.25),colors.paint)
	if triple:
		M.cylinder(foundation,"TripleBaseRing",.76,.11,Vector3(0,.22,0),naval,16)
		for side: float in [-1.0,1.0]:
			M.box(train,"CrewFootplate",Vector3(.42,.08,.56),Vector3(side*.69,.0,.44),colors.steel)
			M.box(train,"SideGuard",Vector3(.15,.47,.57),Vector3(side*.75,.34,.29),colors.paint)
	for side: float in [-1.0,1.0]:
		M.box(train,"Cheek",Vector3(.15,.48,.37),Vector3(side*.36,.36,0),colors.steel)
	var elevation: Node3D=P.node(train,"ElevationPivot",SimData.vec3(spec.mount.elevation_pivot_m))
	var recoil: Node3D=P.node(elevation,"RecoilBarrel")
	if triple:
		M.box(recoil,"CommonCradle",Vector3(1.18,.16,.53),Vector3(0,-.14,.16),colors.steel)
	var muzzles: Array[Marker3D] = []
	for index: int in spec.mount.muzzle_positions_m.size():
		var tip: Vector3 = SimData.vec3(spec.mount.muzzle_positions_m[index])
		var gun: Node3D = GUN.instantiate() as Node3D
		gun.position.x = tip.x
		recoil.add_child(gun)
		var muzzle: Marker3D = Marker3D.new()
		muzzle.name = "Muzzle_%d" % index
		muzzle.position = tip
		elevation.add_child(muzzle)
		muzzles.append(muzzle)
	var seat: Marker3D=Marker3D.new()
	seat.name="WeaponSeat"
	seat.position=train.position
	foundation.add_child(seat)
	return {"train":train,"elevation":elevation,"recoil":recoil,"muzzle":muzzles[0],"muzzles":muzzles,"foundation":foundation,"contacts":[Vector3.ZERO],"seat":seat}


## Static game scenery only; neither the bags nor the entrance add physics nodes.
static func _add_sandbag_ring(host: Node3D) -> void:
	var ring: Node3D = P.node(host,"SandbagRing")
	var palette: Array[Material] = [
		M.material(Color("a18b62")), M.material(Color("b09a74")), M.material(Color("94805a"))]
	var cushion: ArrayMesh = _sandbag_mesh()
	const SLOTS: int = 22
	for row: int in 3:
		var course: Node3D = P.node(ring,"Course%d"%row)
		for index: int in range(2,SLOTS-1):
			var stagger: float = 0.42 if row % 2 == 1 else 0.0
			var angle: float = TAU * (float(index) + stagger) / SLOTS
			var radius: float = 1.94 - .065 * row
			var bag: MeshInstance3D = MeshInstance3D.new()
			bag.name = "Hessian_%02d" % index
			bag.mesh = cushion
			bag.material_override = palette[(index + 2 * row) % palette.size()]
			bag.position = Vector3(sin(angle)*radius,.23+.14*row + .009*sin(index*2.3+row),cos(angle)*radius)
			bag.rotation.y = angle + .05 * sin(index*1.8+row*2.3)
			bag.scale = Vector3(1.0+.055*sin(index*2.8+row),1.0,1.0)
			course.add_child(bag)

static func _sandbag_mesh() -> ArrayMesh:
	# Round the shared box mesh into a soft cloth silhouette with flatter faces.
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(.60,.20,.39)
	box.subdivide_width = 4
	box.subdivide_height = 3
	box.subdivide_depth = 4
	var arrays: Array = box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inner: Vector3 = box.size * .5 - Vector3.ONE*.076
	for i: int in vertices.size():
		var v: Vector3 = vertices[i]
		var center: Vector3 = v.clamp(-inner, inner)
		var normal: Vector3 = (v-center).normalized()
		vertices[i] = center + normal*.076
		normals[i] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
