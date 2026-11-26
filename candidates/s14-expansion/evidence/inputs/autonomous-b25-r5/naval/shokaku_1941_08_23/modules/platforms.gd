extends Node3D
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
var hosts: Dictionary = {}

func _ready() -> void:
	var p: Dictionary = H.palette()
	var assembly: Dictionary = H.read_data("assembly")
	for row: Dictionary in assembly.platforms:
		var host: Node3D = H.group(self,row.id,G.vector(row.center_m))
		host.set_meta("host_id",row.id)
		var w: float = float(row.size_xz_m[0])
		var length: float = float(row.size_xz_m[1])
		var outline: Array[Vector2] = G.beveled_rect(w,length)
		G.prism(host,"PhysicalSponsonDeck",outline,-float(row.thickness_m),0,p.gray)
		var side: float = signf(host.position.x)
		# Source-shaped plated sponson lower structure reaches the actual hull
		# side. A continuous tapered bracket web, not a generic rod or pedestal.
		var inside: float = float(row.hull_connection_x_m)-host.position.x
		var outer: float = side*(w*.46)
		var web: Array[PackedVector3Array] = []
		web.append(PackedVector3Array([Vector3(inside,-2.25,-length*.32),Vector3(inside,-2.25,length*.32),
			Vector3(inside+side*.28,-2.25,length*.32),Vector3(inside+side*.28,-2.25,-length*.32)]))
		web.append(PackedVector3Array([Vector3(inside,-float(row.thickness_m),-length*.40),Vector3(inside,-float(row.thickness_m),length*.40),
			Vector3(outer,-float(row.thickness_m),length*.40),Vector3(outer,-float(row.thickness_m),-length*.40)]))
		# Slab makes triangle winding independent of left/right mirroring.
		G.mesh_node(host,"HullSpecificPlatedSponson",H.loft(web,true,false),p.gray)
		var mount: Dictionary = {}
		for candidate: Dictionary in assembly.mounts:
			if candidate.id==row.station_id: mount=candidate; break
		var at: Vector3 = G.vector(mount.position_m)-host.position
		H.surface(host,row.station_id,at,float(mount.foundation_radius_m))
		hosts[row.id] = host
		# Keep host and marker inspectable after static batching.
		H.batch_static(host)
