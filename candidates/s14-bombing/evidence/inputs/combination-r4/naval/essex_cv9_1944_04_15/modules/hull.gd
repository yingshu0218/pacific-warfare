extends Node3D
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
var camouflage: ShaderMaterial

func _ready() -> void:
	set_meta("host_id","hull")
	camouflage = ShaderMaterial.new()
	camouflage.shader = preload("res://naval/essex_cv9_1944_04_15/measure32.gdshader")
	var stations: Array = H.hull_stations()
	var rings: Array[PackedVector3Array] = []
	for s: Array in stations:
		var w: float = float(s[1])
		var z: float = float(s[0])
		var depth: float = 8.6868 * clampf((133.0-absf(z))/18.0,0.02,1.0)
		var r: PackedVector3Array = []
		for p: Vector2 in [Vector2(0,-depth),Vector2(w*.57,-depth*.94),Vector2(w*.87,-depth*.65),Vector2(w,-depth*.22),Vector2(w,0),Vector2(w*1.035,4.5),Vector2(w*1.035,float(s[2])),Vector2(-w*1.035,float(s[2])),Vector2(-w*1.035,4.5),Vector2(-w,0),Vector2(-w,-depth*.22),Vector2(-w*.87,-depth*.65),Vector2(-w*.57,-depth*.94)]:
			var waterline_rake: float = clampf((absf(z)-110.0)/22.8928,0.0,1.0)*7.9248
			var end_shift: float = waterline_rake*clampf((float(s[2])-p.y)/float(s[2]),0.0,1.0)
			r.append(Vector3(p.x,p.y,z-signf(z)*end_shift))
		rings.append(r)
	var outward_rings: Array[PackedVector3Array] = []
	for ring: PackedVector3Array in rings:
		var reversed: PackedVector3Array = ring.duplicate(); reversed.reverse(); outward_rings.append(reversed)
	var body: ArrayMesh = G.loft(outward_rings,false)
	# Close the raked ends in matched height bands. A non-planar cap fan
	# would falsely extend the nominal waterline beyond its 820ft endpoints.
	var ends: SurfaceTool = SurfaceTool.new(); ends.begin(Mesh.PRIMITIVE_TRIANGLES)
	for end_index: int in [0,rings.size()-1]:
		var ring: PackedVector3Array = rings[end_index]
		var normal: Vector3 = Vector3.FORWARD if end_index==0 else Vector3.BACK
		for level: int in range(1,7):
			var rp: int = level-1
			var lp: int = 0 if level==1 else 13-rp
			H.triangle(ends,ring[rp],ring[lp],ring[13-level],normal)
			H.triangle(ends,ring[rp],ring[13-level],ring[level],normal)
	ends.generate_normals()
	var whole: SurfaceTool = SurfaceTool.new(); whole.begin(Mesh.PRIMITIVE_TRIANGLES)
	whole.append_from(body,0,Transform3D.IDENTITY); whole.append_from(ends.commit(),0,Transform3D.IDENTITY)
	G.mesh_node(self,"ContinuousHull",whole.commit(),camouflage)
	# Visible forecastle/fantail; flight deck is a separate surface above.
	for id: String in ["bow_bofors","stern_bofors"]:
		var forward: bool = id == "bow_bofors"
		var y: float = 10.2 if forward else 9.1
		var z: float = -124 if forward else 124
		var host: Node3D = H.group(self,id,Vector3(0,y-.28,z))
		var points: Array[Vector2] = G.ellipse(10.4,13.8,28)
		G.prism(host,"DeckPlatform",points,0,.28,H.palette().gray)
		host.set_meta("host_id",id)
		H.surface(host,"aa40_bow" if forward else "aa40_stern",Vector3(0 if forward else -3,.28,0),2.6)
	H.batch_static(self)
