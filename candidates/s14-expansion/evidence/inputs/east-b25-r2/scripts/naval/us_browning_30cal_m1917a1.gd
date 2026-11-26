@tool
extends NavalMachineGunVisualBase
class_name USBrowning30CalM1917A1

const BARREL_LENGTH_M: float = 0.60706
const OVERALL_LENGTH_M: float = 0.98146


func _build_weapon(weapon: Node3D) -> void:
	var bore_reference := get_node("Generated/MountInterface/BoreAxisReference") as Marker3D
	bore_reference.position = Vector3(0.0, 0.05, -BARREL_LENGTH_M)
	weapon.position.y = 0.05

	var cooling := Node3D.new()
	cooling.name = "WaterCoolingAssembly"
	weapon.add_child(cooling)
	_add_cylinder_z(cooling, "WaterJacket", 0.052, 0.40, Vector3(0.0, 0.0, -0.28), "jacket")
	_add_cylinder_z(cooling, "JacketRearCollar", 0.056, 0.035, Vector3(0.0, 0.0, -0.0775), "steel_edge")
	_add_ring_z(cooling, "JacketFrontBead", 0.051, 0.008, Vector3(0.0, 0.0, -0.48), "steel_edge")
	_add_ring_z(cooling, "JacketRearSeam", 0.052, 0.005, Vector3(0.0, 0.0, -0.095), "steel")
	_add_box(cooling, "JacketDrainBoss", Vector3(0.046, 0.044, 0.04), Vector3(0.0, -0.053, -0.42), "receiver_light")
	_add_cylinder_y(cooling, "DrainPlug", 0.011, 0.016, Vector3(0.0, -0.082, -0.42), "steel_edge")
	_add_cylinder_z(cooling, "Barrel", 0.017, BARREL_LENGTH_M, Vector3(0.0, 0.0, -BARREL_LENGTH_M * 0.5), "steel")
	_add_cylinder_z(cooling, "MuzzleCrown", 0.02, 0.022, Vector3(0.0, 0.0, -0.596), "steel_edge")
	_add_cylinder_z(cooling, "MuzzleBore", 0.011, 0.003, Vector3(0.0, 0.0, -0.6055), "dark")

	var steam_tube := Node3D.new()
	steam_tube.name = "SteamTubeAssembly"
	weapon.add_child(steam_tube)
	_add_cylinder_z(steam_tube, "InnerSteamTube", 0.007, 0.385, Vector3(0.0, 0.039, -0.28), "steel_edge")
	_add_cylinder_z(steam_tube, "SteamTubeOuterSleeve", 0.009, 0.16, Vector3(0.0, 0.039, -0.28), "steel")

	var receiver := Node3D.new()
	receiver.name = "ReceiverAndFeed"
	weapon.add_child(receiver)
	_add_box(receiver, "MainReceiver", Vector3(0.14, 0.15, 0.32), Vector3(0.0, 0.0, 0.15), "receiver")
	_add_box(receiver, "LockingFrame", Vector3(0.125, 0.13, 0.13), Vector3(0.0, 0.0, -0.075), "steel")
	_add_box(receiver, "TopFeedCover", Vector3(0.13, 0.03, 0.205), Vector3(0.0, 0.089, 0.105), "receiver_light")
	_add_box(receiver, "CoverHinge", Vector3(0.018, 0.04, 0.035), Vector3(0.0, 0.089, 0.25), "steel_edge")
	_add_box(receiver, "FeedTray", Vector3(0.17, 0.024, 0.10), Vector3(0.0, 0.078, -0.09), "steel")
	_add_box(receiver, "RearBufferPlate", Vector3(0.14, 0.15, 0.04), Vector3(0.0, 0.0, 0.335), "steel_edge")
	_add_box(receiver, "SightMountBlock", Vector3(0.05, 0.04, 0.06), Vector3(0.0, 0.09, 0.245), "steel")
	_add_box(receiver, "RearApertureSight", Vector3(0.024, 0.08, 0.022), Vector3(0.0, 0.15, 0.28), "steel_edge")
	_add_cylinder_x(receiver, "ChargingHandle", 0.011, 0.11, Vector3(0.098, 0.005, 0.205), "steel_edge")
	_add_cylinder_x(receiver, "ChargingHandleKnob", 0.016, 0.032, Vector3(0.158, 0.005, 0.205), "dark")
	_add_box(receiver, "LeftSidePlate", Vector3(0.012, 0.098, 0.23), Vector3(-0.073, -0.005, 0.13), "receiver_light")
	_add_box(receiver, "RightSidePlate", Vector3(0.012, 0.098, 0.23), Vector3(0.073, -0.005, 0.13), "receiver_light")
	for side: float in [-1.0, 1.0]:
		for bolt_index: int in range(3):
			_add_sphere(receiver, "ReceiverRivet_%s_%d" % [_side_name(side), bolt_index], 0.008, Vector3(side * 0.082, 0.025, 0.04 + float(bolt_index) * 0.065), "steel_edge")
		_add_cylinder_x(receiver, "TrunnionBoss_%s" % _side_name(side), 0.038, 0.02, Vector3(side * 0.088, -0.05, 0.0), "steel")
		_add_cylinder_x(receiver, "TrunnionPinHead_%s" % _side_name(side), 0.019, 0.008, Vector3(side * 0.102, -0.05, 0.0), "steel_edge")

	var controls := Node3D.new()
	controls.name = "RearPistolGripAndBufferTube"
	weapon.add_child(controls)
	var rear_end_z: float = OVERALL_LENGTH_M - BARREL_LENGTH_M
	_add_cylinder_z(controls, "BufferTube", 0.034, 0.0608, Vector3(0.0, 0.0, rear_end_z - 0.0304), "steel")
	_add_cylinder_z(controls, "BufferTubeEndCap", 0.037, 0.006, Vector3(0.0, 0.0, rear_end_z - 0.003), "steel_edge")
	var pistol_grip := _add_box(controls, "WoodPistolGrip", Vector3(0.075, 0.16, 0.085), Vector3(0.0, -0.06, 0.25), "wood")
	pistol_grip.rotation.x = deg_to_rad(-24.0)
	_add_cylinder_x(controls, "PistolGripScrew", 0.009, 0.08, Vector3(0.0, -0.075, 0.265), "steel_edge")
	_add_box(controls, "TriggerGuardTop", Vector3(0.12, 0.016, 0.09), Vector3(0.0, -0.082, 0.145), "steel")
	_add_box(controls, "TriggerGuardPort", Vector3(0.016, 0.065, 0.09), Vector3(-0.052, -0.121, 0.145), "steel")
	_add_box(controls, "TriggerGuardStarboard", Vector3(0.016, 0.065, 0.09), Vector3(0.052, -0.121, 0.145), "steel")
	_add_box(controls, "TriggerGuardBottom", Vector3(0.12, 0.016, 0.09), Vector3(0.0, -0.165, 0.145), "steel")
	_add_cylinder_x(controls, "Trigger", 0.009, 0.045, Vector3(0.0, -0.10, 0.105), "steel_edge")

	var filler := Node3D.new()
	filler.name = "WaterJacketFillerAndSights"
	weapon.add_child(filler)
	_add_cylinder_y(filler, "FillerNeck", 0.018, 0.024, Vector3(0.0, 0.061, -0.12), "steel_edge")
	_add_cylinder_y(filler, "FillerCap", 0.031, 0.016, Vector3(0.0, 0.081, -0.12), "receiver_light")
	_add_box(filler, "FrontSightFoot", Vector3(0.032, 0.045, 0.05), Vector3(0.0, 0.07, -0.49), "steel")
	_add_box(filler, "FrontSightBlade", Vector3(0.011, 0.06, 0.012), Vector3(0.0, 0.12, -0.49), "steel_edge")
