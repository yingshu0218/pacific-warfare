extends SceneTree
## Exhibit-only checks: shape grouping and decorative previews, not combat or exact historical counts.
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var scenes := {
		"Nagato": ["res://scenes/ships/jp_nagato/nagato_visual.tscn",{"main":4,"secondary":16,"dedicated_aa":6}],
		"Kaga": ["res://scenes/ships/jp_fleet_carriers/kaga_visual.tscn",{"secondary":10,"dedicated_aa":14}],
		"Hiryu": ["res://scenes/ships/jp_fleet_carriers/hiryu_visual.tscn",{"secondary":6,"dedicated_aa":6}]
	}
	for name_id: String in scenes:
		var model := (load(scenes[name_id][0]) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		await process_frame
		var counts := {}
		var sides := {}
		var mounts: Node = model.get_node_or_null("ArchiveGunPivots")
		_check(mounts != null, name_id+" lacks preview group")
		if mounts == null:
			model.free()
			continue
		for mount: Node3D in mounts.get_children():
			counts[mount.role] = int(counts.get(mount.role,0))+1
			if mount.role=="main":
				_check(mount.pitch.get_child_count()==6, name_id+" main displays should each contain two three-piece outlines")
			if mount.role=="secondary":
				sides[signf(mount.position.x)] = int(sides.get(signf(mount.position.x),0))+1
				var single: bool = name_id != "Hiryu"
				_check(mount.pitch.get_child_count()==(1 if single else 2),name_id+" wrong closed outline pattern")
				_check(mount.position.y<10. if single else mount.position.y>10.,name_id+" wrong vertical display band")
		_check(counts==scenes[name_id][1],name_id+" wrong role breakdown: "+str(counts))
		_check(sides.get(-1.,0)==sides.get(1.,-1),name_id+" incomplete paired sides")
		if name_id!="Nagato":
			var island_name := "StarboardBridge" if name_id=="Kaga" else "PortBridge"
			var other_name := "PortBridge" if name_id=="Kaga" else "StarboardBridge"
			var island := model.get_node_or_null(island_name) as Node3D
			_check(island != null and model.get_node_or_null(other_name)==null,name_id+" bridge identity failed")
			if island != null:
				var base := island.find_child("Long low bridge plinth",true,false) as Node3D
				_check(base != null and signf(base.position.x)==(1. if name_id=="Kaga" else -1.),name_id+" bridge on wrong side")
			var low_boxes := model.find_children("Kaga inset hull casemate*","MeshInstance3D",true,false)
			_check(low_boxes.size()==(10 if name_id=="Kaga" else 0), name_id+" incorrect carryover of casemate shape")
		model.free()
	print("JP_EXHIBIT_REFIT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func _check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
