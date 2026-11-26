extends SceneTree
## Independent mesh/contract/assembly checks. Run only through tools/verify.py.
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const MODEL: PackedScene = preload("res://naval/essex_cv9_1944_04_15/essex.tscn")
const FIXTURE: Script = preload("res://naval/essex_cv9_1944_04_15/inspection/deck_fixtures.gd")
var failures: PackedStringArray = []
var checks: int = 0
var report: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _run() -> void:
	var a: Node3D = MODEL.instantiate() as Node3D
	var b: Node3D = MODEL.instantiate() as Node3D
	root.add_child(a); root.add_child(b)
	await process_frame
	b.position.x = 700
	var config: Dictionary = H.read_data("assembly")
	var sockets: Array[Dictionary] = a.call("mount_sockets")
	require(a.scale.is_equal_approx(Vector3.ONE),"Metre scale is 1")
	require(sockets.size()==25,"Complete 8 DP + 5 quad AA + 12 single AA mounts")
	var twins: int = 0
	var singles: int = 0
	var actual_barrels: int = 0
	var contact_rows: Array = []
	var static_meshes: Array[MeshInstance3D] = []
	H.collect_meshes(a,static_meshes,[a.get_node("MountFoundations")])
	for row: Dictionary in config.mounts:
		var record: Dictionary = a.mount_visuals[row.id]
		var socket: Dictionary = record.socket
		var surface: Marker3D = record.surface
		var weapon: Node3D = record.weapon
		var local: Vector3 = a.to_local(surface.global_position)
		require(local.distance_to(G.vector(row.position_m))<.0001,"Real host surface matches "+row.id)
		require(str(surface.get_parent().get_meta("host_id",""))==row.host_id,"Named physical host "+row.id)
		require(record.muzzles.size()==int(row.barrel_count),"Actual barrel count "+row.id)
		var seat: Vector3 = a.to_local((record.seat as Marker3D).global_position)
		require(absf(seat.y-local.y-float(row.foundation_height_m))<.0001,"No doubled/floating foundation "+row.id)
		var hit: Dictionary = _vertical_hit(static_meshes,Vector2(local.x,local.z),local.y+.03,local.y-.05)
		require(not hit.is_empty() and absf(float(hit.get("y",-999))-local.y)<.003,"Physical mesh bears "+row.id)
		contact_rows.append({"id":row.id,"host":row.host_id,"surface_m":_v(local),"actual_mesh_y":hit.get("y",null),"muzzles":record.muzzles.size()})
		if row.role=="main_dual_purpose":
			actual_barrels += record.muzzles.size()
			if row.kind=="mk32": twins += 1
			if row.kind=="mk24": singles += 1
		var frozen: Transform3D = b.call("muzzle_transform_local",row.id,0)
		require(bool(a.call("apply_weapon_state",row.id,{"train_rad":-.31,"elevation_rad":.6})),"Weapon state accepted "+row.id)
		require((b.call("muzzle_transform_local",row.id,0) as Transform3D).is_equal_approx(frozen),"No cross-instance motion "+row.id)
		var axis: Node3D = record.axes[0]
		var expected: Transform3D = a.global_transform.affine_inverse()*(record.muzzles[0] as Marker3D).global_transform
		require((a.call("muzzle_transform_local",row.id,0) as Transform3D).is_equal_approx(expected),"Actual pivot composition "+row.id)
		var before: Vector3 = axis.rotation
		require(not bool(a.call("apply_weapon_state",row.id,{"train_rad":NAN,"elevation_rad":.5})),"NaN rejected "+row.id)
		require(axis.rotation==before,"Invalid state atomic "+row.id)
		a.call("apply_weapon_state",row.id,{"train_rad":0.0,"elevation_rad":0.0})
	require(twins==4 and singles==4 and actual_barrels==12,"Fixed 4x2 Mk32 + 4x1 Mk24 5in/38")
	var independent: Transform3D = a.call("muzzle_transform_local","dp_53",0)
	a.call("apply_weapon_state","dp_51",{"train_rad":-.4,"elevation_rad":.9,"gun_elevations_rad":[.2,.7]})
	require((a.call("muzzle_transform_local","dp_53",0) as Transform3D).is_equal_approx(independent),"Same-ship neighboring mount independent")
	require(not (a.call("muzzle_transform_local","dp_51",0) as Transform3D).basis.is_equal_approx((a.call("muzzle_transform_local","dp_51",1) as Transform3D).basis),"Twin barrels independently elevated")
	a.call("apply_weapon_state","dp_51",{"train_rad":0.0,"elevation_rad":0.0})
	require(not a.call("apply_weapon_state","bad_id",{}),"Unknown weapon rejected")
	var hull_mesh: MeshInstance3D = a.get_node("Hull/ContinuousHull") as MeshInstance3D
	var waterline: Vector2 = Vector2(INF,-INF)
	var faces: PackedVector3Array = hull_mesh.mesh.get_faces()
	for i: int in range(0,faces.size(),3):
		for edge: int in range(3):
			var p: Vector3 = faces[i+edge]
			var q: Vector3 = faces[i+(edge+1)%3]
			if absf(p.y)<.0001:
				waterline.x = minf(waterline.x,p.z); waterline.y = maxf(waterline.y,p.z)
			if p.y*q.y<0:
				var z: float = p.lerp(q,-p.y/(q.y-p.y)).z
				waterline.x = minf(waterline.x,z); waterline.y = maxf(waterline.y,z)
	require(absf(waterline.y-waterline.x-249.936)<.12,"Actual 820ft waterline; not the overall length")
	require(absf(hull_mesh.mesh.get_aabb().size.z-265.7856)<.01,"Actual 872ft hull overall length")
	var arrays: Array = hull_mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tested_normals: int = 0
	for i: int in range(vertices.size()):
		if absf(vertices[i].z)<80 and absf(vertices[i].x)>12 and absf(vertices[i].y)<2 and absf(normals[i].y)<.8:
			require(normals[i].x*vertices[i].x>0,"Hull normals face out, not through opposite shell")
			tested_normals += 1
	require(tested_normals>4,"Both broadside normals inspected")
	var actual_ship_bounds: AABB = _bounds_in(a,a)
	require(actual_ship_bounds.size.x<=45.0,"Entire normal-pose ship including projections within 147ft6in envelope")
	var director_meshes: Array[MeshInstance3D] = []
	H.collect_meshes(a.get_node("Island"),director_meshes,[])
	for at: Vector3 in [Vector3(16.3,27,-31),Vector3(16.3,27.5,5.6)]:
		var hit: Dictionary = _vertical_hit(director_meshes,Vector2(at.x,at.z),at.y+.02,at.y-.04)
		require(not hit.is_empty() and absf(float(hit.get("y",-99))-at.y)<.003,"Mk37 actual island/tower support "+str(at))
	var common_floor_hits: int = _horizontal_surface_hits(static_meshes,Vector2(3.117,12.531),7.926)
	require(common_floor_hits==1,"One shared hull/hangar floor, no duplicate coplanar top")
	var deck: Dictionary = a.call("deck_definition")
	deck.flight_deck.height_m = -90
	require(float(a.call("deck_definition").flight_deck.height_m)>0,"Deck getter defensive copy")
	deck = a.call("deck_definition")
	var deck_meshes: Array[MeshInstance3D] = []
	H.collect_meshes(a.get_node("FlightDeck"),deck_meshes,[])
	var elevator_rows: Array = []
	for lift: Dictionary in deck.elevators:
		var center: Vector2 = Vector2(lift.center_xz_m[0],lift.center_xz_m[1])
		var original_b: float = b.call("deck_surface_at",center).height_m
		a.call("apply_equipment_state",lift.id,{"height_m":lift.lower_height_m})
		# Explicit overlapping port cutout point, not only the outboard elevator center.
		var samples: Array[Vector2] = [center]
		if lift.opening=="deck_edge": samples.append(Vector2(-17,-20))
		for sample: Vector2 in samples:
			var query: Dictionary = a.call("deck_surface_at",sample)
			require(bool(query.supported) and query.surface_id==lift.id and absf(float(query.height_m)-float(lift.lower_height_m))<.0001,"Current lift surface "+lift.id)
			var hit: Dictionary = _vertical_hit(deck_meshes,sample,20,0)
			require(not hit.is_empty() and absf(float(hit.y)-float(query.height_m))<.002,"Actual open deck/lift agreement "+lift.id+str(sample))
			# All ship meshes catch a hidden gallery ceiling through an elevator well.
			var whole_hit: Dictionary = _vertical_hit(static_meshes,sample,20,0)
			require(whole_hit.is_empty() or float(whole_hit.y)<=float(lift.lower_height_m)+.002,"No fixed gallery surface through lift "+lift.id)
			elevator_rows.append({"id":lift.id,"sample_xz_m":[sample.x,sample.y],"query":query,"visible_mesh_y":hit.get("y",null)})
		require(absf(float(b.call("deck_surface_at",center).height_m)-original_b)<.0001,"Independent lift instance "+lift.id)
		require(not a.call("apply_equipment_state",lift.id,{"height_m":NAN}),"Lift NaN rejected")
		a.call("apply_equipment_state",lift.id,{"height_m":1e6})
		require(absf(float(a.call("deck_surface_at",center).height_m)-float(lift.upper_height_m))<.0001,"Lift high clamp")
		a.call("apply_equipment_state",lift.id,{"height_m":lift.upper_height_m})
	require(not a.call("deck_surface_at",Vector2(14,-115)).supported,"Point inside AABB but outside bow taper rejected")
	require(not a.call("deck_surface_at",Vector2(100,0)).supported,"Outside deck unsupported")
	require(not a.call("deck_surface_at",Vector2(NAN,0)).supported,"Invalid point rejected")
	var checked_surface_points: int = 0
	for x: float in [-18,-12,-3,6,12]:
		for z: float in [-125,-110,-89,-60,-20,0,45,70,100,125]:
			var query: Dictionary = a.call("deck_surface_at",Vector2(x,z))
			if not query.supported: continue
			var hit: Dictionary = _vertical_hit(deck_meshes,Vector2(x,z),20,0)
			require(not hit.is_empty() and absf(float(hit.y)-float(query.height_m))<.002,"Flight-deck sampled mesh agreement "+str(Vector2(x,z)))
			checked_surface_points += 1
	var fixture: Node3D = FIXTURE.new() as Node3D
	a.add_child(fixture)
	await process_frame
	var plane_rows: Array = []
	for aircraft: Node3D in fixture.aircraft:
		var bounds: AABB = _bounds_in(aircraft,a)
		var size: Vector3 = bounds.size
		var expected_span: float = float(aircraft.spec.span_m)
		require(absf(size.x-expected_span)<.18,"Actual aircraft span, no resizing "+str(aircraft.name))
		require(aircraft.scale.is_equal_approx(Vector3.ONE),"Aircraft 1:1 scale")
		require(bounds.position.y>=float(deck.flight_deck.height_m)-.015,"No visible aircraft mesh under deck "+str(aircraft.name))
		var envelope: PackedVector2Array = H.rect(Vector2(bounds.get_center().x,bounds.get_center().z),Vector2(size.x,size.z))
		for point: Vector2 in envelope:
			var query: Dictionary = a.call("deck_surface_at",point)
			require(query.supported and absf(float(query.get("height_m",-99))-float(deck.flight_deck.height_m))<.01,"Whole static aircraft envelope on deck "+str(aircraft.name))
		for obstacle: Dictionary in deck.obstacles:
			require(Geometry2D.intersect_polygons(envelope,H.polygon(obstacle.polygon_xz_m)).is_empty(),"Aircraft clears obstacle "+obstacle.id)
		var contacts: Array = _wheel_contacts(aircraft,a)
		require(contacts.size()==3,"Three real tyre contacts "+str(aircraft.name))
		for contact: Dictionary in contacts:
			require(absf(contact.error_m)<.002,"Tyres on actual top "+str(aircraft.name))
		plane_rows.append({"aircraft":aircraft.spec.id,"size_m":_v(size),"min_m":_v(bounds.position),"contacts":contacts})
	# Full-span SB2C is wider than inboard elevators: do not certify folded capacity.
	require(15.164>float(deck.elevators[0].size_xz_m[0]),"Unfolded SB2C rejected for full-envelope inboard lift fit")
	var local_muzzle: Transform3D = a.call("muzzle_transform_local","dp_51",0)
	a.call("apply_state",{"position_m":Vector3(30,3,-12),"rotation_rad":Vector3(.08,.41,-.05),"active":true})
	require((a.call("muzzle_transform_global","dp_51",0) as Transform3D).is_equal_approx(a.global_transform*local_muzzle),"All axes follow ship roll/yaw/pitch")
	for name: String in ["hull","hangar","flight_deck","island","platforms","equipment"]:
		var instance: Node3D = (load(H.BASE+"modules/"+name+".tscn") as PackedScene).instantiate() as Node3D
		root.add_child(instance)
		require(not instance.is_processing(),"Standalone module has no clock "+name)
		instance.free()
	report = {"passed":failures.is_empty(),"checks":checks,"actual_waterline_z_m":[waterline.x,waterline.y],"shared_hangar_floor_hits":common_floor_hits,"actual_ship_bounds_m":{"min":_v(actual_ship_bounds.position),"size":_v(actual_ship_bounds.size)},"failures":failures,"mount_contacts":contact_rows,"elevator_mesh_queries":elevator_rows,"fixed_deck_samples":checked_surface_points,"static_aircraft":plane_rows,"deck_height_m":deck.flight_deck.height_m,"elevator_lower_height_m":deck.elevators[0].lower_height_m,"scope":"Geometry and pure-state adaptation, not aviation operations or historical acceptance"}
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/CV01/mechanism.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	a.free(); b.free()
	if failures.is_empty(): print("PASS CV01 ",checks," independent checks")
	else:
		for failure: String in failures: push_error("CV01: "+failure)
	quit(0 if failures.is_empty() else 1)

func _vertical_hit(meshes: Array[MeshInstance3D], point: Vector2, start_y: float, end_y: float) -> Dictionary:
	var best: float = -INF
	var origin: Vector3 = Vector3(point.x,start_y,point.y)
	for node: MeshInstance3D in meshes:
		if not is_instance_valid(node): continue
		var bounds: AABB = node.global_transform*node.mesh.get_aabb()
		if point.x<bounds.position.x-.001 or point.x>bounds.end.x+.001 or point.y<bounds.position.z-.001 or point.y>bounds.end.z+.001 or bounds.position.y>start_y+.001 or bounds.end.y<end_y-.001: continue
		var faces: PackedVector3Array = node.mesh.get_faces()
		var inverse: Transform3D = node.global_transform.affine_inverse()
		var local: Vector3 = inverse*origin
		var direction: Vector3 = inverse.basis*Vector3.DOWN
		for i: int in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(local,direction,faces[i],faces[i+1],faces[i+2])
			if hit is Vector3:
				var y: float = (node.global_transform*(hit as Vector3)).y
				if y<=start_y+.0001 and y>=end_y-.0001 and y>best: best = y
	return {} if best == -INF else {"y":best}

func _bounds_in(node: Node3D, space: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	H.collect_meshes(node,meshes,[])
	var result: AABB
	var first: bool = true
	for mesh: MeshInstance3D in meshes:
		var transform: Transform3D = space.global_transform.affine_inverse()*mesh.global_transform
		for surface_index: int in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3 = transform*vertex
				result = AABB(point,Vector3.ZERO) if first else result.expand(point)
				first = false
	return result

func _wheel_contacts(aircraft: Node3D, ship: Node3D) -> Array:
	var result: Array = []
	for node: Node in _nodes(aircraft):
		if not node is MeshInstance3D or not str(node.name) in ["Tyre","Tail tyre"]: continue
		var mesh: MeshInstance3D = node as MeshInstance3D
		if not mesh.mesh is CylinderMesh: continue
		var radius: float = (mesh.mesh as CylinderMesh).top_radius
		var center: Vector3 = ship.to_local(mesh.global_position)
		var deck: Dictionary = ship.call("deck_surface_at",Vector2(center.x,center.z))
		result.append({"name":str(node.name),"center_m":_v(center),"radius_m":radius,"error_m":center.y-radius-float(deck.get("height_m",-99))})
	return result

func _nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children(): result.append(child); result.append_array(_nodes(child))
	return result

func _v(v: Vector3) -> Array: return [v.x,v.y,v.z]

func _horizontal_surface_hits(meshes: Array[MeshInstance3D], point: Vector2, y: float) -> int:
	var hits: int = 0
	for node: MeshInstance3D in meshes:
		var faces: PackedVector3Array = node.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			var a: Vector3 = node.global_transform*faces[i]
			var b: Vector3 = node.global_transform*faces[i+1]
			var c: Vector3 = node.global_transform*faces[i+2]
			if absf(a.y-y)>.002 or absf(b.y-y)>.002 or absf(c.y-y)>.002: continue
			if Geometry3D.ray_intersects_triangle(Vector3(point.x,y+.02,point.y),Vector3.DOWN,a,b,c) is Vector3: hits += 1
	return hits
