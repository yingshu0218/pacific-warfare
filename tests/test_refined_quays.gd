extends SceneTree

const QUAY: Script = preload("res://scripts/map02/quay_geometry.gd")
const EPS: float = 0.001
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: FirstPlayableGame = (load("res://showcase/carrier_harbor.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_process(false)
	if not game.running or game.map_view == null: quit(2); return
	var view: IslandHarborView = game.map_view
	var quay: MeshInstance3D = view.get_node_or_null("RefinedQuays")
	var land: MeshInstance3D = view.get_node_or_null("IslandTerrain")
	var road: MeshInstance3D = view.get_node_or_null("PortRoadPaint")
	if quay == null or road == null or land == null: quit(3); return
	assert(quay.mesh.get_surface_count() == 1)
	var parameter: ShaderMaterial = land.material_override
	var meta: Dictionary = quay.get_meta("port_mesh_stats")
	var rects: Array[Dictionary] = []
	var xs: Array[float] = []
	var zs: Array[float] = []
	for object: Dictionary in view.terrain.source.objects:
		if not QUAY.handled(object): continue
		var p: Vector3 = SimData.vec3(object.position_m)
		var s: Vector3 = SimData.vec3(object.size_m)
		var r: Rect2 = Rect2(Vector2(p.x,p.z)-Vector2(s.x,s.z)*.5,Vector2(s.x,s.z))
		rects.append({"rect":r,"top":p.y+s.y})
		for x: float in [r.position.x,r.end.x]:
			if not xs.has(x): xs.append(x)
		for z: float in [r.position.y,r.end.y]:
			if not zs.has(z): zs.append(z)
	xs.sort()
	zs.sort()
	var actual: Array = quay.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = actual[Mesh.ARRAY_VERTEX]
	var ids: PackedInt32Array = actual[Mesh.ARRAY_INDEX]
	var uv: PackedVector2Array = actual[Mesh.ARRAY_TEX_UV]
	var sum_area: float = 0.0
	var top_triangles: Array[Dictionary] = []
	for i: int in range(0,ids.size(),3):
		if uv[ids[i]].x < .5: continue
		var a: Vector3 = points[ids[i]]
		var b: Vector3 = points[ids[i+1]]
		var c: Vector3 = points[ids[i+2]]
		_check(absf(a.y-b.y) < EPS and absf(a.y-c.y) < EPS,"level top")
		_check((c-a).cross(b-a).y > EPS, "deck normals")
		sum_area += absf((b-a).cross(c-a).y)*.5
		top_triangles.append({"a":Vector2(a.x,a.z),"b":Vector2(b.x,b.z),"c":Vector2(c.x,c.z),"y":a.y})
	var coverage: float = 0.0
	for i: int in range(xs.size()-1):
		for j: int in range(zs.size()-1):
			var probe: Vector2 = Vector2(lerpf(xs[i],xs[i+1],.413),lerpf(zs[j],zs[j+1],.373))
			var levels: Array[float] = []
			for item: Dictionary in rects:
				if (item.rect as Rect2).has_point(probe) and not levels.has(item.top): levels.append(item.top)
			if levels.is_empty(): continue
			coverage += (xs[i+1]-xs[i])*(zs[j+1]-zs[j])
			for y: float in levels:
				var found: int = 0
				for t: Dictionary in top_triangles:
					if absf(float(t.y)-y)<EPS and Geometry2D.point_is_inside_triangle(probe,t.a,t.b,t.c): found += 1
				_check(found==1,"single covering face at %s / %s" % [probe,y])
	_check(absf(sum_area-coverage)<1.0,"union area has no overlap or missing panel")
	_check(absf(sum_area-float(meta.covered_area_m2))<1.0,"mesh area agrees with stats")
	_check(ids.size()/3 == meta.triangles and meta.triangles<=16000,"triangle budget")
	_check(meta.details>25 and meta.footprints==10,"both bays and detail counts")
	_check(parameter.get_shader_parameter("deck_count")==10,"port-only trim")
	_check(land.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and road.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"near coplanar surfaces don't cast")
	_check(view.terrain.solids.size()==245 and view.terrain.source.deployment_sites.size()==7,"unchanged solid and deployment counts")
	print("PORT04 checks=",checks," failures=",failures," details=",meta.details," triangles=",meta.triangles," coverage=",coverage)
	game.free()
	quit(1 if failures else 0)

func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PORT04 "+msg)
