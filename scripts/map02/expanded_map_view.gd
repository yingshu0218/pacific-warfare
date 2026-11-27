extends "res://scripts/presentation/maps/island_harbor_view.gd"
## Extend appearance in a private path. Original S09 renderer/shaders are unchanged.

const PORT_PAINT_ROADS: Array[String] = ["map02_port_link", "map02_naval_service"]
const QUAY_GEOMETRY: Script = preload("res://scripts/map02/quay_geometry.gd")
const SUPPORT_PROPS: Script = preload("res://scripts/map02/harbor_support_props.gd")

func build(data: Dictionary) -> void:
	super.build(data)
	if str(data.source.id) != "island_harbor_expanded": return
	var builder: RefCounted = QUAY_GEOMETRY.new()
	var refined: MeshInstance3D = builder.build(data,get_node("IslandTerrain"))
	if refined != null:
		add_child(refined)
		var stats: Dictionary = refined.get_meta("port_mesh_stats")
		statistics.nodes += 1
		statistics.mesh_instances += 1
		statistics.materials += 2
		statistics.static_triangles += int(stats.triangles)
		statistics["refined_quays"] = stats
	_build_port_road_paint()
	var props: Node3D = SUPPORT_PROPS.new()
	props.name = "HarborSupportProps"
	add_child(props)
	props.build(data)
	var triangles: int = 0
	for part: MeshInstance3D in props.get_children():
		var arrays: Array = part.mesh.surface_get_arrays(0)
		triangles += int(arrays[Mesh.ARRAY_INDEX].size() / 3)
	statistics.nodes += props.get_child_count()+1
	statistics.mesh_instances += props.get_child_count()
	# Each kind has one shared material across instances.
	statistics.materials += 8
	statistics.static_triangles += triangles
	statistics["support_props"] = props.get_child_count()

func _road(road: Dictionary) -> void:
	if str(terrain.source.id) == "island_harbor_expanded" and str(road.get("id","")) in PORT_PAINT_ROADS:
		return
	super._road(road)

func _build_port_road_paint() -> void:
	# A planar paint strip shouldn't self-shadow the adjacent dock. Keep the
	# original alignment while moving just these port links into a non-caster.
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var before: int = _triangles
	for road: Dictionary in terrain.source.roads:
		if str(road.get("id","")) in PORT_PAINT_ROADS: super._road(road)
	_surface.generate_normals()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://scripts/map02/quay_road_paint.gdshader")
	_add_mesh(_surface.commit(),material,"PortRoadPaint")
	(get_node("PortRoadPaint") as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	statistics.nodes += 1
	statistics.mesh_instances += 1
	statistics.materials += 1
	statistics.static_triangles += _triangles - before

func _object(obj: Dictionary) -> void:
	if str(terrain.source.id) == "island_harbor_expanded" and QUAY_GEOMETRY.handled(obj): return
	_surface.set_smooth_group(0xffffffff) # Hard industrial edges; terrain keeps its existing smooth normals.
	if not obj.has("map02_shape"):
		super._object(obj)
		return
	var p: Vector3=SimData.vec3(obj.position_m)
	var s: Vector3=SimData.vec3(obj.size_m)
	var color: Color=Color(obj.color)
	match str(obj.map02_shape):
		"cylinder":_round(p,s,color,false)
		"cone":_round(p,s,color,true)
		"gable":_gable(p,s,color,int(obj.get("map02_yaw_quarters",0))%2==1)
		"pyramid":
			var a: Vector3=p+Vector3(-s.x*.5,0,-s.z*.5)
			var b: Vector3=p+Vector3(s.x*.5,0,-s.z*.5)
			var c: Vector3=p+Vector3(s.x*.5,0,s.z*.5)
			var d: Vector3=p+Vector3(-s.x*.5,0,s.z*.5)
			var tip: Vector3=p+Vector3.UP*s.y
			_tri(a,tip,b,color);_tri(b,tip,c,color);_tri(c,tip,d,color);_tri(d,tip,a,color)
		_:_box(p+Vector3.UP*s.y*.5,s,color)

func _round(p: Vector3,s: Vector3,color: Color,cone: bool) -> void:
	for i: int in 24:
		var a: float=TAU*i/24.0;var b: float=TAU*(i+1)/24.0
		var va: Vector3=p+Vector3(cos(a)*s.x*.5,0,sin(a)*s.z*.5)
		var vb: Vector3=p+Vector3(cos(b)*s.x*.5,0,sin(b)*s.z*.5)
		if cone:_tri(va,p+Vector3.UP*s.y,vb,color)
		else:
			_quad(va,va+Vector3.UP*s.y,vb+Vector3.UP*s.y,vb,color)
			_tri(p+Vector3.UP*s.y,vb+Vector3.UP*s.y,va+Vector3.UP*s.y,color)
		_tri(p,va,vb,color)

func _gable(p: Vector3,s: Vector3,color: Color,along_x: bool) -> void:
	var a: Vector3=p+Vector3(-s.x*.5,0,-s.z*.5)
	var b: Vector3=p+Vector3(s.x*.5,0,-s.z*.5)
	var c: Vector3=p+Vector3(s.x*.5,0,s.z*.5)
	var d: Vector3=p+Vector3(-s.x*.5,0,s.z*.5)
	if along_x:
		var e: Vector3=p+Vector3(-s.x*.5,s.y,0)
		var f: Vector3=p+Vector3(s.x*.5,s.y,0)
		_quad(a,e,f,b,color);_quad(e,d,c,f,color);_tri(a,d,e,color);_tri(b,f,c,color)
	else:
		var e: Vector3=p+Vector3(0,s.y,-s.z*.5)
		var f: Vector3=p+Vector3(0,s.y,s.z*.5)
		_quad(a,d,f,e,color);_quad(e,f,c,b,color);_tri(a,e,b,color);_tri(d,c,f,color)

func _site(site: Dictionary) -> void:
	# A paint/compacted-earth surface on the actual terrain, without a raised fake support.
	var p: Vector3=SimData.vec3(site.position_m)
	var radius: float=float(site.radius_m)
	for i: int in 32:
		var a: float=TAU*i/32.0;var b: float=TAU*(i+1)/32.0
		_tri(p+Vector3.UP*.025,p+Vector3(cos(a)*radius,.025,sin(a)*radius),p+Vector3(cos(b)*radius,.025,sin(b)*radius),Color("9e9f85"))
	# Mark the seaward facing sector at the perimeter; no decorative weapon.
	var forward: Vector3=Basis(Vector3.UP,float(site.yaw_rad))*Vector3.FORWARD
	_box(p+forward*(radius*.8)+Vector3.UP*.035,Vector3(3,.025,3),Color("d5cda5"))
