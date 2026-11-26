extends Node3D
## Carrier-specific variants. Mk24 is an open pedestal, Mk32 an enclosed twin.
## Reuses procedural primitives, not a scaled Mk28/Mk30 or another ship's platform.
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
@export_enum("mk32","mk24") var mount_kind: String = "mk32"
var train_axis: Node3D
var elevation_axes: Array[Node3D] = []
var muzzle_markers: Array[Marker3D] = []
var elevation_pivot_m: Vector3

func _ready() -> void:
	var p: Dictionary = H.palette()
	train_axis = H.group(self,"TrainPivot")
	set_meta("interface_id","cv01_5in38_"+mount_kind+ ("_twin" if mount_kind=="mk32" else "_single"))
	if mount_kind == "mk32":
		G.cylinder(self,"FixedRollerPath",2.43,.16,Vector3(0,.08,0),p.steel,28)
		var poly: Array[Vector2] = G.polygon([[-2.25,-2.45],[2.25,-2.45],[2.6,-1.65],[2.6,2.05],[1.9,2.55],[-1.9,2.55],[-2.6,2.05],[-2.6,-1.65]])
		var wall: MeshInstance3D = G.prism(train_axis,"Mk32GunHouse",poly,.16,2.30,p.gray)
		var roof: MeshInstance3D = G.prism(train_axis,"SlopedRoof",poly,2.30,3.00,p.gray,.90,Vector2(0,.18))
		for x: float in [-.72,.72]:
			var slot: AABB = AABB(Vector3(x-.34,1.02,-2.6),Vector3(.68,2.4,2.7))
			G.open_gun_slot(wall,slot); G.open_gun_slot(roof,slot)
		var inner: StandardMaterial3D = G.material(Color("242c30"))
		inner.cull_mode = BaseMaterial3D.CULL_FRONT
		G.mesh_node(train_axis,"GunHouseInnerWall",wall.mesh,inner).scale = Vector3.ONE*.995
		G.mesh_node(train_axis,"GunHouseInnerRoof",roof.mesh,inner).scale = Vector3.ONE*.995
		elevation_pivot_m = Vector3(0,1.65,-.35)
		_guns([-.72,.72],4.0)
	else:
		G.cylinder(self,"DeckPedestalFoot",1.10,.16,Vector3(0,.08,0),p.steel,24)
		G.cylinder(self,"FixedMk24Pedestal",.48,.91,Vector3(0,.615,0),p.gray,20)
		G.cylinder(train_axis,"OpenWorkingPlatform",1.12,.12,Vector3(0,.93,.30),p.steel,24)
		G.box(train_axis,"OpenMountCarriage",Vector3(1.4,.60,1.25),Vector3(0,1.18,.10),p.gray)
		for x: float in [-.62,.62]:
			G.box(train_axis,"TrunnionCheek",Vector3(.17,1.25,.90),Vector3(x,1.4,.05),p.gray)
			G.box(train_axis,"SplinterShieldSide",Vector3(.12,1.5,.9),Vector3(x*1.8,1.65,-.65),p.gray)
		G.box(train_axis,"PartialFrontShield",Vector3(2.35,.7,.10),Vector3(0,1.0,-1.0),p.gray)
		elevation_pivot_m = Vector3(0,1.8,-.10)
		_guns([0.0],3.95)
	H.batch_static(self,[train_axis])
	H.batch_static(train_axis,elevation_axes)
	for axis: Node3D in elevation_axes: H.batch_static(axis)

func _guns(xs: Array[float], length_m: float) -> void:
	var p: Dictionary = H.palette()
	for i: int in range(xs.size()):
		var axis: Node3D = H.group(train_axis,"ElevationPivot_%02d"%i,elevation_pivot_m+Vector3(xs[i],0,0))
		elevation_axes.append(axis)
		G.box(axis,"BreechAndCradle",Vector3(.48,.46,1.4),Vector3(0,0,.15),p.steel)
		G.rod(axis,"BarrelJacket",Vector3(0,0,-.2),Vector3(0,0,-2.15),.18,p.steel,12)
		G.rod(axis,"GunBarrel",Vector3(0,0,-1.8),Vector3(0,0,-length_m),.105,p.steel,12)
		var marker: Marker3D = Marker3D.new()
		marker.name = "Muzzle_%02d"%i
		axis.add_child(marker)
		marker.position = Vector3(0,0,-length_m)
		muzzle_markers.append(marker)
