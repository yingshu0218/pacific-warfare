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

func plan(view: Dictionary, post: String = "", mode: String = "balanced") -> Array[BattleOrder]:
	var result: Array[BattleOrder] = []
	if view.is_empty() or not config.data.commanders.has(view.faction_id):
		return result
	var faction: String = view.faction_id
	var now: float = float(view.time_s)
	if not memory.has(faction):
		memory[faction] = {"last_issue": {}, "signatures": {}, "flagship": "", "air_threat": false, "last_surface_s": -INF, "had_contact": false}
	var state: Dictionary = memory[faction]
	var policy: Dictionary = config.data.commanders[faction]
	var ids: Array = view.units.keys()
	ids.sort()
	var ships: Array[String] = []
	var carriers: Array[String] = []
	var planes: Array[String] = []
	var protectable: Array[String] = []
	var air_defence_anchors: Array[Vector3] = []
	var carrier_station: Dictionary = policy.get("carrier_station", {})
	var own_ship_count: int = 0
	var roster: Dictionary = {"fleet": 0, "air": 0, "strike": 0}
	var ready: Dictionary = {"fleet": 0, "air": 0, "strike": 0}
	var withdrawn: Dictionary = {}
	var orders_by_id: Dictionary = {}
	for order: Dictionary in view.orders:
		orders_by_id[order.order_id] = order
		if order.order_type == "retreat":
			for id: String in order.assigned_unit_ids:
				withdrawn[id] = true
			for id: String in order.execution:
				if order.execution[id].status == "completed":
					withdrawn[id] = true
	var retreats: Dictionary = {}
	for id: String in ids:
		var unit: Dictionary = view.units[id]
		var unit_post: String = "fleet" if config.supports(unit.definition_id) else "air"
		var flight_role: String = str(aircraft.profile(unit.definition_id).get("role", "")) if unit_post == "air" else ""
		var role: String = unit_post if unit_post == "fleet" or flight_role == "fighter" else "strike"
		var active: Dictionary = orders_by_id.get(unit.active_order_id, {})
		var issuer: String = BattleOrder.post_issuer(faction, unit_post)
		var available: bool = unit.active and not withdrawn.has(id) and not BattleOrder.unit_reserved(unit.module_data, unit.task)
		var reason: String = _withdraw_reason(unit, policy) if available and (unit_post == "fleet" or aircraft.supports(unit.definition_id)) else ""
		var may_assign: bool = available and BattleOrder.may_replace(active, issuer)
		if unit.active and unit.module_data.has("ground_initial"):
			air_defence_anchors.append(unit.position_m)
		if unit_post == "fleet":
			own_ship_count += 1
			if unit.active and not withdrawn.has(id) and reason.is_empty():
				protectable.append(id)
				air_defence_anchors.append(unit.position_m)
		if role != "strike" or unit.module_data.has("bomb_rack"):
			roster[role] += 1
			if reason.is_empty() and (may_assign or (available and role == "strike" and active.get("order_type", "") == "bombing")):
				ready[role] += 1
		# Strike aircraft have a separate mission delegate under the air post.
		if not may_assign or role == "strike":
			continue
		if not reason.is_empty():
			if not post.is_empty() and post != unit_post:
				continue
			var key: String = unit_post + ":" + reason
			if not retreats.has(key):
				retreats[key] = []
			retreats[key].append(id)
			continue
		if unit_post == "fleet":
			if not carrier_station.is_empty() and config.data.profiles[unit.definition_id].get("role", "") == "carrier":
				carriers.append(id)
			else:
				ships.append(id)
		else:
			planes.append(id)
	for key: String in retreats:
		var retreat_ids: Array[String] = []
		retreat_ids.assign(retreats[key])
		var ship: bool = key.begins_with("fleet:")
		_offer(result, view, state, retreat_ids, "retreat", "", policy.retreat_center_m if ship else policy.air_retreat_center_m,
			float(config.data.policy.ship_retreat_radius_m if ship else config.data.policy.air_retreat_radius_m), key.get_slice(":", 1), true, orders_by_id, "fleet" if ship else "air")
	var previous_flag: String = str(state.flagship)
	var core: String = _flagship(view.units, ships, previous_flag)
	# A human-controlled friendly core is still a valid air-protection object.
	var ward: String = core if not core.is_empty() else _flagship(view.units, protectable, "")
	var flag_changed: bool = not previous_flag.is_empty() and previous_flag != core
	state.flagship = core
	var anchor: Vector3 = (view.units[ward].position_m as Vector3) if not ward.is_empty() else SimData.vec3(policy.patrol_center_m)
	if air_defence_anchors.is_empty():
		air_defence_anchors.append(anchor)
	var fresh: Array[Dictionary] = []
	var known: Dictionary = {}
	var bombers: Array[Dictionary] = []
	var air_contacts: Array[Dictionary] = []
	for contact: Dictionary in view.contacts:
		if not contact.get("valid", false):
			continue
		known[contact.entity_id] = contact
		if not contact.get("fresh", false):
			continue
		if contact.domain == "aircraft":
			if _is_bomber(contact):
				bombers.append(contact)
			else:
				air_contacts.append(contact)
		else:
			fresh.append(contact)
	var air_threat: bool = not _select_air(bombers, air_defence_anchors, view.units, []).is_empty() or not _select_air(air_contacts, air_defence_anchors, view.units, []).is_empty()
	var new_air_threat: bool = air_threat and not bool(state.air_threat)
	state.air_threat = air_threat
	var posture: String = "balanced"
	if not post.is_empty():
		var force: String = "strike" if post == "air" and roster.air == 0 else post
		var has_contacts: bool = air_threat
		if post == "fleet":
			has_contacts = fresh.any(func(contact: Dictionary) -> bool: return contact.domain == "ship" or contact.get("role", "") == "coastal_gun")
		elif force == "strike":
			has_contacts = not fresh.is_empty()
		_update_posture(view, state, post, mode, ready[force], roster[force], has_contacts)
		posture = state.posture.posture
	if post != "air" and not core.is_empty():
		var main: Array[String] = [core]
		var current: Dictionary = orders_by_id.get(view.units[core].active_order_id, {})
		var committed: String = str(current.get("target_id", "")) if current.get("order_type", "") == "engage" else ""
		var range_m: float = float(config.data.profiles[view.units[core].definition_id].engagement_range_m)
		var current_track: Dictionary = known.get(committed, {})
		var current_fresh: bool = bool(current_track.get("fresh", false))
		var surface: Dictionary = select_surface_contact(fresh, anchor, anchor, range_m, committed, true, posture)
		if not surface.is_empty():
			state.last_surface_s = surface.observed_time_s
			state.had_contact = true
			var in_range: bool = anchor.distance_to(surface.position_m) <= range_m
			var replacing_shore: bool = current_track.get("domain", "") == "ground"
			var reason: String = "shore_battery_threat" if surface.domain == "ground" else ("surface_threat" if in_range else "surface_contact")
			var urgent: bool = flag_changed or (not committed.is_empty() and not current_fresh)
			urgent = urgent or (surface.domain == "ship" and in_range and (committed.is_empty() or replacing_shore))
			_offer(result, view, state, main, "engage", str(surface.entity_id), SimData.array3(surface.position_m), float(policy.patrol_radius_m), "flagship_replacement" if flag_changed else reason, urgent, orders_by_id)
		elif current_fresh:
			# A still-visible battery can cease to threaten this fleet as it moves.
			_offer(result, view, state, main, "patrol", "", policy.patrol_center_m, float(policy.patrol_radius_m), "search_no_contact", false, orders_by_id)
		elif bool(state.had_contact) and now - float(state.last_surface_s) > float(config.data.policy.contact_hysteresis_s):
			# Let the executor's last-contact search produce its own real failure first.
			if committed.is_empty():
				if str(state.signatures.get(core, "")) == "regroup:reform_after_contact_loss" and current.is_empty():
					_offer(result, view, state, main, "patrol", "", policy.patrol_center_m, float(policy.patrol_radius_m), "search_no_contact", false, orders_by_id)
				elif str(current.get("order_type", "")) != "patrol":
					_offer(result, view, state, main, "regroup", "", SimData.array3(anchor), 900.0, "reform_after_contact_loss", false, orders_by_id)
		elif committed.is_empty():
			_offer(result, view, state, main, "patrol", "", policy.patrol_center_m, float(policy.patrol_radius_m), "flagship_replacement" if flag_changed else "search_no_contact", flag_changed, orders_by_id)
		var escorts: Array[String] = ships.duplicate()
		escorts.erase(core)
		_offer(result, view, state, escorts, "escort", core, SimData.array3(anchor), 3500.0, "air_defence_cover" if air_threat else "protect_core", flag_changed or new_air_threat, orders_by_id)
	if post != "air" and not carriers.is_empty():
		_offer(result, view, state, carriers, "patrol", "", carrier_station.center_m, float(carrier_station.radius_m), "carrier_station", false, orders_by_id)
	if post == "fleet":
		return result
	if own_ship_count > 0 and protectable.is_empty():
		_offer(result, view, state, planes, "retreat", "", policy.air_retreat_center_m, float(config.data.policy.air_retreat_radius_m), "force_depleted", true, orders_by_id, "air")
		return result
	_plan_air(result, view, state, orders_by_id, planes, known, bombers, air_contacts, air_defence_anchors, ward, anchor, policy, posture, flag_changed)
	return result

func _update_posture(view: Dictionary, state: Dictionary, post: String, mode: String, ready: int, total: int, has_contacts: bool) -> void:
	var previous: Dictionary = state.get("posture", {})
	var current: String = str(previous.get("posture", "balanced"))
	var next: String = mode
	var reason: String = "posture_fixed"
	if mode == "auto":
		var fraction: float = float(ready) / maxi(1, total)
		var protect_below: float = 0.66 if current == "conservative" else 0.50
		var advance_above: float = 0.70 if current == "offensive" else 0.80
		if total > 0 and fraction < protect_below:
			next = "conservative"
			reason = "posture_limited_force"
		elif ready >= 2 and fraction >= advance_above and has_contacts:
			next = "offensive"
			reason = "posture_contact_ready"
		else:
			next = "balanced"
			reason = "posture_limited_force" if has_contacts else "posture_no_contact"
	if not previous.is_empty() and current != next and float(view.time_s) + 0.000001 - float(previous.changed_s) < 2.0 * float(config.data.policy.decision_period_s):
		return
	var changed: bool = previous.is_empty() or current != next
	state["posture"] = {"posture": next, "reason": reason, "issuer_id": BattleOrder.post_issuer(view.faction_id, post),
		"changed_tick": int(view.get("tick", 0)) if changed else int(previous.changed_tick),
		"changed_s": float(view.time_s) if changed else float(previous.changed_s)}

func _plan_air(result: Array[BattleOrder], view: Dictionary, state: Dictionary, orders: Dictionary, planes: Array[String], known: Dictionary, bombers: Array[Dictionary], air_contacts: Array[Dictionary], anchors: Array[Vector3], ward: String, anchor: Vector3, policy: Dictionary, posture: String, flag_changed: bool) -> void:
	var reserve: Array[String] = planes.duplicate()
	var retained: Dictionary = _retained_intercepts(view, orders, planes, known, anchors)
	var roles: Dictionary = {}
	for entry: Dictionary in retained.values():
		roles[entry.role] = true
		for id: String in entry.members:
			reserve.erase(id)

	var radius_factor: float = {"offensive": 1.30, "balanced": 1.0, "conservative": 0.68}[posture]
	# Preserve the existing pair and use uncommitted aircraft for new contacts.
	var raid: bool = roles.has("bomber")
	if not raid and not reserve.is_empty():
		var threat: Dictionary = _select_air(bombers, anchors, view.units, reserve, radius_factor)
		if not threat.is_empty():
			var pair: Array[String] = _interceptor_pair(reserve, view, threat)
			_offer(result, view, state, pair, "intercept", str(threat.entity_id), SimData.array3(threat.position_m), 2500.0, "intercept_bomber", true, orders, "air")
			for id: String in pair:
				reserve.erase(id)
			raid = true
	if not roles.has("fighter") and not reserve.is_empty():
		var fighter_radius: float = radius_factor * 0.6 if raid and posture == "conservative" else radius_factor
		var threat: Dictionary = _select_air(air_contacts, anchors, view.units, reserve, fighter_radius)
		if not threat.is_empty():
			var pair: Array[String] = _interceptor_pair(reserve, view, threat)
			var reason: String = "intercept_fighter_cover" if raid else "intercept_air_threat"
			_offer(result, view, state, pair, "intercept", str(threat.entity_id), SimData.array3(threat.position_m), 2500.0, reason, true, orders, "air")
			for id: String in pair:
				reserve.erase(id)

	var station: Array = SimData.array3(anchor + Vector3.UP * 1500.0)
	if not ward.is_empty():
		var covering: bool = reserve.size() < planes.size()
		_offer(result, view, state, reserve, "escort", ward, station, 3000.0, "reserve_air_cover" if covering else "protect_core", flag_changed, orders, "air")
	else:
		_offer(result, view, state, reserve, "patrol", "", station, float(policy.patrol_radius_m), "search_no_contact", false, orders, "air")

func _retained_intercepts(view: Dictionary, orders: Dictionary, planes: Array[String], known: Dictionary, anchors: Array[Vector3]) -> Dictionary:
	var result: Dictionary = {}
	for id: String in planes:
		var order: Dictionary = orders.get(view.units[id].active_order_id, {})
		if order.get("order_type", "") != "intercept" or result.has(order.order_id):
			continue
		var contact: Dictionary = known.get(order.target_id, {})
		if contact.is_empty():
			continue
		# Retain everyone still able to fight. The executor handles lead takeover
		# when a wingman is the only remaining member of the order.
		var pair: Array[String] = []
		pair.assign(order.assigned_unit_ids.filter(func(member: String) -> bool: return planes.has(member)))
		if bool(contact.fresh):
			# Preserve the phase even if the post subsequently tightens its dispatch radius.
			if not is_finite(_air_score(contact, anchors, view.units, pair, 1.50)):
				continue
		elif float(view.time_s) - float(contact.observed_time_s) > float(config.data.policy.contact_hysteresis_s):
			continue
		result[order.order_id] = {"role": "bomber" if _is_bomber(contact) else "fighter", "members": pair}
	return result

func _offer(result: Array[BattleOrder], view: Dictionary, state: Dictionary, ids: Array[String], kind: String, target: String, center: Array, radius: float, reason: String, urgent: bool, orders: Dictionary, post: String = "fleet") -> void:
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
	if kind == "intercept":
		# Interception is a shared executor roster, including when only one of its
		# members would otherwise need a change.
		needed = ids
	order.order_id = "%s_ai:%s:%04d" % [post, view.faction_id, serial]
	order.issuer_id = BattleOrder.post_issuer(view.faction_id, post)
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
	if unit.module_data.has("bomb_rack"):
		return "no_ammunition" if int(unit.module_data.bomb_rack.get("remaining", 0)) <= 0 else ""
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

## Shared by the fleet commander and the local escort screen.
static func select_surface_contact(contacts: Array, own_position: Vector3, defended: Vector3, range_m: float, preferred: String, may_approach: bool, posture: String = "") -> Dictionary:
	var best: float = -INF
	var result: Dictionary = {}
	for contact: Dictionary in contacts:
		if not contact.get("valid", false) or not contact.get("fresh", false):
			continue
		var point: Vector3 = contact.position_m
		var velocity: Vector3 = contact.velocity_mps
		point.y = 0.0
		velocity.y = 0.0
		var own_offset: Vector3 = Vector3(own_position.x, 0.0, own_position.z) - point
		var defended_offset: Vector3 = Vector3(defended.x, 0.0, defended.z) - point
		var distance: float = own_offset.length()
		var threat_offset: Vector3 = defended_offset if defended_offset.length_squared() < own_offset.length_squared() else own_offset
		var threat_distance: float = threat_offset.length()
		var closing: float = velocity.dot(threat_offset.normalized())
		var enemy_range: float = float(contact.get("surface_range_m", range_m))
		var committed: bool = str(contact.entity_id) == preferred
		var reachable: bool = distance <= range_m or (committed and distance <= range_m * 1.08)
		var immediate: bool = threat_distance - maxf(0.0, closing) * 30.0 <= enemy_range
		var approach_limit: float = {"offensive": 1.65, "balanced": 1.25, "conservative": 0.0}.get(posture, INF)
		var can_approach: bool = may_approach and (distance <= range_m * approach_limit or (committed and distance <= range_m * 1.25))
		var priority: float
		if contact.domain == "ship" and (reachable or can_approach) and (posture != "conservative" or immediate or committed):
			priority = 0.0
			if reachable:
				priority = 6.0 if immediate else 2.0
		elif contact.domain == "ground" and reachable and contact.get("role", "") == "coastal_gun" and threat_distance <= enemy_range:
			priority = 3.0
		else:
			continue
		var score: float = priority - minf(threat_distance / range_m, 1.5) + clampf(closing / 60.0, -0.35, 0.35)
		if contact.get("role", "") == "heavy_surface":
			score += 1.1 if posture == "offensive" else 0.4
		if committed:
			score += 0.25
		if score > best:
			best = score
			result = contact
	return result

static func _is_bomber(contact: Dictionary) -> bool:
	return str(contact.get("role", "")) in ["level_bomber", "dive_bomber"]

func _select_air(contacts: Array[Dictionary], anchors: Array[Vector3], units: Dictionary, fighters: Array[String], radius_factor: float = 1.0) -> Dictionary:
	var best: float = -INF
	var result: Dictionary = {}
	for contact: Dictionary in contacts:
		var score: float = _air_score(contact, anchors, units, fighters, radius_factor)
		if score > best:
			best = score
			result = contact
	return result

func _air_score(contact: Dictionary, anchors: Array[Vector3], units: Dictionary, fighters: Array[String], radius_factor: float) -> float:
	var radius: float = float(config.data.policy.air_threat_radius_m) * radius_factor
	var point: Vector3 = contact.position_m
	var velocity: Vector3 = contact.velocity_mps
	var projected: Vector3 = point + velocity * 8.0
	var asset_distance: float = INF
	var closing: float = 0.0
	for asset: Vector3 in anchors:
		var distance: float = minf(asset.distance_to(point), asset.distance_to(projected))
		if distance < asset_distance:
			asset_distance = distance
			closing = velocity.dot((asset - point).normalized())
	if asset_distance >= radius:
		return -INF
	var intercept_distance: float = 0.0 if fighters.is_empty() else INF
	for id: String in fighters:
		intercept_distance = minf(intercept_distance, projected.distance_to(units[id].position_m))
	if intercept_distance > radius * 1.35:
		return -INF
	var score: float = -asset_distance / radius - 0.65 * intercept_distance / radius + clampf(closing / 170.0, -0.4, 0.4)
	if _is_bomber(contact) and (closing > 0.0 or asset_distance < radius * 0.5):
		score += 1.4
	return score

func _interceptor_pair(fighters: Array[String], view: Dictionary, contact: Dictionary) -> Array[String]:
	if fighters.size() <= 2:
		return fighters.duplicate()
	var candidates: Array[String] = fighters.duplicate()
	var projected: Vector3 = contact.position_m + (contact.velocity_mps as Vector3) * 8.0
	var costs: Dictionary = {}
	for id: String in candidates:
		costs[id] = projected.distance_to(view.units[id].position_m)
	var best: float = INF
	var pair: Array[String] = []
	var group_ids: Array = view.groups.keys()
	group_ids.sort()
	for group_id: String in group_ids:
		var members: Array = view.groups[group_id].member_ids
		if members.size() != 2 or not members.all(func(id: String) -> bool: return costs.has(id)):
			continue
		var cost: float = float(costs[members[0]]) + float(costs[members[1]])
		if cost < best:
			best = cost
			pair.assign(members)
	if not pair.is_empty():
		return pair
	candidates.sort_custom(func(a: String, b: String) -> bool: return float(costs[a]) < float(costs[b]) if costs[a] != costs[b] else a < b)
	return candidates.slice(0, 2)

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
