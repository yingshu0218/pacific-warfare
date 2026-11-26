class_name StaticModelBatch
extends RefCounted

## Merge opaque static siblings only. Moving Node3D pivots and sockets survive.
## Cached geometry/materials are shared; instance transforms remain independent.
static var _cache: Dictionary = {}

static func apply(root: Node3D, model_id: String) -> void:
	_batch(root, root, model_id)

static func _batch(node: Node3D, root: Node3D, model_id: String) -> void:
	for child: Node in node.get_children():
		if child is Node3D and not child is MeshInstance3D:
			_batch(child, root, model_id)
	var groups: Dictionary = {}
	for child: Node in node.get_children():
		if not child is MeshInstance3D: continue
		var part: MeshInstance3D = child
		if part.has_meta("s14_live_visual"): continue
		if not part.visible or part.get_child_count() > 0 or part.mesh == null or part.mesh.get_surface_count() != 1: continue
		var material: Material = part.material_override if part.material_override != null else part.mesh.surface_get_material(0)
		if not material is StandardMaterial3D or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var key: String = str(material.get_instance_id()) + ":" + str(part.cast_shadow)
		if not groups.has(key): groups[key] = {"material":material, "parts":[]}
		groups[key].parts.append(part)
	var group_index: int = 0
	for group: Dictionary in groups.values():
		group_index += 1
		if group.parts.size() < 2: continue
		var cache_id: String = model_id + ":" + str(root.get_path_to(node)) + ":" + str(group_index)
		if not _cache.has(cache_id):
			var surface: SurfaceTool = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for part: MeshInstance3D in group.parts:
				var expanded: SurfaceTool = SurfaceTool.new()
				expanded.create_from(part.mesh, 0)
				expanded.deindex()
				surface.append_from(expanded.commit(), 0, part.transform)
			_cache[cache_id] = {"mesh":surface.commit(), "material":group.material}
		var merged: MeshInstance3D = MeshInstance3D.new()
		merged.name = "StaticBatch%d" % group_index
		merged.mesh = _cache[cache_id].mesh
		merged.material_override = _cache[cache_id].material
		merged.cast_shadow = (group.parts[0] as MeshInstance3D).cast_shadow
		node.add_child(merged)
		for part: MeshInstance3D in group.parts:
			node.remove_child(part)
			part.free()
