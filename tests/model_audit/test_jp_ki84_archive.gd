extends SceneTree

const STUDY := preload("res://aircraft/jp_ki84_archive/ki84_ia.tscn")

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(valid: bool, message: String) -> void:
	if not valid:
		failures += 1
		push_error(message)

func _run() -> void:
	var model := STUDY.instantiate() as Node3D
	root.add_child(model)
	await process_frame
	var prop := model.find_child("FourBladeDisplayPropeller",true,false)
	_expect(prop != null,"Ki-84 unique four-blade static display hub")
	if prop != null:
		_expect(prop.find_children("StaticBlade_*","Node3D",false,false).size() == 4,"exactly four native blade mesh roots")
	for id: String in ["TallRoundShoulderedFin","ClosedShortChinFairing","RaisedCanopy","PortDisplayGear","StarboardDisplayGear"]:
		_expect(model.find_child(id,true,false) != null,"Ki-84 missing %s"%id)
	var wings := model.find_children("TaperedLowWing_*","MeshInstance3D",true,false)
	_expect(wings.size() == 2,"one mainplane per side")
	for wing: MeshInstance3D in wings:
		var shades: PackedColorArray = wing.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var has_yellow := false
		for shade: Color in shades:
			if shade.r > shade.g * 1.15 and shade.g > shade.b * 1.7:
				has_yellow = true
				break
		_expect(has_yellow,"painted continuous leading-edge recognition strip")
	for not_allowed: String in ["CollisionObject3D","AnimationPlayer","RigidBody3D","Timer"]:
		_expect(model.find_children("*",not_allowed,true,false).is_empty(),"archive model has no %s"%not_allowed)
	var parts := model.find_children("*","MeshInstance3D",true,false)
	_expect(parts.size() > 100,"Ki-84 geometry has full exterior detailing")
	var bounds := AABB()
	var first: bool = true
	for part: MeshInstance3D in parts:
		var mesh := part.mesh
		_expect(mesh != null and mesh.get_surface_count() > 0 and part.material_override is StandardMaterial3D,"mesh with assigned exterior material")
		if mesh == null: continue
		var child_box := part.global_transform * mesh.get_aabb()
		_expect(child_box.position.is_finite() and child_box.size.is_finite(),"finite geometry")
		bounds = child_box if first else bounds.merge(child_box)
		first = false
	_expect(absf(bounds.size.x-11.24) < .12,"representative span")
	_expect(absf(bounds.size.z-9.92) < .13,"representative length")
	_expect(bounds.size.y > 3.1 and bounds.size.y < 3.6,"representative height")
	print("KI84_ARCHIVE meshes=",parts.size()," envelope W/H/L=",bounds.size," failures=",failures)
	model.free()
	quit(0 if failures == 0 else 1)
