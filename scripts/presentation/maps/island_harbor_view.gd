class_name IslandHarborView
extends Node3D

## Static appearance from the exact frozen chart consumed by simulation.
var terrain: Dictionary = {}
var statistics: Dictionary = {}
var _surface: SurfaceTool
var _triangles: int = 0
var shore_material: ShaderMaterial

func presentation_viewpoints() -> Array:
	return terrain.get("source",{}).get("viewpoints",[]).duplicate()


func build(data: Dictionary) -> void:
	terrain = data
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.roughness = 0.93
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_surface = SurfaceTool.new(); _surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for island: Dictionary in data.islands:
		var vertices: Array = island.vertices
		for index: int in island.indices:
			var p: Vector3 = vertices[index]
			_surface.set_color(_ground_color(p).srgb_to_linear())
			_surface.add_vertex(p)
		_triangles += island.indices.size()/3
	_surface.index(); _surface.generate_normals()
	_add_mesh(_surface.commit(),material,"IslandTerrain")
	# Kilometre-scale terrain in short-range ship shadow cascades causes acne.
	# Its shape is lit by shared smooth normals; small objects retain shadows.
	(get_child(get_child_count()-1) as MeshInstance3D).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface = SurfaceTool.new(); _surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for obj: Dictionary in data.source.objects: _object(obj)
	for road: Dictionary in data.source.roads: _road(road)
	for site: Dictionary in data.source.deployment_sites: _site(site)
	_surface.generate_normals()
	_add_mesh(_surface.commit(),material,"TownPortAndSites")
	_build_shore()
	_build_vegetation(material)
	statistics = {"nodes":get_child_count()+1,"mesh_instances":get_child_count(),"static_triangles":_triangles,"materials":3,"terrain_triangles":data.triangles.size(),"colliders":data.solids.size(),"deployment_sites":data.source.deployment_sites.size()}

func advance(time_s: float) -> void:
	if shore_material != null: shore_material.set_shader_parameter("simulation_time",time_s)

func _ground_color(p: Vector3) -> Color:
	var green: Color = Color("65765a")
	var rock: Color = Color("8c9186")
	var sand: Color = Color("c4c3a3")
	var h: float = TerrainQueries.height_data(terrain,p+Vector3(15,0,0))-TerrainQueries.height_data(terrain,p-Vector3(15,0,0))
	var variation: float = sin(p.x*.0031+sin(p.z*.0024))*0.035
	var color: Color = green.lerp(rock,clampf((p.y-240.0)/450.0+absf(h)*.015,0.0,.8))
	color = color.lerp(sand,1.0-smoothstep(2.0,14.0,p.y))
	return color.lightened(variation) if variation>0 else color.darkened(-variation)

func _object(obj: Dictionary) -> void:
	var p: Vector3 = SimData.vec3(obj.position_m)
	var s: Vector3 = SimData.vec3(obj.size_m)
	var color: Color = Color(obj.color)
	if obj.kind == "crane":
		for sign_value: float in [-1.0,1.0]: _box(p+Vector3(sign_value*6,s.y*.5,0),Vector3(2,s.y,2),color)
		_box(p+Vector3(8,s.y,0),Vector3(32,3,4),color)
		_box(p+Vector3(21,s.y-6,0),Vector3(.5,12,.5),color.darkened(.2))
		return
	if obj.has("foundation_bottom_m"):
		var bottom: float=float(obj.foundation_bottom_m)
		_box(Vector3(p.x,(p.y+bottom)*.5,p.z),Vector3(s.x,p.y-bottom,s.z),Color("7c8074"))
	_box(p+Vector3.UP*s.y*.5,s,color)
	if obj.kind in ["house","warehouse"]:
		var roof: Color = Color("805d4d") if obj.kind == "house" else Color("667c7e")
		var a: Vector3 = p+Vector3(-s.x*.55,s.y,-s.z*.55)
		var b: Vector3 = p+Vector3(s.x*.55,s.y,-s.z*.55)
		var c: Vector3 = p+Vector3(0,s.y+3,-s.z*.55)
		var d: Vector3 = a+Vector3(0,0,s.z*1.1)
		var e: Vector3 = b+Vector3(0,0,s.z*1.1)
		var f: Vector3 = c+Vector3(0,0,s.z*1.1)
		_quad(a,d,f,c,roof); _quad(c,f,e,b,roof); _tri(a,c,b,roof); _tri(d,e,f,roof)
		# A few deep window bands preserve scale at normal low-altitude observation.
		_box(p+Vector3(0,s.y*.55,-s.z*.501),Vector3(s.x*.62,1.6,.15),Color("455b60"))
	elif obj.kind == "lighthouse":
		_box(p+Vector3.UP*(s.y-3),Vector3(s.x*1.25,2,s.z*1.25),Color("7d4c42"))

func _site(site: Dictionary) -> void:
	var center: Vector3 = SimData.vec3(site.position_m)
	var radius: float = float(site.radius_m)
	var color: Color = Color("9e9d84")
	for i: int in 24:
		var a: float = TAU*i/24.0; var b: float = TAU*(i+1)/24.0
		_tri(center+Vector3.UP*.12,center+Vector3(cos(a)*radius,.12,sin(a)*radius),center+Vector3(cos(b)*radius,.12,sin(b)*radius),color)
		if i%3==0: _box(center+Vector3(cos(a)*radius,.7,sin(a)*radius),Vector3(3,1.2,2),Color("aa9e80"))
	# Empty emplacement only: no fake gun, no active-unit marker.
	var front: Vector3 = Basis(Vector3.UP,float(site.yaw_rad))*Vector3.FORWARD
	_box(center+front*(radius*.5)+Vector3.UP*.15,Vector3(2,.15,2),Color("d2cbaa"))

func _road(road: Dictionary) -> void:
	for i: int in range(road.points_m.size()-1):
		var a: Vector3 = SimData.vec3(road.points_m[i]); var b: Vector3 = SimData.vec3(road.points_m[i+1])
		var side: Vector3 = (b-a).cross(Vector3.UP).normalized()*float(road.width_m)*.5
		var steps: int = maxi(1,ceili(a.distance_to(b)/20.0))
		for step: int in steps:
			var p: Vector3=a.lerp(b,float(step)/steps);var q: Vector3=a.lerp(b,float(step+1)/steps)
			var points: Array[Vector3]=[p-side,p+side,q+side,q-side]
			for k: int in points.size():points[k].y=TerrainQueries.height_data(terrain,points[k])+.18
			_quad(points[0],points[1],points[2],points[3],Color("8a8773"))

func _box(center: Vector3, size_value: Vector3, color: Color) -> void:
	var h: Vector3 = size_value*.5
	var v: Array[Vector3] = []
	for signs: Vector3 in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]: v.append(center+signs*h)
	for face: Array in [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]]: _quad(v[face[0]],v[face[1]],v[face[2]],v[face[3]],color)

func _tri(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	_surface.set_color(color.srgb_to_linear()); _surface.add_vertex(a); _surface.add_vertex(b); _surface.add_vertex(c); _triangles+=1
func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	_tri(a,b,c,color); _tri(a,c,d,color)

func _add_mesh(mesh_value: Mesh,material: Material,label_value: String) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new(); instance.name=label_value; instance.mesh=mesh_value; instance.material_override=material
	add_child(instance)

func _build_shore() -> void:
	_surface=SurfaceTool.new(); _surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for island: Dictionary in terrain.islands:
		var points: Array = island.outline
		for i: int in points.size():
			var p: Vector3 = points[i]; var q: Vector3 = points[(i+1)%points.size()]
			var tangent: Vector3 = (q-p).normalized()
			var out: Vector3 = Vector3(tangent.z,0,-tangent.x)
			# Check polygon winding; point on the outward side must remain water.
			if TerrainQueries.land_data(terrain,(p+q)*.5+out*8): out=-out
			var inner: Color = Color(.78,.85,.77,0.85); var outer: Color = Color(.22,.55,.55,0.0)
			for triple: Array in [[p+Vector3.UP*.025,q+Vector3.UP*.025,q+out*65+Vector3.UP*.025],[p+Vector3.UP*.025,q+out*65+Vector3.UP*.025,p+out*65+Vector3.UP*.025]]:
				for v: Vector3 in triple:
					_surface.set_color(inner if v.distance_to(p)<2 or v.distance_to(q)<2 else outer); _surface.add_vertex(v)
				_triangles+=1
	_surface.generate_normals()
	shore_material=ShaderMaterial.new(); shore_material.shader=preload("res://scripts/presentation/maps/shore.gdshader")
	_add_mesh(_surface.commit(),shore_material,"ShallowsAndFoam")
	(get_child(get_child_count()-1) as MeshInstance3D).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_vegetation(material: Material) -> void:
	_surface=SurfaceTool.new(); _surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Deterministic appearance-only lattice jitter. It never consumes world.rng.
	for x: int in range(-7500,8000,125):
		for z: int in range(-7000,7000,125):
			var p: Vector3=Vector3(x+sin(x*.07+z*.025)*44,0,z+cos(z*.06+x*.015)*43)
			p.y=TerrainQueries.height_data(terrain,p)
			if p.y<35 or p.y>400 or sin(x*.012+z*.004)<-.35: continue
			var occupied: bool=false
			for pad: Dictionary in terrain.source.pads:
				if Vector2(p.x-float(pad.position_m[0]),p.z-float(pad.position_m[2])).length()<float(pad.radius_m)+float(pad.blend_m): occupied=true;break
			if occupied: continue
			var height: float=9.0+5.0*absf(sin(x*.03+z))
			for i: int in 5:
				var a: float=TAU*i/5.0; var b: float=TAU*(i+1)/5.0
				_tri(p+Vector3(cos(a)*7,2,sin(a)*7),p+Vector3(0,height,0),p+Vector3(cos(b)*7,2,sin(b)*7),Color("455f4c"))
	_surface.generate_normals(); _add_mesh(_surface.commit(),material,"SparseTreeClusters")
