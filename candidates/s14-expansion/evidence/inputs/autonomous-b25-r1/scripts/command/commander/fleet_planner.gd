class_name FleetPlanner
extends RefCounted

## Deliberately has no SimulationWorld reference. All decisions use this friendly
## snapshot and static type parameters; never observer data or enemy live state.
var config: FleetConfig
var aircraft: AircraftPerformance = AircraftPerformance.new()
var memory: Dictionary = {}
var serial: int = 0

func _init(parameters: FleetConfig) -> void:
	config = parameters

func reset() -> void:
	memory.clear()
	serial = 0

func plan(view: Dictionary) -> Array[BattleOrder]:
	var result: Array[BattleOrder] = []
	if view.is_empty() or not config.data.commanders.has(view.faction_id):
		return result
	var faction: String = view.faction_id
	var now: float = float(view.time_s)
	if not memory.has(faction):
		memory[faction] = {"last_issue": {}, "signatures": {}, "flagship": "", "surface_target": "", "air_target": "", "air_threat": false, "last_surface_s": -INF, "had_contact": false}
	var state: Dictionary = memory[faction]
	var policy: Dictionary = config.data.commanders[faction]
	var ids: Array = view.units.keys()
	ids.sort()
	var ships: Array[String] = []
	var planes: Array[String] = []
	var protectable: Array[String] = []
	var own_ship_count: int = 0
	var human_owned: Dictionary = {}
	var withdrawn: Dictionary = {}
	var orders_by_id: Dictionary = {}
	for order: Dictionary in view.orders:
		orders_by_id[order.order_id] = order
		if order.source == "human" and order.status not in BattleOrder.TERMINAL:
			for id: String in order.assigned_unit_ids:
				human_owned[id] = true
		if order.order_type == "retreat":
			for id: String in order.execution:
				if order.execution[id].status == "completed":
					withdrawn[id] = true
	var retreats: Dictionary = {}
	for id: String in ids:
		var unit: Dictionary = view.units[id]
		if config.supports(unit.definition_id):
			own_ship_count += 1
			if unit.active and _withdraw_reason(unit, policy).is_empty():
				protectable.append(id)
		if not unit.active or human_owned.has(id) or withdrawn.has(id):
			continue
		if not config.supports(unit.definition_id) and not aircraft.supports(unit.definition_id):
			continue
		var reason: String = _withdraw_reason(unit, policy)
		if not reason.is_empty():
			var key: String = ("ship:" if config.supports(unit.definition_id) else "air:") + reason
			if not retreats.has(key):
				retreats[key] = []
			retreats[key].append(id)
			continue
		if config.supports(unit.definition_id):
			ships.append(id)
		else:
			# Do not interrupt S04's actual autonomous withdrawal with fresh patrols.
			if str(unit.task.get("aircraft", {}).get("phase", "")) != "withdraw":
				planes.append(id)
	for key: String in retreats:
		var retreat_ids: Array[String] = []
		retreat_ids.assign(retreats[key])
		var ship: bool = key.begins_with("ship:")
		_offer(result, view, state, retreat_ids, "retreat", "", policy.retreat_center_m if ship else policy.air_retreat_center_m,
			float(config.data.policy.ship_retreat_radius_m if ship else config.data.policy.air_retreat_radius_m), key.get_slice(":", 1), true, orders_by_id)
	var previous_flag: String = str(state.flagship)
	var core: String = _flagship(view.units, ships, previous_flag)
	# A human-controlled friendly core is still a valid air-protection object.
	var ward: String = core if not core.is_empty() else _flagship(view.units, protectable, "")
	var flag_changed: bool = not previous_flag.is_empty() and previous_flag != core
	state.flagship = core
	var anchor: Vector3 = (view.units[ward].position_m as Vector3) if not ward.is_empty() else SimData.vec3(policy.patrol_center_m)
	var fresh: Array[Dictionary] = []
	for contact: Dictionary in view.contacts:
		if bool(contact.get("fresh", false)) and bool(contact.get("valid", false)):
			fresh.append(contact)
	var surface: Dictionary = _select_contact(fresh, "ship", anchor, str(state.surface_target))
	# Scene doctrine may prioritize a detected shore battery. Only this faction's
	# fresh contacts are candidates; no ground target is injected before detection.
	var shore: Dictionary = _select_contact(fresh,"ground",anchor,str(state.surface_target))
	if not shore.is_empty() and (surface.is_empty() or bool(policy.get("shore_priority",false))): surface=shore
	if not surface.is_empty():
		state.surface_target = surface.entity_id
		state.last_surface_s = surface.observed_time_s
		state.had_contact = true
	var nearby_air: Array[Dictionary] = []
	for contact: Dictionary in fresh:
		if contact.domain == "aircraft" and (contact.position_m as Vector3).distance_to(anchor) < float(config.data.policy.air_threat_radius_m):
			nearby_air.append(contact)
	var air: Dictionary = _select_contact(nearby_air, "aircraft", anchor, str(state.air_target))
	var air_threat: bool = not air.is_empty()
	var new_air_threat: bool = air_threat and not bool(state.air_threat)
	state.air_threat = air_threat
	if air_threat:
		state.air_target = air.entity_id
	if not core.is_empty():
		var main: Array[String] = [core]
		if not surface.is_empty():
			_offer(result, view, state, main, "engage", str(surface.entity_id), SimData.array3(surface.position_m), float(config.data.commanders[faction].patrol_radius_m), "flagship_replacement" if flag_changed else "surface_contact", flag_changed, orders_by_id)
		elif bool(state.had_contact) and now - float(state.last_surface_s) > float(config.data.policy.contact_hysteresis_s):
			# Let the executor's last-contact search produce its own real failure first.
			var active: Dictionary = orders_by_id.get(view.units[core].active_order_id, {})
			if str(active.get("order_type", "")) != "engage":
				if str(state.signatures.get(core, "")) == "regroup:reform_after_contact_loss" and active.is_empty():
					_offer(result, view, state, main, "patrol", "", policy.patrol_center_m, float(policy.patrol_radius_m), "search_no_contact", false, orders_by_id)
				elif str(active.get("order_type", "")) != "patrol":
					_offer(result, view, state, main, "regroup", "", SimData.array3(anchor), 900.0, "reform_after_contact_loss", false, orders_by_id)
		else:
			_offer(result, view, state, main, "patrol", "", policy.patrol_center_m, float(policy.patrol_radius_m), "flagship_replacement" if flag_changed else "search_no_contact", flag_changed, orders_by_id)
		var escorts: Array[String] = ships.duplicate()
		escorts.erase(core)
		_offer(result, view, state, escorts, "escort", core, SimData.array3(anchor), 3500.0, "air_defence_cover" if air_threat else "protect_core", flag_changed or new_air_threat, orders_by_id)
	if own_ship_count > 0 and protectable.is_empty():
		_offer(result, view, state, planes, "retreat", "", policy.air_retreat_center_m, float(config.data.policy.air_retreat_radius_m), "force_depleted", true, orders_by_id)
		return result
	if not planes.is_empty():
		if air_threat:
			var interceptors: Array[String] = planes.duplicate()
			var reserve: Array[String] = []
			if planes.size() >= 4:
				interceptors.assign(planes.slice(0, 2))
				reserve.assign(planes.slice(2))
			_offer(result, view, state, interceptors, "intercept", str(air.entity_id), SimData.array3(air.position_m), 2500.0, "intercept_air_threat", new_air_threat, orders_by_id)
			if not ward.is_empty():
				_offer(result, view, state, reserve, "escort", ward, SimData.array3(anchor + Vector3(0, 1500, 0)), 3000.0, "reserve_air_cover", flag_changed or new_air_threat, orders_by_id)
			else:
				_offer(result, view, state, reserve, "patrol", "", policy.air_retreat_center_m, 2000.0, "force_depleted", false, orders_by_id)
		elif not ward.is_empty():
			_offer(result, view, state, planes, "escort", ward, SimData.array3(anchor + Vector3(0, 1500, 0)), 3000.0, "protect_core", flag_changed, orders_by_id)
		else:
			_offer(result, view, state, planes, "patrol", "", SimData.array3(SimData.vec3(policy.patrol_center_m) + Vector3(0, 1500, 0)), float(policy.patrol_radius_m), "search_no_contact", false, orders_by_id)
	return result

func _offer(result: Array[BattleOrder], view: Dictionary, state: Dictionary, ids: Array[String], kind: String, target: String, center: Array, radius: float, reason: String, urgent: bool, orders: Dictionary) -> void:
	if ids.is_empty():
		return
	var needed: Array[String] = []
	for id: String in ids:
		var active: Dictionary = orders.get(view.units[id].active_order_id, {})
		if str(active.get("order_type", "")) == kind and str(active.get("target_id", "")) == target and (kind != "escort" or str(active.get("intent", "")) == reason):
			continue
		if not urgent and float(view.time_s) - float(state.last_issue.get(id, -INF)) < float(config.data.policy.order_cooldown_s):
			continue
		# A completed regroup is followed by patrol instead of repeated regroup.
		if kind == "regroup" and str(state.signatures.get(id, "")) == "regroup:" + reason:
			continue
		needed.append(id)
	if needed.is_empty():
		return
	serial += 1
	var order: BattleOrder = BattleOrder.new()
	order.order_id = "fleet_ai:%s:%04d" % [view.faction_id, serial]
	order.issuer_id = str(view.faction_id) + "_commander"
	order.faction_id = view.faction_id
	order.source = "ai"
	order.recipient_ids = _recipients(view.groups, needed)
	order.order_type = kind
	order.target_id = target
	order.area = {"center_m": center.duplicate(), "radius_m": radius}
	order.intent = reason
	result.append(order)

func remember(view: Dictionary, order: BattleOrder, accepted: bool) -> void:
	if not accepted:
		return
	var state: Dictionary = memory[view.faction_id]
	for recipient: String in order.recipient_ids:
		var ids: Array = view.groups[recipient].member_ids if view.groups.has(recipient) else [recipient]
		for id: String in ids:
			state.last_issue[id] = view.time_s
			state.signatures[id] = order.order_type + ":" + order.intent

func _withdraw_reason(unit: Dictionary, policy: Dictionary) -> String:
	var damage: Dictionary = unit.module_data.get("damage", {})
	if float(damage.get("propulsion_factor", 1.0)) < 0.4 or float(damage.get("control_factor", 1.0)) < 0.5 or float(damage.get("structure", 1.0)) < float(damage.get("structure_max", 1.0)) * 0.3:
		return "severe_damage"
	if config.supports(unit.definition_id):
		if float(unit.module_data.get("ship_motion", {}).get("fuel_fraction", 1.0)) < 0.08:
			return "low_fuel"
	else:
		var p: Dictionary = aircraft.profile(unit.definition_id)
		var fuel: float = float(unit.module_data.get("aircraft_motion", {}).get("fuel_kg", p.fuel_capacity_kg))
		var distance: float = (unit.position_m as Vector3).distance_to(SimData.vec3(policy.air_retreat_center_m))
		if fuel < float(p.cruise_burn_kgps) * (float(p.reserve_s) + distance / float(p.cruise_mps) * 1.5):
			return "low_fuel"
	var ammunition: int = 0
	for weapon: Dictionary in unit.weapons.values():
		if bool(weapon.enabled):
			for count: int in weapon.remaining_rounds:
				ammunition += count
	return "no_ammunition" if ammunition == 0 else ""

func _flagship(units: Dictionary, ids: Array[String], previous: String) -> String:
	if ids.has(previous):
		return previous
	var best: float = -INF
	var result: String = ""
	for id: String in ids:
		var rank: float = float(units[id].module_data.get("ship_initial", {}).get("flagship_priority", config.profile(units[id].definition_id).flag_rank))
		if rank > best:
			best = rank
			result = id
	return result

static func _select_contact(contacts: Array[Dictionary], domain: String, anchor: Vector3, preferred: String = "") -> Dictionary:
	var result: Dictionary = {}
	var best: float = INF
	for contact: Dictionary in contacts:
		if contact.domain != domain:
			continue
		if str(contact.entity_id) == preferred:
			return contact
		var distance: float = anchor.distance_to(contact.position_m)
		if distance < best:
			result = contact
			best = distance
	return result

static func _recipients(groups: Dictionary, ids: Array[String]) -> Array[String]:
	var sorted_ids: Array[String] = ids.duplicate()
	sorted_ids.sort()
	var names: Array = groups.keys()
	names.sort()
	for name: String in names:
		var members: Array[String] = []
		members.assign(groups[name].member_ids)
		members.sort()
		if members == sorted_ids:
			return [name]
	return sorted_ids

func snapshot_state() -> Dictionary:
	return {"memory": memory.duplicate(true), "serial": serial}
