extends Node3D
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
func _ready() -> void:
	set_meta("host_id","island")
	var p: Dictionary = H.palette()
	var bridge: Node3D = H.group(self,"Bridge")
	G.prism(bridge,"IslandContinuousBase",G.rounded_front(7.2,48.0,12),15.85,19.25,p.gray).position = Vector3(16.1,0,-9.0)
	G.prism(bridge,"ExtendedFlagBridge1944",G.rounded_front(7.6,20.0,14),19.25,21.8,p.gray).position = Vector3(16.3,0,-23.3)
	G.prism(bridge,"NavigationBridge",G.rounded_front(7.1,16.0,14),21.8,24.7,p.gray).position = Vector3(16.25,0,-25)
	G.prism(bridge,"PilotHouse",G.rounded_front(6.6,13.5,14),24.7,27.0,p.gray).position = Vector3(16.25,0,-25.4)
	for row: Array in [[20.5,3.815,-23.3,20.0],[23.6,3.565,-25.0,16.0],[26.1,3.315,-25.4,13.5]]:
		var y: float = float(row[0])
		var width: float = float(row[1])
		var z: float = float(row[2])
		for side: float in [-1,1]:
			G.box(bridge,"BridgeGlazing",Vector3(.035,.60,7.8),Vector3(16.25+side*width,y,z+1.8),p.glass)
		G.box(bridge,"ForwardBridgeGlazing",Vector3(3.1,.6,.035),Vector3(16.25,y,z-float(row[3])*.5-.015),p.glass)
	var funnel: Node3D = H.group(self,"Funnel")
	G.prism(funnel,"Trunk",G.beveled_rect(6.7,17.5),19.25,29.6,p.gray,.92,Vector2(0,1.2)).position = Vector3(16.4,0,-9.3)
	G.prism(funnel,"BlackCap",G.beveled_rect(6.25,16.6),29.6,30.35,p.dark).position = Vector3(16.4,0,-8.1)
	for i: int in range(6):
		G.box(funnel,"FunnelUptake",Vector3(4.5,.15,.60),Vector3(16.4,30.41,-13.6+i*2.1),p.steel)
	var platforms: Node3D = H.group(self,"IslandPlatforms")
	for id: String in ["53","55"]:
		var z: float = -38 if id=="53" else 22
		var host: Node3D = H.group(platforms,"stbd_"+id,Vector3(16.4,15.85,z))
		host.set_meta("host_id","stbd_"+id)
		G.prism(host,"RaisedFiveInchGunPlatform",G.beveled_rect(6.6,8.4),0,2.23,p.gray)
		H.surface(host,"dp_"+id,Vector3(0,2.23,0),2.8)
	# Upper aft island AA floor. The removed forward-island quad is absent.
	var aft: Node3D = H.group(platforms,"island_aft_bofors",Vector3(16.4,19.25,11.3))
	aft.set_meta("host_id","island_aft_bofors")
	G.prism(aft,"AftAAPlatform",G.ellipse(6.3,7.0,24),0,2.75,p.gray)
	H.surface(aft,"aa40_island_aft",Vector3(0,2.75,0),2.8)
	for entry: Array in [["fore",-24],["aft",-10]]:
		var id: String = "island_outer_"+str(entry[0])+"_bofors"
		var host: Node3D = H.group(platforms,id,Vector3(17.0,18.62,float(entry[1])))
		host.set_meta("host_id",id)
		G.prism(host,"OutboardGunPlatform",G.beveled_rect(6.2,8.0),0,.28,p.gray)
		H.surface(host,"aa40_island_outer_"+str(entry[0]),Vector3(1,.28,0),2.8)
	# E04/P02/P07: aft Mk37 stands on a substantial island director tower,
	# independently of the adjacent 40mm platform and funnel, not a thin support pole.
	var tower: Node3D = H.group(self,"AftDirectorTower",Vector3(16.3,19.25,5.6))
	tower.set_meta("host_id","aft_director_tower")
	G.prism(tower,"DirectorTowerHouse",G.beveled_rect(3.9,4.8),0,6.85,p.gray,.9)
	G.prism(tower,"DirectorControlPlatform",G.beveled_rect(4.6,5.3),6.85,8.25,p.gray)
	H.surface(tower,"director_aft",Vector3(0,8.25,0),1.5)
	H.surface(bridge,"director_forward",Vector3(16.3,27,-31),1.5)
	H.batch_static(self)
