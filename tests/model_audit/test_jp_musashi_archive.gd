extends SceneTree
const MODEL := preload("res://scenes/ships/jp_musashi_1944/musashi_visual.tscn")
var errors: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var ship := MODEL.instantiate() as Node3D
	root.add_child(ship)
	await process_frame
	_check(ship.get_meta("art_only",false),"Exhibit must remain nonfunctional")
	var plating := ship.find_child("Hull plating",true,false) as MeshInstance3D
	_check(plating != null,"Hull plating mesh")
	if plating != null:
		var box: AABB = plating.mesh.get_aabb()
		_check(absf(box.size.z-263.0) < .04,"Length envelope")
		_check(absf(box.size.x-38.9) < 1.0,"Breadth envelope")
	for name_id: String in ["Canted single funnel shell","Sloped enclosed command tower",
			"Aft recessed handling platform","Inset longitudinal planking cues","Crane tower"]:
		_check(ship.find_child(name_id,true,false)!=null,"Missing distinct exterior: "+name_id)
	_check_forecastle(ship)
	var mounts := ship.get_node_or_null("ArchiveGunPivots")
	_check(mounts!=null,"No decorative pose group")
	if mounts != null:
		var by_role := {"main":0,"secondary":0,"dedicated_aa":0}
		var forward_main: int = 0
		for m: Node3D in mounts.get_children():
			by_role[m.role] += 1
			if m.role=="main":
				forward_main += int(m.position.z < 0)
			if m.role in ["main","secondary"]:
				_check(m.pitch.get_child_count()==6,"Closed triple outline: "+str(m.name))
				_check(absf(m.position.x)<.001,"Centerline placement: "+str(m.name))
			_check(m.pose(.12,.13),"Individually poseable")
			_check(m.pose(0.,0.),"Neutral reset")
		_check(by_role == {"main":3,"secondary":2,"dedicated_aa":20},"Wrong exhibit grouping")
		_check(forward_main==2,"Forward and aft main enclosure split")
		_check_display_clearance(ship,mounts)
	print("JP_MUSASHI_ARCHIVE checks=",checks," failures=",errors)
	ship.free()
	quit(1 if errors else 0)

func _check_forecastle(ship: Node3D) -> void:
	var rows: Array[Vector4] = ship._stations()
	_check(rows[0].x < rows[1].x and rows[1].y > rows[0].y, "Nose rounds into the deck")
	_check(rows[0].z > rows[8].z, "Forecastle swept sheer")
	var mirrored: bool = true
	var monotone: bool = true
	for i: int in range(11):
		var left: PackedVector3Array = ship._section(rows[i],-1.)
		var right: PackedVector3Array = ship._section(rows[i],1.)
		for j: int in range(3,right.size()):
			mirrored = mirrored and (right[j]*Vector3(-1.,1.,1.)).is_equal_approx(left[j])
			if j>3:
				monotone = monotone and right[j].y >= right[j-1].y
	_check(mirrored and monotone,"Continuous mirrored exposed skin")
	_check(ship.find_children("Oval anchor recess rim*","MeshInstance3D",true,false).size()==2,"Separate anchors on both sides")
	_check(ship.find_children("Paired chain capstan*","MeshInstance3D",true,false).size()==2,"Paired on-deck chain details")

func _check_display_clearance(ship: Node3D,mounts: Node) -> void:
	# Deliberately conservative mesh bounds, not a physical collision model.
	var fixed: Array[MeshInstance3D] = []
	for node: Node in ship.find_children("*","MeshInstance3D",true,false):
		if node.get_parent().name in ["Tall armored bridge and observation galleries",
				"Aft observation tower and handling deck","Open shoulder terraces and funnel"]:
			fixed.append(node as MeshInstance3D)
	var closed: Array[Node3D] = []
	for m: Node3D in mounts.get_children():
		if m.role in ["main","secondary"]:
			closed.append(m)
	for m: Node3D in closed:
		for yaw: float in [-m.yaw_limit_rad,-m.yaw_limit_rad*.5,0.,m.yaw_limit_rad*.5,m.yaw_limit_rad]:
			for pitch: float in [m.pitch_min_rad,0.,m.pitch_max_rad*.5,m.pitch_max_rad]:
				m.pose(yaw,pitch)
				var hit := _first_overlap(_mesh_list(m.train),fixed)
				_check(hit.is_empty(),"%s crosses fixed superstructure at %s: %s" % [m.name,Vector2(yaw,pitch),hit])
		m.pose(0.,0.)
	for i: int in range(closed.size()):
		for j: int in range(i+1,closed.size()):
			var hit := _first_overlap(_mesh_list(closed[i].train),_mesh_list(closed[j].train))
			_check(hit.is_empty(),"Neutral models %s and %s overlap: %s" % [closed[i].name,closed[j].name,hit])

func _mesh_list(parent: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in parent.find_children("*","MeshInstance3D",true,false):
		out.append(child as MeshInstance3D)
	return out

func _first_overlap(a: Array[MeshInstance3D],b: Array[MeshInstance3D]) -> String:
	for p: MeshInstance3D in a:
		var box: AABB = p.global_transform * p.mesh.get_aabb()
		for q: MeshInstance3D in b:
			var other: AABB = q.global_transform * q.mesh.get_aabb()
			if box.intersects(other):
				return "%s / %s" % [p.name,q.name]
	return ""

func _check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		errors+=1
		push_error(label)
