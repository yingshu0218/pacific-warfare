extends SceneTree

const SHIP_SCENE: PackedScene = preload("res://scenes/iowa_bb61.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ship: IowaShip = SHIP_SCENE.instantiate() as IowaShip
	if ship == null:
		push_error("Could not instantiate Iowa standalone model")
		quit(1)
		return
	root.add_child(ship)
	await process_frame
	var failures: PackedStringArray = PackedStringArray()
	var expected_counts: Dictionary = {"main_16in":3,"secondary_5in":10,"bofors_40mm":19,"oerlikon_20mm":26}
	var actual_counts: Dictionary = ship.get_weapon_counts()
	if actual_counts != expected_counts:
		failures.append("mount inventory mismatch: %s" % JSON.stringify(actual_counts))
	var seen_ids: Dictionary = {}
	for mount: IowaWeaponMount in ship.get_weapon_mounts():
		if seen_ids.has(mount.mount_id):
			failures.append("duplicate mount id: %s" % mount.mount_id)
		seen_ids[mount.mount_id] = true
		var train_axis: Node3D = mount.get_node_or_null("TrainPivot") as Node3D
		var elevation_count: int = mount.elevation_axes.size()
		if train_axis == null or elevation_count < 1:
			failures.append("missing independent axes: %s" % mount.mount_id)
		if mount.train_rate_deg_s <= 0.0 or mount.elevation_rate_deg_s <= 0.0:
			failures.append("non-positive drive rate: %s" % mount.mount_id)
		var expected_y: float = ship.expected_mount_support_height(mount)
		var audit: Dictionary = mount.get_audit_record()
		if not is_finite(expected_y) or float(audit.station_contact_error_m) > 0.005:
			failures.append("mount or foundation misses declared station: %s (%s)" % [mount.mount_id, mount.support_surface])
	if ship.get_weapon_mounts().size() != 58:
		failures.append("expected 58 independent mount roots")
	var controlled_mount: IowaWeaponMount = ship.get_mount_by_id("main_01")
	var untouched_mount: IowaWeaponMount = ship.get_mount_by_id("main_02")
	if controlled_mount == null or untouched_mount == null:
		failures.append("could not retrieve independently addressable main mounts")
	elif controlled_mount.elevation_axes.size() != 3:
		failures.append("main three-gun turret must have three elevation pivots")
	else:
		controlled_mount.moving = false
		var before_guns: PackedFloat64Array = controlled_mount.get_gun_elevation_states()
		var untouched_before: PackedFloat64Array = untouched_mount.get_gun_elevation_states()
		controlled_mount.aim_at_gun_elevation(0, float(before_guns[0]) + 20.0)
		controlled_mount.advance(0.5, 1.0)
		var after_guns: PackedFloat64Array = controlled_mount.get_gun_elevation_states()
		var untouched_after: PackedFloat64Array = untouched_mount.get_gun_elevation_states()
		if absf(after_guns[0] - before_guns[0]) < 0.001:
			failures.append("per-gun elevation command did not move its selected gun")
		if absf(after_guns[1] - before_guns[1]) > 0.001 or absf(after_guns[2] - before_guns[2]) > 0.001:
			failures.append("per-gun elevation command moved an adjacent gun")
		if untouched_after.size() != untouched_before.size():
			failures.append("independent turret changed its gun count")
		else:
			for gun_index: int in range(untouched_after.size()):
				if absf(untouched_after[gun_index] - untouched_before[gun_index]) > 0.001:
					failures.append("command moved another mount root")
					break
	if failures.is_empty():
		print("PASS: 58 mounts; 3 shared-scene main turrets, installation contact, and per-gun elevation verified")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
