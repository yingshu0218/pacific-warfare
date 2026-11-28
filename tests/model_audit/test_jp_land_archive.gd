extends SceneTree
## Standalone archives only: normal geometry, no simulation parts.

const STUDIES := {
	"ki43_ii": {"width":10.84,"length":8.92,"proof":"ClosedDarkRadialFace","absent":"ClosedRoundedRadiatorHousing"},
	"ki61_i": {"width":12.0,"length":8.74,"proof":"ClosedRoundedRadiatorHousing","absent":"ClosedDarkRadialFace"},
}

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(valid: bool,message: String) -> void:
	if not valid:
		failures += 1
		push_error(message)

func _run() -> void:
	for name_id: String in STUDIES:
		var spec: Dictionary = STUDIES[name_id]
		var scene := load("res://aircraft/jp_land_archive/%s.tscn"%name_id) as PackedScene
		_expect(scene != null,name_id+" scene loads")
		if scene == null: continue
		var model := scene.instantiate() as Node3D
		root.add_child(model)
		await process_frame
		var parts := model.find_children("*","MeshInstance3D",true,false)
		_expect(parts.size() >= 75,name_id+" visible structured details")
		_expect(model.find_child(spec.proof,true,false) != null,name_id+" type-specific identity mesh")
		_expect(model.find_child(spec.absent,true,false) == null,name_id+" no engine geometry from other exhibit")
		_expect(model.find_children("*","CollisionObject3D",true,false).is_empty(),name_id+" archive does not affect collision")
		_expect(model.find_children("*","AnimationPlayer",true,false).is_empty(),name_id+" archive remains static")
		var bounds := AABB()
		var first: bool = true
		for part: MeshInstance3D in parts:
			var mesh := part.mesh
			_expect(mesh != null and mesh.get_surface_count() >= 1 and part.material_override is StandardMaterial3D,name_id+" visible mesh and material")
			if mesh == null: continue
			var child_box := part.global_transform * mesh.get_aabb()
			_expect(child_box.position.is_finite() and child_box.size.is_finite(),name_id+" finite bounds")
			bounds = child_box if first else bounds.merge(child_box)
			first = false
		_expect(absf(bounds.size.x-float(spec.width)) < .11,name_id+" representative span")
		_expect(absf(bounds.size.z-float(spec.length)) < .13,name_id+" representative length")
		print(name_id, " count=",parts.size()," visual envelope W/H/L ",bounds.size)
		model.free()
	print("JP_LAND_ARCHIVE failures=",failures)
	quit(0 if failures == 0 else 1)
