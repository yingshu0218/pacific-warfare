extends Node3D
## Pure CV02 model. No simulation, camera, autonomous timers or aircraft motion.
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
var configuration: Dictionary = {}
var modules: Dictionary = {}
var mount_visuals: Dictionary = {}
var _sockets: Array[Dictionary] = []
var flight_deck: Node3D

func _ready() -> void:
	configuration=H.read_data("assembly")
	for id: String in ["hull","hangar","flight_deck","island","funnels","platforms","equipment"]:
		var scene: PackedScene = load(H.BASE+"modules/"+id+".tscn") as PackedScene
		var module: Node3D = scene.instantiate() as Node3D
		module.name=id.to_pascal_case(); add_child(module); modules[id]=module
	flight_deck=modules.flight_deck
	var root: Node3D = H.group(self,"MountFoundations")
	var palette: Dictionary = H.palette()
	for row: Dictionary in configuration.mounts:
		var surface: Marker3D = _find_surface(modules.platforms,row.id)
		assert(surface!=null,"CV02 missing host surface "+str(row.id))
		var foundation: Node3D = H.group(root,"Foundation_"+str(row.id))
		foundation.transform=global_transform.affine_inverse()*surface.global_transform
		foundation.set_meta("host_id",row.host_id)
		foundation.set_meta("surface_path",get_path_to(surface))
		var height: float = float(row.foundation_height_m)
		G.cylinder(foundation,"FixedSeatingRing",row.foundation_radius_m,height,Vector3(0,height*.5,0),palette.steel,24)
		var seat: Marker3D = Marker3D.new(); seat.name="WeaponSeat"; seat.position.y=height; foundation.add_child(seat)
		var kind: String = "type89" if str(row.kind).begins_with("type89") else "type96"
		var scene: PackedScene = load(H.BASE+"weapons/"+kind+".tscn") as PackedScene
		var weapon: Node3D = scene.instantiate() as Node3D
		weapon.set("smokeproof",str(row.kind).ends_with("smoke")); seat.add_child(weapon)
		var train: Node3D = weapon.get("train_axis") as Node3D
		var axes: Array[Node3D] = []; axes.assign(weapon.get("elevation_axes"))
		var muzzles: Array[Marker3D] = []; muzzles.assign(weapon.get("muzzle_markers"))
		var pivot: Vector3 = weapon.get("elevation_pivot_m")
		var local_seat: Vector3 = to_local(seat.global_position)
		var points: Array = []
		for marker: Marker3D in muzzles:
			var point: Vector3 = weapon.to_local(marker.global_position)-pivot
			points.append([point.x,point.y,point.z])
		var socket: Dictionary = {"id":row.id,"host_id":row.host_id,"weapon_definition_id":row.interface_id,
			"role":row.role,"position_m":[local_seat.x,local_seat.y,local_seat.z],"base_yaw_deg":row.base_yaw_deg,
			"elevation_pivot_m":[pivot.x,pivot.y,pivot.z],"muzzle_positions_m":points,"source_status":row.placement_status}
		_sockets.append(socket)
		mount_visuals[row.id]={"weapon":weapon,"surface":surface,"foundation":foundation,"seat":seat,
			"train":train,"axes":axes,"muzzles":muzzles,"socket":socket,"base_yaw":deg_to_rad(float(row.base_yaw_deg)),
			"min_elevation":deg_to_rad(-8 if kind=="type89" else -10),"max_elevation":deg_to_rad(90 if kind=="type89" else 85)}
		apply_weapon_state(row.id,{"train_rad":0.0,"elevation_rad":0.0})

func _find_surface(node: Node, id: String) -> Marker3D:
	if node is Marker3D and str(node.get_meta("station_id",""))==id: return node as Marker3D
	for child: Node in node.get_children():
		var found: Marker3D = _find_surface(child,id)
		if found!=null: return found
	return null

func apply_state(state: Dictionary) -> void:
	var at: Vector3 = G.vector(state.get("position_m",position))
	var angles: Vector3 = G.vector(state.get("rotation_rad",rotation))
	if not at.is_finite() or not angles.is_finite(): return
	position=at; rotation=angles; visible=bool(state.get("active",true))
	for id: String in state.get("weapons",{}): apply_weapon_state(id,state.weapons[id])
	for id: String in state.get("equipment",{}): apply_equipment_state(id,state.equipment[id])

func mount_sockets() -> Array[Dictionary]:
	return _sockets.duplicate(true)

func apply_weapon_state(id: String, state: Dictionary) -> bool:
	if not mount_visuals.has(id): return false
	var train: float = float(state.get("train_rad",0.0))
	var elevation: float = float(state.get("elevation_rad",0.0))
	if not is_finite(train) or not is_finite(elevation): return false
	var record: Dictionary = mount_visuals[id]
	(record.train as Node3D).rotation.y=record.base_yaw+clampf(train,deg_to_rad(-55),deg_to_rad(55))
	for axis: Node3D in record.axes: axis.rotation.x=clampf(elevation,record.min_elevation,record.max_elevation)
	return true

func muzzle_transform_local(id: String, barrel_index: int) -> Transform3D:
	if not mount_visuals.has(id) or barrel_index<0 or barrel_index>=mount_visuals[id].muzzles.size(): return Transform3D.IDENTITY
	return global_transform.affine_inverse()*(mount_visuals[id].muzzles[barrel_index] as Marker3D).global_transform

func muzzle_transform_global(id: String, barrel_index: int) -> Transform3D:
	return global_transform*muzzle_transform_local(id,barrel_index)

func deck_definition() -> Dictionary:
	return (flight_deck.get("definition") as Dictionary).duplicate(true)

func deck_obstacles() -> Array:
	return deck_definition().obstacles

func collision_proxies() -> Array:
	return configuration.collision_proxies.duplicate(true)

func apply_equipment_state(id: String, state: Dictionary) -> bool:
	if not (flight_deck.get("elevators") as Dictionary).has(id): return false
	var height: float = float(state.get("height_m",NAN))
	if not is_finite(height): return false
	for e: Dictionary in deck_definition().elevators:
		if e.id==id:
			(flight_deck.elevators[id] as Node3D).position.y=clampf(height,e.lower_height_m,e.upper_height_m)
			return true
	return false

func deck_surface_at(point: Vector2) -> Dictionary:
	if not point.is_finite(): return {"supported":false}
	var data: Dictionary = deck_definition()
	for e: Dictionary in data.elevators:
		if absf(point.x-float(e.center_xz_m[0]))<=float(e.size_xz_m[0])*.5 and absf(point.y-float(e.center_xz_m[1]))<=float(e.size_xz_m[1])*.5:
			return {"supported":true,"height_m":(flight_deck.elevators[e.id] as Node3D).position.y,"surface_id":e.id}
	if Geometry2D.is_point_in_polygon(point,H.polygon(data.flight_deck.boundary_xz_m)):
		return {"supported":true,"height_m":data.flight_deck.height_m,"surface_id":"flight_deck"}
	return {"supported":false}
