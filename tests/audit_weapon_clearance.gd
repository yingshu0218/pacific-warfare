extends SceneTree

func _initialize() -> void:
	call_deferred("audit")

func audit() -> void:
	var builder: Node3D = load("res://scripts/ship_geometry.gd").new()
	root.add_child(builder)
	builder.load_mount_layout()
	var findings: Array[Dictionary] = []
	for entry: Dictionary in builder.weapons:
		var mount: WeaponMount = entry.pivot
		mount.set_process(false)
		mount.rotation.y = mount.base_heading
	for entry: Dictionary in builder.weapons:
		var mount: WeaponMount = entry.pivot
		if mount.get_meta("profile") != "main": continue
		for train: int in range(-150,151,5):
			mount.rotation.y = mount.base_heading+deg_to_rad(train)
			for elevation: int in [-5,0,10,20,30,45]:
				mount.elevation_axis.rotation.x = deg_to_rad(elevation)
				for barrel: int in range(3):
					var start: Vector3 = mount.elevation_axis.global_transform*Vector3((barrel-1)*3.05,0,0)
					var end: Vector3 = mount.elevation_axis.global_transform*Vector3((barrel-1)*3.05,0,-17.5)
					for target_entry: Dictionary in builder.weapons:
						var target: WeaponMount = target_entry.pivot
						if target == mount or target.get_meta("profile") not in ["main","secondary"]: continue
						for child: Node in target.get_children():
							if not child is MeshInstance3D: continue
							var part: MeshInstance3D = child
							var faces: PackedVector3Array = part.mesh.get_faces()
							var local_start: Vector3 = part.global_transform.affine_inverse()*start
							var local_end: Vector3 = part.global_transform.affine_inverse()*end
							for index: int in range(0,faces.size(),3):
								var hit: Variant = Geometry3D.segment_intersects_triangle(local_start,local_end,faces[index],faces[index+1],faces[index+2])
								if hit != null:
									findings.append({"mount":str(mount.name),"target":str(target.name),"train":train,"elevation":elevation,"barrel":barrel+1})
									break
		mount.rotation.y = mount.base_heading
		mount.elevation_axis.rotation.x = 0
	var output: FileAccess = FileAccess.open("res://docs/weapon_clearance_audit.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"method":"barrel centerline versus adjacent train-fixed turret triangles; targets neutral; excludes barrel thickness, gun bodies and ship structures","findings":findings},"\t"))
	print("Clearance audit: ",findings.size()," intersecting centerline cases")
	quit()
