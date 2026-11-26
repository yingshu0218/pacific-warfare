class_name CombatProjectiles
extends SimulationModule

class Round extends RefCounted:
	var id: String
	var entity_id: String
	var weapon_id: String
	var target_id: String
	var faction_id: String
	var ammo_id: String
	var position_m: Vector3
	var velocity_mps: Vector3
	var age_s: float = 0.0
	var fuze_s: float
	var self_destruct: bool = false
	var gravity: float
	var lifetime_s: float
	var mass_kg: float
	var caliber_m: float
	var born_tick: int
	var cleared_self: bool
	var release_mode: String = "gun"
	var drag_per_m: float = 0.0
	var arming_s: float = 0.0
	var arming_distance_m: float = 0.0
	var impact_delay_s: float = 0.0
	var travelled_m: float = 0.0
	var contact: Dictionary = {}
	var delay_remaining_s: float = 0.0
	var release_order_id: String = ""
	var slot: int = -1
	var forward_m: Vector3 = Vector3.FORWARD
	var up_m: Vector3 = Vector3.UP
	var collision_length_m: float = 0.0
	var collision_span_m: float = 0.0
	func snapshot() -> Dictionary:
		return {"id":id,"entity_id":entity_id,"weapon_id":weapon_id,"target_id":target_id,"faction_id":faction_id,
			"ammo_id":ammo_id,"position_m":position_m,"velocity_mps":velocity_mps,"age_s":age_s,"fuze_s":fuze_s,
			"gravity":gravity,"lifetime_s":lifetime_s,"mass_kg":mass_kg,"caliber_m":caliber_m,"born_tick":born_tick,"cleared_self":cleared_self,"self_destruct":self_destruct,"release_mode":release_mode,"travelled_m":travelled_m,"contact":contact.duplicate(true),"delay_remaining_s":delay_remaining_s,"release_order_id":release_order_id,"slot":slot,"forward_m":forward_m,"up_m":up_m,"collision_length_m":collision_length_m,"collision_span_m":collision_span_m}

var config: CombatConfig
var frame: CombatFrame
var rounds: Dictionary = {}
var next_id: int = 0
var capacity_rejections: int = 0
var terminated: int = 0
var peak_active: int = 0
var collision_units: Array[Dictionary] = []
var collision_grid: Dictionary = {}
const CELL_M: float = 512.0
const NO_HIT: Dictionary = {"fraction":INF}
const EMPTY_INDICES: Array[int] = []

func _init(parameters: CombatConfig, geometry: CombatFrame) -> void:
	module_id = "combat_projectiles"
	priority = 600
	config = parameters
	frame = geometry

func reset(_world: RefCounted) -> void:
	rounds.clear()
	next_id = 0
	capacity_rejections = 0
	terminated = 0
	peak_active = 0
	collision_units.clear()
	collision_grid.clear()

func has_capacity(count: int = 1) -> bool:
	return rounds.size() + count <= int(config.data.limits.projectiles)

## Weapons alone calls this in production; harnesses can launch controlled probes.
func launch(world: SimulationWorld, shooter: UnitState, weapon: WeaponState, ammo: AmmoDefinition, position: Vector3, direction: Vector3, fuze_s: float = -1.0, barrel: int = 0, flight_s: float = 0.0) -> bool:
	if ammo.release_mode != "gun": return false
	if not CombatPresence.is_present(shooter.module_data):
		return false
	if not has_capacity():
		capacity_rejections += 1
		return false
	next_id += 1
	var id: String = "projectile_%08d" % next_id
	var velocity: Vector3 = direction.normalized() * ammo.muzzle_speed_mps + shooter.velocity_mps
	var tracer: bool = next_id % int(config.data.limits.get("tracer_every", 3)) == 0 or ammo.caliber_m > 0.1
	var cleared_self: bool = not CombatGeometry.contains(shooter.world_transform().affine_inverse() * position, frame.proxies[shooter.id])
	var p: Round = Round.new()
	p.id=id
	p.entity_id=shooter.id
	p.weapon_id=weapon.id
	p.target_id=shooter.module_data.get("combat_runtime",{}).get("mount_targets",{}).get(weapon.mount_id,"")
	p.faction_id=shooter.faction_id
	p.ammo_id=ammo.id
	p.position_m=position
	p.velocity_mps=velocity
	p.fuze_s=fuze_s
	var sd: float = float(config.data.ammo_profiles[ammo.id].get("self_destruct_s", -1.0))
	if sd > 0.0:
		p.fuze_s=sd
		p.self_destruct=true
	p.gravity=ammo.gravity_mps2
	p.lifetime_s=ammo.max_lifetime_s
	p.mass_kg=ammo.projectile_mass_kg
	p.caliber_m=ammo.caliber_m
	p.born_tick=world.tick
	p.cleared_self=cleared_self
	rounds[id]=p
	peak_active=maxi(peak_active,rounds.size())
	var source: UnitDefinition = frame.definitions[shooter.id]
	var role: String = ""
	for mount: MountSocket in source.mounts:
		if mount.id == weapon.mount_id:
			role = mount.role
			break
	world.emit_event("fired", shooter.id, weapon.id, position, {"projectile_id": id, "ammo_id": ammo.id,
		"caliber_m": ammo.caliber_m, "barrel_index": barrel, "muzzle_direction": direction,
		"train_rad": weapon.train_rad, "elevation_rad": weapon.elevation_rad,
		"velocity_mps": velocity, "gravity_mps2": ammo.gravity_mps2, "flight_time_s": flight_s, "tracer": tracer,
		"lifetime_s":p.lifetime_s, "mount_role":role, "source_domain":source.domain}, rounds[id].target_id)
	return true

## BombStores is the only production caller and inventory writer. No fake gun.
func release_bomb(world: SimulationWorld, shooter: UnitState, rack_id: String, slot: int, ammo: AmmoDefinition, position: Vector3, order_id: String, local_pitch_rad: float = 0.0) -> bool:
	if ammo.release_mode != "gravity_release" or ammo.muzzle_speed_mps != 0.0: return false
	if not shooter.active or not CombatPresence.is_present(shooter.module_data): return false
	if not has_capacity():
		capacity_rejections += 1
		return false
	if not position.is_finite() or not shooter.velocity_mps.is_finite(): return false
	next_id += 1
	var p: Round = Round.new()
	p.id = "projectile_%08d" % next_id
	p.entity_id = shooter.id
	p.weapon_id = rack_id
	p.target_id = "" # No enemy world-state reference or guidance after release.
	p.faction_id = shooter.faction_id
	p.ammo_id = ammo.id
	p.position_m = position
	p.velocity_mps = shooter.velocity_mps
	p.fuze_s = -1.0
	p.gravity = ammo.gravity_mps2
	p.lifetime_s = ammo.max_lifetime_s
	p.mass_kg = ammo.projectile_mass_kg
	p.caliber_m = ammo.caliber_m
	p.born_tick = world.tick
	var release_basis: Basis = shooter.world_transform().basis*Basis(Vector3.RIGHT,local_pitch_rad)
	p.forward_m = -release_basis.z
	p.up_m = release_basis.y
	p.collision_length_m = ammo.collision_length_m
	p.collision_span_m = maxf(ammo.collision_span_m,ammo.caliber_m)
	p.cleared_self = not _inside_source(shooter.world_transform().affine_inverse()*position,frame.proxies[shooter.id],p.collision_span_m*0.5,shooter.world_transform().basis.inverse()*p.forward_m,p.collision_length_m*0.5)
	p.release_mode = ammo.release_mode
	p.drag_per_m = ammo.drag_per_m
	p.arming_s = ammo.arming_s
	p.arming_distance_m = ammo.arming_distance_m
	p.impact_delay_s = ammo.impact_delay_s
	p.release_order_id = order_id
	p.slot = slot
	rounds[p.id] = p
	peak_active = maxi(peak_active,rounds.size())
	world.emit_event("bomb_released",shooter.id,rack_id,position,{"projectile_id":p.id,"ammo_id":p.ammo_id,"slot":slot,"order_id":order_id,"velocity_mps":p.velocity_mps,"release_mode":p.release_mode,"arming_s":p.arming_s,"arming_distance_m":p.arming_distance_m,"impact_delay_s":p.impact_delay_s,"forward_m":p.forward_m,"up_m":p.up_m,"collision_length_m":p.collision_length_m,"collision_span_m":p.collision_span_m})
	return true

func fixed_update(world_ref: RefCounted, delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	# Once per tick, rather than once per projectile/target pair.
	collision_units.clear()
	collision_grid.clear()
	for id: String in frame.proxies:
		var unit: UnitState = world.get_unit(id)
		if not CombatPresence.is_present(unit.module_data): continue
		var start: Transform3D = frame.starts[id]
		var end: Transform3D = unit.world_transform()
		collision_units.append({"id":id,"start":start,"end":end,"inverse_start":start.affine_inverse(),
			"inverse_end":end.affine_inverse(),"static_basis":start.basis.is_equal_approx(end.basis),
			"boxes":frame.proxies[id],"bound":frame.bounds[id],"faction_id":unit.faction_id,
			"velocity_mps":unit.velocity_mps,
			"domain":(frame.definitions[id] as UnitDefinition).domain})
		var pad: Vector3 = Vector3.ONE * float(frame.bounds[id])
		var low: Vector3i = _cell(start.origin.min(end.origin) - pad)
		var high: Vector3i = _cell(start.origin.max(end.origin) + pad)
		for x: int in range(low.x, high.x+1):
			for y: int in range(low.y, high.y+1):
				for z: int in range(low.z, high.z+1):
					var cell: Vector3i = Vector3i(x,y,z)
					if not collision_grid.has(cell):
						var indices: Array[int] = []
						collision_grid[cell] = indices
					collision_grid[cell].append(collision_units.size()-1)
	for id: String in rounds.keys():
		var p: Round = rounds[id]
		# Firing follows movement: birth is at the END of this tick, not its start.
		if int(p.born_tick) == world.tick:
			continue
		if not p.contact.is_empty():
			p.delay_remaining_s -= delta_s
			if p.delay_remaining_s <= 0.0000001: _finish(world,p,str(p.contact.kind),p.contact)
			continue
		if p.release_mode == "gravity_release": _align_bomb(p,delta_s)
		var age: float = float(p.age_s)
		var duration: float = minf(delta_s, float(p.lifetime_s) - age)
		if float(p.fuze_s) >= 0:
			duration = minf(duration, maxf(0.0, float(p.fuze_s) - age))
		var a: Vector3 = p.position_m
		var acceleration: Vector3 = Vector3.DOWN * float(p.gravity)
		if p.release_mode == "gravity_release": acceleration = BombBallistics.acceleration(a,p.velocity_mps,p.gravity,p.drag_per_m)
		var b: Vector3 = a + (p.velocity_mps as Vector3) * duration + acceleration * (0.5 * duration * duration)
		var hit: Dictionary = _first_hit(world, a, b, duration / delta_s, p)
		if float(hit.fraction) <= 1.0:
			var elapsed: float = duration * float(hit.fraction)
			p.velocity_mps += acceleration * elapsed
			p.position_m = a.lerp(b, float(hit.fraction))
			if p.release_mode == "gravity_release":
				p.age_s = age+elapsed
				p.travelled_m += a.distance_to(p.position_m)
				hit["armed"] = p.age_s >= p.arming_s and p.travelled_m >= p.arming_distance_m
				hit["normal"] = hit.get("normal",-p.velocity_mps.normalized())
				world.emit_event("bomb_contact",p.entity_id,p.weapon_id,p.position_m,{"projectile_id":p.id,"ammo_id":p.ammo_id,"surface":hit.surface,"armed":hit.armed,"age_s":p.age_s,"travelled_m":p.travelled_m,"order_id":p.release_order_id},str(hit.get("target_id","")))
				if hit.armed and p.impact_delay_s > 0.0:
					p.contact = hit.duplicate(true)
					p.delay_remaining_s = p.impact_delay_s
					continue
			_finish(world, p, hit.kind, hit)
			continue
		if p.release_mode == "gravity_release": p.travelled_m += a.distance_to(b)
		p.position_m = b
		p.velocity_mps += acceleration * duration
		p.age_s = age + duration
		if float(p.fuze_s) >= 0 and float(p.age_s) + 0.0000001 >= float(p.fuze_s):
			var profile: Dictionary = config.data.ammo_profiles[p.ammo_id]
			_finish(world, p, "airburst", {"radius_m":float(profile.get("self_destruct_radius_m",0.0)) if p.self_destruct else float(profile.burst_radius_m),"reason":"tracer_self_destruct" if p.self_destruct else "time_fuze","age_s":p.age_s})
		elif float(p.age_s) + 0.0000001 >= float(p.lifetime_s):
			_finish(world, p, "projectile_expired", {"reason": "lifetime"})

func _first_hit(world: SimulationWorld, a: Vector3, b: Vector3, tick_fraction: float, p: Round) -> Dictionary:
	# Check full-body separation before spatial rejection; a fast exit must not
	# leave a permanent source exemption when the source leaves the query grid.
	if p.release_mode == "gravity_release" and not p.cleared_self and frame.starts.has(p.entity_id):
		var inverse: Transform3D=(frame.starts[p.entity_id] as Transform3D).affine_inverse()
		if not _inside_source(inverse*a,frame.proxies[p.entity_id],p.collision_span_m*0.5,inverse.basis*p.forward_m,p.collision_length_m*0.5):
			p.cleared_self=true
			world.emit_event("bomb_source_cleared",p.entity_id,p.weapon_id,a,{"projectile_id":p.id,"ammo_id":p.ammo_id,"age_s":p.age_s,"forward_m":p.forward_m,"length_m":p.collision_length_m,"span_m":p.collision_span_m})
	var best: Dictionary = NO_HIT
	for index: int in _candidates(a,b,float(p.caliber_m)*.5):
		var entry: Dictionary = collision_units[index]
		var start: Transform3D = entry.start
		var end: Transform3D = entry.end
		# Cheap conservative broad phase includes full relative translation.
		var ra: Vector3 = a - start.origin
		var rb: Vector3 = b - start.origin.lerp(end.origin, tick_fraction)
		var bound: float = float(entry.bound) + float(p.caliber_m)
		# Scalar slab rejection avoids allocating proxy transforms in empty space.
		if minf(ra.x,rb.x)>bound or maxf(ra.x,rb.x)<-bound or minf(ra.y,rb.y)>bound or maxf(ra.y,rb.y)<-bound or minf(ra.z,rb.z)>bound or maxf(ra.z,rb.z)<-bound:
			continue
		if entry.id == p.entity_id and not p.cleared_self:
			if p.release_mode == "gravity_release":
				if _inside_source((entry.inverse_start as Transform3D)*a,entry.boxes,p.collision_span_m*0.5,(entry.inverse_start as Transform3D).basis*p.forward_m,p.collision_length_m*0.5): continue
			elif CombatGeometry.contains((entry.inverse_start as Transform3D) * a, entry.boxes): continue
			p.cleared_self = true
		var hit: Dictionary = {"fraction":INF}
		if entry.static_basis:
			var local_a: Vector3 = (entry.inverse_start as Transform3D) * a
			var local_b: Vector3 = start.basis.transposed() * rb
			for box: Dictionary in entry.boxes:
				var t: float = CombatGeometry.segment_box(local_a,local_b,SimData.vec3(box.center_m),SimData.vec3(box.half_extents_m)+Vector3.ONE*float(p.caliber_m)*.5)
				if t<float(hit.fraction):hit={"fraction":t,"part_id":box.part,"armor_mm":float(box.get("armor_mm",0.)),"local_position_m":local_a.lerp(local_b,t)}
		else:
			hit = CombatGeometry.moving_boxes(a,b,start,start.interpolate_with(end,tick_fraction),entry.boxes,float(p.caliber_m)*.5)
		if float(hit.fraction) < float(best.fraction):
			best = hit
			best["kind"] = "hit"
			best["target_id"] = entry.id
			best["surface"] = entry.domain
			best["target_velocity_mps"] = entry.velocity_mps
			best["friendly"] = entry.faction_id == p.faction_id
			best["damage_allowed"] = not best.friendly or bool(config.data.environment.friendly_fire)
	for solid: Dictionary in config.data.environment.get("solids", []):
		var t: float = CombatGeometry.segment_box(a, b, SimData.vec3(solid.center_m), SimData.vec3(solid.half_extents_m))
		if t < float(best.fraction):
			best = {"fraction": t, "kind": "surface_impact", "target_id": str(solid.get("id", "")), "surface": solid.surface,
				"normal": CombatGeometry.normal_for_box(a.lerp(b, t), solid)}
	if world.shared_state.has("terrain"):
		var terrain_hit: Dictionary = TerrainQueries.segment_hit(world,a,b)
		if not terrain_hit.is_empty() and float(terrain_hit.fraction) < float(best.fraction):
			best = terrain_hit
			best["kind"] = "surface_impact"
	else:
		var sea_y: float = float(config.data.environment.sea_level_m)
		if a.y >= sea_y and b.y <= sea_y and a.y > b.y:
			var t: float = (a.y - sea_y) / (a.y - b.y)
			var point: Vector3 = a.lerp(b, t)
			var over_land: bool = false
			for solid: Dictionary in config.data.environment.get("solids", []):
				if solid.surface != "ground":
					continue
				var center: Vector3 = SimData.vec3(solid.center_m)
				var size: Vector3 = SimData.vec3(solid.half_extents_m)
				if absf(point.x - center.x) <= size.x and absf(point.z - center.z) <= size.z:
					over_land = true
			if t < float(best.fraction) and not over_land:
				best = {"fraction": t, "kind": "surface_impact", "target_id": "", "surface": "sea", "normal": Vector3.UP}
	return best

static func _cell(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x/CELL_M),floori(point.y/CELL_M),floori(point.z/CELL_M))

func _candidates(a: Vector3, b: Vector3, radius: float) -> Array[int]:
	var low: Vector3i = _cell(a.min(b)-Vector3.ONE*radius)
	var high: Vector3i = _cell(a.max(b)+Vector3.ONE*radius)
	if low==high:
		return collision_grid.get(low,EMPTY_INDICES)
	var seen: Dictionary = {}
	for x: int in range(low.x,high.x+1):
		for y: int in range(low.y,high.y+1):
			for z: int in range(low.z,high.z+1):
				for index: int in collision_grid.get(Vector3i(x,y,z),[]): seen[index]=true
	var result: Array[int] = []
	result.assign(seen.keys())
	result.sort()
	return result

func _finish(world: SimulationWorld, p: Round, kind: String, extra: Dictionary) -> void:
	var relative_velocity: Vector3 = p.velocity_mps - (extra.get("target_velocity_mps",Vector3.ZERO) as Vector3)
	var data: Dictionary = {"projectile_id": p.id, "ammo_id": p.ammo_id, "caliber_m": p.caliber_m,
		"energy_j": 0.5 * p.mass_kg * relative_velocity.length_squared(), "velocity_mps": p.velocity_mps,
		"source_faction_id": p.faction_id}
	if p.release_mode == "gravity_release":
		data.merge({"release_mode":p.release_mode,"armed":bool(extra.get("armed",false)),"order_id":p.release_order_id,"slot":p.slot,"age_s":p.age_s,"travelled_m":p.travelled_m})
	data.merge(extra, true)
	data.erase("kind")
	data.erase("fraction")
	world.emit_event(kind, p.entity_id, p.weapon_id, p.position_m, data, extra.get("target_id", ""))
	if p.release_mode == "gravity_release" and bool(data.armed):
		var profile: Dictionary = config.data.ammo_profiles[p.ammo_id]
		data["radius_m"] = float(profile.blast_radius_m)
		data["visual_radius_m"] = float(profile.visual_radius_m)
		world.emit_event("bomb_explosion",p.entity_id,p.weapon_id,p.position_m,data,str(extra.get("target_id","")))
	rounds.erase(p.id)
	terminated += 1

func snapshot_state() -> Dictionary:
	var records: Dictionary = {}
	for id: String in rounds:
		records[id]=(rounds[id] as Round).snapshot()
	return {"rounds": records, "launched": next_id, "terminated": terminated, "capacity_rejections": capacity_rejections,"peak_active":peak_active}

## A bomb clears its source only after its complete conservative axial envelope leaves the hull.
## Once clear, later self-intersection is physical and cannot be waived.
static func _inside_source(point: Vector3, boxes: Array, radius: float, axis: Vector3, half_length: float) -> bool:
	for box: Dictionary in boxes:
		var center: Vector3 = SimData.vec3(box.center_m)
		var half: Vector3 = SimData.vec3(box.half_extents_m)+Vector3.ONE*(radius+0.002)+axis.abs()*maxf(0.0,half_length-radius)
		if point.is_equal_approx(point.clamp(center-half,center+half)): return true
	return false

## Weathercock orientation is simulated at fixed ticks and never steers velocity.
## It preserves D4Y's real tilted crutch attitude at birth instead of snapping it.
static func _align_bomb(p: Round, dt: float) -> void:
	if p.velocity_mps.length_squared()<1.0:return
	var desired: Vector3=p.velocity_mps.normalized()
	var angle: float=p.forward_m.angle_to(desired)
	if angle>0.00001:p.forward_m=p.forward_m.slerp(desired,minf(1.0,1.6*dt/angle)).normalized()
	p.up_m=AircraftFlightMath.frame(p.forward_m,p.up_m).y
