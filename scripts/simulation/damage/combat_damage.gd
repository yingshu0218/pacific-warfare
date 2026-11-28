class_name CombatDamage
extends SimulationModule

var config: CombatConfig
var frame: CombatFrame

func _init(parameters: CombatConfig, geometry: CombatFrame) -> void:
	module_id = "combat_damage"
	priority = 650
	config = parameters
	frame = geometry

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		var p: Dictionary = config.unit_profile(unit.definition_id)
		var parts: Dictionary = {"engine": 1.0, "steering": 1.0, "control": 1.0}
		for mount_id: String in unit.weapons:
			parts["weapon:" + mount_id] = 1.0
		unit.module_data["damage"] = {"structure": float(p.structure), "structure_max": float(p.structure),
			"parts": parts, "propulsion_factor": 1.0, "control_factor": 1.0, "disabled_mounts": [],
			"fire": 0.0, "flooding": 0.0, "phase": "operational", "phase_time_s": 0.0, "list_rad": 0.0}
		if (frame.definitions[id] as UnitDefinition).domain == "ship":
			# Combat capability and watertight reserve are separate coarse quantities.
			# Topsides may be destroyed without inventing an underwater breach.
			unit.module_data.damage["ship"] = {"flotation":float(p.structure), "flotation_max":float(p.structure),
				"breach_hits":0, "last_hit_region":"", "last_hit_local_m":Vector3.ZERO,
				"submerge_depth_m":_submerge_depth(frame.definitions[id],frame.proxies[id])}
			unit.module_data.damage["fire_control_factor"] = 1.0
		if p.has("aircraft_damage"):
			AircraftDamageMotion.initialize(unit)
			for box: Dictionary in p.boxes:
				if box.part in ["cockpit", "engine_left", "engine_right"]:
					parts[box.part] = 1.0
		elif (frame.definitions[id] as UnitDefinition).domain == "aircraft":
			# Whole-airframe terminal state for admitted models without detachable groups.
			# Do not invent wing cuts or run healthy flight after an actual loss.
			unit.module_data.damage["coarse_airframe"] = {"detached_parts":[],"angular_velocity_body_radps":Vector3.ZERO,"terminal_started":false,"terminal_born_tick":-1,"contact_surface":""}

func fixed_update(world_ref: RefCounted, delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for event: BattleEvent in world.events_for_tick(world.tick):
		if event.kind == "hit" and event.data.get("release_mode", "gun") != "gravity_release" and bool(event.data.damage_allowed):
			_apply(world, event.target_id, str(event.data.part_id), float(event.data.armor_mm), event, 1.0)
		elif event.kind == "bomb_explosion":
			_bomb_blast(world,event)
		elif event.kind == "airburst":
			_blast(world, event)
		elif event.kind == "unit_surface_contact":
			_surface_contact(world, event)
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not CombatPresence.is_present(unit.module_data):
			continue
		var damage: Dictionary = unit.module_data.damage
		var profile: Dictionary = config.data.unit_profiles[unit.definition_id]
		if damage.has("aircraft"):
			AircraftDamageMotion.advance_fragments(world, unit, delta_s, config.data.environment)
			AircraftDamageMotion.update_emitters(unit, profile)
		if damage.phase in ["operational", "disabled"]:
			# Ongoing losses can only start from previous physical hits.
			var ongoing: float = (float(damage.fire) * float(profile.get("fire_loss_per_s", 0.2)) + float(damage.flooding) * float(profile.get("flood_loss_per_s", 1.0))) * delta_s
			damage.structure = maxf(0, float(damage.structure) - ongoing)
			damage.fire = maxf(0, float(damage.fire) - delta_s * float(profile.get("fire_decay_per_s", 0.002)))
			if float(damage.flooding) > 0:
				damage.flooding = minf(1, float(damage.flooding) + delta_s * float(profile.get("flood_growth_per_s", 0.0005)))
			damage.list_rad = float(damage.flooding) * 0.15
			if damage.has("ship"):
				var flood_loss: float = float(damage.flooding) * float(profile.get("flood_loss_per_s", 1.0)) * delta_s
				damage.ship.flotation = maxf(0, float(damage.ship.flotation) - flood_loss)
				if float(damage.ship.flotation) <= 0 or float(damage.flooding) >= 1.0:
					_disable(world, unit, "flooding" if float(damage.flooding) >= 1.0 else "hull_breach")
				elif float(damage.structure) <= 0:
					_disable(world, unit, "structure")
			elif float(damage.structure) <= 0 or float(damage.flooding) >= 1.0:
				_disable(world, unit, "structure" if float(damage.structure) <= 0 else "flooding")
			elif float(damage.parts.control) <= 0 and damage.phase == "operational":
				_disable(world, unit, "control")
			elif (frame.definitions[id] as UnitDefinition).domain == "ground" and damage.phase == "operational" and unit.weapons.values().all(func(w: WeaponState) -> bool:return not w.enabled):
				_disable(world, unit, "weapons")
			if damage.phase == "disabled":
				damage.phase_time_s += delta_s
		else:
			damage.phase_time_s += delta_s
			var domain: String = (frame.definitions[id] as UnitDefinition).domain
			if damage.phase in ["sinking", "crashing"]:
				if domain == "ship":
					unit.position_m.y -= float(profile.get("sink_mps", 0.4)) * delta_s
					damage.list_rad = minf(1.1, float(damage.list_rad) + delta_s * 0.015)
				else:
					# Failure follows this tick's healthy movement; do not integrate twice.
					if int(damage.get("aircraft",damage.get("coarse_airframe",{})).get("terminal_born_tick",-1)) == world.tick: continue
					var previous: Vector3 = unit.position_m
					var incoming_velocity: Vector3 = unit.velocity_mps
					var contact: Dictionary = AircraftDamageMotion.advance_terminal(world, unit, delta_s)
					if contact.is_empty(): contact = _crash_surface(world, previous, unit.position_m)
					if not contact.is_empty():
						var fraction: float = clampf(previous.distance_to(contact.position_m) / maxf(0.000001, previous.distance_to(unit.position_m)), 0.0, 1.0)
						var impact_velocity: Vector3 = incoming_velocity.lerp(unit.velocity_mps, fraction)
						var event: BattleEvent = world.emit_event("unit_surface_contact",unit.id,"",contact.position_m,{"surface":contact.surface,"velocity_mps":impact_velocity,"reason":"crash","normal":contact.get("normal",Vector3.UP)})
						_surface_contact(world,event)

				# A fixed timer alone left tall superstructures visibly above water
				# when wrecks stopped sinking and were subsequently removed.
				if domain == "ship" and float(damage.phase_time_s) >= float(profile.get("loss_duration_s", 40.0)) and unit.position_m.y+float(damage.ship.submerge_depth_m)<=float(config.data.environment.sea_level_m)-2.0:
					_phase(world, unit, "wreck")
			elif damage.phase == "wreck":
				var lifetime_s: float = float(config.data.limits.get("wreck_lifetime_s", 30.0))
				if damage.has("aircraft"):
					lifetime_s = float(profile.aircraft_damage.wreck_lifetime_s)
					if damage.aircraft.contact_surface == "sea": unit.position_m.y -= 0.9 * delta_s
					AircraftDamageMotion._coast_propeller(unit.module_data.get("aircraft_motion",{}), 0, delta_s)
				if float(damage.phase_time_s) >= lifetime_s: _phase(world, unit, "removed")

## Conservative extent around the ship's visual list axis. Catalog dimensions
## include mast height; actual proxies cover any larger collision installation.
## No model nodes are loaded by the simulation, and no visible wreck is removed.
func _submerge_depth(definition: UnitDefinition, boxes: Array) -> float:
	var top: float = definition.dimensions_m.y
	var half_beam: float = definition.dimensions_m.x*.5
	for box: Dictionary in boxes:
		var center: Vector3 = SimData.vec3(box.center_m)
		var half: Vector3 = SimData.vec3(box.half_extents_m)
		top = maxf(top,center.y+half.y)
		half_beam = maxf(half_beam,absf(center.x)+half.x)
	return Vector2(top,half_beam).length()

func _crash_surface(world: SimulationWorld, a: Vector3, b: Vector3) -> Dictionary:
	if world.shared_state.has("terrain"): return TerrainQueries.segment_hit(world,a,b)
	var fraction: float = INF
	var surface: String = ""
	for solid: Dictionary in config.data.environment.get("solids",[]):
		var t: float = CombatGeometry.segment_box(a,b,SimData.vec3(solid.center_m),SimData.vec3(solid.half_extents_m))
		if t<fraction:
			fraction=t
			surface=solid.surface
	var sea_y: float = float(config.data.environment.sea_level_m)
	if a.y>=sea_y and b.y<=sea_y and b.y<a.y:
		var t: float = (a.y-sea_y)/(a.y-b.y)
		if t<fraction:
			fraction=t
			surface="sea"
	if not is_finite(fraction):return {}
	return {"position_m":a.lerp(b,fraction),"surface":surface}

func _surface_contact(world: SimulationWorld, event: BattleEvent) -> void:
	var unit: UnitState = world.get_unit(event.entity_id)
	if unit==null or (frame.definitions[unit.id] as UnitDefinition).domain!="aircraft":return
	if not CombatPresence.is_present(unit.module_data):return
	var damage: Dictionary = unit.module_data.damage
	if damage.phase in ["wreck","removed"] or event.data.get("surface","") not in ["sea","ground","building"]:return
	if not event.data.get("velocity_mps") is Vector3:return
	var velocity: Vector3 = event.data.velocity_mps
	if not velocity.is_finite():return
	var was_active: bool = unit.active
	var destroyed: bool = float(damage.structure)<=0.0 or velocity.length()>=35.0 or velocity.y < -6.0
	unit.active=false
	unit.position_m=event.position_m
	if damage.has("coarse_airframe"): damage.coarse_airframe.contact_surface = str(event.data.surface)
	if damage.has("aircraft"):
		damage.aircraft.contact_surface = str(event.data.surface)
		damage.effect_emitters = []
		damage.fire = 0.0
		if destroyed:
			unit.velocity_mps = velocity
			AircraftDamageMotion.breakup(world, unit, config.unit_profile(unit.definition_id), frame, "surface_impact")
	unit.velocity_mps=Vector3.ZERO
	damage.propulsion_factor=0.0
	damage.control_factor=0.0
	damage.parts.control=0.0
	if destroyed:damage.structure=0.0
	for mount_id: String in unit.weapons:(unit.weapons[mount_id] as WeaponState).enabled=false
	_phase(world,unit,"wreck")
	var data: Dictionary = {"surface":event.data.surface,"velocity_mps":velocity,"reason":event.data.get("reason","surface_contact"),"destroyed":destroyed,"size_m":(frame.definitions[unit.id] as UnitDefinition).dimensions_m.x}
	world.emit_event("unit_impact",unit.id,"",event.position_m,data)
	if was_active:world.emit_event("disabled",unit.id,"",event.position_m,{"phase":"wreck","reason":data.reason,"destroyed":destroyed})

func _apply(world: SimulationWorld, id: String, part: String, armor_mm: float, event: BattleEvent, falloff: float) -> void:
	var unit: UnitState = world.get_unit(id)
	if unit == null or not CombatPresence.is_present(unit.module_data):
		return
	var damage: Dictionary = unit.module_data.damage
	if damage.phase not in ["operational", "disabled"] and not (damage.has("aircraft") and damage.phase == "crashing"): return
	var ammo: Dictionary = config.data.ammo_profiles[event.data.ammo_id]
	var caliber_mm: float = float(event.data.caliber_m) * 1000.0
	# Explicit coarse resistance proxy, NOT a historical penetration formula.
	var resistance: float = armor_mm / maxf(1, caliber_mm * (3.0 if ammo.kind == "ap" else 0.7))
	var penetration: float = clampf(1.0 - resistance, 0.0, 1.0)
	var kinetic: float = sqrt(maxf(0, float(event.data.energy_j))) * float(ammo.damage_scale) * penetration
	var amount: float = kinetic * falloff
	if amount <= 0.0:
		return
	var profile: Dictionary = config.data.unit_profiles[unit.definition_id]
	var proxy_part: String = part
	var ship_hit: Dictionary = {}
	var hull_transfer: float = 0.25 if part.begins_with("weapon:") else 1.0
	if damage.has("ship"):
		ship_hit = _ship_hit(unit, part, event, profile)
		part = str(ship_hit.part_id)
		hull_transfer = float(ship_hit.structure_transfer)
		damage.ship.last_hit_region = ship_hit.region
		damage.ship.last_hit_local_m = ship_hit.local_position_m
		if bool(ship_hit.wet_hull):
			damage.ship.flotation = maxf(0, float(damage.ship.flotation) - amount)
			if amount > 10.0:
				damage.ship.breach_hits += 1
				damage.flooding = minf(1, float(damage.flooding) + amount / float(profile.structure) * 0.5)
	elif damage.has("aircraft"):
		if part in ["engine", "engine_left", "engine_right"]: hull_transfer = float(profile.aircraft_damage.engine_structure_transfer)
		elif part == "cockpit": hull_transfer = float(profile.aircraft_damage.get("cockpit_structure_transfer", 0.2))
		elif part in ["wing_left", "wing_right"]: hull_transfer = float(profile.aircraft_damage.wing_structure_transfer)
		elif part == "tail": hull_transfer = float(profile.aircraft_damage.tail_structure_transfer)
	damage.structure = maxf(0, float(damage.structure) - amount * hull_transfer)
	if damage.parts.has(part):
		var durability: float = float(profile.get("part_durability", 100.0))
		if damage.has("aircraft"):
			if part in ["wing_left", "wing_right"]: durability = float(profile.aircraft_damage.wing_durability)
			elif part == "tail": durability = float(profile.aircraft_damage.tail_durability)
			elif part == "cockpit": durability = float(profile.aircraft_damage.get("cockpit_durability", 30.0))
		if part.begins_with("weapon:"):
			durability = float(profile.get("weapon_durability", 25.0))
			var mount_id: String = part.trim_prefix("weapon:")
			var mounted_gun: WeaponState = unit.weapons[mount_id]
			var target_gun: WeaponDefinition = frame.guns[mounted_gun.definition_id]
			if (frame.ammunition[target_gun.ammo_id] as AmmoDefinition).caliber_m > 0.3:
				durability = float(profile.get("main_weapon_durability",durability*8.0))
		var old_value: float = float(damage.parts[part])
		damage.parts[part] = maxf(0, old_value - amount / durability)
		if part.begins_with("weapon:") and old_value > 0 and float(damage.parts[part]) <= 0:
			var mount_id: String = part.trim_prefix("weapon:")
			(unit.weapons[mount_id] as WeaponState).enabled = false
			damage.disabled_mounts.append(mount_id)
	if ammo.kind == "he" and amount > 1.0:
		damage.fire = minf(1, float(damage.fire) + amount * (hull_transfer if damage.has("aircraft") else 1.0) / float(profile.structure))
	if damage.parts.has("engine_left") and damage.parts.has("engine_right"):
		damage.parts.engine = 0.5 * (float(damage.parts.engine_left) + float(damage.parts.engine_right))
	damage.propulsion_factor = maxf(0.0, float(damage.parts.engine))
	if damage.has("ship"):
		# Ship control proxies describe directors/bridge; steering has its own part.
		# A dead director degrades gunnery, not every mount and the propulsion plant.
		damage.fire_control_factor = float(damage.parts.control)
		damage.control_factor = float(damage.parts.steering)
	else:
		damage.control_factor = minf(float(damage.parts.steering), float(damage.parts.control))
	if damage.has("aircraft"):
		damage.control_factor = minf(float(damage.control_factor), minf(float(damage.parts.tail), float(damage.parts.get("cockpit", 1.0))))
		if damage.phase == "crashing":
			damage.control_factor = 0.0
			damage.propulsion_factor = 0.0
	var result: Dictionary = {"projectile_id": event.data.projectile_id, "ammo_id": event.data.ammo_id,
		"part_id":part, "proxy_part_id":proxy_part, "amount":amount, "structure_amount":amount*hull_transfer,
		"structure_transfer":hull_transfer, "structure":damage.structure,
		"propulsion_factor":damage.propulsion_factor, "control_factor":damage.control_factor}
	if not ship_hit.is_empty():
		result.merge({"hit_region":ship_hit.region, "local_position_m":ship_hit.local_position_m,
			"wet_hull":ship_hit.wet_hull, "flotation":damage.ship.flotation,
			"fire_control_factor":damage.fire_control_factor, "fire":damage.fire, "flooding":damage.flooding})
	world.emit_event("damaged", event.entity_id, event.weapon_id, event.position_m, result, id)
	if damage.has("aircraft"):
		if float(damage.structure) <= 0:
			# Accumulated functional loss need not take the airframe apart in midair.
			if amount * hull_transfer >= float(profile.structure) * 0.8:
				AircraftDamageMotion.breakup(world, unit, profile, frame, "catastrophic_structure", str(event.data.projectile_id))
			_disable(world, unit, "structure")
		elif part in ["wing_left", "wing_right"] and float(damage.parts.get(part,1)) <= 0:
			AircraftDamageMotion.detach(world, unit, part, profile, frame, "part_failure", str(event.data.projectile_id))
			_disable(world, unit, part)
		elif part in ["cockpit", "control", "tail"] and float(damage.parts[part]) <= 0:
			_disable(world, unit, part)
		AircraftDamageMotion.update_emitters(unit, profile)

## Existing hull proxies also label above-water side plating as "engine"/"steering".
## Restrict those functional hits to the configured submerged vital-space envelope.
## Transfers are explicit game approximations; no AP overpenetration/fuze solver is claimed.
func _ship_hit(unit: UnitState, part: String, event: BattleEvent, profile: Dictionary) -> Dictionary:
	var settings: Dictionary = profile.get("ship_damage", {})
	var local: Vector3 = unit.world_transform().affine_inverse() * event.position_m
	if event.data.get("local_position_m") is Vector3: local = event.data.local_position_m
	var sea_y: float = float(config.data.environment.sea_level_m)
	var wet: bool = event.position_m.y <= sea_y + float(event.data.caliber_m)*0.5
	var hull_part: bool = part in ["structure", "engine", "steering"]
	var resolved: String = part
	if part in ["engine", "steering"] and local.y > float(settings.get("vital_space_top_m", 0.0)):
		resolved = "structure"
	var region: String = "mount" if part.begins_with("weapon:") else "superstructure"
	var transfer: float = 0.25 if region == "mount" else float(settings.get("superstructure_transfer", 0.35))
	if hull_part and wet:
		region = "waterline_hull"
		transfer = 1.0
	elif hull_part and local.y <= float(settings.get("weather_deck_m", 4.0)):
		region = "above_water_hull"
		transfer = float(settings.get("above_water_hull_transfer", 1.0))
	return {"part_id":resolved, "region":region, "local_position_m":local,
		"wet_hull":hull_part and wet, "structure_transfer":clampf(transfer, 0.0, 1.0)}


func _blast(world: SimulationWorld, event: BattleEvent) -> void:
	var radius: float = float(event.data.radius_m)
	if radius <= 0:
		return
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not unit.active or not CombatPresence.is_present(unit.module_data) or (frame.definitions[id] as UnitDefinition).domain != "aircraft":
			continue
		if unit.faction_id == event.data.source_faction_id and not bool(config.data.environment.friendly_fire):
			continue
		var distance: float = unit.position_m.distance_to(event.position_m)
		if distance >= radius:
			continue
		if world.shared_state.has("terrain") and not TerrainQueries.segment_hit(world,event.position_m,unit.position_m,false).is_empty(): continue
		if CombatGeometry.masked(event.position_m, unit.position_m, config.data.environment.get("solids", [])):
			continue
		var blocked: bool = false
		for blocker_id: String in frame.proxies:
			if blocker_id == id:
				continue
			if not CombatPresence.is_present(world.get_unit(blocker_id).module_data):continue
			var inverse: Transform3D = world.get_unit(blocker_id).world_transform().affine_inverse()
			if CombatGeometry.masked(inverse * event.position_m, inverse * unit.position_m, frame.proxies[blocker_id]):
				blocked = true
				break
		if not blocked:
			_apply(world, id, "control", 0.0, event, pow(1.0 - distance / radius, 2) * 0.03)

## One exposure per entity, nearest real proxy; every domain uses the same _apply.
## A decorative MAP02 solid can block a blast but has no invented health/statistic.
func _bomb_blast(world: SimulationWorld, event: BattleEvent) -> void:
	var profile: Dictionary = config.data.ammo_profiles[event.data.ammo_id]
	var radius: float = float(profile.blast_radius_m)
	var origin: Vector3 = event.position_m + (event.data.get("normal",Vector3.UP) as Vector3)*0.25
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if not CombatPresence.is_present(unit.module_data): continue
		if unit.faction_id == event.data.source_faction_id and not bool(config.data.environment.friendly_fire): continue
		var transform: Transform3D = unit.world_transform()
		var local: Vector3 = transform.affine_inverse()*event.position_m
		var distance: float = INF
		var selected: Dictionary = {}
		var point: Vector3 = unit.position_m
		for box: Dictionary in frame.proxies[id]:
			var center: Vector3 = SimData.vec3(box.center_m)
			var half: Vector3 = SimData.vec3(box.half_extents_m)
			var candidate: Vector3 = transform*local.clamp(center-half,center+half)
			var d: float = candidate.distance_to(event.position_m)
			if d < distance:
				distance = d
				selected = box
				point = candidate
		if distance >= radius or selected.is_empty(): continue
		if id != event.target_id:
			var end: Vector3 = point+(origin-point).normalized()*0.05
			if world.shared_state.has("terrain") and not TerrainQueries.segment_hit(world,origin,end,false).is_empty(): continue
			if CombatGeometry.masked(origin,end,config.data.environment.get("solids",[])): continue
			var blocked: bool = false
			for blocker_id: String in frame.proxies:
				if blocker_id == id or not CombatPresence.is_present(world.get_unit(blocker_id).module_data): continue
				var inverse: Transform3D = world.get_unit(blocker_id).world_transform().affine_inverse()
				if CombatGeometry.masked(inverse*origin,inverse*end,frame.proxies[blocker_id]):
					blocked = true
					break
			if blocked: continue
		var blast: BattleEvent = event.copy()
		blast.data["energy_j"] = float(profile.explosive_kg)*4184000.0
		blast.position_m = point
		blast.data["local_position_m"] = transform.affine_inverse()*point
		_apply(world,id,str(selected.part),float(selected.get("armor_mm",0)),blast,pow(1.0-distance/radius,2))

func _disable(world: SimulationWorld, unit: UnitState, reason: String) -> void:
	# Rechecking exhausted structure on an afloat disabled ship must not restart
	# its phase or emit "disabled" every tick. New flooding may still sink it.
	if unit.module_data.damage.has("ship"):
		var sinking: bool = float(unit.module_data.damage.ship.flotation) <= 0 or float(unit.module_data.damage.flooding) >= 1.0
		var next_phase: String = "sinking" if sinking else "disabled"
		if unit.module_data.damage.phase == next_phase: return
	if unit.module_data.damage.has("coarse_airframe"):
		AircraftDamageMotion.begin_terminal(unit)
		unit.module_data.damage.coarse_airframe.terminal_born_tick = world.tick
	if unit.module_data.damage.has("aircraft"):
		AircraftDamageMotion.begin_terminal(unit)
		if unit.module_data.damage.phase == "crashing": return
		unit.module_data.damage.aircraft["terminal_born_tick"] = world.tick
	unit.active = false
	unit.module_data.damage.control_factor = 0.0
	for mount_id: String in unit.weapons:
		(unit.weapons[mount_id] as WeaponState).enabled = false
	var domain: String = (frame.definitions[unit.id] as UnitDefinition).domain
	var is_ship: bool = domain == "ship"
	var phase: String = "crashing"
	if is_ship:
		phase = "sinking" if float(unit.module_data.damage.ship.flotation) <= 0 or float(unit.module_data.damage.flooding) >= 1.0 else "disabled"
	if domain == "ground":
		phase = "wreck" if reason == "structure" else "disabled"
		unit.velocity_mps = Vector3.ZERO
	if phase != "disabled":
		unit.module_data.damage.propulsion_factor = 0.0
	unit.module_data.damage["disabled_reason"] = reason
	_phase(world, unit, phase)
	world.emit_event("disabled", unit.id, "", unit.position_m, {"reason": reason, "phase": phase})

func _phase(world: SimulationWorld, unit: UnitState, phase: String) -> void:
	unit.module_data.damage.phase = phase
	unit.module_data.damage.phase_time_s = 0.0
	if phase == "removed" and unit.module_data.damage.has("aircraft"):
		unit.module_data.damage.aircraft.fragments.clear()
		unit.module_data.damage.effect_emitters = []
	world.emit_event("damage_phase", unit.id, "", unit.position_m, {"phase": phase,"domain":(frame.definitions[unit.id] as UnitDefinition).domain})
