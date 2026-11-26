extends Node3D
## Simplified triple Type96; private smoke shield variant for exhaust-side AA.
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
@export var smokeproof: bool = false
var train_axis: Node3D
var elevation_axes: Array[Node3D] = []
var muzzle_markers: Array[Marker3D] = []
var elevation_pivot_m: Vector3 = Vector3(0,.95,-.15)

func _ready() -> void:
	set_meta("interface_id","cv02_type96_25mm_triple")
	var p: Dictionary = H.palette()
	G.cylinder(self,"FixedPedestalFoot",.68,.16,Vector3(0,.08,0),p.steel,18)
	G.cylinder(self,"FixedPedestal",.30,.55,Vector3(0,.42,0),p.gray,16)
	train_axis=H.group(self,"TrainPivot")
	G.box(train_axis,"TripleYoke",Vector3(1.2,.45,.75),Vector3(0,.7,0),p.gray)
	if smokeproof:
		G.prism(train_axis,"SmokeShield",G.beveled_rect(2.3,2.25),.15,1.55,p.gray)
		var shield: MeshInstance3D = train_axis.get_child(train_axis.get_child_count()-1) as MeshInstance3D
		G.open_gun_slot(shield,AABB(Vector3(-.72,.75,-1.3),Vector3(1.44,1.2,1.8)))
	var axis: Node3D = H.group(train_axis,"ElevationPivot",elevation_pivot_m)
	elevation_axes.append(axis)
	for x: float in [-.24,0,.24]:
		G.box(axis,"Receiver",Vector3(.15,.23,.75),Vector3(x,0,.18),p.steel)
		G.box(axis,"BoxMagazine",Vector3(.10,.35,.21),Vector3(x,.26,.18),p.steel)
		G.rod(axis,"Barrel",Vector3(x,0,-.20),Vector3(x,0,-1.55),.039,p.steel,8)
		var marker: Marker3D = Marker3D.new()
		marker.name="Muzzle_%02d"%muzzle_markers.size(); marker.position=Vector3(x,0,-1.55)
		axis.add_child(marker); muzzle_markers.append(marker)
	H.batch_static(self,[train_axis]); H.batch_static(train_axis,elevation_axes); H.batch_static(axis)
