extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var checks := 0
	var problems: Array[String] = []
	for id: String in ["nagato"]:
		var scene := load("res://scenes/ships/jp_nagato/%s_visual.tscn" % id) as PackedScene
		if scene == null:
			problems.append(id + " scene missing")
			continue
		var ship := scene.instantiate() as Node3D
		root.add_child(ship)
		await process_frame
		checks += 3
		var pivots := ship.get_node_or_null("ArchiveGunPivots")
		if pivots == null:
			problems.append(id + " no rigs")
			continue
		checks += 6
		if ship.get_meta("exterior_revision",0) != 2: problems.append(id + " old exterior loaded")
		for part: String in ["Shaped single funnel shell", "Recessed dark funnel opening",
			"Restrained longitudinal plank seams", "Stern crane upright"]:
			if ship.find_child(part,true,false) == null: problems.append(id + " missing " + part)
		if ship.find_children("Shaped bridge balcony *","MeshInstance3D",true,false).size() != 8:
			problems.append(id + " bridge levels missing")
		var rigs := pivots.get_children()
		if rigs.size() != 10:
			problems.append(id + " wrong rig count")
		if ship.find_children("*","MeshInstance3D",true,false).size() < 200:
			problems.append(id + " exterior missing")
		for rig: Node3D in rigs:
			var housing: Node3D = rig.train.get_children().filter(func(n: Node) -> bool: return n != rig.pitch)[0]
			var spar: Node3D = rig.pitch.get_child(0)
			var idle_hull := ship.global_transform
			var neutral_hull := housing.global_transform
			var neutral_spar := spar.global_transform
			var neighbours: Dictionary = {}
			for other: Node3D in rigs:
				if other != rig:
					neighbours[other] = other.pitch.global_transform
			checks += 5 + neighbours.size()
			if not rig.pose(.35, .23): problems.append("%s pose failed" % str(rig.name))
			if housing.global_transform.is_equal_approx(neutral_hull): problems.append("%s no traverse" % str(rig.name))
			if spar.global_transform.is_equal_approx(neutral_spar): problems.append("%s no pose" % str(rig.name))
			for other: Node3D in neighbours:
				if not other.pitch.global_transform.is_equal_approx(neighbours[other]):
					problems.append("%s moved adjacent turret %s" % [str(rig.name), str(other.name)])
			if not ship.global_transform.is_equal_approx(idle_hull): problems.append("Hull moved")
			rig.pose(0.,0.)
			if not neutral_hull.is_equal_approx(housing.global_transform) or not neutral_spar.is_equal_approx(spar.global_transform):
				problems.append("%s neutral reset failure" % str(rig.name))
		ship.free()
	for msg: String in problems:
		push_error(msg)
	print("JP_NAGATO checks=",checks," failures=",problems.size())
	quit(1 if not problems.is_empty() else 0)
