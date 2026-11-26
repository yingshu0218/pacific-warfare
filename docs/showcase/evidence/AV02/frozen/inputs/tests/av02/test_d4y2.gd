extends SceneTree
## Tests actual meshes/markers and unmodified Shokaku query, not copied builder outputs.
const SCENE: PackedScene = preload("res://aircraft/d4y2/d4y2.tscn")
const MODEL: Script = preload("res://aircraft/d4y2/d4y2.gd")
const G: Script = preload("res://aircraft/d4y2/geometry.gd")
const SHIP: PackedScene = preload("res://naval/shokaku_1941_08_23/shokaku.tscn")
var checks: Array[Dictionary] = []
var measurements: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(id: String, passed: bool, data: Variant = null) -> void:
	checks.append({"id": id, "passed": passed, "data": data})
	if not passed:
		print("AV02 FAIL ", id, ": ", data)

func points(model: Node3D, part: Node3D = null) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for mesh: MeshInstance3D in G.meshes(model if part == null else part):
		var t: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
		for vertex: Vector3 in mesh.mesh.get_faces():
			result.append(t * vertex)
	return result

func bounds(vertices: Array[Vector3], t: Transform3D = Transform3D.IDENTITY) -> AABB:
	var lo: Vector3 = Vector3(INF, INF, INF); var hi: Vector3 = -lo
	for p: Vector3 in vertices:
		var q: Vector3 = t * p
		lo = lo.min(q); hi = hi.max(q)
	return AABB(lo, hi - lo)

func vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func part_clearance(model: Node3D, parked: Transform3D, name_fragment: String) -> float:
	var low: float = INF
	for mesh: MeshInstance3D in G.meshes(model):
		if name_fragment not in str(model.get_path_to(mesh)): continue
		var t: Transform3D = parked * model.global_transform.affine_inverse() * mesh.global_transform
		for p: Vector3 in mesh.mesh.get_faces(): low = minf(low, (t * p).y)
	return low

func _run() -> void:
	var model: Node3D = SCENE.instantiate() as Node3D
	var other: Node3D = SCENE.instantiate() as Node3D
	root.add_child(model); root.add_child(other)
	check("unit_root_identity", model.transform == Transform3D.IDENTITY and model.scale == Vector3.ONE)
	check("no_autonomous_model_process", not model.is_processing() and not model.is_physics_processing())
	model.set_flight_configuration()
	var flight: AABB = bounds(points(model))
	check("actual_span_11_50m", absf(flight.size.x - 11.50) < 0.015, vec(flight.size))
	check("actual_length_10_22m", absf(flight.size.z - 10.22) < 0.015, vec(flight.size))
	check("no_shared_model_resources", model.propeller != other.propeller and model.materials.top != other.materials.top)
	var marker_count: int = model.markers.size()
	for id: String in model.markers:
		var marker: Marker3D = model.markers[id]
		check("marker_finite_" + id, marker.global_position.is_finite() and marker.global_basis.is_finite())
	for id: String in ["MUZZLE_TYPE97_PORT", "MUZZLE_TYPE97_STARBOARD"]:
		var marker: Marker3D = model.markers[id]
		check("forward_gun_direction_" + id, (-marker.global_basis.z).dot(Vector3.FORWARD) > 0.999)
	model.apply_visual_state({"gear": 1.0})
	var parked: Transform3D = model.get_parked_transform()
	var contact_data: Array = []
	for id: String in ["WHEEL_PORT", "WHEEL_STARBOARD", "WHEEL_TAIL"]:
		var marker: Marker3D = model.markers[id]
		var center: Vector3 = model.to_local(marker.global_position)
		var radius: float = MODEL.TAIL_WHEEL_RADIUS_M if id == "WHEEL_TAIL" else MODEL.MAIN_WHEEL_RADIUS_M
		check("analytic_tyre_tangent_" + id, absf((parked * center).y - radius) < 0.00001)
		var tyre: MeshInstance3D
		for m: MeshInstance3D in G.meshes(marker.get_parent()):
			if str(m.name).ends_with("Tyre"): tyre = m
		var low: float = INF
		var t: Transform3D = parked * model.global_transform.affine_inverse() * tyre.global_transform
		for vertex: Vector3 in tyre.mesh.get_faces(): low = minf(low, (t * vertex).y)
		check("actual_tyre_mesh_contact_" + id, low >= -0.0001 and low < 0.0005, low)
		contact_data.append({"id": id, "center_m": vec(center), "radius_m": radius, "lowest_mesh_y_m": low})
	check("tail_low_photo_attitude", parked.basis.get_euler().x > deg_to_rad(8.0) and parked.basis.get_euler().x < deg_to_rad(14.0), rad_to_deg(parked.basis.get_euler().x))
	var clearances: Dictionary = {}
	# Entire swept propeller disc, not just the current three blades.
	var disc_low: float = (parked * model.propeller.position).y - MODEL.PROPELLER_RADIUS_M * absf(parked.basis.y.y)
	clearances.propeller_disc_m = disc_low
	clearances.propeller_swept_top_m = (parked * model.propeller.position).y + MODEL.PROPELLER_RADIUS_M * absf(parked.basis.y.y)
	check("parked_full_prop_disc_clear", disc_low > 0.25, disc_low)
	clearances.belly_skin_m = part_clearance(model, parked, "ContinuousSkin")
	clearances.chin_radiator_m = part_clearance(model, parked, "ChinRadiatorFairing")
	check("belly_and_chin_clear", float(clearances.belly_skin_m) > 0.10 and float(clearances.chin_radiator_m) > 0.25)
	for option: Dictionary in [{"flap": 1.0}, {"flap": 0.0, "brake": 1.0}, {"brake": 0.0, "bay": 1.0, "crutch": 0.0}, {"bay": 0.0, "crutch": 0.0, "hook": 1.0}]:
		model.apply_visual_state(option)
		var box: AABB = bounds(points(model), parked)
		var key: String = str(option)
		clearances[key] = box.position.y
		check("full_extension_no_deck_penetration_" + key, box.position.y >= -0.0001, box.position.y)
		if option.has("flap") and option.flap == 1.0:
			clearances.flap_low_m = part_clearance(model, parked, "Flap")
			check("actual_flap_mesh_clear", float(clearances.flap_low_m) > 0.10)
		if option.has("brake") and option.brake == 1.0:
			clearances.brake_low_m = part_clearance(model, parked, "DiveBrake")
			check("actual_brake_mesh_clear", float(clearances.brake_low_m) > 0.10)
		if option.has("hook") and option.hook == 1.0:
			clearances.hook_tip_m = (parked * model.to_local(model.markers.HOOK_TIP.global_position)).y
			check("actual_hook_tip_clear", float(clearances.hook_tip_m) > 0.0)
	model.apply_visual_state({"hook": 0.0, "bay": 1.0, "crutch": 1.0})
	clearances.fully_swung_bomb_parked_m = bounds(points(model), parked).position.y
	check("crutch_ground_clearance_constraint_recorded", float(clearances.fully_swung_bomb_parked_m) < 0.0)
	# Real motion hierarchy and repeatable snapshots; no drift or state leak across instances.
	model.apply_visual_state({"gear": 0.3, "hook": 0.5, "flap": 1.0, "brake": 1.0, "bay": 1.0, "crutch": 1.0,
		"rear_gun": true, "propeller_rad": 1.1, "aileron_left_wing_rad": 0.20, "aileron_right_wing_rad": -0.20,
		"elevator_left_rad": 0.15, "elevator_right_rad": 0.15, "rudder_rad": 0.20})
	check("flap_brake_interlock", absf(model.surfaces.brake_left_wing_0.rotation.x) < 0.0001)
	check("continuous_gear", model.gear_axes[0].rotation.z > 0.1 and model.gear_axes[0].rotation.z < PI * 0.5)
	check("crutch_moves_actual_release_reference", model.markers.BOMB_RELEASE.global_position.y < -0.9)
	var rear: Marker3D = model.markers.MUZZLE_TYPE1_REAR
	check("rear_gun_bore_is_aft_up", (-rear.global_basis.z).z > 0.5 and (-rear.global_basis.z).y > 0.3)
	check("other_instance_untouched", other.state.gear == 1.0 and other.state.bay == 0.0 and other.propeller.rotation == Vector3.ZERO)
	var x: float = model.surfaces.flap_left_wing.position.z
	model.apply_visual_state({"flap": 1.0}); model.apply_visual_state({"flap": 1.0})
	check("fowler_snapshot_no_drift", absf(x - model.surfaces.flap_left_wing.position.z) < 0.00001)
	model.apply_visual_state({"gear": NAN, "hook": INF})
	check("invalid_input_rejected", model.state.gear == 0.3 and model.state.hook == 0.5)
	for id: String in ["engine", "left_wing", "right_wing", "tail"]:
		model.apply_damage_state({id: false})
		check("damage_group_visibility_" + id, not model.damage_modules[id].visible and other.damage_modules[id].visible)
		check("damage_group_has_geometry_" + id, not G.meshes(model.damage_modules[id], false).is_empty())
		model.apply_damage_state({id: true})
	model.apply_visual_state({"gear": 1.0, "hook": 0.0, "flap": 0.0, "brake": 0.0, "bay": 0.0, "crutch": 0.0, "rear_gun": false,
		"propeller_rad": 0.0, "aileron_left_wing_rad": 0.0, "aileron_right_wing_rad": 0.0, "elevator_left_rad": 0.0, "elevator_right_rad": 0.0, "rudder_rad": 0.0})
	var parked_bounds: AABB = bounds(points(model), parked)
	measurements = {"flight_envelope_m": {"min": vec(flight.position), "size": vec(flight.size)},
		"parked_envelope_m": {"min": vec(parked_bounds.position), "size": vec(parked_bounds.size)},
		"parked_pitch_deg": rad_to_deg(parked.basis.get_euler().x), "parked_translation_m": vec(parked.origin),
		"contacts": contact_data, "clearances": clearances, "marker_count": marker_count}
	_export_interfaces(model)
	_check_ship(model, parked)
	var passed: bool = true
	for row: Dictionary in checks: passed = passed and bool(row.passed)
	var report: Dictionary = {"task": "AV02", "status": "self_test_only_pending_root_review", "passed": passed,
		"checks": checks, "measurements": measurements, "engine": Engine.get_version_info().string,
		"sources": {"model": FileAccess.get_sha256("res://aircraft/d4y2/d4y2.gd"), "geometry": FileAccess.get_sha256("res://aircraft/d4y2/geometry.gd"),
			"ship": FileAccess.get_sha256("res://naval/shokaku_1941_08_23/shokaku.gd"), "deck": FileAccess.get_sha256("res://naval/shokaku_1941_08_23/data/deck.json")}}
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/AV02/mechanisms.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print("AV02 checks=", checks.size(), " passed=", passed, " measurements=", JSON.stringify(measurements))
	model.free(); other.free()
	quit(0 if passed else 1)

func _export_interfaces(model: Node3D) -> void:
	var record: Dictionary = {"schema_version": "av02-model-0.1", "model_id": "jp_d4y2_model12_1944_10",
		"registered": false, "axis": {"forward": "-Z", "up": "+Y", "right": "+X", "units": "m, rad, s", "origin": "fixed visual airframe datum (not surveyed CG)"},
		"default_state": model.state.duplicate(true), "markers": [], "motion_axes": [], "damage_modules": [],
		"measurement": measurements.duplicate(true), "confidence": "nominal dimensions original A11; stations photographic estimates; NOT factory survey"}
	for id: String in model.markers:
		var marker: Marker3D = model.markers[id]
		var t: Transform3D = model.global_transform.affine_inverse() * marker.global_transform
		record.markers.append({"id": id, "path": str(model.get_path_to(marker)), "position_m": vec(t.origin),
			"forward": vec(-t.basis.z), "source_status": marker.get_meta("source_status"), "host_id": marker.get_meta("host_id")})
	for id: String in model.surfaces:
		var axis: Node3D = model.surfaces[id]
		record.motion_axes.append({"id": id, "path": str(model.get_path_to(axis)), "position_m": vec(model.to_local(axis.global_position)),
			"axis": "+Y" if id == "rudder" else "+X", "hierarchy_in_damage_part": true})
	for id: String in model.damage_modules:
		var node: Node3D = model.damage_modules[id]
		var bb: AABB = bounds(points(model, node))
		record.damage_modules.append({"id": id, "path": str(model.get_path_to(node)), "root_transform": "identity, world-airframe coordinates; reparent with transform retained",
			"bbox_min_m": vec(bb.position), "bbox_size_m": vec(bb.size), "collision_proxy": "suggested bounds only; must refine simulation hits by part, not applied collision bodies"})
	var triangle_count: int = 0
	var all_meshes: Array[MeshInstance3D] = G.meshes(model, false)
	for mesh: MeshInstance3D in all_meshes: triangle_count += mesh.mesh.get_faces().size() / 3
	record.geometry_budget = {"all_states_mesh_nodes": all_meshes.size(), "all_states_triangles": triangle_count,
		"note": "native source model includes independently movable pieces; no production batching or fleet performance claim"}
	var file: FileAccess = FileAccess.open("res://aircraft/d4y2/data/interfaces.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t") + "\n"); file.close()

func _check_ship(model: Node3D, parked: Transform3D) -> void:
	var ship: Node3D = SHIP.instantiate() as Node3D
	root.add_child(ship)
	var definition: Dictionary = ship.deck_definition()
	var vertices: Array[Vector3] = points(model)
	var records: Array[Dictionary] = []
	for lift: Dictionary in definition.elevators:
		var at: Vector3 = Vector3(lift.center_xz_m[0], lift.upper_height_m, lift.center_xz_m[1])
		var assembly: Transform3D = Transform3D(Basis.IDENTITY, at) * parked
		var bb: AABB = bounds(vertices, assembly)
		var inside: bool = bb.position.x >= at.x - float(lift.size_xz_m[0]) * 0.5 and bb.end.x <= at.x + float(lift.size_xz_m[0]) * 0.5
		inside = inside and bb.position.z >= at.z - float(lift.size_xz_m[1]) * 0.5 and bb.end.z <= at.z + float(lift.size_xz_m[1]) * 0.5
		check("whole_envelope_on_" + str(lift.id), inside, {"size": vec(bb.size), "min": vec(bb.position)})
		for height: float in [float(lift.upper_height_m), float(lift.lower_height_m)]:
			ship.apply_equipment_state(lift.id, {"height_m": height})
			for id: String in ["WHEEL_PORT", "WHEEL_STARBOARD", "WHEEL_TAIL"]:
				var c: Vector3 = parked * model.to_local(model.markers[id].global_position) + Vector3(at.x, height, at.z)
				var support: Dictionary = ship.deck_surface_at(Vector2(c.x, c.z))
				check("tyre_supported_" + str(lift.id) + "_" + id + "_" + str(height), bool(support.supported) and absf(float(support.height_m) - height) < 0.0001, support)
		ship.apply_equipment_state(lift.id, {"height_m": lift.upper_height_m})
		records.append({"id": lift.id, "min_m": vec(bb.position), "size_m": vec(bb.size), "unfolded_wing_clearance_each_side_m": (float(lift.size_xz_m[0]) - bb.size.x) * 0.5})
	# Three distinct parking zones; full projected mesh envelope, not only wheel centres.
	for row: Array in [["forward_park", Vector3(-0.5, 14.15, -80.0)], ["mid_park", Vector3(-0.5, 14.15, -3.0)], ["aft_park", Vector3(-0.5, 14.15, 56.0)]]:
		var assembly: Transform3D = Transform3D(Basis.IDENTITY, row[1]) * parked
		var zone: PackedVector2Array = []
		for z: Dictionary in definition.zones:
			if z.id == row[0]:
				for p: Array in z.polygon_xz_m: zone.append(Vector2(p[0], p[1]))
		var within: bool = true; var clear: bool = true
		for vertex: Vector3 in vertices:
			var p: Vector3 = assembly * vertex
			within = within and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), zone)
			for obstacle: Dictionary in definition.obstacles:
				if p.y < float(obstacle.bottom_m) or p.y > float(obstacle.top_m): continue
				var poly: PackedVector2Array = []
				for q: Array in obstacle.polygon_xz_m: poly.append(Vector2(q[0], q[1]))
				clear = clear and not Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), poly)
		check("whole_plane_within_" + str(row[0]), within)
		check("whole_plane_clear_obstacles_" + str(row[0]), clear)
		for id: String in ["WHEEL_PORT", "WHEEL_STARBOARD", "WHEEL_TAIL"]:
			var c: Vector3 = assembly * model.to_local(model.markers[id].global_position)
			var s: Dictionary = ship.deck_surface_at(Vector2(c.x, c.z))
			check("parking_support_" + str(row[0]) + "_" + id, bool(s.supported) and absf(float(s.height_m) - 14.15) < 0.0001)
	# Complete moving host transform, without recomputing flight datum or snapping tyres.
	var host: Transform3D = Transform3D(Basis.from_euler(Vector3(0.035, 0.7, -0.025)), Vector3(70.0, 3.0, -90.0))
	var local_plane: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 14.15, -80.0)) * parked
	var up: Vector3 = host.basis.y
	var c: Vector3 = model.to_local(model.markers.WHEEL_PORT.global_position)
	var radius: float = MODEL.MAIN_WHEEL_RADIUS_M
	var world_center: Vector3 = host * local_plane * c
	var contact: Vector3 = world_center - up * radius
	var origin_on_deck: Vector3 = host * Vector3(0.0, 14.15, -80.0)
	check("host_pitch_roll_yaw_contact_plane", absf((contact - origin_on_deck).dot(up)) < 0.00001)
	check("pure_root_unchanged_after_static_fit", model.transform == Transform3D.IDENTITY)
	measurements.shokaku_static_fits = records
	ship.free()
