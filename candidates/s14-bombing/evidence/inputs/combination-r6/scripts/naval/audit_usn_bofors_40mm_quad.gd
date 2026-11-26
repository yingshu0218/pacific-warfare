extends SceneTree

const MOUNT_SCENE: PackedScene = preload("res://assets/naval/weapons/usn_bofors_40mm/mark2_mod5/usn_bofors_40mm_quad_mk2_mod5.tscn")


func _initialize() -> void:
	_run_audit.call_deferred()


func _run_audit() -> void:
	var first: USNBofors40mmQuadMark2Mod5 = MOUNT_SCENE.instantiate() as USNBofors40mmQuadMark2Mod5
	var second: USNBofors40mmQuadMark2Mod5 = MOUNT_SCENE.instantiate() as USNBofors40mmQuadMark2Mod5
	if first == null or second == null:
		push_error("Mount PackedScene did not instantiate as the expected typed scene.")
		quit(1)
		return

	root.add_child(first)
	root.add_child(second)
	await process_frame

	var first_train: Node3D = first.get_node("Generated/TrainPivot") as Node3D
	var first_elevation: Node3D = first.get_node("Generated/TrainPivot/ElevationPivot") as Node3D
	var second_train: Node3D = second.get_node("Generated/TrainPivot") as Node3D
	var second_elevation: Node3D = second.get_node("Generated/TrainPivot/ElevationPivot") as Node3D
	var deck_contact: Marker3D = first.get_node("Generated/MountFoundation/DeckContact") as Marker3D
	var weapon_seat: Marker3D = first.get_node("Generated/MountFoundation/WeaponSeat") as Marker3D
	var gun_count: int = first.get_node("Generated/TrainPivot/ElevationPivot").get_child_count()
	var named_gun_count: int = 0
	for child: Node in first.get_node("Generated/TrainPivot/ElevationPivot").get_children():
		if child.name.begins_with("Gun_"):
			named_gun_count += 1

	first.set_train_angle(-45.0)
	first.set_elevation(-90.0)
	second.set_train_angle(135.0)
	second.set_elevation(125.0)
	await process_frame

	var failures: PackedStringArray = PackedStringArray()
	if not is_equal_approx(deck_contact.position.y, 0.0):
		failures.append("deck contact marker is not at root y=0")
	if not is_equal_approx(weapon_seat.position.y, 0.78):
		failures.append("weapon seat marker does not match the fixed stand height")
	if named_gun_count != 4:
		failures.append("expected four individually inspectable gun groups; found %d" % named_gun_count)
	if not is_equal_approx(first.elevation_degrees, -5.0) or not is_equal_approx(second.elevation_degrees, 90.0):
		failures.append("elevation commands did not clamp to -5 and +90 degrees")
	if not is_equal_approx(first.train_degrees, 315.0) or not is_equal_approx(second.train_degrees, 135.0):
		failures.append("train angles were not normalized independently")
	if not is_equal_approx(first_train.rotation.y, deg_to_rad(315.0)) or not is_equal_approx(second_train.rotation.y, deg_to_rad(135.0)):
		failures.append("train pivot transforms did not follow their separate commands")
	if not is_equal_approx(first_elevation.rotation.x, deg_to_rad(-5.0)) or not is_equal_approx(second_elevation.rotation.x, deg_to_rad(90.0)):
		failures.append("elevation pivot transforms did not follow their separate commands")
	if gun_count < named_gun_count:
		failures.append("named gun groups are not children of the elevation assembly")

	if failures.size() > 0:
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return

	print("PASS: Mark 2 Mod. 5 scene loads; deck/seat interface, four gun groups, elevation limits, and independent two-axis control verified.")
	quit()
