class_name CombatPresence
extends RefCounted

## Authoritative physical/presentation boundary, NOT a commander intelligence API.
## Inactive disabled/sinking/crashing/wreck units remain physically present.
static func has_exited(module_data: Dictionary) -> bool:
	return bool(module_data.get("aircraft_motion", {}).get("exited", false)) or bool(module_data.get("ship_motion", {}).get("exited", false))

static func is_present(module_data: Dictionary) -> bool:
	return not has_exited(module_data) and module_data.get("damage", {}).get("phase", "") != "removed"
