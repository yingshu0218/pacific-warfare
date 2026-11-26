extends SceneTree
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const MODEL: PackedScene = preload("res://naval/shokaku_1941_08_23/shokaku.tscn")
const FIXTURE: Script = preload("res://naval/shokaku_1941_08_23/inspection/deck_fixtures.gd")
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var output: String = "res://docs/showcase/evidence/CV02/mechanisms.json"

func _initialize() -> void:
	call_deferred("_run")

func check(passed: bool, id: String, detail: Variant = null) -> void:
	checks.append({"id":id,"passed":passed,"detail":detail})
	if not passed: failures.append(id); push_error("CV02 "+id)

func ray_y(module: Node3D, point: Vector2) -> float:
	var meshes: Array[MeshInstance3D] = []
	H.collect_meshes(module,meshes,[])
	var best: float = -INF
	for mesh: MeshInstance3D in meshes:
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		var local: Transform3D = module.global_transform.affine_inverse()*mesh.global_transform
		for i: int in range(0,faces.size(),3):
			var a: Vector3=local*faces[i]; var b: Vector3=local*faces[i+1]; var c: Vector3=local*faces[i+2]
			var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(point.x,100,point.y),Vector3.DOWN,a,b,c)
			if hit is Vector3: best=maxf(best,hit.y)
	return best

func _run() -> void:
	for i: int in range(OS.get_cmdline_user_args().size()-1):
		if OS.get_cmdline_user_args()[i]=="--report": output=OS.get_cmdline_user_args()[i+1]
	var ship: Node3D = MODEL.instantiate() as Node3D
	root.add_child(ship)
	var other: Node3D = MODEL.instantiate() as Node3D
	root.add_child(other)
	await process_frame
	check(ship.scale.is_equal_approx(Vector3.ONE),"ship_1_to_1")
	check(ship.modules.size()==7,"seven_independent_modules")
	var supports: Array=[]
	for child: Node in ship.modules.hangar.get_children():
		if child is Marker3D and child.get_meta("kind","")=="underdeck_support_base":
			var base: Vector3=ship.to_local(child.global_position)
			var hull_y: float=ray_y(ship.modules.hull,Vector2(base.x,base.z))
			check(is_finite(hull_y) and absf(hull_y-base.y)<.025,"real_hull_under_support_"+str(child.name),{"base_y":base.y,"hull_mesh_y":hull_y})
			supports.append([base.x,base.y,base.z])
	check(supports.size()==8,"eight_real_end_supports")
	var twins: int=0; var smoke: int=0; var light: int=0
	var mounts: Array = []
	for row: Dictionary in ship.configuration.mounts:
		if row.role=="dual_purpose":
			twins+=1
			if row.kind=="type89_smoke": smoke+=1; check(row.id.begins_with("dp_starboard") and float(row.position_m[2])>40,"smoke_shields_right_aft_"+row.id)
		else: light+=1
		var record: Dictionary=ship.mount_visuals[row.id]
		check(record.muzzles.size()==int(row.barrels),"barrel_count_"+row.id)
		check(str(record.surface.get_meta("host_id"))==row.host_id,"explicit_host_"+row.id)
		var surface_point: Vector3=ship.to_local(record.surface.global_position)
		var seat_point: Vector3=ship.to_local(record.seat.global_position)
		check(surface_point.is_equal_approx(G.vector(row.position_m)),"host_station_"+row.id)
		check(absf(seat_point.y-surface_point.y-float(row.foundation_height_m))<.0001,"foundation_end_contacts_"+row.id)
		var host: Node3D=record.surface.get_parent() as Node3D
		var at: Vector3=host.to_local(record.surface.global_position)
		var mesh_height: float=ray_y(host,Vector2(at.x,at.z))
		check(is_finite(mesh_height) and absf(mesh_height-at.y)<.001,"actual_sponson_surface_"+row.id,{"mesh_y":mesh_height,"marker_y":at.y})
		# Ring footprint sampled against visible host, independent of JSON radius.
		for angle: float in [0,PI*.5,PI,PI*1.5]:
			var sample: Vector2=Vector2(at.x,at.z)+Vector2(cos(angle),sin(angle))*float(row.foundation_radius_m)*.95
			check(absf(ray_y(host,sample))<.001,"ring_footprint_"+row.id+"_"+str(angle))
		var before: Transform3D=ship.muzzle_transform_local(row.id,0)
		var other_before: Transform3D=other.muzzle_transform_local(row.id,0)
		check(ship.apply_weapon_state(row.id,{"train_rad":.22,"elevation_rad":.53}),"weapon_state_"+row.id)
		check(not ship.muzzle_transform_local(row.id,0).is_equal_approx(before),"muzzle_tracks_axes_"+row.id)
		check(other.muzzle_transform_local(row.id,0).is_equal_approx(other_before),"instance_isolation_"+row.id)
		var basis_before: Basis=record.train.basis
		check(not ship.apply_weapon_state(row.id,{"train_rad":NAN}),"reject_nonfinite_mount_"+row.id)
		check(record.train.basis.is_equal_approx(basis_before),"nonfinite_no_mutation_"+row.id)
		ship.apply_weapon_state(row.id,{"train_rad":0.0,"elevation_rad":0.0})
		mounts.append({"id":row.id,"host":row.host_id,"kind":row.kind,"surface_m":[surface_point.x,surface_point.y,surface_point.z],"seat_m":[seat_point.x,seat_point.y,seat_point.z],"barrels":record.muzzles.size()})
	check(twins==8 and smoke==2,"eight_fixed_twins_two_smoke_six_open",{"twins":twins,"smoke":smoke,"open":twins-smoke})
	check(light==6,"dedicated_aa_game_fit_separate",{"historical_triples":12,"game_triples":light})
	var data: Dictionary=ship.deck_definition()
	data.flight_deck.height_m=999
	check(is_equal_approx(float(ship.deck_definition().flight_deck.height_m),14.15),"defensive_deck_definition")
	check(ship.deck_surface_at(Vector2(0,-116)).supported,"bow_visible_deck_supported")
	check(not ship.deck_surface_at(Vector2(-14.8,-116)).supported,"reject_bounding_rectangle_outside_polygon")
	check(not ship.deck_surface_at(Vector2(12,-100)).supported,"forward_deck_progressive_taper")
	check(ship.deck_surface_at(Vector2(12,-60)).supported,"forward_deck_widens_aft")
	check(not ship.deck_surface_at(Vector2(NAN,0)).supported,"reject_nonfinite_query")
	for wire: Dictionary in ship.deck_definition().arresting_wires:
		var from: Vector3=G.vector(wire.points_m[0]); var to: Vector3=G.vector(wire.points_m[1])
		check(absf(from.y-14.31)<.001 and absf(to.y-14.31)<.001,"wire_height_from_actual_deck_"+wire.id)
		for f: float in [0.0,.25,.5,.75,1.0]:
			var point: Vector3=from.lerp(to,f)
			var support: Dictionary=ship.deck_surface_at(Vector2(point.x,point.z))
			check(support.supported and support.surface_id=="flight_deck","wire_clears_elevator_openings_"+wire.id+"_"+str(f))
	var elevator_results: Array=[]
	for e: Dictionary in ship.deck_definition().elevators:
		var center: Vector2=Vector2(e.center_xz_m[0],e.center_xz_m[1])
		var second: float=other.deck_surface_at(center).height_m
		for height: float in [14.15,8.95,4.0]:
			check(ship.apply_equipment_state(e.id,{"height_m":height}),"lift_state_"+e.id+"_"+str(height))
			var surface: Dictionary=ship.deck_surface_at(center)
			# Check the entire assembly: hull weather decks / hangar modules must
			# not leave a hidden roof over the lower lift or the carried aircraft.
			var actual: float=ray_y(ship,center)
			check(absf(float(surface.height_m)-height)<.001 and absf(actual-height)<.035,"real_hole_and_surface_"+e.id+"_"+str(height),{"query_y":surface.height_m,"mesh_y":actual})
			check(absf(float(other.deck_surface_at(center).height_m)-second)<.001,"lift_instance_isolation_"+e.id+"_"+str(height))
			# Inside/outside both hole edges: detects fixed decks covering holes
			# and mismatched platform sizes rather than only centre-point state.
			for delta: float in [-.04,.04]:
				var point: Vector2=center+Vector2(float(e.size_xz_m[0])*.5+delta,0)
				var result: Dictionary=ship.deck_surface_at(point)
				check(absf(ray_y(ship,point)-float(result.height_m))<.035,"lift_edge_mesh_query_"+e.id+"_"+str(height)+"_"+str(delta))
		check(not ship.apply_equipment_state(e.id,{"height_m":INF}),"reject_nonfinite_lift_"+e.id)
		ship.apply_equipment_state(e.id,{"height_m":1000})
		check(absf(float(ship.deck_surface_at(center).height_m)-14.15)<.001,"clamp_lift_travel_"+e.id)
		elevator_results.append({"id":e.id,"upper":14.15,"intermediate":8.95,"lower":4.0,"mesh_and_query_checked":true})
	var fixtures: Node3D=FIXTURE.new() as Node3D
	ship.add_child(fixtures)
	for record: Dictionary in fixtures.records:
		if record.kind=="dimension_proxy_only":
			var size: Vector3=G.vector(record.envelope_size_m)
			var station: Vector3=G.vector(record.station_m)
			for x: float in [-size.x*.5,size.x*.5]:
				for z: float in [-size.z*.5,size.z*.5]:
					var support: Dictionary=ship.deck_surface_at(Vector2(station.x+x,station.z+z))
					check(support.supported and support.surface_id=="elevator_middle","explicit_dimension_proxy_lift_clearance_"+str(x)+"_"+str(z))
			continue
		check(record.root_transform_unchanged and record.scale==[1.0,1.0,1.0],"unaltered_actual_aircraft_"+record.id)
		check(record.tyres.size()==3,"measured_three_actual_tyres_"+record.id)
		for tyre: Dictionary in record.tyres:
			var contact: Vector3=G.vector(tyre.ship_contact_m)
			var surface: Dictionary=ship.deck_surface_at(Vector2(contact.x,contact.z))
			check(surface.supported and absf(contact.y-float(surface.height_m))<.02,"actual_tyre_on_surface_"+record.id+"_"+tyre.mesh_path,{"wheel_y":contact.y,"deck_y":surface.get("height_m",null)})
		for point_value: Array in record.footprint_corners_ship_m:
			var point: Vector3=G.vector(point_value)
			check(ship.deck_surface_at(Vector2(point.x,point.z)).supported,"full_mesh_envelope_in_deck_"+record.id+"_"+str(point.x)+"_"+str(point.z))
		for obstacle: Dictionary in ship.deck_obstacles():
			var poly: PackedVector2Array=H.polygon(obstacle.polygon_xz_m)
			var a: Vector3=G.vector(record.envelope_min_m)+G.vector(record.station_m)
			var b: Vector3=G.vector(record.envelope_max_m)+G.vector(record.station_m)
			var overlaps: Array[PackedVector2Array]=Geometry2D.intersect_polygons(H.rect(Vector2((a.x+b.x)*.5,(a.z+b.z)*.5),Vector2(b.x-a.x,b.z-a.z)),poly)
			check(overlaps.is_empty() or b.y<float(obstacle.bottom_m) or a.y>float(obstacle.top_m),"mesh_envelope_obstacle_clear_"+record.id+"_"+obstacle.id)
	# Full ship pose inheritance: wheels rotate/translate with the deck without
	# changing local aircraft origin, or re-grounding via query/teleport.
	var fixture_point: Vector3=G.vector(fixtures.records[0].tyres[0].ship_contact_m)
	ship.apply_state({"position_m":[47,5,-91],"rotation_rad":[.08,.63,-.04]})
	var actual_world: Vector3=(fixtures.aircraft[0] as Node3D).global_transform*G.vector(fixtures.records[0].tyres[0].local_contact_m)
	check(actual_world.distance_to(ship.global_transform*fixture_point)<.0001,"carrier_full_pose_inheritance")
	var report: Dictionary={"task":"CV02","passed":failures.is_empty(),"checks":checks,"failures":failures,
		"mounts":mounts,"elevators":elevator_results,"underdeck_support_bases":supports,"aircraft_fixtures":fixtures.records,
		"scope":"geometry, static bearing and pure adapter only; not takeoff, recovery, queue, combat or historical full acceptance"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file: FileAccess=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("PASS" if failures.is_empty() else "FAIL"," CV02 ",checks.size()," checks; ",failures.size()," failures; ",output)
	ship.free(); other.free()
	quit(0 if failures.is_empty() else 1)
