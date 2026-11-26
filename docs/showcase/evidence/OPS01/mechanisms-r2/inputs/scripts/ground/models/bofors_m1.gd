extends RefCounted
## US M1 / M2A1, firing configuration, TM9-252 (1944), figs1,4,89,161.
const P: Script = preload("res://scripts/ground/models/parts.gd")
const M: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

static func build(root: Node3D, spec: Dictionary) -> Dictionary:
	var c: Dictionary = P.palette()
	var fixed: Node3D = P.node(root,"M2A1FixedCarriage")
	M.box(fixed,"LongitudinalFrame",Vector3(.38,.21,3.45),Vector3(0,.48,0),c.paint)
	M.cylinder(fixed,"TurntableBase",.63,.23,Vector3(0,.65,0),c.paint,28)
	var contacts: Array[Vector3] = []
	for side: float in [-1.0,1.0]:
		for end: float in [-1.0,1.0]:
			var wheel: Vector3 = Vector3(side*.7032625,.50,end*1.6002)
			var tire: MeshInstance3D = M.cylinder(fixed,"RubberTire",.43,.17,wheel,c.rubber,28)
			tire.rotation.z=PI*.5
			var hub: MeshInstance3D = M.cylinder(fixed,"WheelDisk",.30,.183,wheel,c.paint,24)
			hub.rotation.z=PI*.5
			M.rod(fixed,"Axle",Vector3(0,.50,end*1.6002),wheel,.075,c.steel)
		var feet: Array[Vector3] = [Vector3(side*1.85,0,0),Vector3(0,0,side*1.95)]
		for foot: Vector3 in feet:
			M.rod(fixed,"OutriggerBeam",Vector3(0,.46,0),foot+Vector3(0,.36,0),.12,c.paint)
			M.cylinder(fixed,"LevelingJack",.065,.52,foot+Vector3(0,.285,0),c.steel,16)
			M.cylinder(fixed,"JackFoot",.17,.05,foot+Vector3(0,.025,0),c.paint,20)
			M.rod(fixed,"JackHandle",foot+Vector3(-.15,.55,0),foot+Vector3(.15,.55,0),.014,c.steel)
			contacts.append(foot)
		M.rod(fixed,"DrawbarArm",Vector3(side*.40,.46,-1.59),Vector3(0,.46,-2.78),.045,c.paint)
	P.ring(fixed,"TowLunette",.105,.023,Vector3(0,.46,-2.85),Vector3.UP,c.steel)
	var train: Node3D = P.node(root,"TrainPivot",SimData.vec3(spec.mount.position_m))
	var body: Node3D = P.node(train,"RotatingBody",Vector3(0,-.8,0))
	M.cylinder(body,"TrainingRace",.57,.12,Vector3(0,.80,0),c.steel,28)
	M.box(body,"CradleBase",Vector3(.72,.28,1.13),Vector3(0,.98,.10),c.paint)
	for side: float in [-1.0,1.0]:
		M.box(body,"TrunnionCheek",Vector3(.14,.51,.54),Vector3(side*.31,1.26,0),c.paint)
		var bearing: MeshInstance3D = M.cylinder(body,"Trunnion",.17,.15,Vector3(side*.38,1.49,0),c.steel,20)
		bearing.rotation.z=PI*.5
		M.rod(body,"SeatFrame",Vector3(side*.32,.91,.22),Vector3(side*.68,.87,.61),.035,c.paint)
		M.box(body,"OperatorSeat",Vector3(.37,.06,.35),Vector3(side*.68,.90,.60),c.seat)
		M.box(body,"SeatBack",Vector3(.37,.26,.045),Vector3(side*.68,1.05,.79),c.seat)
		M.rod(body,"SeatBackSupport",Vector3(side*.68,.87,.61),Vector3(side*.68,1.08,.81),.027,c.paint)
		P.handwheel(body,"ManualDrive",Vector3(side*.54,1.08,.17),.19,c.steel)
		M.rod(body,"FootrestArm",Vector3(side*.40,.87,.4),Vector3(side*.68,.60,-.1),.027,c.paint)
		M.box(body,"Footrest",Vector3(.32,.045,.27),Vector3(side*.68,.60,-.1),c.steel)
	var elevation: Node3D = P.node(train,"ElevationPivot",SimData.vec3(spec.mount.elevation_pivot_m))
	M.box(elevation,"Receiver",Vector3(.40,.37,1.06),Vector3(0,0,.30),c.paint)
	M.box(elevation,"FourRoundFeedGuide",Vector3(.29,.39,.27),Vector3(0,.36,.31),c.paint)
	M.box(elevation,"FeedOpening",Vector3(.22,.012,.20),Vector3(0,.562,.31),c.dark)
	P.tube(elevation,"CradleRecoilHousing",-.72,.61,.13,.16,-.14,c.paint)
	var recoil: Node3D = P.node(elevation,"RecoilBarrel")
	P.tube(recoil,"BarrelJacket",-.98,-.30,.115,.145,0,c.paint)
	P.tube(recoil,"SingleBarrel",-2.52,-.91,.037,.065,0,c.steel)
	P.tube(recoil,"ConicalFlashHider",-2.701,-2.50,.082,.037,0,c.steel)
	P.tube(recoil,"Bore",-2.703,-2.699,.020,.020,0,c.dark)
	# M3 sights: physically supported crossbar and two fore/aft bars.
	M.rod(elevation,"SightCrossbar",Vector3(-.59,.24,-.65),Vector3(.59,.24,-.65),.022,c.steel)
	for side: float in [-1.0,1.0]:
		M.rod(elevation,"SightBracket",Vector3(side*.15,.12,-.56),Vector3(side*.36,.24,-.65),.022,c.paint)
		M.rod(elevation,"SightBar",Vector3(side*.59,.24,-.65),Vector3(side*.59,.39,-1.11),.018,c.steel)
		P.ring(elevation,"FrontM3Sight",.11,.009,Vector3(side*.59,.50,-1.11),Vector3.FORWARD,c.steel)
		M.rod(elevation,"SightStem",Vector3(side*.59,.39,-1.11),Vector3(side*.59,.50,-1.11),.012,c.steel)
		P.ring(elevation,"RearM3Sight",.069,.009,Vector3(side*.59,.31,-.65),Vector3.FORWARD,c.steel)
	var muzzle: Marker3D = Marker3D.new();muzzle.name="Muzzle_0"
	muzzle.position=SimData.vec3(spec.mount.muzzle_positions_m[0]);elevation.add_child(muzzle)
	var seat: Marker3D = Marker3D.new();seat.name="WeaponSeat"
	seat.position=SimData.vec3(spec.mount.position_m);fixed.add_child(seat)
	return {"train":train,"elevation":elevation,"recoil":recoil,"muzzle":muzzle,"foundation":fixed,"contacts":contacts,"seat":seat}
