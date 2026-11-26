extends Node3D
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

func _ready() -> void:
	set_meta("host_id","funnels")
	var p: Dictionary = H.palette()
	for item: Array in [["ForwardFunnel",-18.5,9.6],["AftFunnel",-5.5,8.1]]:
		var funnel: Node3D = H.group(self,item[0],Vector3(11.4,11.85,float(item[1])))
		var half_long: float = float(item[2])*.5
		# Flattened curved ducts first rise, turn outboard and then down. Their
		# actual connection is the side of the hangar, not an island chimney.
		var rings: Array[PackedVector3Array] = []
		for step: Array in [[0.0,0.0,1.0],[1.2,0.6,1.0],[3.3,.62,1.0],[5.3,-.18,.96],[7.25,-1.6,.92]]:
			var ring: PackedVector3Array = []
			for j: int in range(24):
				var angle: float = TAU*float(j)/24
				ring.append(Vector3(float(step[0]),float(step[1])+cos(angle)*1.15*float(step[2]),sin(angle)*half_long))
			rings.append(ring)
		G.mesh_node(funnel,"DownturnedExhaustDuct",H.loft(rings,false),p.gray)
		# Black exhaust opening is a separate recessed cap, not a solid grey end.
		# Mouth follows the final YZ ellipse, separate from the grey duct.
		var st: SurfaceTool = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j: int in range(24):
			var a: Vector3 = rings.back()[j]
			var b: Vector3 = rings.back()[(j+1)%24]
			H.triangle(st,Vector3(7.26,-1.6,0),Vector3(7.26,a.y,a.z),Vector3(7.26,b.y,b.z),Vector3.RIGHT)
		st.generate_normals(); G.mesh_node(funnel,"ExhaustMouth",st.commit(),p.dark)
		H.batch_static(funnel)
