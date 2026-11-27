extends SceneTree
const SHIP: PackedScene = preload("res://naval/carrier_gallery/casablanca.tscn")
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("_inspect")
func ck(value: bool, label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(label)
func _inspect() -> void:
	var model: PackedScene = SHIP
	ck(model!=null,"asset loads")
	if model==null:
		quit(1)
		return
	var s: Node3D = model.instantiate() as Node3D
	root.add_child(s)
	for mod: String in ["Hull","Hangar","FlightDeck","Superstructure","Equipment"]:
		ck(s.has_node(mod),mod)
	var hull: MeshInstance3D = s.get_node("Hull/UpperShell")
	var deck: MeshInstance3D = s.get_node("FlightDeck/DeckSurface")
	var box: AABB = deck.mesh.get_aabb()
	ck(absf(hull.mesh.get_aabb().size.z-s.LENGTH)<.02,"hull length")
	ck(absf(hull.mesh.get_aabb().size.x-s.BEAM)<.02,"hull beam")
	ck(is_equal_approx(box.size.x,s.DECK_WIDTH) and is_equal_approx(box.size.z,s.DECK_LENGTH),"deck plan")
	var h: MeshInstance3D = s.get_node("Hangar/HangarEnclosure")
	ck(h.mesh.get_aabb().position.y<hull.mesh.get_aabb().end.y,"hull to enclosure")
	ck(h.mesh.get_aabb().end.y>=s.DECK_Y-.81,"enclosure to deck")
	var island: MeshInstance3D = s.get_node("Superstructure/Bridge/IslandBase")
	ck(island.to_global(island.mesh.get_aabb().get_center()).x>0.0,"island starboard")
	ck(island.to_global(island.mesh.get_aabb().get_center()).z< -19.0,"island forward placement")
	ck(s.has_node("Superstructure/Masts/MainMast"),"distinct mast silhouette")
	ck(s.has_node("FlightDeck/SternTransverseFascia"),"stern structural silhouette")
	var lifts: Array[Node] = s.get_node("FlightDeck").find_children("Lift_*","Marker3D",false,false)
	ck(lifts.size()==2,"two fixed deck lift markers")
	for lift: Marker3D in lifts:
		ck(absf(lift.position.x)<.001 and lift.position.y>s.DECK_Y,"centerline deck lift")
	var meshes: Array[Node] = s.find_children("*","MeshInstance3D",true,false)
	ck(meshes.size()>100 and meshes.size()<550,"static draw-piece budget")
	for m: MeshInstance3D in meshes:
		ck(m.mesh!=null and m.transform.is_finite(),"finite mesh "+str(m.name))
	var destination: String = OS.get_environment("CARRIER_EXPORT_DIR")
	if not destination.is_empty():
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		ck(doc.append_from_scene(s,state)==OK,"gather Godot geometry")
		ck(doc.write_to_filesystem(state,destination.path_join("casablanca.glb"))==OK,"export inspectable asset")
	print("CASABLANCA checks=",checks," failures=",failures," meshes=",meshes.size())
	quit(1 if failures!=0 else 0)
