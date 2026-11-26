extends Node3D
## Pure CV01 visual adapter: no process callback, world commands or aircraft motion.
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const MK32: PackedScene = preload("res://naval/essex_cv9_1944_04_15/weapons/mk32.tscn")
const MK24: PackedScene = preload("res://naval/essex_cv9_1944_04_15/weapons/mk24.tscn")
const BOFORS: PackedScene = preload("res://assets/naval/weapons/usn_bofors_40mm/mark2_mod5/usn_bofors_40mm_quad_mk2_mod5.tscn")
const OERLIKON: PackedScene = preload("res://scenes/ships/destroyer_modules/us_oerlikon_single.tscn")
var configuration: Dictionary
var mount_visuals: Dictionary = {}
var _sockets: Array[Dictionary] = []
var flight_deck: Node3D
var hull: Node3D

func _ready() -> void:
	configuration = H.read_data("assembly")
	for name: String in ["hull","hangar","flight_deck","island","platforms","equipment"]:
		var scene: PackedScene = load(H.BASE+"modules/"+name+".tscn") as PackedScene
		var module: Node3D = scene.instantiate() as Node3D
		module.name = name.to_pascal_case()
		add_child(module)
		if name=="flight_deck": flight_deck = module
		if name=="hull": hull = module
	var root: Node3D = H.group(self,"MountFoundations")
	for row: Dictionary in configuration.mounts:
		var surface: Marker3D = _find_surface(self,row.id)
		assert(surface != null,"Missing physical host for "+str(row.id))
		var foundation: Node3D = H.group(root,"Foundation_"+str(row.id))
		foundation.transform = global_transform.affine_inverse()*surface.global_transform
		foundation.set_meta("host_id",row.host_id)
		foundation.set_meta("surface_path",get_path_to(surface))
		var height: float = float(row.foundation_height_m)
		if height>0:
			G.cylinder(foundation,"FixedSeatingRing",row.foundation_radius_m,height,Vector3(0,height*.5,0),H.palette().steel,24)
		var seat: Marker3D = Marker3D.new()
		seat.name = "WeaponSeat"; seat.position.y = height; foundation.add_child(seat)
		var weapon: Node3D
		match row.kind:
			"mk32": weapon = MK32.instantiate() as Node3D
			"mk24": weapon = MK24.instantiate() as Node3D
			"bofors": weapon = BOFORS.instantiate() as Node3D
			_: weapon = OERLIKON.instantiate() as Node3D
		seat.add_child(weapon)
		var train: Node3D
		var axes: Array[Node3D] = []
		var muzzles: Array[Marker3D] = []
		var pivot: Vector3
		if row.kind == "bofors":
			train = weapon.get("_train_pivot") as Node3D
			var axis: Node3D = weapon.get("_elevation_pivot") as Node3D
			axes.append(axis)
			pivot = axis.position + train.position
			for i: int in range(4):
				var marker: Marker3D = Marker3D.new()
				marker.name = "CV01_Muzzle_%02d"%i; marker.position = Vector3([-1.12,-.39,.39,1.12][i],0,-2.700)
				axis.add_child(marker); muzzles.append(marker)
			H.batch_static(weapon,[train]); H.batch_static(train,[axis]); H.batch_static(axis)
		else:
			train = weapon.train_axis
			axes.assign(weapon.elevation_axes)
			muzzles.assign(weapon.muzzle_markers)
			pivot = weapon.elevation_pivot_m
			if row.kind == "oerlikon":
				H.batch_static(weapon,[train]); H.batch_static(train,axes)
				for axis: Node3D in axes: H.batch_static(axis)
		var position_local: Vector3 = to_local(seat.global_position)
		var muzzle_points: Array = []
		for marker: Marker3D in muzzles:
			# Zero-elevation offsets relative to the shared pivot; individual axes still supported.
			var point: Vector3 = weapon.to_local(marker.global_position)-pivot
			muzzle_points.append([point.x,point.y,point.z])
		var socket: Dictionary = {"id":row.id,"host_id":row.host_id,"weapon_definition_id":row.interface_id,"role":row.role,"position_m":[position_local.x,position_local.y,position_local.z],"base_yaw_deg":row.base_yaw_deg,"elevation_pivot_m":[pivot.x,pivot.y,pivot.z],"muzzle_positions_m":muzzle_points,"source_status":row.placement_status}
		_sockets.append(socket)
		mount_visuals[row.id] = {"weapon":weapon,"train":train,"axes":axes,"muzzles":muzzles,"socket":socket,"surface":surface,"foundation":foundation,"seat":seat,"base_yaw":deg_to_rad(float(row.base_yaw_deg)),"min_elevation":deg_to_rad(-15.0 if row.kind in ["mk32","mk24"] else -5.0),"max_elevation":deg_to_rad(85.0 if row.kind in ["mk32","mk24","oerlikon"] else 90.0)}
		apply_weapon_state(row.id,{"train_rad":0.0,"elevation_rad":0.0})
	_update_material_pose()

func _find_surface(node: Node, id: String) -> Marker3D:
	if node is Marker3D and str(node.get_meta("station_id",""))==id: return node as Marker3D
	for child: Node in node.get_children():
		var found: Marker3D = _find_surface(child,id)
		if found != null: return found
	return null

func apply_state(state: Dictionary) -> void:
	var at: Vector3 = G.vector(state.get("position_m",position))
	var angles: Vector3 = G.vector(state.get("rotation_rad",rotation))
	if not at.is_finite() or not angles.is_finite(): return
	position = at; rotation = angles; visible = bool(state.get("active",true))
	for id: String in state.get("weapons",{}): apply_weapon_state(id,state.weapons[id])
	for id: String in state.get("equipment",{}): apply_equipment_state(id,state.equipment[id])
	_update_material_pose()

func _update_material_pose() -> void:
	if hull != null: (hull.get("camouflage") as ShaderMaterial).set_shader_parameter("ship_inverse",global_transform.affine_inverse())

func mount_sockets() -> Array[Dictionary]: return _sockets.duplicate(true)

func apply_weapon_state(id: String, state: Dictionary) -> bool:
	if not mount_visuals.has(id): return false
	var train: float = float(state.get("train_rad",0.0))
	var elevation: float = float(state.get("elevation_rad",0.0))
	var individual: Array = state.get("gun_elevations_rad",[])
	if not is_finite(train) or not is_finite(elevation): return false
	for value: Variant in individual:
		if not (value is float or value is int) or not is_finite(float(value)): return false
	var record: Dictionary = mount_visuals[id]
	(record.train as Node3D).rotation.y = record.base_yaw+clampf(train,-PI,PI)
	for i: int in range(record.axes.size()):
		(record.axes[i] as Node3D).rotation.x = clampf(elevation if i>=individual.size() else float(individual[i]),record.min_elevation,record.max_elevation)
	return true

func muzzle_transform_local(id: String, barrel_index: int) -> Transform3D:
	if not mount_visuals.has(id) or barrel_index<0 or barrel_index>=mount_visuals[id].muzzles.size(): return Transform3D.IDENTITY
	return global_transform.affine_inverse()*(mount_visuals[id].muzzles[barrel_index] as Marker3D).global_transform

func muzzle_transform_global(id: String, barrel_index: int) -> Transform3D:
	return global_transform*muzzle_transform_local(id,barrel_index)

func deck_definition() -> Dictionary: return (flight_deck.get("definition") as Dictionary).duplicate(true)
func deck_obstacles() -> Array: return deck_definition().obstacles
func collision_proxies() -> Array: return configuration.collision_proxies.duplicate(true)

func apply_equipment_state(id: String, state: Dictionary) -> bool:
	if not (flight_deck.get("elevators") as Dictionary).has(id): return false
	var height: float = float(state.get("height_m",NAN))
	if not is_finite(height): return false
	for e: Dictionary in deck_definition().elevators:
		if e.id==id:
			(flight_deck.elevators[id] as Node3D).position.y = clampf(height,e.lower_height_m,e.upper_height_m)
			return true
	return false

func deck_surface_at(point: Vector2) -> Dictionary:
	if not point.is_finite(): return {"supported":false}
	var definition: Dictionary = deck_definition()
	# Test all movable surfaces BEFORE fixed boundary, including its overlapping deck-edge cutout.
	for e: Dictionary in definition.elevators:
		if absf(point.x-float(e.center_xz_m[0]))<=float(e.size_xz_m[0])*.5 and absf(point.y-float(e.center_xz_m[1]))<=float(e.size_xz_m[1])*.5:
			return {"supported":true,"height_m":(flight_deck.elevators[e.id] as Node3D).position.y,"surface_id":e.id}
	if Geometry2D.is_point_in_polygon(point,H.polygon(definition.flight_deck.boundary_xz_m)):
		return {"supported":true,"height_m":definition.flight_deck.height_m,"surface_id":"flight_deck"}
	return {"supported":false}
