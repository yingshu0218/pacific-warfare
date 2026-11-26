extends SceneTree

const ADAPTER: Script = preload("res://scripts/presentation/models/capital_ship_adapter.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id: String in ["jp_yamato_1944_04","us_iowa_bb61_1944_12_28"]:
		var model: CapitalShipAdapter = ADAPTER.new() as CapitalShipAdapter
		model.model_id = id
		root.add_child(model)
		var groups: Dictionary = {}
		var total: int = 0
		for child: Node in model.find_children("*","MeshInstance3D",true,false):
			var part: MeshInstance3D = child as MeshInstance3D
			var count: int = part.mesh.get_faces().size()/3
			total += count
			var parent: String = str(part.get_parent().get_path()).replace(str(model.get_path()),"")
			groups[parent] = int(groups.get(parent,0))+count
		var rows: Array[Dictionary] = []
		for path: String in groups:
			rows.append({"path":path,"triangles":groups[path]})
		rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.triangles)>int(b.triangles))
		print(JSON.stringify({"id":id,"raw_triangles":total,"largest_groups":rows.slice(0,12)}))
		model.free()
	quit(0)
