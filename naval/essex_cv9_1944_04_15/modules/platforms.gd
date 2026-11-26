extends Node3D
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
func _ready() -> void:
	var p: Dictionary = H.palette()
	for forward: bool in [true,false]:
		var id: String = "port_forward_sponson" if forward else "port_aft_sponson"
		var center_z: float = -96.5 if forward else 97
		var host: Node3D = H.group(self,id,Vector3(-16.9,11.3,center_z))
		host.set_meta("host_id",id)
		var outline: Array[Vector2] = G.beveled_rect(12.7,42.0)
		G.prism(host,"GallerySponsonStructure",outline,0,2.25,p.gray,.98)
		# Inboard integration into the gallery/hull is continuous, no invented posts.
		G.box(host,"GalleryConnection",Vector3(5,1.1,32),Vector3(6.1,1.7,0),p.gray)
		for record: Dictionary in H.read_data("assembly").mounts:
			if record.host_id != id: continue
			var loc: Vector3 = G.vector(record.position_m)-host.position
			H.surface(host,record.id,loc,2.7)
		# Outboard splinter face stays below gun trunnions.
		G.box(host,"SplinterFace",Vector3(.15,.8,38),Vector3(-6.2,2.65,0),p.gray)
	for record: Dictionary in H.read_data("assembly").mounts:
		if record.id in ["dp_51","dp_57"]:
			var host: Node3D = H.group(self,record.host_id,Vector3(16.4,15.46,record.position_m[2]))
			host.set_meta("host_id",record.host_id)
			G.prism(host,"FlightLevelBatteryFloor",G.beveled_rect(6.7,9.0),0,.39,p.gray)
			# Actual gallery-level ship structure bears the battery, not a mount adapter.
			G.box(host,"BatteryGallerySupport",Vector3(5.5,2.8,8),Vector3(-1,-1.4,0),p.gray)
			H.surface(host,record.id,Vector3(0,.39,0),2.8)
		elif record.kind == "oerlikon":
			var host: Node3D = H.group(self,record.host_id,G.vector(record.position_m)-Vector3(0,.18,0))
			host.set_meta("host_id",record.host_id)
			G.prism(host,"GalleryGunFloor",G.ellipse(2.0,2.8,16),0,.18,p.gray)
			var side: float = -1 if host.position.x<0 else 1
			G.box(host,"ContinuousCatwalkLink",Vector3(4.2,.18,2.0),Vector3(-side*1.5,.09,0),p.gray)
			H.surface(host,record.id,Vector3(0,.18,0),.7)
	H.batch_static(self)
