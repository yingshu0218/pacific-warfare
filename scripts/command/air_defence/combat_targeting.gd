class_name CombatTargeting
extends SimulationModule

const BLOCKED_STATUSES: Array[String] = ["arc", "masked", "terrain_masked", "out_of_range"]

var config: CombatConfig
var frame: CombatFrame
var intelligence: CombatContacts
var changed: Dictionary = {}
var ship_policies: Dictionary = {}

func _init(parameters: CombatConfig, geometry: CombatFrame, contacts: CombatContacts) -> void:
	module_id = "combat_targeting"
	priority = 450
	config = parameters
	frame = geometry
	intelligence = contacts

func reset(_world: RefCounted) -> void:
	changed.clear()
	ship_policies.clear()

func fixed_update(world_ref: RefCounted, _delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	var views: Dictionary = {}
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not views.has(unit.faction_id):
			var contacts: Dictionary = {}
			for c: Dictionary in intelligence.records.get(unit.faction_id, {}).values():
				if c.fresh and c.valid:
					contacts[c.entity_id] = c
			views[unit.faction_id] = contacts
		var runtime: Dictionary = unit.module_data.get("combat_runtime", {})
		var intent: Dictionary = unit.module_data.get("combat_intent", {})
		var definition: UnitDefinition = frame.definitions[id]
		var contacts: Dictionary = views[unit.faction_id]
		var targets: Dictionary = {}
		var reasons: Dictionary = {}
		if definition.domain == "ship":
			_assign_ship(world, unit, definition, contacts, intent, runtime, targets, reasons)
		else:
			_assign_non_ship(world, unit, definition, contacts, intent, runtime, targets, reasons)
		runtime["mount_targets"] = targets
		runtime["mount_reasons"] = reasons
		if not runtime.has("mount_status"):
			runtime["mount_status"] = {}
		unit.module_data["combat_runtime"] = runtime

func _assign_ship(world: SimulationWorld, unit: UnitState, definition: UnitDefinition, contacts: Dictionary, intent: Dictionary, runtime: Dictionary, targets: Dictionary, reasons: Dictionary) -> void:
	var posture: String = str(world.shared_state.get("command_postures", {}).get(unit.faction_id, {}).get("fleet", {}).get("posture", "balanced"))
	if posture not in ["offensive", "conservative"]:
		posture = "balanced"
	var fire: bool = bool(intent.get("fire", false)) and not unit.target_id.is_empty()
	var allow_aa: bool = bool(intent.get("allow_aa", false))
	var locked: bool = bool(intent.get("lock_target", false))
	var policy: Array = [unit.target_id, posture, fire, allow_aa, locked]
	var same_policy: bool = ship_policies.get(unit.id, []) == policy
	ship_policies[unit.id] = policy
	var live: bool = unit.active and CombatPresence.is_present(unit.module_data)
	var now_s: float = world.time_s()
	var cooldown_s: float = float(config.data.contacts.target_cooldown_s)
	var task_domain: String = intelligence.records.get(unit.faction_id, {}).get(unit.target_id, {}).get("domain", "")
	var local_contacts: Dictionary = {}
	if live and not unit.cease_fire and (fire or (allow_aa and not locked)):
		var to_local: Transform3D = unit.world_transform().affine_inverse()
		for target_id: String in contacts:
			if locked and target_id != unit.target_id:
				continue
			var contact: Dictionary = contacts[target_id]
			var domain: String = contact.domain
			if domain == "aircraft":
				if not allow_aa:
					continue
			elif not fire or domain != task_domain:
				continue
			var age_s: float = maxf(0.0, now_s - float(contact.observed_time_s))
			var velocity: Vector3 = contact.velocity_mps
			var point: Vector3 = contact.position_m + velocity * age_s
			if domain == "ship":
				point.y += 3.0
			elif domain == "ground":
				point += contact.get("aim_offset_m", Vector3.ZERO) as Vector3
			var offset: Vector3 = point - unit.position_m
			var closing: float = -(velocity - unit.velocity_mps).dot(offset.normalized())
			local_contacts[target_id] = {"domain": domain, "point": to_local * point, "closing": closing}

	var assigned: Dictionary = {}
	var previous_targets: Dictionary = runtime.get("mount_targets", {})
	var statuses: Dictionary = runtime.get("mount_status", {})
	var parts: Dictionary = unit.module_data.get("damage", {}).get("parts", {})
	for mount: MountSocket in definition.mounts:
		var weapon: WeaponState = unit.weapons[mount.id]
		var target: String = ""
		var reason: String = "no_contact"
		if not live or not weapon.enabled or float(parts.get("weapon:" + mount.id, 1.0)) <= 0.0:
			reason = "disabled"
		elif not _has_rounds(weapon):
			reason = "empty"
		elif unit.cease_fire:
			reason = "hold_fire"
		elif not local_contacts.is_empty():
			var previous: String = previous_targets.get(mount.id, "")
			var committed: bool = same_policy and now_s - float(changed.get(weapon.id, -INF)) < cooldown_s
			var blocked: bool = statuses.get(mount.id, "") in BLOCKED_STATUSES
			target = _choose_ship_target(unit.target_id, mount, local_contacts, assigned, posture, locked, previous, committed, blocked)
			if not target.is_empty():
				assigned[target] = int(assigned.get(target, 0)) + 1
				if target == unit.target_id:
					reason = "task_target"
				elif local_contacts[target].domain == "aircraft":
					reason = "aa_closing_distance_allocation"
				else:
					reason = "surface_contact_allocation"
		if target.is_empty():
			changed.erase(weapon.id)
		elif target != previous_targets.get(mount.id, "") or not same_policy:
			changed[weapon.id] = now_s
		targets[mount.id] = target
		reasons[mount.id] = reason

func _choose_ship_target(task_id: String, mount: MountSocket, contacts: Dictionary, assigned: Dictionary, posture: String, locked: bool, previous: String, committed: bool, blocked: bool) -> String:
	var profile: Dictionary = config.data.weapon_profiles[mount.weapon_definition_id]
	var gun: WeaponDefinition = frame.guns[mount.weapon_definition_id]
	var dedicated: bool = mount.role == "dedicated_aa"
	var dual: bool = bool(profile.get("dual_purpose", false))
	var primary: bool = mount.role == "main"
	if locked or (primary and not dual and posture != "offensive"):
		return task_id if _ship_contact_score(contacts.get(task_id, {}), mount, gun, profile, dedicated, dual) > -INF else ""
	# Keep a viable assignment during traverse and reload. A new order or
	# posture releases this commitment, as does an invalid candidate.
	if committed and _ship_contact_score(contacts.get(previous, {}), mount, gun, profile, dedicated, dual) > -INF:
		return previous
	var prefer_task: bool = primary and not (dual and posture == "conservative")
	if prefer_task and not (previous == task_id and blocked):
		if _ship_contact_score(contacts.get(task_id, {}), mount, gun, profile, dedicated, dual) > -INF:
			return task_id
	var best: float = -INF
	var target: String = ""
	for target_id: String in contacts:
		var candidate: Dictionary = contacts[target_id]
		var air: bool = candidate.domain == "aircraft"
		if not air and target_id != task_id and (posture == "conservative" or (primary and posture != "offensive")):
			continue
		var score: float = _ship_contact_score(candidate, mount, gun, profile, dedicated, dual)
		if score == -INF:
			continue
		if target_id == task_id:
			score += 3.0 if prefer_task else 0.55
		if dual and posture != "balanced":
			if air == (posture == "conservative"):
				score += 4.0
		score -= float(mini(6, int(assigned.get(target_id, 0)))) * 0.3
		if target_id == previous:
			score += -5.0 if blocked else 0.2
		if score > best or (score == best and target_id < target):
			best = score
			target = target_id
	return target

func _ship_contact_score(contact: Dictionary, mount: MountSocket, gun: WeaponDefinition, profile: Dictionary, dedicated: bool, dual: bool) -> float:
	if contact.is_empty() or contact.domain not in profile.domains:
		return -INF
	var air: bool = contact.domain == "aircraft"
	if (air and not (dedicated or dual)) or (dedicated and not air):
		return -INF
	var offset: Vector3 = (contact.point as Vector3) - mount.position_m
	var distance_m: float = offset.length()
	var range_m: float = float(profile.range_m)
	if distance_m > range_m or distance_m < 1.0:
		return -INF
	var yaw: float = wrapf(atan2(-offset.x, -offset.z) - mount.base_yaw_rad, -PI, PI)
	if yaw < gun.train_limits_rad.x or yaw > gun.train_limits_rad.y:
		return -INF
	# This bearing check only screens candidates. The existing executor still
	# computes lead and tests actual muzzle traversal, obstruction and release.
	var elevation: float = atan2(offset.y, Vector2(offset.x, offset.z).length())
	if elevation > gun.elevation_limits_rad.y:
		return -INF
	var closing_bonus: float = clampf(float(contact.closing) / 200.0, 0.0, 0.6) if air else 0.0
	return 1.0 - distance_m / range_m + closing_bonus

func _has_rounds(weapon: WeaponState) -> bool:
	for rounds: int in weapon.remaining_rounds:
		if rounds > 0:
			return true
	return false

func _assign_non_ship(world: SimulationWorld, unit: UnitState, definition: UnitDefinition, contacts: Dictionary, intent: Dictionary, old: Dictionary, targets: Dictionary, reasons: Dictionary) -> void:
	var assigned: Dictionary = {}
	for mount: MountSocket in definition.mounts:
		var p: Dictionary = config.data.weapon_profiles[mount.weapon_definition_id]
		if definition.domain == "aircraft" and mount.role == "dedicated_aa":
			_assign_aircraft_defense(world, unit, mount, contacts, p, targets, reasons)
			continue
		var selected: String = ""
		var reason: String = "no_contact"
		var contact: Dictionary = contacts.get(unit.target_id, {})
		if not contact.is_empty() and contact.domain in p.domains and bool(intent.get("fire", false)):
			selected = unit.target_id
			reason = "task_target"
		# AA autonomy is limited to the task's explicitly permitted responsibility.
		if (mount.role == "dedicated_aa" or bool(p.get("dual_purpose", false))) and bool(intent.get("allow_aa", false)) and not bool(intent.get("lock_target",false)) and (selected.is_empty() or mount.role == "dedicated_aa"):
			var best: float = -INF
			var previous: String = old.get("mount_targets", {}).get(mount.id, "")
			for target_id: String in contacts:
				var c: Dictionary = contacts[target_id]
				if c.domain != "aircraft" or not "aircraft" in p.domains:
					continue
				var offset: Vector3 = c.position_m - unit.position_m
				var distance: float = offset.length()
				if distance > float(p.range_m) or distance < 1.0:
					continue
				var local: Vector3 = unit.world_transform().basis.inverse() * offset
				var yaw: float = wrapf(atan2(-local.x, -local.z) - mount.base_yaw_rad, -PI, PI)
				var gun: WeaponDefinition = frame.guns[mount.weapon_definition_id]
				if yaw < gun.train_limits_rad.x or yaw > gun.train_limits_rad.y:
					continue
				var closing: float = -(c.velocity_mps as Vector3).dot(offset / distance)
				var score: float = 2.0 - distance / float(p.range_m) + maxf(closing, 0.0) / 200.0 - float(assigned.get(target_id, 0)) * 0.35
				if target_id == previous and world.time_s() - float(changed.get(unit.id + "/" + mount.id, -100.0)) < float(config.data.contacts.target_cooldown_s):
					score += 100.0
				if score > best:
					best = score
					selected = target_id
					reason = "aa_closing_distance_allocation"
			if selected != previous:
				changed[unit.id + "/" + mount.id] = world.time_s()
		if not selected.is_empty():
			assigned[selected] = int(assigned.get(selected, 0)) + 1
		targets[mount.id] = selected
		reasons[mount.id] = reason

func _assign_aircraft_defense(world: SimulationWorld, unit: UnitState, mount: MountSocket, contacts: Dictionary, profile: Dictionary, targets: Dictionary, reasons: Dictionary) -> void:
	var station: WeaponState = unit.weapons[mount.id]
	var flight: Dictionary = unit.module_data.get("aircraft_motion", {})
	var damage: Dictionary = unit.module_data.get("damage", {})
	targets[mount.id] = ""
	if not unit.active or not station.enabled or not CombatPresence.is_present(unit.module_data) or damage.get("phase", "operational") != "operational" or float(damage.get("parts", {}).get("weapon:" + mount.id, 1.0)) <= 0.0:
		reasons[mount.id] = "disabled"
	elif unit.cease_fire:
		reasons[mount.id] = "hold_fire"
	elif not _has_rounds(station):
		reasons[mount.id] = "empty"
	elif flight.is_empty() or bool(flight.get("surface_contact", false)) or bool(unit.module_data.get("carrier_ops", {}).get("on_deck", false)):
		reasons[mount.id] = "grounded"
	else:
		var to_local: Transform3D = unit.world_transform().affine_inverse()
		var best: float = INF
		var selected: String = ""
		var rejection: String = "no_contact"
		var gun: WeaponDefinition = frame.guns[station.definition_id]
		for id: String in contacts:
			var c: Dictionary = contacts[id]
			if c.domain != "aircraft" or c.domain not in profile.domains:
				continue
			var age: float = world.time_s() - float(c.observed_time_s)
			var offset: Vector3 = to_local * (c.position_m + (c.velocity_mps as Vector3) * age) - mount.position_m
			var distance: float = offset.length()
			if distance < 1.0 or distance > float(profile.range_m):
				if rejection == "no_contact": rejection = "out_of_range"
				continue
			var yaw: float = wrapf(atan2(-offset.x, -offset.z) - mount.base_yaw_rad, -PI, PI)
			var elevation: float = atan2(offset.y, Vector2(offset.x, offset.z).length())
			if yaw < gun.train_limits_rad.x or yaw > gun.train_limits_rad.y or elevation < gun.elevation_limits_rad.x or elevation > gun.elevation_limits_rad.y:
				rejection = "arc"
				continue
			if distance < best or (distance == best and id < selected):
				best = distance
				selected = id
		targets[mount.id] = selected
		reasons[mount.id] = "aircraft_self_defense" if not selected.is_empty() else rejection

func snapshot_state() -> Dictionary:
	return {"changed_time_s": changed.duplicate(true), "ship_policies": ship_policies.duplicate(true)}
