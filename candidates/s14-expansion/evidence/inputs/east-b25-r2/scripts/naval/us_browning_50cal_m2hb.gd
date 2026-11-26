@tool
extends NavalMachineGunVisualBase
class_name USBrowning50CalM2HB

const BARREL_LENGTH_M: float = 1.143
const OVERALL_LENGTH_M: float = 1.6543
const MUZZLE_Z_M: float = -0.813


func _build_weapon(weapon: Node3D) -> void:
	var bore_reference := get_node("Generated/MountInterface/BoreAxisReference") as Marker3D
	bore_reference.position = Vector3(0.0, 0.05, MUZZLE_Z_M)
	weapon.position.y = 0.05
	var receiver := Node3D.new()
	receiver.name = "ReceiverAndBackplate"
	weapon.add_child(receiver)
	_add_box(receiver, "ReceiverBody", Vector3(0.17, 0.18, 0.47), Vector3(0.0, 0.0, 0.15), "receiver")
	_add_box(receiver, "ReceiverLeftPlate", Vector3(0.012, 0.148, 0.38), Vector3(-0.091, 0.0, 0.15), "receiver_light")
	_add_box(receiver, "ReceiverRightPlate", Vector3(0.012, 0.148, 0.38), Vector3(0.091, 0.0, 0.15), "receiver_light")
	_add_box(receiver, "CoverRim", Vector3(0.16, 0.018, 0.32), Vector3(0.0, 0.102, 0.105), "steel_edge")
	_add_box(receiver, "FeedCover", Vector3(0.15, 0.047, 0.30), Vector3(0.0, 0.13, 0.105), "receiver_light")
	_add_box(receiver, "FeedCoverRidge", Vector3(0.13, 0.012, 0.21), Vector3(0.0, 0.16, 0.11), "steel")
	_add_box(receiver, "FeedCoverLatch", Vector3(0.035, 0.024, 0.05), Vector3(0.0, 0.116, -0.065), "steel_edge")
	_add_box(receiver, "FeedTrayLip", Vector3(0.21, 0.027, 0.115), Vector3(0.0, 0.094, -0.13), "steel")
	_add_box(receiver, "BarrelExtensionBlock", Vector3(0.18, 0.145, 0.115), Vector3(0.0, -0.004, -0.125), "steel")
	_add_box(receiver, "Backplate", Vector3(0.17, 0.18, 0.055), Vector3(0.0, 0.0, 0.405), "steel_edge")
	_add_box(receiver, "BufferHousing", Vector3(0.12, 0.11, 0.12), Vector3(0.0, -0.005, 0.47), "receiver")
	_add_box(receiver, "FrontSightBase", Vector3(0.045, 0.065, 0.065), Vector3(0.0, 0.12, -0.245), "steel")
	_add_box(receiver, "FrontSightBlade", Vector3(0.012, 0.075, 0.014), Vector3(0.0, 0.179, -0.245), "steel_edge")
	_add_box(receiver, "RearSightBase", Vector3(0.065, 0.045, 0.06), Vector3(0.0, 0.11, 0.31), "steel")
	_add_box(receiver, "RearSightLeaf", Vector3(0.025, 0.115, 0.023), Vector3(0.0, 0.19, 0.32), "steel_edge")
	_add_box(receiver, "RearAperture", Vector3(0.032, 0.018, 0.018), Vector3(0.0, 0.174, 0.323), "dark")
	_add_cylinder_x(receiver, "ChargingHandleShaft", 0.014, 0.14, Vector3(0.112, 0.01, 0.245), "steel_edge")
	_add_cylinder_x(receiver, "ChargingHandleGrip", 0.021, 0.045, Vector3(0.185, 0.01, 0.245), "dark")
	_add_box(receiver, "ChargingHandleTrack", Vector3(0.025, 0.045, 0.19), Vector3(0.102, 0.012, 0.13), "steel")
	_add_box(receiver, "EjectionPortCover", Vector3(0.016, 0.068, 0.17), Vector3(0.101, -0.035, 0.19), "steel")
	_add_box(receiver, "SearSlide", Vector3(0.045, 0.03, 0.12), Vector3(0.0, -0.112, 0.20), "steel_edge")
	for side: float in [-1.0, 1.0]:
		_add_cylinder_x(receiver, "TrunnionBoss_%s" % _side_name(side), 0.052, 0.036, Vector3(side * 0.093, -0.05, 0.0), "steel")
		_add_cylinder_x(receiver, "TrunnionPin_%s" % _side_name(side), 0.027, 0.012, Vector3(side * 0.105, -0.05, 0.0), "steel_edge")
		for bolt_index: int in range(4):
			var bolt_y: float = -0.04 + float(bolt_index % 2) * 0.075
			var bolt_z: float = 0.015 + float(bolt_index / 2) * 0.22
			_add_sphere(receiver, "SideRivet_%s_%d" % [_side_name(side), bolt_index], 0.01, Vector3(side * 0.101, bolt_y, bolt_z), "steel_edge")

	var barrel := Node3D.new()
	barrel.name = "HeavyBarrelAssembly"
	weapon.add_child(barrel)
	# FM 23-65 gives a 45-inch barrel; the breech-to-muzzle span here is 1.143 m.
	_add_cylinder_z(barrel, "HeavyAirCooledBarrel", 0.029, BARREL_LENGTH_M, Vector3(0.0, 0.0, -0.2415), "steel")
	_add_cylinder_z(barrel, "BarrelRootCollar", 0.052, 0.09, Vector3(0.0, 0.0, -0.125), "steel_edge")
	_add_ring_z(barrel, "BarrelShoulderBand", 0.036, 0.006, Vector3(0.0, 0.0, -0.19), "receiver_light")
	_add_cylinder_z(barrel, "MuzzleCrown", 0.031, 0.027, Vector3(0.0, 0.0, MUZZLE_Z_M + 0.0135), "steel_edge")
	_add_cylinder_z(barrel, "MuzzleBore", 0.018, 0.003, Vector3(0.0, 0.0, MUZZLE_Z_M + 0.0015), "dark")

	var controls := Node3D.new()
	controls.name = "SpadeGripsAndTrigger"
	weapon.add_child(controls)
	_add_box(controls, "GripCrossbar", Vector3(0.30, 0.07, 0.07), Vector3(0.0, 0.0, 0.49), "steel")
	var rear_grip_center_z: float = OVERALL_LENGTH_M + MUZZLE_Z_M - 0.035
	for side: float in [-1.0, 1.0]:
		_add_box(controls, "SpadeGripSupportRail_%s" % _side_name(side), Vector3(0.05, 0.055, 0.30), Vector3(side * 0.12, -0.02, 0.65), "steel")
		_add_box(controls, "SpadeGripStem_%s" % _side_name(side), Vector3(0.055, 0.17, 0.055), Vector3(side * 0.12, -0.075, rear_grip_center_z - 0.016), "steel")
		_add_box(controls, "SpadeGrip_%s" % _side_name(side), Vector3(0.074, 0.19, 0.065), Vector3(side * 0.12, -0.20, rear_grip_center_z), "rubber")
		_add_box(controls, "SpadeGripEnd_%s" % _side_name(side), Vector3(0.078, 0.025, 0.07), Vector3(side * 0.12, -0.302, rear_grip_center_z), "steel_edge")
	_add_box(controls, "ButterflyTrigger", Vector3(0.105, 0.022, 0.04), Vector3(0.0, -0.11, 0.505), "steel_edge")
	_add_box(controls, "TriggerShoe", Vector3(0.038, 0.035, 0.03), Vector3(0.0, -0.125, 0.48), "dark")

	var barrel_support := Node3D.new()
	barrel_support.name = "BarrelSupportLugs"
	weapon.add_child(barrel_support)
	_add_box(barrel_support, "FrontSightProtectionLeft", Vector3(0.018, 0.12, 0.03), Vector3(-0.033, 0.17, -0.255), "steel")
	_add_box(barrel_support, "FrontSightProtectionRight", Vector3(0.018, 0.12, 0.03), Vector3(0.033, 0.17, -0.255), "steel")
