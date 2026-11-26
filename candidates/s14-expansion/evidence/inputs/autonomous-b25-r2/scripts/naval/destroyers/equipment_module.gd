extends Node3D
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
@export_file("*.json") var assembly_path: String
var torpedo_axes: Dictionary = {}

func _ready() -> void:
	var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(assembly_path))
	var p: Dictionary = G.palette(c.country_id == "us")
	for record: Dictionary in c.equipment:
		var module: Node3D = Node3D.new()
		module.name = record.id
		module.position = G.vector(record.position_m)
		module.rotation.y = deg_to_rad(float(record.get("yaw_deg",0.0)))
		module.set_meta("source_ids", record.source_ids)
		add_child(module)
		match str(record.kind):
			"mast": _mast(module, record, p)
			"torpedo": _torpedo(module, record, p)
			"boat": _boat(module, record, p)
			"director": _director(module, record, p)
			"depth_rack": _depth_rack(module, p)
			"reload": G.box(module, "TorpedoReloadHousing", G.vector(record.size_m), Vector3(0, float(record.size_m[1]) * 0.5, 0), p.gray)
			"searchlight":
				G.cylinder(module, "Pedestal", 0.20, 0.8, Vector3(0,0.4,0), p.gray)
				var lamp: MeshInstance3D = G.cylinder(module, "Lamp", 0.44, 0.58, Vector3(0,1.15,0), p.steel)
				lamp.rotation.x = PI * 0.5
			"anchor":
				G.rod(module, "Shank", Vector3(0,-0.5,0), Vector3(0,0.5,0), 0.1, p.dark)
				G.rod(module, "Flukes", Vector3(-0.5,-0.3,0), Vector3(0.5,-0.3,0), 0.15, p.dark)
			"bollard":
				for x: float in [-0.24, 0.24]:
					G.cylinder(module, "Bollard", 0.13, 0.45, Vector3(x,0.225,0), p.steel, 10)

func _mast(parent: Node3D, r: Dictionary, p: Dictionary) -> void:
	var height: float = float(r.height_m)
	G.rod(parent, "Pole", Vector3.ZERO, Vector3(0,height,0.5), 0.11, p.gray)
	if r.get("tripod", false):
		for x: float in [-1.15, 1.15]:
			G.rod(parent, "TripodLeg", Vector3(x,0,1.4), Vector3(0,height * 0.90,0.45), 0.10, p.gray)
	for fraction: float in [0.52,0.80]:
		var width: float = 3.8 if fraction < 0.7 else 2.8
		G.rod(parent, "Yard", Vector3(-width,height * fraction,0.3), Vector3(width,height * fraction,0.3), 0.055, p.steel)
	if r.get("radar", false):
		G.box(parent, "SC2Frame", Vector3(3.2,1.25,0.12), Vector3(0,height - 0.2,0.5), p.dark)
		for x: float in [-1.3,0,1.3]:
			G.rod(parent, "SC2Vertical", Vector3(x,height - 0.7,0.4), Vector3(x,height + 0.25,0.4), 0.035, p.gray)

func _torpedo(parent: Node3D, r: Dictionary, p: Dictionary) -> void:
	var count: int = int(r.tube_count)
	var train: Node3D = Node3D.new()
	train.name = "LauncherTrain"
	parent.add_child(train)
	torpedo_axes[r.id] = train
	G.cylinder(parent, "FixedSeat", 1.0, 0.34, Vector3(0,0.17,0), p.gray)
	G.box(train, "TubeBed", Vector3(float(count) * 0.78,0.32,2.3), Vector3(0,0.52,0), p.steel)
	for index: int in range(count):
		var x: float = (float(index) - float(count - 1) * 0.5) * (0.69 if count == 5 else 0.78)
		var radius: float = 0.30 if count == 5 else 0.35
		G.rod(train, "Tube_%02d" % index, Vector3(x,0.99,3.75), Vector3(x,0.99,-3.75), radius, p.steel, 14)
		G.rod(train, "TubeDoor_%02d" % index, Vector3(x,0.99,-3.74), Vector3(x,0.99,-3.84), radius * 1.04, p.gray, 14)
	if count == 4:
		G.prism(train, "Type92Shield", G.beveled_rect(3.30,6.4), 0.70, 1.95, p.gray, 0.90)
	else:
		G.box(train, "TrainingCab", Vector3(0.75,0.85,1.1), Vector3(1.25,1.5,1.2), p.gray)
	parent.set_meta("tube_count", count)
	parent.set_meta("firing_system", "not_implemented_in_showcase")

func _boat(parent: Node3D, r: Dictionary, p: Dictionary) -> void:
	var length: float = float(r.get("length_m",6.6))
	var hull: MeshInstance3D = G.prism(parent, "BoatHull", G.ellipse(1.85,length,20), 0, 0.68, p.gray, 0.88)
	hull.position.y = 0.18
	G.prism(parent, "CanvasCover", G.ellipse(1.60,length * 0.90,20), 0.83, 1.04, p.canvas)
	for z: float in [-2.1,2.1]:
		var foot: float = float(r.get("deck_y_m",r.position_m[1])) - float(r.position_m[1])
		G.rod(parent, "Davit", Vector3(-0.6,foot,z), Vector3(-0.6,1.8,z), 0.07, p.gray)
		G.rod(parent, "DavitHead", Vector3(-0.6,1.8,z), Vector3(0.2,1.8,z), 0.07, p.gray)
		G.rod(parent, "BoatHanger",Vector3(0.2,1.8,z),Vector3(0.2,1.0,z),0.025,p.steel)

func _director(parent: Node3D, r: Dictionary, p: Dictionary) -> void:
	G.cylinder(parent, "FixedDirectorBase", 0.68, 0.44, Vector3(0,0.22,0), p.gray)
	var us: bool = bool(r.get("usn",false))
	G.prism(parent, "DirectorHouse", G.rounded_front(2.25 if us else 2.8,2.2 if us else 2.6), 0.44, 2.15, p.gray, 0.86)
	G.rod(parent, "OpticalRangefinder", Vector3(-2.0,1.5,0), Vector3(2.0,1.5,0), 0.20, p.gray)
	if us:
		G.box(parent, "Mk4RadarFrame", Vector3(2.1,0.9,0.12), Vector3(0,2.65,0), p.steel).rotation.x = -0.25
	else:
		G.prism(parent,"DirectorRoof",G.rounded_front(2.8,2.6),2.15,2.35,p.gray,0.82)

func _depth_rack(parent: Node3D, p: Dictionary) -> void:
	for x: float in [-0.38,0.38]:
		G.rod(parent, "Track", Vector3(x,0.2,-1.5), Vector3(x,0.2,1.5),0.055,p.steel)
	for z: float in [-1.1,-0.4,0.3,1.0]:
		G.rod(parent, "DepthCharge",Vector3(-0.35,0.55,z),Vector3(0.35,0.55,z),0.30,p.dark,12)
