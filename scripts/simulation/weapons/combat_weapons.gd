class_name CombatWeapons
extends SimulationModule

var config: CombatConfig
var frame: CombatFrame
var intelligence: CombatContacts
var projectiles: CombatProjectiles
var fired_per_weapon: Dictionary = {}
var aim_cache: Dictionary = {}

func _init(parameters: CombatConfig, geometry: CombatFrame, contacts: CombatContacts, flight: CombatProjectiles) -> void:
	module_id = "combat_weapons"
	priority = 500
	config = parameters
	frame = geometry
	intelligence = contacts
	projectiles = flight

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	fired_per_weapon.clear()
	aim_cache.clear()
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		unit.module_data.erase("combat_runtime")
		for mount_id: String in unit.weapons:
			var state: WeaponState = unit.weapons[mount_id]
			var p: Dictionary = config.data.weapon_profiles[state.definition_id]
			if p.has("initial_rounds_per_barrel"):
				for index: int in range(state.remaining_rounds.size()):
					state.remaining_rounds[index] = int(p.initial_rounds_per_barrel)

func fixed_update(world_ref: RefCounted, delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		var runtime: Dictionary = unit.module_data.combat_runtime
		if not runtime.has("mount_efficiency"): runtime["mount_efficiency"] = {}
		runtime["fire_control_quality"] = _director_quality(unit)
		var salvos: Dictionary = {}
		for mount: MountSocket in (frame.definitions[id] as UnitDefinition).mounts:
			var state: WeaponState = unit.weapons[mount.id]
			var efficiency: float = _mount_efficiency(unit, mount.id)
			runtime.mount_efficiency[mount.id] = efficiency
			if state.cycle_remaining_s > 0:
				state.cycle_remaining_s -= delta_s * efficiency
			var count: int = _update_mount(world, unit, mount, state, delta_s)
			if count > 0 and mount.role == "main":
				var target_id: String = runtime.mount_targets[mount.id]
				if not salvos.has(target_id):
					salvos[target_id] = {"mount_ids": [], "rounds": 0}
				var salvo: Dictionary = salvos[target_id]
				salvo.mount_ids.append(mount.id)
				salvo.rounds += count
			if count == 0 and state.cycle_remaining_s < 0:
				state.cycle_remaining_s = 0.0
		if not salvos.is_empty():
			runtime["last_salvo_tick"] = world.tick
			for target_id: String in salvos:
				world.emit_event("salvo", unit.id, "", unit.position_m, salvos[target_id], target_id)

func _update_mount(world: SimulationWorld, unit: UnitState, mount: MountSocket, state: WeaponState, delta_s: float) -> int:
	var runtime: Dictionary = unit.module_data.combat_runtime
	var p: Dictionary = config.data.weapon_profiles[state.definition_id]
	var gun: WeaponDefinition = frame.guns[state.definition_id]
	var ammo: AmmoDefinition = frame.ammunition[gun.ammo_id]
	var target_id: String = runtime.mount_targets.get(mount.id, "")
	var contact: Dictionary = intelligence.records.get(unit.faction_id, {}).get(target_id, {})
	var self_defense: bool = mount.role == "dedicated_aa" and (frame.definitions[unit.id] as UnitDefinition).domain == "aircraft"
	var status: String = "ready"
	var efficiency: float = _mount_efficiency(unit, mount.id)
	var director: float = _director_quality(unit)
	if not unit.active or not state.enabled or efficiency <= 0 or not CombatPresence.is_present(unit.module_data):
		status = "disabled"
	elif state.remaining_rounds.all(func(count: int)->bool:return count<=0):
		status = "empty"
	elif unit.cease_fire and runtime.get("mount_reasons", {}).get(mount.id, "") == "hold_fire":
		status = "hold_fire"
	elif contact.is_empty() or not bool(contact.fresh):
		status = "no_contact"
		if self_defense and target_id.is_empty():
			status = str(runtime.mount_reasons.get(mount.id, "no_contact"))
	if status != "ready":
		runtime.mount_status[mount.id] = status
		return 0
	var envelope := config.mount_envelope(unit.definition_id, mount.id, gun)
	var age: float = world.time_s() - float(contact.observed_time_s)
	var point: Vector3 = contact.position_m + (contact.velocity_mps as Vector3) * age
	# Ship contact anchor is its waterline; aim at visible hull/upper belt.
	if contact.domain == "ship":
		point.y += 3.0
	elif contact.domain == "ground":
		# Sensor-published and retained with this contact, never enemy live state.
		point += contact.get("aim_offset_m", Vector3.ZERO) as Vector3
	var transform: Transform3D = unit.world_transform()
	var origin: Vector3 = transform * mount.local_muzzle_transform(0, state.train_rad, state.elevation_rad).origin
	var cached: Dictionary = aim_cache.get(state.id,{})
	var solution: Dictionary = {}
	# Reloading guns still train every tick. Only their expensive range solution is
	# sampled at a finite director rate; a ready gun ALWAYS solves current geometry.
	if state.cycle_remaining_s<=delta_s or cached.get("target_id","")!=target_id or world.tick>=int(cached.get("next_tick",-1)):
		solution=CombatFireControl.intercept(origin,unit.velocity_mps,point,contact.velocity_mps,ammo.muzzle_speed_mps,ammo.gravity_mps2,ammo.max_lifetime_s)
		aim_cache[state.id]={"target_id":target_id,"next_tick":world.tick+maxi(1,roundi(float(p.get("reload_track_interval_s",.1))*world.tick_hz/maxf(.25,director))),"solution":solution}
	else:
		solution=cached.solution
		if not solution.is_empty():
			var t: float=float(solution.time_s)
			var offset: Vector3=point+((contact.velocity_mps as Vector3)-unit.velocity_mps)*t-origin+Vector3.UP*ammo.gravity_mps2*.5*t*t
			solution={"direction":offset.normalized(),"time_s":t,"point_m":point+(contact.velocity_mps as Vector3)*t}
	if origin.distance_to(point) > float(envelope.range_m) or solution.is_empty():
		runtime.mount_status[mount.id] = "out_of_range"
		return 0
	var local: Vector3 = transform.basis.inverse() * (solution.direction as Vector3)
	var desired_train: float = wrapf(atan2(-local.x, -local.z) - mount.base_yaw_rad, -PI, PI)
	var desired_elevation: float = atan2(local.y, Vector2(local.x, local.z).length())
	var fixed: bool = mount.role == "aircraft_fixed"
	if not fixed:
		var elevation_limits: Vector2 = envelope.pitch_rad
		var train_limits: Vector2 = envelope.train_rad
		var site: Dictionary = unit.module_data.get("ground_initial", {})
		if not site.is_empty():
			train_limits = Vector2(maxf(train_limits.x,deg_to_rad(float(site.train_limits_deg[0]))),minf(train_limits.y,deg_to_rad(float(site.train_limits_deg[1]))))
			elevation_limits = Vector2(maxf(elevation_limits.x,deg_to_rad(float(site.elevation_limits_deg[0]))),minf(elevation_limits.y,deg_to_rad(float(site.elevation_limits_deg[1]))))
		if train_limits.x > train_limits.y or elevation_limits.x > elevation_limits.y:
			runtime.mount_status[mount.id] = "arc"
			return 0
		var train: float = clampf(desired_train, train_limits.x, train_limits.y)
		var elevation: float = clampf(desired_elevation, elevation_limits.x, elevation_limits.y)
		var rate: float = deg_to_rad(float(p.get("train_rate_degps", rad_to_deg(gun.train_rate_radps)))) * efficiency
		if train_limits.y - train_limits.x >= TAU - 0.001:
			state.train_rad = wrapf(state.train_rad + clampf(wrapf(train - state.train_rad, -PI, PI), -rate * delta_s, rate * delta_s), -PI, PI)
		else:
			state.train_rad = move_toward(state.train_rad, train, rate * delta_s)
		state.elevation_rad = move_toward(state.elevation_rad, elevation, deg_to_rad(float(p.get("elevation_rate_degps", rad_to_deg(gun.elevation_rate_radps)))) * delta_s * efficiency)
		if desired_train < train_limits.x - 0.0001 or desired_train > train_limits.y + 0.0001 or desired_elevation < elevation_limits.x or desired_elevation > elevation_limits.y:
			status = "arc"
	var muzzle: Transform3D = transform * mount.local_muzzle_transform(0, state.train_rad, state.elevation_rad)
	var direction: Vector3 = -muzzle.basis.z.normalized()
	var tolerance: float = float(p.get("aim_tolerance_rad", 0.003))
	if status == "ready" and direction.angle_to(solution.direction) > tolerance:
		status = "traversing"
	var intent: Dictionary = unit.module_data.get("combat_intent", {})
	var aa: bool = contact.domain == "aircraft" and not fixed
	# The air defense assignment itself is permission for this station. The
	# bomber's mission intent still owns all attack and flight behavior.
	if unit.cease_fire or (not self_defense and not bool(intent.get("allow_aa" if aa else "fire", false))):
		status = "hold_fire"
	if fixed and world.tick > int(intent.get("burst_until_tick", -1)):
		status = "burst_ended"
	if state.cycle_remaining_s > 0.00000001 and status == "ready":
		status = "reloading"
	var ready_barrels: Array[int] = []
	for index: int in range(state.remaining_rounds.size()):
		if state.remaining_rounds[index] > 0:
			ready_barrels.append(index)
	if ready_barrels.is_empty():
		status = "empty"
	if status != "ready":
		runtime.mount_status[mount.id] = status
		return 0
	if not projectiles.has_capacity(ready_barrels.size()):
		projectiles.capacity_rejections += 1
		runtime.mount_status[mount.id] = "capacity"
		return 0
	var count: int = 0
	for index: int in ready_barrels:
		muzzle = transform * mount.local_muzzle_transform(index, state.train_rad, state.elevation_rad)
		direction = -muzzle.basis.z.normalized()
		var local_muzzle: Vector3 = transform.affine_inverse() * muzzle.origin
		var pivot: Vector3 = mount.position_m + Basis(Vector3.UP, mount.base_yaw_rad + state.train_rad) * mount.elevation_pivot_m
		var exclusion: String = "weapon:" + mount.id
		# Both barrel path and forward path; no muzzle teleport through superstructure.
		if CombatGeometry.masked(pivot, local_muzzle, frame.proxies[unit.id], exclusion) or CombatGeometry.masked(local_muzzle, local_muzzle + transform.basis.inverse() * direction * 400.0, frame.proxies[unit.id], exclusion):
			runtime.mount_status[mount.id] = "masked"
			continue
		if world.shared_state.has("terrain") and not TerrainQueries.segment_hit(world,muzzle.origin,muzzle.origin+direction*400.0,false).is_empty():
			runtime.mount_status[mount.id] = "terrain_masked"
			continue
		# A fixed aircraft mount only launches down its posed barrel. The
		# intercept solution gates the shot; it must never steer the round.
		var launch_direction: Vector3 = direction
		if not fixed:
			var spread: float = float(p.dispersion_rad) * (1.0 + 4.0 * (1.0 - director))
			launch_direction = CombatFireControl.scatter(direction, spread, world.rng)
			if CombatGeometry.masked(local_muzzle, local_muzzle + transform.basis.inverse() * launch_direction * 400.0, frame.proxies[unit.id], exclusion):
				runtime.mount_status[mount.id] = "masked"
				continue
		var fuze: float = -1.0
		if aa and float(config.data.ammo_profiles[ammo.id].burst_radius_m) > 0:
			fuze = clampf(float(solution.time_s) + world.rng.randf_range(-float(p.get("fuze_error_s", 0.15)), float(p.get("fuze_error_s", 0.15))), 0.05, ammo.max_lifetime_s)
		if projectiles.launch(world, unit, state, ammo, muzzle.origin, launch_direction, fuze, index, float(solution.time_s)):
			state.remaining_rounds[index] -= 1
			count += 1
	if count > 0:
		state.cycle_remaining_s += float(p.get("cycle_s", gun.cycle_s))
		fired_per_weapon[state.id] = int(fired_per_weapon.get(state.id, 0)) + count
		runtime["shots_fired"] = int(runtime.get("shots_fired", 0)) + count
		runtime.mount_status[mount.id] = "fired"
	return count

func _mount_efficiency(unit: UnitState, mount_id: String) -> float:
	var health: float = clampf(float(unit.module_data.get("damage",{}).get("parts",{}).get("weapon:"+mount_id,1.0)),0.,1.)
	return 0.0 if health<=0.0 else .25+.75*health

func _director_quality(unit: UnitState) -> float:
	if (frame.definitions[unit.id] as UnitDefinition).domain != "ship": return 1.0
	return clampf(float(unit.module_data.get("damage",{}).get("fire_control_factor",1.0)),0.,1.)

func snapshot_state() -> Dictionary:
	return {"fired_per_weapon": fired_per_weapon.duplicate(true),"aim_cache":aim_cache.duplicate(true)}
