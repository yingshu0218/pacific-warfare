extends Node3D
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

func _ready() -> void:
	set_meta("host_id","island")
	var p: Dictionary = H.palette()
	var bridge: Node3D = H.group(self,"Bridge",Vector3(14.4,14.15,-40.5))
	# The small stepped island is distinct from the two outboard funnels.
	# Individual bridge decks preserve the rounded forward faces in S01/M01.
	G.prism(bridge,"BridgeLowerHouse",G.rounded_front(5.3,15.5),0,3.0,p.gray)
	G.prism(bridge,"NavigationBridge",G.rounded_front(6.9,12.8),3.0,4.45,p.gray)
	G.prism(bridge,"CompassPlatform",G.rounded_front(7.2,12.1),4.45,4.7,p.gray)
	G.prism(bridge,"UpperBridge",G.rounded_front(5.3,10.2),4.7,6.4,p.gray)
	G.prism(bridge,"OpenBridgePlatform",G.rounded_front(6.2,10.8),6.4,6.65,p.gray)
	G.prism(bridge,"AirControlBridge",G.rounded_front(4.2,7.4),6.65,7.75,p.gray)
	# Sparse dark windows follow the stepped walls; no interior or railings.
	for y: float in [3.85,5.75,7.15]:
		var half: float = 3.47 if y<4.0 else (2.67 if y<6 else 2.12)
		var length: float = 8.6 if y<4.0 else (7.2 if y<6 else 5.6)
		for side: float in [-1,1]:
			G.box(bridge,"BridgeWindowBand",Vector3(.025,.42,length),Vector3(side*half,y,-.2),p.glass)
		G.box(bridge,"BridgeForwardWindows",Vector3(half*1.36,.42,.035),Vector3(0,y,-length*.54),p.glass)
	G.cylinder(bridge,"Type94DirectorPedestal",.85,1.05,Vector3(0,8.18,-2.2),p.gray,20)
	G.prism(bridge,"Type94Director",G.beveled_rect(2.45,2.35),8.65,9.65,p.gray)
	G.rod(bridge,"DirectorOpticalBaseline",Vector3(-1.55,9.2,-2.2),Vector3(1.55,9.2,-2.2),.16,p.steel,10)
	# Source-visible tripod immediately aft of the island, not atop a funnel.
	var mast: Node3D = H.group(self,"Foremast",Vector3(12.6,14.15,-29.7))
	for foot: Vector3 in [Vector3(-1.45,0,1.45),Vector3(1.45,0,1.45),Vector3(0,0,-1.6)]:
		G.rod(mast,"TripodLeg",foot,Vector3(0,11.5,0),.13,p.gray,10)
	G.rod(mast,"Topmast",Vector3(0,9.5,0),Vector3(0,17.85,0),.095,p.gray,10)
	G.rod(mast,"MastYard",Vector3(-2.4,13.0,0),Vector3(2.4,13.0,0),.075,p.gray,8)
	# Two side-mounted directors are small supported gallery equipment.
	for z: float in [-53.0,-28.3]:
		G.cylinder(self,"DirectorGalleryFoot",1.1,1.2,Vector3(15.2,14.75,z),p.gray,20)
		G.prism(self,"DirectorHead",G.beveled_rect(2.15,2.15),15.35,16.7,p.gray)
		# Above prism is created at origin, so assign the station explicitly.
		var head: Node3D = get_child(get_child_count()-1) as Node3D
		head.position.x=15.2; head.position.z=z
	H.batch_static(self)
