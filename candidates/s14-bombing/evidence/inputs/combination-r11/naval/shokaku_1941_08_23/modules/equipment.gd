extends Node3D
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

func _ready() -> void:
	set_meta("host_id","equipment")
	var p: Dictionary = H.palette()
	# Only large hull-attached boats / folding radio masts needed for identity.
	for side: float in [-1,1]:
		for z: float in [-12,45]:
			var boat: Node3D = H.group(self,"GalleryBoat",Vector3(side*12.15,8.96,z))
			var mesh: Array[PackedVector3Array] = []
			for ring: Array in [[0.0,0.0],[1.1,.7],[1.8,1.0]]:
				var r: PackedVector3Array = []
				for q: Vector2 in G.ellipse(1.65*float(ring[1])+.05,8.0,18): r.append(Vector3(q.x,float(ring[0])*.35,q.y))
				mesh.append(r)
			G.mesh_node(boat,"BoatHull",H.loft(mesh,true),p.steel)
			G.box(boat,"BoatCover",Vector3(1.55,.16,4.5),Vector3(0,.63,.45),p.gray)
	var aft: Node3D = H.group(self,"AftBoatDeck",Vector3(0,5.8,118.0))
	for x: float in [-2.0,2.0]:
		G.prism(aft,"AftShipBoat",G.ellipse(1.65,7.6,18),0,.65,p.steel)
		var boat: Node3D = aft.get_child(aft.get_child_count()-1) as Node3D; boat.position.x=x
	for item: Array in [[-15.1,36.0],[-15.1,61.5],[14.2,88.0]]:
		var mast: Node3D = H.group(self,"FoldingRadioMast",Vector3(item[0],14.15,item[1]))
		G.rod(mast,"RadioPole",Vector3.ZERO,Vector3(0,8.5,0),.085,p.gray,8)
		G.rod(mast,"RadioCrossarm",Vector3(-1.3,6.6,0),Vector3(1.3,6.6,0),.055,p.gray,8)
	H.batch_static(self)
