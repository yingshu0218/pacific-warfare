class_name BombStores
extends SimulationModule

var projectiles: CombatProjectiles
var parameters: Dictionary
var requests: Dictionary = {}

func _init(flight: CombatProjectiles, data: Dictionary) -> void:
	module_id = "bomb_stores"
	priority = 520 # Task -> actual movement -> release -> first contact -> damage.
	projectiles = flight
	parameters = data.duplicate(true)

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	requests.clear()
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not parameters.aircraft.has(unit.definition_id): continue
		var p: Dictionary = parameters.aircraft[unit.definition_id]
		var slots: Array = []
		for position: Array in p.slots_m:
			slots.append({"position_m":SimData.vec3(position),"loaded":true})
		unit.module_data["bomb_rack"] = {"slots":slots,"remaining":slots.size(),"released":0,"mass_kg":slots.size()*float(parameters.ammunition[p.ammo_id].projectile_mass_kg),"last_release_tick":-1,"next_release_s":0.0,"bay":0.0,"crutch":0.0,"brake":0.0,"bay_target":0.0,"crutch_target":0.0,"brake_target":0.0,"reason":"loaded","ammo_id":p.ammo_id}
		unit.module_data.erase("bombing")

func request(unit_id: String, order_id: String) -> bool:
	if requests.has(unit_id): return false
	requests[unit_id] = order_id
	return true

func cancel(unit_id: String) -> void:
	requests.erase(unit_id)

static func local_slot(p: Dictionary, rack: Dictionary, slot: int) -> Vector3:
	var point: Vector3 = rack.slots[slot].position_m
	if p.get("crutch_kind","") == "d4y":
		return Vector3(0,-0.30,-0.72)+Basis(Vector3.RIGHT,deg_to_rad(34)*float(rack.crutch))*Vector3(0,-0.27,0.95)
	return point

func fixed_update(world_ref: RefCounted, _delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not unit.module_data.has("bomb_rack"): continue
		var rack: Dictionary = unit.module_data.bomb_rack
		var airborne: bool = unit.active and unit.position_m.y-TerrainQueries.height_m(world,unit.position_m,true) > 120.0 and not bool(unit.module_data.get("aircraft_motion",{}).get("surface_contact",false))
		for key: String in ["bay","crutch","brake"]:
			var wanted: float = float(rack.get(key+"_target",0.0)) if airborne else 0.0
			if key == "crutch" and float(rack.bay) < 0.99: wanted = 0.0
			rack[key] = move_toward(float(rack[key]),wanted,world.fixed_delta_s()/1.2)
	for id: String in requests.keys():
		var order_id: String = requests[id]
		var unit: UnitState = world.get_unit(id)
		var rack: Dictionary = unit.module_data.bomb_rack
		var p: Dictionary = parameters.aircraft[unit.definition_id]
		var reason: String = release_guard(world,unit,order_id,p,rack)
		if not reason.is_empty():
			rack.reason = reason
			continue
		var index: int = -1
		for i: int in rack.slots.size():
			if rack.slots[i].loaded:
				index = i
				break
		if index < 0: continue
		var position: Vector3 = unit.world_transform()*local_slot(p,rack,index)
		var ammo: AmmoDefinition = world.ammo_definition(str(p.ammo_id))
		if projectiles.release_bomb(world,unit,id+"/bomb_rack",index,ammo,position,order_id):
			rack.slots[index].loaded = false
			rack.remaining -= 1
			rack.released += 1
			rack.mass_kg = float(rack.remaining)*ammo.projectile_mass_kg
			rack.last_release_tick = world.tick
			rack.next_release_s = world.time_s()+float(p.interval_s)
			rack.reason = "released"
	requests.clear() # Every request is valid for one tick only, including rejections.

static func release_guard(world: SimulationWorld, unit: UnitState, order_id: String, p: Dictionary, rack: Dictionary) -> String:
	if not unit.active or str(unit.module_data.get("damage",{}).get("phase","operational")) != "operational": return "damage_abort"
	if not world.owned_order_unit_ids(order_id,"aircraft").has(unit.id): return "order_released"
	if int(rack.remaining) <= 0: return "empty"
	if int(rack.last_release_tick) == world.tick or world.time_s() < float(rack.next_release_s): return "release_interval"
	var flight: Dictionary = unit.module_data.get("aircraft_motion",{})
	if flight.is_empty() or str(flight.safety_state) != "normal" or bool(flight.get("surface_contact",false)): return "flight_safety"
	if unit.module_data.get("carrier_ops",{}).get("on_deck",false): return "not_airborne"
	if unit.position_m.y-TerrainQueries.height_m(world,unit.position_m,true) < float(p.min_release_agl_m): return "too_low"
	var speed: float = unit.velocity_mps.length()
	if speed < float(p.min_release_mps) or speed > float(p.max_release_mps): return "release_speed"
	if absf(float(flight.bank_rad)) > deg_to_rad(float(p.release_bank_deg)): return "release_bank"
	var pitch: float = rad_to_deg(float(flight.path_pitch_rad))
	if pitch < float(p.release_pitch_deg[0]) or pitch > float(p.release_pitch_deg[1]): return "release_pitch"
	if float(rack.bay) < 0.99 or float(rack.crutch) < float(p.get("required_crutch",0.0)): return "rack_not_ready"
	return ""
