extends RefCounted
## Stylized naval shore mount for the fictional Qingjia scene.
const P: Script = preload("res://scripts/ground/models/parts.gd")
const M: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const GUN: PackedScene = preload("res://scenes/weapons/type96_25mm_single.tscn")

static func build(root: Node3D, spec: Dictionary) -> Dictionary:
	var colors: Dictionary = P.palette()
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
