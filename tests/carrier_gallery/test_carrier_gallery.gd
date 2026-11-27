extends SceneTree
const Gallery: PackedScene = preload("res://naval/carrier_gallery/viewer.tscn")
var checks: int = 0
var errors: int = 0
func _initialize() -> void:
	call_deferred("_test")

func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		push_error(what)

func _test() -> void:
	var gallery: Node3D = Gallery.instantiate() as Node3D
	root.add_child(gallery)
	var models: Array[String] = ["enterprise","independence","akagi","zuiho"]
	var lengths: Array[float] = [246.7356,185.928,260.67,205.5]
	var lift_counts: Array[int] = [3,2,3,2]
	for i: int in models.size():
		gallery.select_ship(i)
		var ship: Node3D = gallery.ship
		_check(ship.ship_id==models[i],"Roster order")
		var modules: Array[String] = ["Hull","Hangar","FlightDeck","Superstructure","Equipment"]
		for mod: String in modules:
			_check(ship.has_node(mod),models[i]+" module "+mod)
		var upper: MeshInstance3D = ship.get_node("Hull/UpperShell")
		_check(absf(upper.mesh.get_aabb().size.z-lengths[i])<.02,models[i]+" hull length")
		var deck: MeshInstance3D = ship.get_node("FlightDeck/DeckSurface")
		_check(is_equal_approx(deck.mesh.get_aabb().size.z, float(ship.spec.deck_length)),models[i]+" deck length")
		_check(is_equal_approx(deck.mesh.get_aabb().size.x, float(ship.spec.deck_width)),models[i]+" deck width")
		_check(ship.get_node("FlightDeck").find_children("Lift_*","Marker3D",false,false).size()==lift_counts[i],models[i]+" lift count")
		var base: MeshInstance3D = ship.get_node_or_null("Superstructure/Bridge/IslandBase")
		if i==3:
			_check(base==null and ship.has_node("Superstructure/Bridge/UnderDeckBridge"),"Zuiho clear deck and bridge")
		else:
			var position: Vector3 = base.mesh.get_aabb().get_center()
			_check(position.x<0.0 if i==2 else position.x>0.0,models[i]+" island side")
		var hangar: MeshInstance3D = ship.get_node("Hangar/HangarEnclosure")
		var deck_base: MeshInstance3D = ship.get_node("FlightDeck/FlightDeckStructure")
		_check(hangar.mesh.get_aabb().end.y > deck_base.mesh.get_aabb().position.y,models[i]+" deck/hangar overlap")
		_check(hangar.mesh.get_aabb().position.y <= upper.mesh.get_aabb().end.y,models[i]+" hangar/hull overlap")
		for v: int in 4:
			gallery.view = v
			gallery._frame()
			_check((gallery.get_node("Camera") as Camera3D).transform.is_finite(),models[i]+" camera "+str(v))
		var destination: String = OS.get_environment("CARRIER_EXPORT_DIR")
		if not destination.is_empty():
			for child: Node in ship.find_children("*","MeshInstance3D",true,false):
				child.owner = ship
			for child: Node in ship.find_children("*","Node3D",true,false):
				child.owner = ship
			var gltf := GLTFDocument.new()
			var state := GLTFState.new()
			_check(gltf.append_from_scene(ship,state)==OK,models[i]+" export gather")
			_check(gltf.write_to_filesystem(state,destination.path_join(models[i]+".glb"))==OK,models[i]+" export write")
	for i: int in [4,5]:
		gallery.select_ship(i)
		var escort: Node3D = gallery.ship
		var expected: String = "Casablanca" if i==4 else "Taiyo"
		_check(expected in escort.spec.label,expected+" accessible in gallery")
		_check(escort.find_children("*","MeshInstance3D",true,false).size()>30,expected+" actual geometry")
		for v: int in 4:
			gallery.view = v
			gallery._frame()
			_check((gallery.get_node("Camera") as Camera3D).transform.is_finite(),expected+" camera "+str(v))
	print("CARRIER GALLERY: ",checks," checks, ",errors," failures")
	quit(1 if errors else 0)
