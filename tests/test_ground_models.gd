extends SceneTree
var failures: PackedStringArray = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	var specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ground/models.json"))
	var audit: Dictionary = {"checks":[],"models":{}}
	for id: String in specs:
		var packed: PackedScene = load("res://scenes/ground/"+id+".tscn")
		var model: GroundUnitModel = packed.instantiate() as GroundUnitModel
		var twin: GroundUnitModel = packed.instantiate() as GroundUnitModel
		root.add_child(model)
		root.add_child(twin)
		var socket: MountSocket = MountSocket.from_data(model.spec.mount)
		var mount_id: String = str(model.spec.mount.id)
		check(model.mount_visuals.size()==1,id+": one independent single mount")
		check(not model.is_processing(),id+": passive model has no clock")
		check(model.scale.is_equal_approx(Vector3.ONE),id+": metre scale")
		var untouched: Transform3D = twin.muzzle_transform_local(mount_id,0)
		var angles: Array[Vector2] = [Vector2.ZERO,Vector2(.4,.2),Vector2(-.7,deg_to_rad(float(model.spec.elevation_limits_deg[1]))),Vector2(.1,deg_to_rad(float(model.spec.elevation_limits_deg[0])))]
		var samples: Array = []
		for pose: Vector2 in angles:
			check(model.apply_weapon_state(mount_id,{"train_rad":pose.x,"elevation_rad":pose.y}),id+": finite pose accepted")
			var actual: Transform3D = model.muzzle_transform_local(mount_id,0)
			var expected: Transform3D = socket.local_muzzle_transform(0,pose.x,pose.y)
			check(actual.origin.distance_to(expected.origin)<.0001,id+": data matches physical muzzle")
			check((-actual.basis.z).dot(-expected.basis.z)>.99999,id+": correct bore direction")
			check(actual.origin.y>.2,id+": depressed muzzle clears ground")
			samples.append({"train":pose.x,"elevation":pose.y,"muzzle_m":SimData.array3(actual.origin)})
		check(twin.muzzle_transform_local(mount_id,0).is_equal_approx(untouched),id+": separate instance unaffected")
		check(not model.apply_weapon_state(mount_id,{"train_rad":NAN}),id+": nonfinite rejected")
		check((model.parts.seat as Marker3D).global_position.distance_to((model.parts.train as Node3D).global_position)<.0001,id+": physical host seat joins train axis")
		for foot: Vector3 in model.parts.contacts:
			check(mesh_contact(model.parts.foundation,foot+Vector3.UP*.002,foot+Vector3.DOWN*.02),id+": actual bottom contact face")
		var mesh_count: int = model.find_children("*","MeshInstance3D",true,false).size()
		var triangles: int = 0
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false): triangles += mesh.mesh.get_faces().size()/3
		audit.models[id] = {"poses":samples,"mesh_instances":mesh_count,"triangles":triangles,"contacts":model.parts.contacts.map(func(p: Vector3) -> Array:return SimData.array3(p))}
		model.free();twin.free()
	audit.check_count=checks;audit.failures=Array(failures)
	FileAccess.open("res://docs/showcase/evidence/S10/model_checks.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"\t"))
	if not failures.is_empty():
		for failure: String in failures: push_error(failure)
	print("S10_MODEL_CHECKS ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func mesh_contact(host: Node3D, a: Vector3, b: Vector3) -> bool:
	for mesh: MeshInstance3D in host.find_children("*","MeshInstance3D",true,false):
		var local: Transform3D = mesh.global_transform.affine_inverse()
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for index: int in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(local*a,local*b,faces[index],faces[index+1],faces[index+2])!=null: return true
	return false
