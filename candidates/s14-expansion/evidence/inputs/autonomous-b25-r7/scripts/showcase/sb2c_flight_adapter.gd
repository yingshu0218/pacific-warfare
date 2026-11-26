class_name SB2CFlightAdapter
extends Node3D

## The existing model is a read-only dependency; no local flight or damage roll.
var model_root: PacificAircraftBuilder

func _ready() -> void:
	model_root = preload("res://aircraft/sb2c4/sb2c4.gd").new() as PacificAircraftBuilder
	model_root.position.y = -2.38
	add_child(model_root)
	model_root.call("set_showcase_configuration",true)
	model_root.landing_gear.visible = false
	StaticModelBatch.apply(model_root, "s14_sb2c4")

func apply_state(view: Dictionary) -> void:
	position = view.position_m
	rotation = view.rotation_rad
	var damage: Dictionary = view.module_data.get("damage", {})
	visible = bool(view.active) or str(damage.get("phase", "")) in ["crashing", "wreck"]
	var flight: Dictionary = view.module_data.get("aircraft_motion", {})
	model_root.propeller.rotation.z = float(flight.get("propeller_phase_rad", 0.0))
	model_root.landing_gear.visible = false
	for surface: Node3D in model_root.animated_surfaces:
		var label: String = str(surface.name).to_lower()
		if "aileron" in label: surface.rotation.z = float(flight.get("aileron_rad", 0.0)) * (-1.0 if "port" in label else 1.0)
		elif "elevator" in label: surface.rotation.x = float(flight.get("elevator_rad", 0.0))

func mount_sockets() -> Array[Dictionary]: return []
func apply_weapon_state(_id: String, _state: Dictionary) -> bool: return false
