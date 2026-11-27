extends RefCounted
## Game-only visual mounting of an existing in-project asset, not a historical
## emplacement reconstruction. The same adapter drives every independent node.
const P: Script = preload("res://scripts/ground/models/parts.gd")
const M: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const GUN: PackedScene = preload("res://scenes/weapons/type96_25mm_single.tscn")

static func build(root: Node3D, spec: Dictionary) -> Dictionary:
	var colors: Dictionary = P.palette()
	var foundation: Node3D = P.node(root,"HarborEmplacement")
	M.cylinder(foundation,"ConcretePad",2.75,.19,Vector3(0,.095,0),colors.concrete,14)
	M.cylinder(foundation,"FixedStand",.44,.67,Vector3(0,.52,0),colors.paint,12)
	for side: float in [-1.0,1.0]:
		M.box(foundation,"SupplyBox",Vector3(.50,.45,.74),Vector3(side*1.85,.33,1.53),colors.paint)
		M.box(foundation,"SupplyLid",Vector3(.55,.09,.79),Vector3(side*1.85,.60,1.53),colors.steel)
		for i: int in range(4):
			var anchor: Vector3=Vector3(side*(1.95+.12*i),.16,.16-i*.49)
			M.box(foundation,"LowSandbag",Vector3(.51,.29,.52),anchor,colors.concrete)
	var train: Node3D = P.node(root,"TrainPivot",SimData.vec3(spec.mount.position_m))
	M.box(train,"TurningFrame",Vector3(.84,.23,.68),Vector3(0,.12,.25),colors.paint)
	for side: float in [-1.0,1.0]:
		M.box(train,"Cheek",Vector3(.15,.48,.37),Vector3(side*.36,.36,0),colors.steel)
	var elevation: Node3D=P.node(train,"ElevationPivot",SimData.vec3(spec.mount.elevation_pivot_m))
	var recoil: Node3D=P.node(elevation,"RecoilBarrel")
	recoil.add_child(GUN.instantiate())
	var muzzle: Marker3D=Marker3D.new()
	muzzle.name="Muzzle_0"
	muzzle.position=SimData.vec3(spec.mount.muzzle_positions_m[0])
	elevation.add_child(muzzle)
	var seat: Marker3D=Marker3D.new()
	seat.name="WeaponSeat"
	seat.position=train.position
	foundation.add_child(seat)
	return {"train":train,"elevation":elevation,"recoil":recoil,"muzzle":muzzle,"foundation":foundation,"contacts":[Vector3.ZERO],"seat":seat}
