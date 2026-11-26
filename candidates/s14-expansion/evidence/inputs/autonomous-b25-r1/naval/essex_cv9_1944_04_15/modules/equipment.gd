extends Node3D
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
func _ready() -> void:
	var p: Dictionary = H.palette()
	var mast: Node3D = H.group(self,"Foremast",Vector3(16.5,27.0,-23.0))
	G.rod(mast,"MainPole",Vector3.ZERO,Vector3(0,14,1.8),.17,p.steel,10)
	for side: float in [-1,1]:
		G.rod(mast,"TripodLeg",Vector3(side*2.2,-1,2.8),Vector3(0,7.8,.8),.13,p.gray,8)
	for y: float in [5,9,12]:
		G.rod(mast,"Yard",Vector3(-3.5,y,1),Vector3(3.5,y,1),.08,p.steel,8)
	# Open rectangular SK frame; no postwar circular SK-2 dish.
	var radar: Node3D = H.group(mast,"SKRadar",Vector3(0,10.3,1.2))
	for x: float in [-2.2,-1.1,0,1.1,2.2]:
		G.rod(radar,"SKVertical",Vector3(x,-1.1,0),Vector3(x,1.1,0),.045,p.steel,6)
	for y: float in [-1.1,0,1.1]:
		G.rod(radar,"SKHorizontal",Vector3(-2.2,y,0),Vector3(2.2,y,0),.045,p.steel,6)
	for entry: Array in [[-31,27.0],[5.6,27.5]]:
		var director: Node3D = H.group(self,"DirectorForward" if float(entry[0])<0 else "DirectorAft",Vector3(16.3,float(entry[1]),float(entry[0])))
		director.set_meta("equipment_id","director_forward" if float(entry[0])<0 else "director_aft")
		G.cylinder(director,"DirectorPedestal",.75,1.0,Vector3(0,.5,0),p.gray,16)
		G.prism(director,"DirectorCab",G.beveled_rect(2.8,2.6),1,2.8,p.gray)
		G.rod(director,"Rangefinder",Vector3(-2.3,2.3,0),Vector3(2.3,2.3,0),.15,p.gray,8)
		G.box(director,"Mk4Radar",Vector3(2.7,1.2,.10),Vector3(0,3.5,0),p.steel)
	for z: float in [-100,65,112]:
		var at: Vector3 = Vector3(-17.0,15.6,z)
		G.rod(self,"PortRadioMast",at,at+Vector3(0,12,1),.085,p.steel,8)
	# Stern aircraft crane silhouette, port quarter, in the stowed position.
	var at: Vector3 = Vector3(-12,14.3,112)
	G.rod(self,"CranePost",at,at+Vector3(0,4,0),.28,p.gray,10)
	G.rod(self,"StowedCraneBoom",at+Vector3(0,4,0),at+Vector3(0,4.5,-13),.16,p.steel,8)
	H.batch_static(self)
