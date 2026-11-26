extends SceneTree

## Offline geometry extraction only. Runtime collision reads this pure data.
const MODEL: Script = preload("res://aircraft/models/f6f5.gd")
var model: Node3D

func _initialize() -> void: call_deferred("run")

func run() -> void:
	model = MODEL.new() as Node3D; model.set("flight_simplified",true); root.add_child(model)
	var states: Dictionary = {}
	var counts: Dictionary = {}
	for state: String in ["clean","landing"]:
		model.call("apply_carrier_usage_state",{"gear_down":true,"hook_down":false,"flaps_down":state == "landing"})
		var groups: Dictionary = {"body":[],"wing_left":[],"wing_right":[],"tail":[]}
		for child: Node in model.find_children("*","MeshInstance3D",true,false):
			var mesh: MeshInstance3D = child as MeshInstance3D
			if _excluded(mesh): continue
			var host: String = "body"
			for part: String in ["wing_left","wing_right","tail"]:
				if (model.get("damage_parts")[part] as Node3D).is_ancestor_of(mesh): host = part
			var transform: Transform3D = model.global_transform.affine_inverse()*mesh.global_transform
			for v: Vector3 in mesh.mesh.get_faces(): groups[host].append(transform*v+Vector3(0,-2.30,0))
		var hulls: Dictionary = {}
		for host: String in groups:
			var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			hull.points = PackedVector3Array(groups[host])
			# Godot's actual convex hull supplies a bounded exact support set;
			# interior triangle vertices are immaterial for plane first-contact.
			var debug: ArrayMesh = hull.get_debug_mesh()
			var unique: Dictionary = {}
			for v: Vector3 in debug.get_faces(): unique[str(v)] = v
			var points: Array = []
			for v: Vector3 in unique.values(): points.append(SimData.array3(v))
			hulls[host] = points
			counts[state+":"+host] = {"input_vertices":groups[host].size(),"hull_vertices":points.size()}
		states[state] = hulls
	var propeller: Node3D = model.get("propeller") as Node3D
	var propeller_points: Dictionary = {}
	for child: Node in propeller.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		var transform: Transform3D = propeller.global_transform.affine_inverse()*mesh.global_transform
		for v: Vector3 in mesh.mesh.get_faces():
			var point: Vector3 = transform*v
			propeller_points[str(point)] = SimData.array3(point)
	var stopped: Dictionary = {"center_flight_m":SimData.array3(propeller.position+Vector3(0,-2.30,0)),"points":propeller_points.values()}
	var file: FileAccess = FileAccess.open("res://scripts/air_operations/model_contact_proxy.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"geometry_id":"S04_r10_actual_mesh_hulls","model_to_flight_m":[0,-2.30,0],"source":"Accepted S04 r10 meshes, helper wheel/hook kept separate; offline convex support vertices for flat-deck collision, not a replacement visual mesh. Stopped propeller uses its actual phase and mesh vertices, not the spinning disc.","states":states,"counts":counts,"stopped_propeller":stopped},"\t")); file.close()
	print("OPS01 proxy extracted ",counts)
	model.free(); quit()

func _excluded(mesh: MeshInstance3D) -> bool:
	var node: Node = mesh
	while node != model:
		if node == model.get("propeller") or node == model.get("arresting_hook"): return true
		if node in (model.get("carrier_gear") as Dictionary).values(): return true
		if node in (model.get("closed_gear_covers") as Array): return true
		node = node.get_parent()
	return false
