extends AircraftAdapter

## Private consumption of existing model capabilities only. The missing F6F hook
## is reported by the inspector; this adapter does not invent a new public model.
func apply_state(state: Dictionary) -> void:
	super.apply_state(state)
	var s: Dictionary = state.get("module_data",{}).get("carrier_ops",{})
	model_root.landing_gear.visible = bool(s.get("gear_down",false))
	for surface: Node3D in model_root.animated_surfaces:
		if "flap" in str(surface.name).to_lower(): surface.rotation.x = deg_to_rad(35.0) if bool(s.get("flaps_down",false)) else 0.0
