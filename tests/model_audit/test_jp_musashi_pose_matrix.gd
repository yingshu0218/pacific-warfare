extends SceneTree
## Clearance of nonfunctional gallery art. Oriented mesh bounds give a conservative,
## reproducible check; moving parts of the same exhibit intentionally overlap.
const MODEL := preload("res://scenes/ships/jp_musashi_1944/musashi_visual.tscn")
const STEPS_X := 16
const STEPS_Y := 12

class BoxProbe:
	var label: String
	var mount: String
	var center: Vector3
	var half: Vector3
	var axes: Array[Vector3]
	var aabb: AABB

class ShapePose:
	var boxes: Array[BoxProbe] = []
	var envelope: AABB
	var request: Vector2
	func append(box: BoxProbe) -> void:
		envelope = envelope.merge(box.aabb) if not boxes.is_empty() else box.aabb
		boxes.append(box)

class SampleSet:
	var mount: String
	var poses: Array[ShapePose] = []
	var sweep: AABB
	func append(p: ShapePose) -> void:
		sweep = sweep.merge(p.envelope) if not poses.is_empty() else p.envelope
		poses.append(p)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ship: Node3D = MODEL.instantiate()
	root.add_child(ship)
	await process_frame
	var mounts: Node = ship.get_node("ArchiveGunPivots")
	var fixed: Array[BoxProbe] = []
	for layer_name: String in ["Tall armored bridge and observation galleries", "Aft observation tower and handling deck",
			"Open shoulder terraces and funnel","Forecastle planking and fittings","Independent closed display silhouettes"]:
		var layer: Node = ship.get_node(layer_name)
		for node: Node in layer.find_children("*","MeshInstance3D",true,false):
			var mesh := node as MeshInstance3D
			# Planks are one ship-wide batch, not a solid 3-D obstacle.
			if mesh.name=="Inset longitudinal planking cues":
				continue
			fixed.append(_box(mesh,String(mesh.get_meta("exhibit_owner",""))))
	var samples: Array[SampleSet] = []
	var fixed_hits: int = 0
	var fixed_checks: int = 0
	var pairs_checked: int = 0
	var pairs_hits: int = 0
	var movement_failures: int = 0
	for rig: Node3D in mounts.get_children():
		rig.pose(0.,0.)
		var sample_piece := rig.pitch.get_child(0) as Node3D
		var neutral: Transform3D = sample_piece.global_transform
		var base: Transform3D = rig.train.transform
		rig.pose(rig.yaw_limit_rad*.5,0.)
		if rig.train.transform.is_equal_approx(base) or neutral.is_equal_approx(sample_piece.global_transform):
			movement_failures+=1
		rig.pose(0.,rig.pitch_max_rad*.5)
		if not rig.train.transform.is_equal_approx(base) or neutral.is_equal_approx(sample_piece.global_transform):
			movement_failures+=1
		var set_a := SampleSet.new()
		set_a.mount=rig.mount_id
		var hist := {}
		var rest: ShapePose = _sample(rig,0.,0.)
		set_a.append(rest)
		var rest_hit: String = _fixed_hit(rest,fixed,rig.mount_id)
		fixed_checks+=1
		if not rest_hit.is_empty():
			fixed_hits+=1
			hist[rest_hit]=rest_hit+" neutral"
		for i: int in range(STEPS_X+1):
			var yaw: float = lerpf(-rig.yaw_limit_rad,rig.yaw_limit_rad,float(i)/STEPS_X)
			for j: int in range(STEPS_Y+1):
				var pitch: float = lerpf(rig.pitch_min_rad,rig.pitch_max_rad,float(j)/STEPS_Y)
				var p: ShapePose = _sample(rig,yaw,pitch)
				set_a.append(p)
				var hit: String = _fixed_hit(p,fixed,rig.mount_id)
				fixed_checks+=1
				if not hit.is_empty():
					fixed_hits+=1
					var tag: String = hit+" "+str(p.request.snapped(Vector2.ONE))
					if hist.size()<5 and not hist.has(hit): hist[hit]=tag
		rig.pose(0.,0.)
		samples.append(set_a)
		if not hist.is_empty(): print("FIXED ",rig.mount_id," ",hist.values())
	for i: int in range(samples.size()):
		var a: SampleSet = samples[i]
		for j: int in range(i+1,samples.size()):
			var b: SampleSet = samples[j]
			pairs_checked+=a.poses.size()*b.poses.size()
			if not a.sweep.intersects(b.sweep):
				continue
			var hits: int = 0
			var first := ""
			for p: ShapePose in a.poses:
				for q: ShapePose in b.poses:
					if not p.envelope.intersects(q.envelope): continue
					var hit: String = _moving_hit(p,q)
					if not hit.is_empty():
						hits+=1
						if first.is_empty(): first="%s, %s: %s" % [p.request.snapped(Vector2.ONE),q.request.snapped(Vector2.ONE),hit]
			pairs_hits+=hits
			if hits>0: print("PAIR ",a.mount,"/",b.mount," count=",hits," ",first)
	print("MUSASHI_POSE_MATRIX mounts=",samples.size()," fixed_checks=",fixed_checks," fixed_hits=",fixed_hits,
		" pair_checks=",pairs_checked," pair_hits=",pairs_hits," movement_failures=",movement_failures)
	ship.free()
	quit(0 if samples.size()==25 and fixed_hits==0 and pairs_hits==0 and movement_failures==0 else 1)

func _sample(rig: Node3D,yaw: float,pitch: float) -> ShapePose:
	rig.pose(yaw,pitch)
	var p := ShapePose.new()
	p.request=Vector2(rad_to_deg(yaw),rad_to_deg(pitch))
	for node: Node in rig.train.find_children("*","MeshInstance3D",true,false):
		p.append(_box(node as MeshInstance3D,rig.mount_id))
	return p

func _box(mesh: MeshInstance3D,owner_id: String) -> BoxProbe:
	var p:=BoxProbe.new()
	var transform: Transform3D=mesh.global_transform
	var local: AABB=mesh.mesh.get_aabb()
	p.label=str(mesh.name)
	p.mount=owner_id
	p.center=transform*local.get_center()
	var b: Basis=transform.basis
	p.axes=[b.x.normalized(),b.y.normalized(),b.z.normalized()]
	# Small contact tolerance, only for the visual bounding boxes.
	p.half=(local.size*.5*Vector3(b.x.length(),b.y.length(),b.z.length())-Vector3.ONE*.025).max(Vector3.ONE*.005)
	p.aabb=transform*local
	return p

func _fixed_hit(p: ShapePose,fixed: Array[BoxProbe],id: String) -> String:
	for b: BoxProbe in fixed:
		if b.mount==id or not b.aabb.intersects(p.envelope): continue
		for a: BoxProbe in p.boxes:
			if _intersects(a,b): return a.label+" / "+b.label
	return ""

func _moving_hit(p: ShapePose,q: ShapePose) -> String:
	for a: BoxProbe in p.boxes:
		for b: BoxProbe in q.boxes:
			if _intersects(a,b): return a.label+" / "+b.label
	return ""

func _intersects(a: BoxProbe,b: BoxProbe) -> bool:
	if not a.aabb.intersects(b.aabb): return false
	var delta: Vector3=b.center-a.center
	for axis: Vector3 in a.axes:
		if _separated(a,b,delta,axis): return false
	for axis: Vector3 in b.axes:
		if _separated(a,b,delta,axis): return false
	for u: Vector3 in a.axes:
		for v: Vector3 in b.axes:
			var axis: Vector3=u.cross(v)
			if axis.length_squared()>1e-8 and _separated(a,b,delta,axis): return false
	return true

func _separated(a: BoxProbe,b: BoxProbe,d: Vector3,u: Vector3) -> bool:
	var limit: float=0.
	for i: int in range(3):
		limit+=a.half[i]*absf(u.dot(a.axes[i]))+b.half[i]*absf(u.dot(b.axes[i]))
	return absf(u.dot(d))>=limit
