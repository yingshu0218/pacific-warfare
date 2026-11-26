extends SceneTree

const ADAPTER: Script = preload("res://scripts/presentation/models/capital_ship_adapter.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id: String in ["jp_yamato_1944_04","us_iowa_bb61_1944_12_28"]:
		var model: CapitalShipAdapter = ADAPTER.new() as CapitalShipAdapter
		model.model_id = id
		root.add_child(model)
		var path: String = "res://data/units/"+id+".json"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		data["mounts"] = model.mount_sockets()
		var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
		if file == null:
			push_error("Could not write socket manifest: "+path)
			quit(1)
			return
		file.store_string(JSON.stringify(data,"  ",false,true)+"\n")
		file.close()
		print("EXPORTED "+id+": "+str(data.mounts.size())+" real model sockets")
		model.free()
	quit(0)
