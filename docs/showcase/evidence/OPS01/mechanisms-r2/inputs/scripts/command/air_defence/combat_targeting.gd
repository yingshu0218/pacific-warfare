class_name CombatTargeting
extends SimulationModule

var config: CombatConfig
var frame: CombatFrame
var intelligence: CombatContacts
var changed: Dictionary = {}

func _init(parameters: CombatConfig, geometry: CombatFrame, contacts: CombatContacts) -> void:
	module_id = "combat_targeting"
	priority = 450
	config = parameters
	frame = geometry
	intelligence = contacts

func reset(_world: RefCounted) -> void:
	changed.clear()

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
		var old: Dictionary = unit.module_data.get("combat_runtime", {})
		var targets: Dictionary = {}
		var reasons: Dictionary = {}
		var assigned: Dictionary = {}
		var intent: Dictionary = unit.module_data.get("combat_intent", {})
		for mount: MountSocket in (frame.definitions[id] as UnitDefinition).mounts:
			var p: Dictionary = config.data.weapon_profiles[mount.weapon_definition_id]
			var selected: String = ""
			var reason: String = "no_contact"
			var contact: Dictionary = views[unit.faction_id].get(unit.target_id, {})
			if not contact.is_empty() and contact.domain in p.domains and bool(intent.get("fire", false)):
				selected = unit.target_id
				reason = "task_target"
			# AA autonomy is limited to the task's explicitly permitted responsibility.
			if (mount.role == "dedicated_aa" or bool(p.get("dual_purpose", false))) and bool(intent.get("allow_aa", false)) and not bool(intent.get("lock_target",false)) and (selected.is_empty() or mount.role == "dedicated_aa"):
				var best: float = -INF
				var previous: String = old.get("mount_targets", {}).get(mount.id, "")
				for target_id: String in views[unit.faction_id]:
					var c: Dictionary = views[unit.faction_id][target_id]
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
					if target_id == previous and world.time_s() - float(changed.get(id + "/" + mount.id, -100.0)) < float(config.data.contacts.target_cooldown_s):
						score += 100.0
					if score > best:
						best = score
						selected = target_id
						reason = "aa_closing_distance_allocation"
				if selected != previous:
					changed[id + "/" + mount.id] = world.time_s()
			if not selected.is_empty():
				assigned[selected] = int(assigned.get(selected, 0)) + 1
			targets[mount.id] = selected
			reasons[mount.id] = reason
		old["mount_targets"] = targets
		old["mount_reasons"] = reasons
		if not old.has("mount_status"):
			old["mount_status"] = {}
		unit.module_data["combat_runtime"] = old

func snapshot_state() -> Dictionary:
	return {"changed_time_s": changed.duplicate(true)}
