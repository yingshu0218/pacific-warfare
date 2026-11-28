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
	print("JP_MUSASHI_ARCHIVE checks=",checks," failures=",errors)
	ship.free()
	quit(1 if errors else 0)

func _check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		errors+=1
		push_error(label)
