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
		var profile_id: String = str(mount.get_meta("profile"))
		if profile_id not in ["light_aa","heavy_aa"]: continue
		var record: Dictionary = {}
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/yamato_1944_mounts.json"))
		for item: Dictionary in layout.mounts:
			if item.id == str(mount.name): record = item
		if record.get("shield_variant","") != "enclosed": continue
		var profile: Dictionary = builder.weapon_profiles[profile_id]
		var targets: Array[Dictionary] = []
		for child: Node in mount.get_children():
			if child is MeshInstance3D:
				var part: MeshInstance3D = child
				targets.append({"inverse":part.global_transform.affine_inverse(),"mesh":part.mesh.generate_triangle_mesh()})
		var scale_factor: float = float(mount.get_meta("geometry_scale"))
		for elevation: int in range(int(mount.elevation_limits.x),int(mount.elevation_limits.y)+1):
			mount.elevation_axis.rotation.x = deg_to_rad(elevation)
			for barrel: int in range(int(record.barrels)):
				var x: float = (barrel-(int(record.barrels)-1)*0.5)*float(profile.gun_spacing)
				for sample: int in range(9):
					var radial: Vector2 = Vector2.ZERO if sample == 0 else Vector2.from_angle((sample-1)*TAU/8)
					var start: Vector3 = mount.elevation_axis.global_transform*Vector3(x+radial.x*0.8*scale_factor,radial.y*0.8*scale_factor,0)
					var end: Vector3 = mount.elevation_axis.global_transform*Vector3(x+radial.x*0.29*scale_factor,radial.y*0.29*scale_factor,-float(profile.forward_barrel_length))
					for target: Dictionary in targets:
						var hit: Dictionary = (target.mesh as TriangleMesh).intersect_segment(target.inverse*start,target.inverse*end)
						if not hit.is_empty():
							findings.append({"id":str(mount.name),"elevation":elevation,"barrel":barrel+1,"radial_sample":sample})
	var file: FileAccess = FileAccess.open("res://docs/aa_shield_clearance_audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"method":"barrel centerline plus 8 tapered surface rays vs own fixed geometry; 1-degree steps; discrete approximation, excludes collars and breech","findings":findings},"\t"))
	print("Own-shield clearance audit: ",findings.size()," intersecting samples")
	assert(findings.is_empty(),"Sampled barrel envelopes must clear their own fixed shields throughout elevation range")
	quit()
