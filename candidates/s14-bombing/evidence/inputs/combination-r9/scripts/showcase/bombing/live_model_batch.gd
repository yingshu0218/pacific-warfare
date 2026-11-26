extends RefCounted

## Preserve mesh references used by the accepted models' pure visual APIs.
## Static siblings still batch; no added geometry, physics or animation state.
static func apply(model: Node3D, key: String) -> void:
	for property: Dictionary in model.get_property_list():
		_collect(model.get(str(property.name)),0)
	StaticModelBatch.apply(model,key)

static func _collect(value: Variant, depth: int) -> void:
	if depth>8: return
	if value is MeshInstance3D:
		(value as MeshInstance3D).set_meta("s14_live_visual",true)
	elif value is Array:
		for item: Variant in value: _collect(item,depth+1)
	elif value is Dictionary:
		for item: Variant in value.values(): _collect(item,depth+1)
