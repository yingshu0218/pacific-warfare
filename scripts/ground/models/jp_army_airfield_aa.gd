extends RefCounted
## Stylized in-game exterior. No working internals or historical firing data.
const P: Script = preload("res://scripts/ground/models/parts.gd")
const M: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

static func build(root: Node3D, spec: Dictionary) -> Dictionary:
	var paint: Material = M.material(Color("68613c"))
	var dark: Material = M.material(Color("353631"))
	var earth: Material = M.material(Color("80674a"))
	var sacks: Material = M.material(Color("a18e69"))
	var timber: Material = M.material(Color("654b35"))
	var foundation: Node3D = P.node(root,"ArmyFieldEarthwork")
	M.cylinder(foundation,"CompactedEarth",2.35,.19,Vector3(0,.015,0),earth,13,2.13)
	for side: float in [-1.0,1.0]:
		for i: int in 5:
			var bag: MeshInstance3D = M.box(foundation,"Hessian",Vector3(.47,.18,.32),
				Vector3(side*(1.53+.08*i),.12,-.84+.34*i),sacks)
			bag.rotation.y = side*(.18+.03*i)
		M.box(foundation,"FieldCrate",Vector3(.6,.38,.47),Vector3(side*1.36,.19,1.1),timber)
	# Detached transport wheels set against the rear rack are visual props only.
	var rack: Node3D = P.node(foundation,"TransportWheelRack",Vector3(-1.11,.37,1.49))
	for x: float in [-.29,.29]:
		var wheel: Node3D = P.node(rack,"SpokedWheel",Vector3(x,0,0))
		var rim: MeshInstance3D = M.cylinder(wheel,"IronRim",.31,.12,Vector3.ZERO,dark,20)
		rim.rotation.z = PI*.5
		var face: MeshInstance3D = M.cylinder(wheel,"WoodFace",.271,.126,Vector3.ZERO,timber,20)
		face.rotation.z = PI*.5
		for i: int in 6:
			var angle: float = TAU*i/6.0
			M.rod(wheel,"RaisedSpoke",Vector3(.07,0,0),Vector3(.07,sin(angle)*.23,cos(angle)*.23),.015,paint)
	var sign: Node3D = P.node(foundation,"ArmyAirfieldSign",Vector3(1.34,.47,1.52))
	for x: float in [-.34,.34]:
		M.box(sign,"Stake",Vector3(.06,.93,.09),Vector3(x,0,0),timber)
	M.box(sign,"Board",Vector3(.96,.29,.08),Vector3(0,.21,0),timber)
	var label: Label3D = Label3D.new()
	label.font = FONT
	label.font_size = 48
	label.pixel_size = .003
	label.outline_size = 0
	label.modulate = Color("e8d9af")
	label.text = "陸軍飛行場"
	label.position = Vector3(0,.213,.043)
	sign.add_child(label)
	var stand: Node3D = P.node(root,"FieldCarriage")
	for i: int in 3:
		var yaw: float = TAU*i/3.0
		var support: Node3D = P.node(stand,"SplayedLeg%d"%i)
		support.rotation.y = yaw
		M.rod(support,"Leg",Vector3(0,.41,0),Vector3(0,.115,1.04),.085,paint)
		M.box(support,"Foot",Vector3(.33,.12,.33),Vector3(0,.09,1.05),dark)
	M.cylinder(stand,"Turntable",.26,.17,Vector3(0,.43,0),paint,12)
	var train: Node3D = P.node(root,"TrainPivot",SimData.vec3(spec.mount.position_m))
	M.box(train,"Saddle",Vector3(.60,.19,.58),Vector3(0,.03,.02),paint)
	for side: float in [-1.0,1.0]:
		M.box(train,"SideFrame",Vector3(.10,.39,.41),Vector3(side*.246,.20,.04),paint)
	M.box(train,"SeatArm",Vector3(.1,.1,.57),Vector3(-.39,.12,.46),paint)
	M.box(train,"Seat",Vector3(.31,.08,.27),Vector3(-.39,.15,.73),timber)
	var elevation: Node3D = P.node(train,"ElevationPivot",SimData.vec3(spec.mount.elevation_pivot_m))
	var recoil: Node3D = P.node(elevation,"Type98Exterior")
	M.box(recoil,"ReceiverSilhouette",Vector3(.25,.24,.66),Vector3(0,.018,.17),dark)
	M.box(recoil,"TallMagazineSilhouette",Vector3(.12,.40,.16),Vector3(0,.29,.03),dark).rotation.x = -.19
	P.tube(recoil,"BarrelSilhouette",-1.56,-.13,.026,.046,0,dark)
	P.tube(recoil,"BarrelShoulder",-.66,-.19,.055,.061,0,paint)
	P.tube(recoil,"MuzzleExterior",-1.56,-1.42,.038,.036,0,dark)
	var muzzle: Marker3D = Marker3D.new()
	muzzle.name = "Muzzle_0"
	muzzle.position = SimData.vec3(spec.mount.muzzle_positions_m[0])
	elevation.add_child(muzzle)
	var seat: Marker3D = Marker3D.new()
	seat.name = "WeaponSeat"
	seat.position = train.position
	stand.add_child(seat)
	return {"train":train,"elevation":elevation,"recoil":recoil,"muzzle":muzzle,
		"foundation":foundation,"contacts":[Vector3.ZERO],"seat":seat}
