extends Node3D
## Static assembly fixtures. A6M is the real existing 1:1 model; proxy is labeled.
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const A6M: PackedScene = preload("res://aircraft/scenes/a6m5_52ko.tscn")
var aircraft: Array[Node3D] = []
var records: Array[Dictionary] = []

func _ready() -> void:
	for item: Array in [["A6M_ForwardPark",Vector3(-1,14.15,-79)],
		["A6M_ForwardElevator",Vector3(0,14.15,-43.5)],
		["A6M_AftElevator",Vector3(0,14.15,84.5)]]:
		var holder: Node3D = H.group(self,item[0],item[1])
		var model: Node3D = A6M.instantiate() as Node3D
		model.set("flight_simplified",true)
		holder.add_child(model)
		# Use the model's original ground-based origin and original tyre meshes.
		# No scaling, moved gear, hidden wheels or changed flight model origin.
		aircraft.append(model)
		var record: Dictionary = measure_aircraft(model)
		record.id=item[0]; record.kind="actual_A6M5a_1944_static_cross_era_fit"
		record.station_m=[holder.position.x,holder.position.y,holder.position.z]
		records.append(record)
		H.batch_static(model)
	var proxy: Node3D = H.group(self,"D4Y2_DIMENSION_PROXY_NOT_ADMITTED",Vector3(0,14.15,29))
	proxy.set_meta("scope","Dimensions only; no D4Y geometry, gear, hook or flight-operations approval")
	var p: Dictionary = H.palette()
	# Unmistakably a dimension cage, with no aircraft silhouette or equipment.
	var width: float = 11.50; var length: float = 10.22; var height: float = 3.740
	for y: float in [0.025,height]:
		for side: float in [-1,1]:
			G.rod(proxy,"ProxyWidth",Vector3(-width*.5,y,side*length*.5),Vector3(width*.5,y,side*length*.5),.045,p.mark,6)
			G.rod(proxy,"ProxyLength",Vector3(side*width*.5,y,-length*.5),Vector3(side*width*.5,y,length*.5),.045,p.mark,6)
	for x: float in [-width*.5,width*.5]:
		for z: float in [-length*.5,length*.5]: G.rod(proxy,"ProxyHeight",Vector3(x,0,z),Vector3(x,height,z),.045,p.mark,6)
	records.append({"id":"D4Y2_DIMENSION_PROXY_NOT_ADMITTED","kind":"dimension_proxy_only",
		"station_m":[0,14.15,29],"envelope_size_m":[width,height,length],"source_status":"USNTMJ A11 Table II SUISEI-12 nominal size (height 3.740m) for conservative clearance reservation; AV02 admission still required; not an aircraft model"})
	H.batch_static(proxy)

static func measure_aircraft(model: Node3D) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	H.collect_meshes(model,meshes,[])
	var min_point: Vector3 = Vector3(INF,INF,INF)
	var max_point: Vector3 = Vector3(-INF,-INF,-INF)
	var tyres: Array[Dictionary] = []
	var footprint: Array = []
	for mesh: MeshInstance3D in meshes:
		var transform_to_model: Transform3D = model.global_transform.affine_inverse()*mesh.global_transform
		var tyre_min: Vector3 = Vector3(INF,INF,INF)
		var tyre_at: Vector3 = Vector3.ZERO
		var low_points: Array[Vector3] = []
		for vertex: Vector3 in mesh.mesh.get_faces():
			var point: Vector3 = transform_to_model*vertex
			min_point=min_point.min(point); max_point=max_point.max(point)
			if point.y<tyre_min.y: tyre_min=point
			if str(mesh.name).to_lower().contains("tyre"): low_points.append(point)
		if not low_points.is_empty():
			var count: int = 0
			for point: Vector3 in low_points:
				if point.y<=tyre_min.y+.0001: tyre_at+=point; count+=1
			tyre_at/=float(count)
			var world: Vector3 = model.global_transform*tyre_at
			tyres.append({"mesh_path":str(model.get_path_to(mesh)),"local_contact_m":[tyre_at.x,tyre_at.y,tyre_at.z],
				"ship_contact_m":[world.x,world.y,world.z],"minimum_local_y_m":tyre_min.y})
	for x: float in [min_point.x,max_point.x]:
		for z: float in [min_point.z,max_point.z]:
			var point: Vector3 = model.global_transform*Vector3(x,min_point.y,z)
			footprint.append([point.x,point.y,point.z])
	var size: Vector3 = max_point-min_point
	return {"scale":[model.scale.x,model.scale.y,model.scale.z],"root_transform_unchanged":model.transform.is_equal_approx(Transform3D.IDENTITY),
		"envelope_min_m":[min_point.x,min_point.y,min_point.z],"envelope_max_m":[max_point.x,max_point.y,max_point.z],
		"envelope_size_m":[size.x,size.y,size.z],"tyres":tyres,"footprint_corners_ship_m":footprint,
		"nominal_dimensions_m":[11.0,3.509,9.121],"note":"Measured current mesh envelope differs slightly from nominal equipment data; both reported, never rescaled"}
