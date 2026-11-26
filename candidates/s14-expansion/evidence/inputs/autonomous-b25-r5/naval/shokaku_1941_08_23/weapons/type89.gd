extends Node3D
## CV02 Type89 twin A1-family simplified open / smokeproof variants.
## Ship sponsons are NOT in this weapon. Root is fixed mounting plane.
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
@export var smokeproof: bool = false
var train_axis: Node3D
var elevation_axes: Array[Node3D] = []
var muzzle_markers: Array[Marker3D] = []
var elevation_pivot_m: Vector3 = Vector3(0,1.42,-.15)

func _ready() -> void:
	set_meta("interface_id","cv02_type89_127mm_twin")
	var p: Dictionary = H.palette()
	G.cylinder(self,"FixedRollerSeat",1.7,.16,Vector3(0,.08,0),p.steel,24)
	train_axis=H.group(self,"TrainPivot")
	G.cylinder(train_axis,"WorkingPlatform",2.1,.18,Vector3(0,.25,.18),p.gray,28)
	for x: float in [-.96,.96]:
		G.box(train_axis,"TrunnionCheek",Vector3(.20,1.55,1.2),Vector3(x,1.10,.15),p.gray)
	if smokeproof:
		# Rounded smoke shield is a mount variant visible on the TWO right-aft
		# stations, not the Yamato turret copied to all eight positions.
		var rings: Array[PackedVector3Array] = []
		for level: int in range(9):
			var phi: float = PI*.5*float(level)/8
			var radius: float = maxf(cos(phi),.015)
			var ring: PackedVector3Array = []
			for j: int in range(32):
				var angle: float = TAU*float(j)/32
				ring.append(Vector3(cos(angle)*2.15*radius,.35+sin(phi)*2.65,sin(angle)*2.2*radius))
			rings.append(ring)
		var hood: MeshInstance3D = G.mesh_node(train_axis,"SmokeproofRoundedHood",H.loft(rings,true),p.gray)
		for x: float in [-.38,.38]:
			G.open_gun_slot(hood,AABB(Vector3(x-.23,1.16,-2.7),Vector3(.46,2.0,2.8)))
	else:
		# Open rear and top: partial shield, carriage and visible twin breeches.
		G.box(train_axis,"PartialFrontShield",Vector3(3.5,1.05,.13),Vector3(0,.87,-1.05),p.gray)
		for x: float in [-1.68,1.68]:
			G.box(train_axis,"OpenSideShield",Vector3(.12,1.10,1.5),Vector3(x,.9,-.35),p.gray)
		G.box(train_axis,"OpenTwinCarriage",Vector3(1.8,.6,1.4),Vector3(0,.76,.18),p.steel)
	var axis: Node3D = H.group(train_axis,"ElevationPivot",elevation_pivot_m)
	elevation_axes.append(axis)
	# Type89 twins elevate together; one shared cradle, two real muzzle points.
	for x: float in [-.38,.38]:
		G.box(axis,"GunBreech",Vector3(.37,.43,1.45),Vector3(x,0,.25),p.steel)
		G.rod(axis,"BarrelJacket",Vector3(x,0,-.4),Vector3(x,0,-1.85),.17,p.steel,12)
		G.rod(axis,"GunBarrel",Vector3(x,0,-1.7),Vector3(x,0,-3.8),.095,p.steel,12)
		var marker: Marker3D = Marker3D.new()
		marker.name="Muzzle_%02d"%muzzle_markers.size(); marker.position=Vector3(x,0,-3.8)
		axis.add_child(marker); muzzle_markers.append(marker)
	H.batch_static(self,[train_axis]); H.batch_static(train_axis,elevation_axes); H.batch_static(axis)
