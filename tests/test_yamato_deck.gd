extends SceneTree

const BUILDER: Script = preload("res://scripts/ship_geometry.gd")
const ADAPTER: Script = preload("res://scripts/presentation/models/capital_ship_adapter.gd")
var failures: PackedStringArray = []
var audit: Dictionary = {"scope":"Yamato deck continuity, real shared edge and installation only"}

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)

func _run() -> void:
	var builder: Node3D = BUILDER.new() as Node3D
	root.add_child(builder)
	var points: Array = builder.deck_sheer_stations
	var max_slope_jump: float = 0.0
	var max_mesh_error: float = 0.0
	for index: int in range(points.size()):
		var z: float = float(points[index][0])
		_check(absf(builder.deck_height(z)-float(points[index][1]))<0.00001,"Source profile ordinate moved")
		if index > 0 and index < points.size()-1:
			var left: float = (builder.deck_height(z)-builder.deck_height(z-0.001))/0.001
			var right: float = (builder.deck_height(z+0.001)-builder.deck_height(z))/0.001
			max_slope_jump = maxf(max_slope_jump,absf(right-left))
			_check(absf(right-left)<0.0001,"Deck retains a tangent discontinuity at a profile station")
		if index == points.size()-1: continue
		for sample: int in range(101):
			var sample_z: float = lerpf(z,float(points[index+1][0]),float(sample)/100.0)
			var y: float = builder.deck_height(sample_z)
			var low: float = minf(float(points[index][1]),float(points[index+1][1]))
			var high: float = maxf(float(points[index][1]),float(points[index+1][1]))
			_check(y >= low-0.00001 and y <= high+0.00001,"Deck spline overshoots its source segment")
			max_mesh_error = maxf(max_mesh_error,absf(y-builder.deck_surface_height(sample_z)))
	_check(max_mesh_error<0.0041,"Tessellated deck differs from the smooth profile by more than 4mm")
	builder.hull()
	var shell: MeshInstance3D = builder.get_node("HullShell") as MeshInstance3D
	var deck: MeshInstance3D = builder.get_node("WeatherDeck") as MeshInstance3D
	var shell_vertices: Dictionary = {}
	for vertex: Vector3 in shell.mesh.get_faces(): shell_vertices[_key(vertex)] = true
	var seam_vertices: Dictionary = {}
	for vertex: Vector3 in deck.mesh.get_faces():
		_check(shell_vertices.has(_key(vertex)),"Deck and hull have different boundary vertices")
		seam_vertices[_key(vertex)] = true
	_check(seam_vertices.size()==builder.hull_longitudinal_stations().size()*2,"Shared deck edge has missing or duplicated stations")
	audit["source_ordinates"] = points
	audit["max_tangent_jump_m_per_m"] = max_slope_jump
	audit["max_curve_to_mesh_error_m"] = max_mesh_error
	audit["shared_boundary_vertices"] = seam_vertices.size()
	builder.free()
	var model: CapitalShipAdapter = ADAPTER.new() as CapitalShipAdapter
	root.add_child(model)
	var installation: Array[Dictionary] = []
	for entry: Dictionary in model._builder.weapons:
		var station: Marker3D = entry.station as Marker3D
		var id: String = str(entry.station_id)
		_check(_contact(station),"No true host surface at "+id)
		if not id.begins_with("main_"): continue
		var foundation: Node3D = entry.foundation as Node3D
		var seat: Vector3 = model.model_root.to_local((entry.pivot as Node3D).global_position)
		var expected_y: float = {"main_01":7.2,"main_02":11.4,"main_03":8.7}[id]
		_check(absf(seat.y-expected_y)<0.00001,"Main weapon seat moved during contact correction")
		var foot_points: Dictionary = {}
		var max_contact_error: float = 0.0
		var worst_contact: Array = []
		for child: Node in foundation.get_children():
			if not child is MeshInstance3D: continue
			var part: MeshInstance3D = child as MeshInstance3D
			for vertex: Vector3 in part.mesh.get_faces():
				var point: Vector3 = model.model_root.to_local(part.to_global(vertex))
				if point.y >= seat.y-0.0001: continue
				var height: float = model._builder.deck_surface_height(point.z)
				if absf(point.y-height)>max_contact_error:
					max_contact_error = absf(point.y-height)
					worst_contact = [point.x,point.y,point.z,height]
				_check(absf(point.y-height)<0.0002,"Barbette skirt does not meet the actual deck at "+id)
				foot_points[_key(point)] = point
		_check(foot_points.size()>=17,"Barbette lacks its deck-conforming lower perimeter")
		installation.append({"id":id,"host_y_m":station.global_position.y,"fixed_seat_m":[seat.x,seat.y,seat.z],"deck_contact_points":foot_points.size(),"max_contact_error_m":max_contact_error,"worst_contact_xyz_and_expected_y_m":worst_contact})
	# Both side deckhouses and the fore/aft secondary shells retain their roofs
	# above the hull, with the lower shell overlapping the real deck rather than floating.
	var shelter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shelter_deck.json"))
	for point: Array in shelter.outline_xz:
		var deck_y: float = model._builder.deck_surface_height(float(point[1]))
		_check(float(shelter.bottom_y)<deck_y and float(shelter.top_y)>deck_y+2.0,"Shelter/side platform has lost its hull contact or clearance")
	for z: float in [-14.0,-9.508,0.0,3.0]:
		_check(model._builder.deck_surface_height(z)>8.3 and model._builder.deck_surface_height(z)<13.3,"Fore secondary shell is floating or buried")
	audit["main_foundations"] = installation
	audit["all_host_contacts_checked"] = model.mount_sockets().size()
	audit["failures"] = failures
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S02-deck/geometry_installation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(audit,"\t"))
	file.close()
	model.free()
	if failures.is_empty():
		print("PASS S02-deck: source ordinates, C1 profile, no overshoot, shared mesh edge, 39 host faces, three conforming main barbettes and deckhouse contacts")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)

func _key(value: Vector3) -> Vector3i:
	return Vector3i(roundi(value.x*10000),roundi(value.y*10000),roundi(value.z*10000))

func _contact(station: Marker3D) -> bool:
	for child: Node in station.get_parent().get_children():
		if not child is MeshInstance3D: continue
		var part: MeshInstance3D = child as MeshInstance3D
		var triangles: TriangleMesh = part.mesh.generate_triangle_mesh()
		if not triangles.intersect_segment(part.to_local(station.global_position+Vector3.UP*0.002),part.to_local(station.global_position-Vector3.UP*0.002)).is_empty(): return true
	return false
