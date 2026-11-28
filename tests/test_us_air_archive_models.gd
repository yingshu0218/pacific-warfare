extends SceneTree
## Independent art admission, not the production flight or battle loader.
const AIRCRAFT: Dictionary = {
	"fm2":[11.58,8.81],
	"pby5a":[31.699,19.456],
	"p51d":[11.28,9.83],
	"b29":[43.053,30.1752],
}
var failures: int = 0

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	for slug: String in AIRCRAFT:
		var source: String = "res://aircraft/us_archive/%s.tscn" % slug
		var pack: PackedScene = load(source)
		if pack == null:
			_fail("Missing independent model: "+source)
			continue
		var model: Node3D = pack.instantiate() as Node3D
		root.add_child(model)
		await process_frame
		await process_frame
		var have_geometry: bool = false
		var bounds: AABB
		var mesh_count: int = 0
		for child: Node in model.find_children("*","MeshInstance3D",true,false):
			var shape: MeshInstance3D = child as MeshInstance3D
			if shape.mesh == null or not shape.is_visible_in_tree():
				continue
			var transformed: AABB = (model.global_transform.affine_inverse() * shape.global_transform) * shape.get_aabb()
			if not transformed.position.is_finite() or not transformed.size.is_finite():
				_fail("Invalid visible bounds: "+slug)
				continue
			bounds = bounds.merge(transformed) if have_geometry else transformed
			have_geometry = true
			mesh_count += 1
		var expected: Array = AIRCRAFT[slug]
		if not have_geometry or mesh_count < 12 or absf(bounds.size.x-float(expected[0])) > .015*float(expected[0]) or absf(bounds.size.z-float(expected[1])) > .025*float(expected[1]):
			_fail("Model measurable outline mismatch: "+slug+" "+str(bounds))
		if not model.find_children("*","CollisionObject3D",true,false).is_empty():
			_fail("Unexpected physics component in static model: "+slug)
		var palette: Dictionary = model.get("paint")
		var skin: StandardMaterial3D = palette.get("skin")
		var glass: StandardMaterial3D = palette.get("glass")
		if skin == null or not is_equal_approx(skin.roughness,.76) or not is_equal_approx(skin.metallic,.1):
			_fail("Model did not adopt the batch satin skin: "+slug)
		if glass == null or not is_equal_approx(glass.roughness,.29) or not glass.albedo_color.is_equal_approx(Color("355267")):
			_fail("Model did not adopt the batch glazing: "+slug)
		print(slug,": visible mesh count=",mesh_count," span_m=",snappedf(bounds.size.x,.01)," length_m=",snappedf(bounds.size.z,.01))
		model.free()
	quit(1 if failures > 0 else 0)

func _fail(reason: String) -> void:
	failures += 1
	push_error(reason)
