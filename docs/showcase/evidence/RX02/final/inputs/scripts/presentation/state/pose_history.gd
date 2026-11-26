extends SimulationModule

## Read-only final-tick samples. This module never writes units, RNG or commands.
var previous: Dictionary = {}
var current: Dictionary = {}
var previous_tick: int = 0
var current_tick: int = 0
var previous_bombs: Dictionary = {}
var current_bombs: Dictionary = {}
var _projectiles: CombatProjectiles

func _init() -> void:
	module_id = "presentation_pose_history"
	priority = 10000

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	current = _sample(world)
	previous = current
	current_tick = world.tick
	previous_tick = current_tick
	_projectiles = null
	for module: SimulationModule in world._modules:
		if module is CombatProjectiles: _projectiles = module as CombatProjectiles
	current_bombs = _sample_bombs(world)
	previous_bombs = current_bombs

func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	previous = current
	previous_tick = current_tick
	current = _sample(world)
	current_tick = world.tick
	previous_bombs = current_bombs
	current_bombs = _sample_bombs(world)

func interpolate(units: Dictionary, alpha: float) -> Dictionary:
	var result: Dictionary = {}
	for id: String in units:
		var view: Dictionary = units[id].duplicate()
		result[id] = view
		if not previous.has(id) or not current.has(id): continue
		var a: Dictionary = previous[id]
		var b: Dictionary = current[id]
		if a.definition_id != b.definition_id: continue
		view.position_m = (a.position_m as Vector3).lerp(b.position_m,alpha)
		view.rotation_rad = _rotation(a.rotation_rad,b.rotation_rad,alpha)
		view.velocity_mps = (a.velocity_mps as Vector3).lerp(b.velocity_mps,alpha)
		var weapons: Dictionary = view.weapons.duplicate()
		view.weapons = weapons
		for station: String in weapons:
			if not a.weapons.has(station) or not b.weapons.has(station): continue
			var weapon: Dictionary = weapons[station].duplicate()
			weapons[station] = weapon
			weapon.train_rad = lerp_angle(a.weapons[station].x,b.weapons[station].x,alpha)
			weapon.elevation_rad = lerpf(a.weapons[station].y,b.weapons[station].y,alpha)
		var data: Dictionary = view.module_data.duplicate()
		view.module_data = data
		if not b.flight.is_empty():
			var flight: Dictionary = data.aircraft_motion.duplicate()
			data.aircraft_motion = flight
			for field: String in b.flight:
				flight[field] = lerp_angle(float(a.flight.get(field,b.flight[field])),b.flight[field],alpha)
		if data.has("carrier_ops"):
			var ops: Dictionary = data.carrier_ops.duplicate()
			data.carrier_ops = ops
			ops.hook_deflection_rad = lerpf(a.hook_deflection_rad,b.hook_deflection_rad,alpha)
		if data.has("bomb_rack") and not b.rack.is_empty():
			var rack: Dictionary = data.bomb_rack.duplicate()
			data.bomb_rack = rack
			for field: String in ["bay","crutch","brake"]:
				rack[field] = lerpf(float(a.rack.get(field,b.rack[field])),float(b.rack[field]),alpha)
			# Births are at the END of their actual tick. Keep the attached visual
			# until that same presentation time; do not show an early detached bomb.
			if alpha<1.0 and not a.rack.is_empty():
				rack.slots = a.rack.slots.duplicate(true)
				rack.remaining = a.rack.remaining
				rack.released = a.rack.released
		var damage: Dictionary = data.get("damage",{})
		if not damage.is_empty():
			damage = damage.duplicate();data.damage = damage
			damage.list_rad = lerpf(a.list_rad,b.list_rad,alpha)
			if alpha<1.0:
				view.active = a.active
				damage.phase = a.damage_phase
				damage.disabled_mounts = a.disabled_mounts.duplicate()
				if a.has_emitters: damage.effect_emitters = a.effect_emitters.duplicate(true)
				elif damage.has("effect_emitters"): damage.erase("effect_emitters")
		if damage.has("aircraft"):
			var aircraft: Dictionary = damage.aircraft.duplicate()
			damage.aircraft = aircraft
			if alpha<1.0:
				aircraft.detached_parts = a.detached_parts.duplicate()
				aircraft.breakup = a.breakup
			var fragments: Array = []
			var visible_pieces: Array = a.fragment_rows if alpha<1.0 else aircraft.get("fragments",[])
			for piece: Dictionary in visible_pieces:
				var part: Dictionary = piece.duplicate()
				fragments.append(part)
				var key: String = str(piece.part_id)
				if not a.fragments.has(key) or not b.fragments.has(key): continue
				part.position_m = (a.fragments[key].position_m as Vector3).lerp(b.fragments[key].position_m,alpha)
				part.rotation_rad = _rotation(a.fragments[key].rotation_rad,b.fragments[key].rotation_rad,alpha)
			aircraft.fragments = fragments
	return result

func interpolate_bombs(alpha: float) -> Dictionary:
	var result: Dictionary = {}
	var tick_time: float = lerpf(float(previous_tick),float(current_tick),alpha)
	for id: String in current_bombs:
		var b: Dictionary = current_bombs[id]
		if tick_time+0.0000001<float(b.born_tick): continue
		if int(b.terminated_tick)>=0 and tick_time>=float(b.terminated_tick): continue
		var pose: Dictionary = b.duplicate()
		if previous_bombs.has(id):
			var a: Dictionary = previous_bombs[id]
			pose.position_m = (a.position_m as Vector3).lerp(b.position_m,alpha)
			pose.rotation_rad = _rotation(a.rotation_rad,b.rotation_rad,alpha)
			pose.velocity_mps = (a.velocity_mps as Vector3).lerp(b.velocity_mps,alpha)
		result[id] = pose
	return result

func _sample_bombs(world: SimulationWorld) -> Dictionary:
	var result: Dictionary = {}
	if _projectiles == null: return result
	for id: String in _projectiles.rounds:
		var p: CombatProjectiles.Round = _projectiles.rounds[id]
		if p.release_mode!="gravity_release": continue
		result[id] = {"id":id,"entity_id":p.entity_id,"slot":p.slot,"position_m":p.position_m,"velocity_mps":p.velocity_mps,"rotation_rad":AircraftFlightMath.frame(p.forward_m,p.up_m).get_euler(),"born_tick":p.born_tick,"terminated_tick":-1}
	var missing: Array[String] = []
	for id: String in previous_bombs:
		if not result.has(id) and int(previous_bombs[id].terminated_tick)<0: missing.append(id)
	if not missing.is_empty():
		for event: BattleEvent in world.events_for_tick(world.tick):
			var id: String = str(event.data.get("projectile_id",""))
			if not missing.has(id): continue
			var endpoint: Dictionary = previous_bombs[id].duplicate()
			endpoint.position_m = event.position_m
			endpoint.terminated_tick = world.tick
			result[id] = endpoint
	return result

static func _rotation(a: Vector3, b: Vector3, alpha: float) -> Vector3:
	var start: Quaternion = Basis.from_euler(a).get_rotation_quaternion()
	var end: Quaternion = Basis.from_euler(b).get_rotation_quaternion()
	return Basis(start.slerp(end,alpha).normalized()).get_euler()

static func _sample(world: SimulationWorld) -> Dictionary:
	var result: Dictionary = {}
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		var weapons: Dictionary = {}
		for station: String in unit.weapons:
			var weapon: WeaponState = unit.weapons[station]
			weapons[station] = Vector2(weapon.train_rad,weapon.elevation_rad)
		var flight: Dictionary = {}
		var motion: Dictionary = unit.module_data.get("aircraft_motion",{})
		for field: String in ["propeller_phase_rad","aileron_rad","elevator_rad"]:
			if motion.has(field): flight[field] = float(motion[field])
		var fragments: Dictionary = {}
		var damage: Dictionary = unit.module_data.get("damage",{})
		var aircraft: Dictionary = damage.get("aircraft",{})
		for part: Dictionary in aircraft.get("fragments",[]):
			fragments[str(part.part_id)] = {"position_m":part.position_m,"rotation_rad":part.rotation_rad}
		result[id] = {"definition_id":unit.definition_id,"position_m":unit.position_m,"rotation_rad":unit.rotation_rad,"velocity_mps":unit.velocity_mps,"weapons":weapons,"flight":flight,"fragments":fragments,"fragment_rows":aircraft.get("fragments",[]).duplicate(true),"detached_parts":aircraft.get("detached_parts",[]).duplicate(),"breakup":bool(aircraft.get("breakup",false)),"active":unit.active,"damage_phase":damage.get("phase","operational"),"list_rad":float(damage.get("list_rad",0)),"has_emitters":damage.has("effect_emitters"),"effect_emitters":damage.get("effect_emitters",[]).duplicate(true),"disabled_mounts":damage.get("disabled_mounts",[]).duplicate(),"rack":unit.module_data.get("bomb_rack",{}).duplicate(true),"hook_deflection_rad":float(unit.module_data.get("carrier_ops",{}).get("hook_deflection_rad",0))}
	return result
