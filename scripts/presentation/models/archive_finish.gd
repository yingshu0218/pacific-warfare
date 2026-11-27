extends RefCounted
## Shared semi-realistic painted finish. No meshes, markings, transforms, or game state change.
const STYLED_META: StringName = &"pacific_archive_finish_v1"

static func apply(model: Node3D, domain: String) -> int:
	var mapped: Dictionary = {}
	var count: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = node as MeshInstance3D
		if part.mesh == null:
			continue
		if part.material_override != null:
			var source: Material = part.material_override
			var result: Material = _finish(source, domain, mapped, str(part.name))
			if result != source:
				part.material_override = result
				count += 1
			continue
		for surface: int in range(part.mesh.get_surface_count()):
			var source: Material = part.get_active_material(surface)
			var result: Material = _finish(source, domain, mapped, str(part.name))
			if result != source:
				part.set_surface_override_material(surface, result)
				count += 1
	return count

static func can_style(source: Material, part_name: String = "") -> bool:
	if not source is StandardMaterial3D:
		return false
	var base: StandardMaterial3D = source
	var label: String = part_name.to_lower()
	if base.roughness < 0.44:
		for hint: String in ["glass", "glazing", "canopy", "windscreen", "windshield", "window", "pane"]:
			if hint in label:
				return false
	# Preserve transparency (including cut-outs), special livery shaders, and lamps.
	return (
		base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		and base.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
		and not base.emission_enabled and not base.refraction_enabled
		and base.albedo_color.a >= 0.999
	)

static func _finish(source: Material, domain: String, mapped: Dictionary, part_name: String) -> Material:
	if not can_style(source, part_name) or source.has_meta(STYLED_META):
		return source
	var key: int = source.get_instance_id()
	if mapped.has(key):
		return mapped[key]
	var base: StandardMaterial3D = source
	var result: StandardMaterial3D = base.duplicate(false) as StandardMaterial3D
	var raw_metal: bool = base.metallic >= 0.45 and base.metallic_texture == null
	if raw_metal:
		# Keep metal readable without letting polished props dominate the painted hull.
		result.roughness = clampf(lerpf(base.roughness, 0.60, 0.65), 0.48, 0.82)
		result.metallic = clampf(base.metallic, 0.45, 0.68)
		result.metallic_specular = minf(base.metallic_specular, 0.46)
	else:
		var target: float = 0.86 if domain == "ship" else 0.77
		result.roughness = clampf(lerpf(base.roughness, target, 0.82), target - 0.085, target + 0.075)
		if base.metallic_texture == null:
			result.metallic = minf(base.metallic, 0.12)
		result.metallic_specular = minf(base.metallic_specular, 0.31 if domain == "ship" else 0.34)
	result.set_meta(STYLED_META, domain)
	mapped[key] = result
	return result
