extends AircraftAdapter

## Private consumption of existing model capabilities only. The missing F6F hook
## is reported by the inspector; this adapter does not invent a new public model.
func apply_state(state: Dictionary) -> void:
	super.apply_state(state)
	# Accepted S04 adapter owns gear/hook/flap presentation, including batch and
	# damage hosts. No second override of flap hinges or gear visibility here.
