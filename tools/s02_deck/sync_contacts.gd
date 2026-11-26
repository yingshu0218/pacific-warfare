extends SceneTree

## Update Yamato host ordinates only; weapon seats and the persisted sockets stay fixed.
const BUILDER: Script = preload("res://scripts/ship_geometry.gd")

func _initialize() -> void:
	var builder: Node3D = BUILDER.new() as Node3D
	var path: String = "res://data/yamato_1944_mounts.json"
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var changed: Array[Dictionary] = []
	for entry: Dictionary in layout.mounts:
		if str(entry.attachment.host) != "main_deck": continue
		var surface_y: float = snappedf(builder.deck_surface_height(float(entry.position[2])),0.0001)
		if not is_equal_approx(float(entry.attachment.surface_y),surface_y):
			changed.append({"id":entry.id,"before_y":entry.attachment.surface_y,"after_y":surface_y,"seat_unchanged_m":entry.position})
		entry.attachment.surface_y = surface_y
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_error("Could not update Yamato contact data")
		builder.free()
		quit(1)
		return
	file.store_string(JSON.stringify(layout,"\t",false,true)+"\n")
	file.close()
	file = FileAccess.open("res://docs/showcase/evidence/S02-deck/contact_changes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(changed,"\t"))
	file.close()
	builder.free()
	print("PASS S02-deck: synced "+str(changed.size())+" Yamato host ordinates; every weapon seat unchanged")
	quit(0)
