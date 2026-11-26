extends SceneTree

const MODEL: Script = preload("res://aircraft/sb2c4/sb2c4.gd")
const ADAPTER: Script = preload("res://scripts/showcase/sb2c_flight_adapter.gd")
const OUTPUT: String = "res://docs/showcase/evidence/SB2C-admission/interfaces.json"

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model_a: PacificAircraftBuilder = MODEL.new() as PacificAircraftBuilder
	var model_b: PacificAircraftBuilder = MODEL.new() as PacificAircraftBuilder
	model_a.name = "AdmissionFlight"
	model_b.name = "AdmissionDisplay"
	root.add_child(model_a)
	root.add_child(model_b)
	await process_frame
	_require(model_a.position.is_equal_approx(Vector3.ZERO) and model_a.scale.is_equal_approx(Vector3.ONE), "Pure-model origin/scale changed.")
	model_a.call("set_flight_configuration")
	_require(not model_a.landing_gear.visible, "Flight gear still visible.")
	_require(not (model_a.get("external_stores_module") as Node3D).visible, "Flight display rockets still visible.")
	_require(not (model_a.get("bay_open_group") as Node3D).visible, "Flight bay open.")
	_require((model_a.get("bay_closed_group") as Node3D).visible, "Flight closed bay missing.")
	_require(not (model_a.get("dive_brakes_module") as Node3D).visible, "Flight dive brakes open.")
	_require(not (model_a.get("arrestor_hook") as Node3D).visible, "Flight hook deployed.")
	_require(model_b.landing_gear.visible and (model_b.get("external_stores_module") as Node3D).visible, "Instance states leaked.")

	model_a.call("set_bomb_bay_open", true)
	model_b.call("set_showcase_configuration", true)
	_require((model_a.get("bay_open_group") as Node3D).visible, "Bay state leaked between instances.")
	model_a.call("set_flight_configuration")
	model_b.call("set_showcase_configuration", false)
	_require(model_a.animated_surfaces.size() == 5, "Expected two ailerons, two elevators and one rudder.")
	model_a.propeller.rotation.z = 0.7
	model_a.animated_surfaces[0].rotation.z = 0.1
	_require(is_zero_approx(model_b.propeller.rotation.z) and is_zero_approx(model_b.animated_surfaces[0].rotation.z), "Motion state leaked between instances.")
	model_a.propeller.rotation.z = 0.0
	model_a.animated_surfaces[0].rotation.z = 0.0

	var marker_records: Array[Dictionary] = []
	var markers: Dictionary = {}
	for node: Node in _descendants(model_b):
		if node is Marker3D and node.has_meta("station_id"):
			var marker: Marker3D = node as Marker3D
			var station_id: String = str(marker.get_meta("station_id"))
			_require(not markers.has(station_id), "Duplicate marker: " + station_id)
			markers[station_id] = marker
			var local_point: Vector3 = model_b.to_local(marker.global_position)
			var direction: Vector3 = -marker.global_basis.z.normalized()
			marker_records.append({
				"id": station_id, "path": str(model_b.get_path_to(marker)), "position_m": _v(local_point),
				"forward": _v(direction), "host": str(marker.get_meta("host_module_id", "")),
				"source_status": str(marker.get_meta("source_status", "")),
				"confidence": float(marker.get_meta("confidence", 0.0)),
				"wheel_radius_m": float(marker.get_meta("wheel_radius_m", 0.0)),
			})
	_require(markers.has("AIRCRAFT_FLIGHT_REFERENCE"), "Flight reference missing.")
	if markers.has("AIRCRAFT_FLIGHT_REFERENCE"):
		_require(model_b.to_local((markers["AIRCRAFT_FLIGHT_REFERENCE"] as Marker3D).global_position).is_equal_approx(Vector3(0.0, 2.38, 0.0)), "S14 flight reference moved.")
	for station_id: String in ["MUZZLE_CANNON_ANM2_PORT", "MUZZLE_CANNON_ANM2_STARBOARD"]:
		_require(markers.has(station_id), "Fixed muzzle missing: " + station_id)
		if markers.has(station_id):
			_require((-((markers[station_id] as Marker3D).global_basis.z)).dot(Vector3.FORWARD) > 0.99, "Cannon muzzle points backward.")
	for station_id: String in ["MUZZLE_AFT_M1919_PORT", "MUZZLE_AFT_M1919_STARBOARD"]:
		_require(markers.has(station_id), "Aft muzzle missing: " + station_id)
		if markers.has(station_id):
			var direction: Vector3 = -(markers[station_id] as Marker3D).global_basis.z
			_require(direction.z > 0.8 and direction.y > 0.25, "Aft guns do not face aft/up.")

	var parked: Transform3D = model_b.call("get_parked_transform")
	var contacts: Array[Dictionary] = []
	for station_id: String in ["GEAR_WHEEL_PORT", "GEAR_WHEEL_STARBOARD", "GEAR_WHEEL_TAIL"]:
		_require(markers.has(station_id), "Wheel interface missing: " + station_id)
		if not markers.has(station_id):
			continue
		var marker: Marker3D = markers[station_id] as Marker3D
		var center: Vector3 = parked * model_b.to_local(marker.global_position)
		var radius: float = float(marker.get_meta("wheel_radius_m"))
		var error_m: float = center.y - radius
		_require(absf(error_m) < 0.001, "Parked wheel does not touch ground: " + station_id)
		contacts.append({"id": station_id, "parked_center_m": _v(center), "radius_m": radius, "contact_error_m": error_m})
	var store_noses: Array[Dictionary] = []
	var bomb_count: int = 0
	var rocket_count: int = 0
	for node: Node in _descendants(model_b):
		if node is MeshInstance3D and (node.name == "Bomb nose" or node.name == "HVAR warhead nose"):
			var instance: MeshInstance3D = node as MeshInstance3D
			var cylinder: CylinderMesh = instance.mesh as CylinderMesh
			_require(cylinder != null, "Unexpected store nose mesh.")
			if cylinder == null:
				continue
			var tip_y: float = cylinder.height * (-0.5 if cylinder.bottom_radius < cylinder.top_radius else 0.5)
			var tip: Vector3 = model_b.to_local(instance.to_global(Vector3(0.0, tip_y, 0.0)))
			var root_point: Vector3 = model_b.to_local(instance.to_global(Vector3(0.0, -tip_y, 0.0)))
			_require(tip.z < root_point.z - 0.20, "Store nose points aft.")
			store_noses.append({"path": str(model_b.get_path_to(instance)), "tip_m": _v(tip), "root_m": _v(root_point), "forward": _v((tip - root_point).normalized())})
			if node.name == "Bomb nose":
				bomb_count += 1
			else:
				rocket_count += 1
		_require(not str(node.name).contains("Tapered tailwheel keel"), "Oversized tailwheel fairing returned.")
	_require(bomb_count == 1 and rocket_count == 8, "Display-load count changed.")
	var flight_bounds: AABB = _bounds(model_a)
	var span_error: float = absf(flight_bounds.size.x - float(model_a.spec["span_m"]))
	var length_error: float = absf(flight_bounds.size.z - float(model_a.spec["length_m"]))
	_require(span_error < 0.16 and length_error < 0.17, "Model span/length drift exceeds 1.5 percent.")

	var adapter: Node3D = ADAPTER.new() as Node3D
	adapter.name = "S14ReadOnlyAssembly"
	root.add_child(adapter)
	await process_frame
	adapter.call("apply_state", {
		"position_m": Vector3(20.0, 200.0, -30.0), "rotation_rad": Vector3(0.02, 0.1, -0.03),
		"active": true, "module_data": {"aircraft_motion": {"propeller_phase_rad": 1.1, "aileron_rad": 0.12, "elevator_rad": -0.06}}
	})
	var adapter_model: PacificAircraftBuilder = adapter.get("model_root") as PacificAircraftBuilder
	_require(adapter_model != null, "Current S14 adapter could not assemble model.")
	if adapter_model != null:
		_require(is_equal_approx(adapter_model.position.y, -2.38), "Current S14 origin offset changed.")
		_require(not adapter_model.landing_gear.visible and is_equal_approx(adapter_model.propeller.rotation.z, 1.1), "S14 gear/propeller interface failed.")
		for control: Node3D in adapter_model.animated_surfaces:
			if "aileron" in str(control.name).to_lower():
				_require(is_equal_approx(absf(control.rotation.z), 0.12), "S14 aileron interface failed.")
			elif "elevator" in str(control.name).to_lower():
				_require(is_equal_approx(control.rotation.x, -0.06), "S14 elevator interface failed.")

	var module_records: Array[Dictionary] = []
	for node: Node in model_b.get_children():
		if node.has_meta("module_id"):
			module_records.append({"id": str(node.get_meta("module_id")), "path": str(model_b.get_path_to(node))})
	var controls: Array[String] = []
	for control: Node3D in model_b.animated_surfaces:
		controls.append(str(model_b.get_path_to(control)))
	var result: Dictionary = {
		"status": "checks_passed_pending_coordinator_visual_acceptance" if failures.is_empty() else "failed",
		"engine": Engine.get_version_info()["string"], "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"model_source_sha256": FileAccess.get_sha256("res://aircraft/sb2c4/sb2c4.gd"),
		"shared_builder_sha256": FileAccess.get_sha256("res://aircraft/scripts/aircraft_builder.gd"),
		"s14_adapter_sha256": FileAccess.get_sha256("res://scripts/showcase/sb2c_flight_adapter.gd"),
		"origin": {"source_m": [0, 0, 0], "flight_reference_m": [0, 2.38, 0], "s14_translation_m": [0, -2.38, 0], "scale": [1, 1, 1], "axes": "+X right, +Y up, -Z forward"},
		"flight_bounds_m": {"position": _v(flight_bounds.position), "size": _v(flight_bounds.size)},
		"nominal_dimensions_m": {"length": model_a.spec["length_m"], "span": model_a.spec["span_m"], "height_estimate": model_a.spec["height_m"]},
		"parked_transform": {"pitch_rad": parked.basis.get_euler().x, "position_m": _v(parked.origin), "wheel_contacts": contacts},
		"modules": module_records, "markers": marker_records, "animated_surfaces": controls,
		"propeller_path": str(model_b.get_path_to(model_b.propeller)),
		"landing_gear_path": str(model_b.get_path_to(model_b.landing_gear)),
		"arrestor_hook_path": str(model_b.get_path_to(model_b.get("arrestor_hook") as Node)),
		"store_noses": store_noses, "display_load": {"hvar": rocket_count, "internal_500lb": bomb_count, "not_a_verified_sortie_load": true},
		"state_isolation": true, "s14_existing_adapter_smoke": failures.is_empty(),
		"unimplemented": ["carrier takeoff/landing logic", "bomb release/fire control/ammunition", "aft gun traverse/fire control", "continuous gear/hook/brake animation", "SB2C pre-cut damage modules"],
		"failures": Array(failures),
	}
	var output: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	_require(output != null, "Could not write interface evidence.")
	if output != null:
		output.store_string(JSON.stringify(result, "\t") + "\n")
		output.close()
	adapter.free()
	model_a.free()
	model_b.free()
	print("SB2C_ADMISSION " + JSON.stringify({"failures": Array(failures), "flight_span_m": flight_bounds.size.x, "flight_length_m": flight_bounds.size.z, "marker_count": marker_records.size()}))
	quit(0 if failures.is_empty() else 1)


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


func _bounds(model: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var initialized: bool = false
	for node: Node in _descendants(model):
		if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
			var mesh: MeshInstance3D = node as MeshInstance3D
			var relative: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
			var box: AABB = relative * mesh.get_aabb()
			bounds = bounds.merge(box) if initialized else box
			initialized = true
	return bounds


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _v(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
