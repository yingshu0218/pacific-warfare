extends RefCounted
## Mk8 Mod0 / Mk13 Mod4: OP1112 pp162-163, sheet date1945-01-15.
const P: Script = preload("res://scripts/ground/models/parts.gd")
const M: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

static func build(root: Node3D, spec: Dictionary) -> Dictionary:
	var c: Dictionary = P.palette()
	var foundation: Node3D = P.node(root,"Foundation")
	# Original scenario host slab; not a claimed Wake underground foundation.
	M.cylinder(foundation,"ConcreteHost",2.65,.18,Vector3(0,.09,0),c.concrete,40)
	var pedestal: Node3D = P.node(foundation,"Mk13FixedPedestal",Vector3(0,.18,0))
	M.prism(pedestal,"BaseFlange",M.ellipse(1.31,1.3462,32),0,.10,c.paint,1.0,Vector2(0,.0635))
	M.cylinder(pedestal,"PedestalCasting",.51,.43,Vector3(0,.285,0),c.paint,28,.34)
	M.cylinder(pedestal,"SeatRing",.39,.12,Vector3(0,.51,0),c.steel,28)
	var train: Node3D = P.node(root,"TrainPivot",SimData.vec3(spec.mount.position_m))
	var carriage: Node3D = P.node(train,"OpenCarriage")
	var outline: Array[Vector2] = [Vector2(-.52,.46),Vector2(.57,.46),Vector2(.52,.87),Vector2(.28,1.09),Vector2(-.25,1.09),Vector2(-.52,.78)]
	for side: float in [-1.0,1.0]:
		P.side_plate(carriage,"YokePort" if side<0 else "YokeStarboard",outline,side*.36,.13,c.paint)
		var bearing: MeshInstance3D = M.cylinder(carriage,"TrunnionBearing",.18,.20,Vector3(side*.39,1.02362,0),c.steel,24)
		bearing.rotation.z = PI*.5
		P.handwheel(carriage,"ElevationHandwheel" if side<0 else "TrainingHandwheel",Vector3(side*.66,.76,.45),.20,c.paint)
		M.rod(carriage,"WheelSupport",Vector3(side*.37,.56,.29),Vector3(side*.60,.76,.45),.045,c.paint)
		M.box(carriage,"OperatorFootboard",Vector3(.34,.06,.70),Vector3(side*.67,.18,.58),c.steel)
	M.box(carriage,"RearCrossmember",Vector3(.84,.12,.22),Vector3(0,.53,.52),c.paint)
	var elevation: Node3D = P.node(train,"ElevationPivot",SimData.vec3(spec.mount.elevation_pivot_m))
	# Slide / cradle stays with elevation; only the barrel body recoils.
	M.box(elevation,"Slide",Vector3(.61,.20,1.60),Vector3(0,-.22,.10),c.paint)
	P.tube(elevation,"RecoilCylinder",-.62,1.21,.105,.105,-.39,c.steel)
	var recoil: Node3D = P.node(elevation,"RecoilBarrel")
	P.tube(recoil,"TaperedChase",-4.73075,-.64,.105,.225,0,c.paint)
	P.tube(recoil,"Jacket",-.76,.88,.245,.28,0,c.paint)
	P.tube(recoil,"BreechRing",.88,1.36,.30,.30,0,c.paint)
	M.box(recoil,"ScrewBreechBody",Vector3(.54,.56,.46),Vector3(0,0,1.49),c.paint)
	P.tube(recoil,"BreechBlock",1.68,1.84,.255,.255,0,c.steel)
	M.rod(recoil,"BreechOperatingLever",Vector3(.29,0,1.47),Vector3(.38,.26,1.86),.035,c.steel)
	# Dark shallow bore is a visual recess, with no oversized muzzle brake.
	P.tube(recoil,"Bore",-4.732,-4.728,.0635,.0635,0,c.dark)
	var muzzle: Marker3D = Marker3D.new()
	muzzle.name = "Muzzle_0"
	muzzle.position = SimData.vec3(spec.mount.muzzle_positions_m[0])
	elevation.add_child(muzzle)
	var seat: Marker3D = Marker3D.new()
	seat.name = "WeaponSeat"
	seat.position = SimData.vec3(spec.mount.position_m)
	foundation.add_child(seat)
	return {"train":train,"elevation":elevation,"recoil":recoil,"muzzle":muzzle,
		"foundation":foundation,"contacts":[Vector3.ZERO],"seat":seat}
