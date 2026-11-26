extends SceneTree

func _initialize() -> void:
	call_deferred("audit")

func audit() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var observations: Array[Dictionary] = []
	for entry: Dictionary in scene.weapons:
		var mount: WeaponMount = entry.pivot
		mount.set_process(false)
		observations.append({"id":str(mount.name),"train_min":0.0,"train_max":0.0,"elevation_min":0.0,"elevation_max":0.0,"blocked_steps":0})
	for step: int in range(600):
		for index: int in range(scene.weapons.size()):
			var mount: WeaponMount = scene.weapons[index].pivot
			mount._process(0.1)
			var observation: Dictionary = observations[index]
			var train: float = rad_to_deg(mount.rotation.y-mount.base_heading)
			var elevation: float = rad_to_deg(mount.elevation_axis.rotation.x)
			observation.train_min = minf(observation.train_min,train)
			observation.train_max = maxf(observation.train_max,train)
			observation.elevation_min = minf(observation.elevation_min,elevation)
			observation.elevation_max = maxf(observation.elevation_max,elevation)
			if mount.obstructed:
				observation.blocked_steps += 1
				observation["last_obstruction_point"] = mount.get_meta("last_obstruction_point",[])
	var stuck: Array[String] = []
	for observation: Dictionary in observations:
		if observation.train_max-observation.train_min < 0.1 or observation.elevation_max-observation.elevation_min < 0.1: stuck.append(observation.id)
	var file: FileAccess = FileAccess.open("res://docs/guarded_motion_audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"duration_seconds":60,"step_seconds":0.1,"stuck_mounts":stuck,"observations":observations},"\t"))
	print("Guarded motion audit: ",stuck.size()," mounts with less than 0.1 degree movement on either axis: ",stuck)
	assert(stuck.is_empty(),"Every guarded weapon must show movement on both axes over the 60-second demonstration")
	quit()
