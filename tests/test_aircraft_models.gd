extends SceneTree

var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func _run() -> void:
	var catalog: DefinitionCatalog = AircraftFixture.catalog()
	for definition_id: String in ["jp_a6m5a_1944", "us_f6f5_1944"]:
		var definition: UnitDefinition = catalog.unit(definition_id)
		var scene: PackedScene = load(definition.model_scene)
		var first: AircraftAdapter = scene.instantiate() as AircraftAdapter
		var second: AircraftAdapter = scene.instantiate() as AircraftAdapter
		root.add_child(first)
		root.add_child(second)
		check(not first.model_root.landing_gear.visible, definition_id + " gear retracted")
		check(first.installation_sockets().size() == definition.mounts.size(), "mount count")
		var bounds: AABB = AABB()
		var started: bool = false
		for child: Node in first.find_children("*", "MeshInstance3D", true, false):
			var part: MeshInstance3D = child as MeshInstance3D
			if not part.is_visible_in_tree():
				continue
			var part_box: AABB = (first.global_transform.affine_inverse() * part.global_transform) * part.get_aabb()
			bounds = bounds.merge(part_box) if started else part_box
			started = true
		check(absf(bounds.size.x - definition.dimensions_m.x) < 0.05, definition_id + " span unchanged")
		check(absf(bounds.size.z - definition.dimensions_m.z) < 0.05, definition_id + " length unchanged")
		for mount: MountSocket in definition.mounts:
			var actual: Transform3D = first.muzzle_transform_local(mount.id, 0)
			check(actual.origin.distance_to(mount.local_muzzle_transform(0, 0, 0).origin) < 0.00001, "muzzle mismatch: " + definition_id + "/" + mount.id + " " + str(actual.origin) + " vs " + str(mount.position_m))
			check((-actual.basis.z).dot(Vector3.FORWARD) > 0.999999, "forward fixed gun")
		var state: Dictionary = {"position_m": Vector3(40, 1500, -500), "rotation_rad": Vector3(0.06, 0.8, 0.3),
			"module_data": {"aircraft_motion": {"propeller_phase_rad": 1.3, "aileron_rad": 0.1}}}
		first.apply_state(state)
		check(second.position == Vector3.ZERO and second.model_root.propeller.rotation.z == 0.0, "instances isolated")
		check(first.muzzle_transform_global(definition.mounts[0].id, 0).origin.distance_to(first.global_transform * definition.mounts[0].position_m) < 0.0005, "world muzzle agrees")
		first.apply_state({"active": false, "module_data": {"damage": {"phase": "crashing"}}})
		check(first.visible, "crashing visible")
		first.apply_state({"active": false, "module_data": {"damage": {"phase": "removed"}}})
		check(not first.visible, "removed hidden")
		first.free()
		second.free()
	for path: String in ["res://aircraft/scenes/a6m5_52ko.tscn", "res://aircraft/scenes/f6f5.tscn"]:
		var scene: PackedScene = load(path)
		var legacy: PacificAircraftBuilder = scene.instantiate() as PacificAircraftBuilder
		root.add_child(legacy)
		check(not legacy.flight_simplified and legacy.landing_gear.visible, "legacy model compatible")
		legacy.free()
	print("S04 aircraft models PASS checks=", checks)
	quit(0)
