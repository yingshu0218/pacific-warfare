extends Node3D
## Static installation only. Reads existing aircraft; no copied geometry or movement.
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const F6F: PackedScene = preload("res://aircraft/scenes/f6f5.tscn")
const SB2C: PackedScene = preload("res://aircraft/sb2c4/sb2c4.tscn")
var aircraft: Array[Node3D] = []

func _ready() -> void:
	_add_f6f("F6F_ForwardPark",Vector3(-2,15.85,-57))
	_add_f6f("F6F_ForwardElevator",Vector3(0,15.85,-89))
	var mount: Node3D = H.group(self,"SB2C_AftPark",Vector3(-2,15.85,83))
	var model: Node3D = SB2C.instantiate() as Node3D
	model.set("flight_simplified",true)
	mount.add_child(model)
	model.call("set_showcase_configuration",true)
	model.call("set_landing_gear_deployed",true)
	model.transform = model.call("get_parked_transform")
	aircraft.append(model)
	H.batch_static(model,[_find_gear(model)])

func _add_f6f(id: String, at: Vector3) -> void:
	var mount: Node3D = H.group(self,id,at)
	var model: Node3D = F6F.instantiate() as Node3D
	model.set("flight_simplified",true)
	mount.add_child(model)
	aircraft.append(model)
	H.batch_static(model,[_find_gear(model)])

func _find_gear(model: Node3D) -> Node3D:
	return model.get("landing_gear") as Node3D
