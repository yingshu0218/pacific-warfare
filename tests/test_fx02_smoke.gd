extends "res://tests/fixtures/combat_test.gd"

const OUT: String = "res://.local/fx02/evidence/smoke_checks.json"
var measurements: Dictionary = {}
var actual_shots: Array[BattleEvent] = []

func run_test() -> void:
	_gun_and_wind()
	_terminals()
	_bomb_overlap()
	_budget()
	var folder: String = ProjectSettings.globalize_path(OUT.get_base_dir())
	DirAccess.make_dir_recursive_absolute(folder)
	var file: FileAccess = FileAccess.open(OUT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t")+"\n")
	file.close()
	finish("FX02 smoke")

func _effects(capacity: int = 144) -> BombingEffects:
	var fx: BombingEffects = BombingEffects.new()
	fx.effect_capacity = capacity
	fx.sound_enabled = false
	root.add_child(fx)
	fx.clear(1)
	return fx

func _active(fx: CombatEffects, kind: String) -> Array[Dictionary]:
	return fx.slots.filter(func(slot: Dictionary) -> bool: return slot.active and slot.kind==kind)

func _event(events: Array[BattleEvent], kind: String, caliber: float = -1., surface: String = "") -> BattleEvent:
	for event: BattleEvent in events:
		if event.kind!=kind: continue
		if caliber>0. and not is_equal_approx(float(event.data.get("caliber_m",0.)),caliber): continue
		if not surface.is_empty() and event.data.get("surface")!=surface: continue
		return event
	return null

func _gun_and_wind() -> void:
	var arena: Dictionary = FIX.arena([FIX.spawn("shooter","us",Vector3(0,0,-420),"us_iowa_bb61_1944_12_28",Vector3(0,0,-15))])
	var world: SimulationWorld = arena.world
	var ship: UnitState = world.get_unit("shooter")
	world.step_ticks(1)
	var barrel: MountSocket = world.unit_definition(ship.definition_id).mounts[0]
	var muzzle: Transform3D = ship.world_transform()*barrel.local_muzzle_transform(0,.65,.12)
	var direction: Vector3 = -muzzle.basis.z.normalized()
	var weapon: WeaponState = ship.weapons.values()[0]
	var projectile: CombatProjectiles = arena.projectiles
	projectile.launch(world,ship,weapon,world.ammo_definition("us_406mm_mk8_ap"),muzzle.origin,direction)
	for mount: MountSocket in world.unit_definition(ship.definition_id).mounts:
		if mount.role not in ["secondary","dual_purpose"]: continue
		var secondary: WeaponState = ship.weapons.values().filter(func(w: WeaponState) -> bool: return w.mount_id==mount.id)[0]
		projectile.launch(world,ship,secondary,world.ammo_definition("us_127mm_5in38_shell"),muzzle.origin+Vector3.RIGHT*80.,direction)
		break
	var events: Array[BattleEvent] = world.drain_events()
	actual_shots = events.filter(func(event: BattleEvent) -> bool: return event.kind=="fired")
	var fired: BattleEvent = _event(events,"fired",.4064)
	expect(fired!=null and fired.position_m.is_equal_approx(muzzle.origin) and fired.data.muzzle_direction.is_equal_approx(direction),"Actual launch takes mount world origin and axis independently of ship velocity")
	var fx: BombingEffects = _effects()
	fx.consume(events,1)
	var puffs: Array[Dictionary] = _active(fx,"muzzle_smoke")
	var flashes: Array[Dictionary] = _active(fx,"muzzle_flash")
	expect(puffs.size()==3 and flashes.size()==2,"One flash per barrel plus major and secondary muzzle clouds")
	if fired==null or puffs.size()!=3 or flashes.size()!=2:
		fx.free()
		return
	expect(puffs[0].position==fired.position_m and puffs[0].owner_id=="" and puffs[0].size>puffs[2].size*2.5 and puffs[0].life>puffs[2].life,"Main and secondary smoke share their own real barrel origin and differ in size and lifetime")
	var material: ShaderMaterial = flashes[0].material
	expect((material.get_shader_parameter("trail_axis") as Vector3).is_equal_approx(direction),"Flash uses barrel launch axis")
	fx.advance(.24)
	var cloud: Dictionary = puffs[0]
	var mesh: MeshInstance3D = cloud.mesh
	var early_point: Vector3 = mesh.position
	var early_scale: Vector3 = mesh.scale
	expect((early_point-fired.position_m).dot(direction)>3. and _active(fx,"muzzle_flash").is_empty(),"Gas goes forward first and flare expires separately")
	var paused: Transform3D = mesh.transform
	var paused_fade: float = cloud.opacity
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	camera.position = Vector3(-300.,100.,400.)
	camera.look_at(early_point)
	fx.advance(0.)
	expect(mesh.transform==paused and cloud.opacity==paused_fade,"Pause and camera motion keep opacity and world-space gas pose")
	camera.free()
	world.step_ticks(300)
	var snapshot: Dictionary = world.snapshot()
	fx.apply_snapshot(snapshot)
	var late: BombingEffects = _effects()
	late.advance(fired.time_s+5.)
	late.consume(events,1)
	fx.advance(5.-.24)
	var late_cloud: Dictionary = _active(late,"muzzle_smoke")[0]
	var after: Vector3 = mesh.position
	expect(after.is_equal_approx((late_cloud.mesh as MeshInstance3D).position) and is_equal_approx(cloud.opacity,late_cloud.opacity),"Batched event and regular playback reach identical smoke pose and fade")
	var wind: Vector2 = CloudSeaEnvironment.WIND.normalized()
	var late_step: Vector3 = after-early_point
	expect(Vector2(late_step.x,late_step.z).normalized().dot(wind)>.9 and mesh.scale.x>early_scale.x and float(cloud.opacity)<.6,"Puff broadens, thins and travels down the sea/cloud wind")
	expect((snapshot.units.shooter.position_m as Vector3).distance_to(ship.world_transform().origin)<.001 and world.snapshot()==snapshot,"Snapshot and visuals leave all simulation state intact")
	var shown: int = fx.shown_events
	fx.consume(events,1)
	expect(fx.shown_events==shown and mesh.position==after,"Replayed shot sequence is idempotent")
	fx.clear(2)
	expect(fx.statistics().visible_instances==0 and fx.elapsed_s==0.,"New generation clears visuals and resets age")
	fx.effects_enabled = false
	fx.consume(events,2)
	expect(fx.statistics().active==0 and fx.shown_events==events.size() and world.snapshot()==snapshot,"Disabling FX advances the cursor without touching simulation")
	fx.effects_enabled = true
	fx.consume(events,2)
	expect(fx.statistics().active==0,"Toggling FX on does not replay prior events")
	measurements.muzzle = {"point_m":SimData.array3(fired.position_m),"early_m":SimData.array3(early_point),
		"late_m":SimData.array3(after),"late_opacity":late_cloud.opacity,"seconds":[.24,5.]}
	fx.free()
	late.free()

func _terminals() -> void:
	var settings: CombatConfig = FIX.config()
	settings.data.environment.solids = [{"id":"bank","surface":"ground","center_m":[120.,10.,0.],"half_extents_m":[12.,10.,12.]}]
	var arena: Dictionary = FIX.arena([
		FIX.spawn("shooter","us",Vector3(1000,300,500)),
		FIX.spawn("ship","jp",Vector3(-120,0,0),"jp_yamato_1944_04")
	],settings,false)
	var launcher: FIX.Launcher = arena.launcher
	launcher.pending = [
		{"ammo":"us_406mm_mk8_ap","position":Vector3(-30,8,0),"direction":Vector3.LEFT},
		{"ammo":"us_406mm_mk8_ap","position":Vector3(120,100,0),"direction":Vector3.DOWN},
		{"ammo":"us_406mm_mk8_ap","position":Vector3(0,100,100),"direction":Vector3.DOWN},
		{"ammo":"us_127mm_5in38_shell","position":Vector3(0,230,300),"direction":Vector3.RIGHT,"fuze":.24},
		{"ammo":"us_127mm_m2_ball","position":Vector3(0,260,300),"direction":Vector3.RIGHT,"lifetime":.12},
		{"ammo":"s10_us_40mm_mkii_het_sd","position":Vector3(0,700,30),"direction":Vector3.RIGHT}
	]
	var world: SimulationWorld = arena.world
	world.step_ticks(18)
	var events: Array[BattleEvent] = world.drain_events()
	var ship: BattleEvent = _event(events,"hit",.4064,"ship")
	var ground: BattleEvent = _event(events,"surface_impact",.4064,"ground")
	var water: BattleEvent = _event(events,"surface_impact",.4064,"sea")
	var flak: BattleEvent = _event(events,"airburst",.127)
	var expired: BattleEvent = _event(events,"projectile_expired")
	expect(ship!=null and ground!=null and water!=null and flak!=null and expired!=null,"Shared swept pipeline resolves each controlled surface, fuze and lifetime")
	if ship==null or ground==null or water==null or flak==null or expired==null: return
	var fx: BombingEffects = _effects()
	var terminals: Array[BattleEvent] = [ship,ground,water,flak,expired]
	terminals.sort_custom(func(a: BattleEvent,b: BattleEvent) -> bool: return a.sequence<b.sequence)
	fx.consume(terminals,1)
	expect(_active(fx,"impact_smoke").size()==3 and _active(fx,"impact_dust").size()==1 and _active(fx,"blast_sparks").size()==2,"Ship blast and ground dust use separate contact profiles")
	expect(_active(fx,"water").size()==3 and _active(fx,"foam").size()==1,"Sea contact still creates three jets and one foam ring")
	var bursts: Array[Dictionary] = _active(fx,"burst")
	expect(bursts.size()==3 and bursts.all(func(s: Dictionary) -> bool: return s.position==flak.position_m),"Only actual fuze event seeds three lobes at the same physical airburst point")
	fx.advance(.23)
	if bursts.size()==3:
		expect((bursts[0].mesh as MeshInstance3D).position.distance_to((bursts[1].mesh as MeshInstance3D).position)>3.,"Flak lobes spread independently after ignition")
	fx.advance(3.5)
	expect(_active(fx,"impact_smoke").size()==3 and _active(fx,"burst").size()==3 and _active(fx,"blast_flash").is_empty(),"Smoke survives the ship flash and the flak ignition")
	world.step_ticks(500)
	var sd: BattleEvent = _event(world.drain_events(),"airburst",.04)
	expect(sd!=null and sd.data.reason=="tracer_self_destruct","40 mm round reaches its own configured self-destruct")
	if sd!=null:
		fx.consume([sd],1)
		var light: Array[Dictionary] = _active(fx,"self_destruct")
		expect(light.size()==1 and light[0].life<2. and light[0].size<1.5 and _active(fx,"burst").is_empty(),"Small self-destruct never produces heavy black flak; clock catch-up ages previous effect slots")
	fx.free()

func _bomb_overlap() -> void:
	var settings: CombatConfig = FIX.config()
	var bombing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bombing/combat_profiles.json"))
	settings.data.ammo_profiles.merge(bombing.ammo_profiles,true)
	settings.data.environment.solids = [{"id":"roof","surface":"building","center_m":[0.,8.,0.],"half_extents_m":[15.,2.,15.]}]
	var arena: Dictionary = FIX.arena([FIX.spawn("bomber","us",Vector3(1000,300,500),"us_f6f5_1944")],settings,false)
	var world: SimulationWorld = arena.world
	world.step_ticks(1)
	var projectiles: CombatProjectiles = arena.projectiles
	var unit: UnitState = world.get_unit("bomber")
	var ammo: AmmoDefinition = world.ammo_definition("us_an_m64_tnt_tm1950")
	projectiles.release_bomb(world,unit,"probe",0,ammo,Vector3(0,140,0),"probe")
	world.step_ticks(420)
	var events: Array[BattleEvent] = world.drain_events()
	var contact: BattleEvent = _event(events,"surface_impact",-1.,"building")
	var blast: BattleEvent = _event(events,"bomb_explosion")
	expect(contact!=null and blast!=null and contact.data.projectile_id==blast.data.projectile_id,"Real bomb emits contact and detonation for one projectile")
	if contact==null or blast==null: return
	var fx: BombingEffects = _effects()
	fx.consume([contact],1)
	expect(fx.statistics().active==0,"Armed terminal event awaits detonation for its visuals")
	fx.consume([blast],1)
	var counts: Dictionary = fx.requested_by_kind.duplicate()
	expect(counts.get("blast_flash")==1 and counts.get("impact_dust")==1 and counts.get("impact_smoke")==1,"Armed bomb produces one land flash, dust skirt and upper smoke")
	fx.consume([contact,blast],1)
	expect(fx.requested_by_kind==counts,"Re-delivered bomb contact and explosion produce no duplicate visuals")
	fx.clear(2)
	fx.consume([contact,blast],2)
	expect(fx.requested_by_kind==counts,"Bomb detonation sequence can be used again in a fresh generation")
	fx.free()

func _budget() -> void:
	var fx: BombingEffects = _effects(30)
	var events: Array[BattleEvent] = []
	for index: int in 80:
		var event: BattleEvent = BattleEvent.new()
		event.kind = "airburst"
		event.sequence = index+1
		event.time_s = 1.
		event.position_m = Vector3(index*8.,150.,0.)
		event.data = {"projectile_id":"stress_%d"%index,"caliber_m":.127,"reason":"time_fuze"}
		events.append(event)
	fx.consume(events,1)
	var pressure: Array[BattleEvent] = []
	for shot: BattleEvent in actual_shots:
		var copy: BattleEvent = shot.copy()
		copy.sequence = 81+pressure.size()
		copy.time_s = 1.02
		pressure.append(copy)
	fx.consume(pressure,1)
	fx.advance(.3)
	var stats: Dictionary = fx.statistics()
	expect(not _active(fx,"muzzle_smoke").is_empty() and _active(fx,"shell").size()==1 and _active(fx,"tracer").size()==1 and _active(fx,"burst").size()>12,"Muzzle smoke, shell and light tracer reclaim capacity when every slot is occupied by dense flak")
	expect(fx.active_by_group[CombatEffects.BudgetGroup.TRACER]==1,"Active slot group count survives preemption")
	expect(stats.allocated==30 and stats.peak_visible==30 and stats.rejected_by_kind.get("burst",0)>0,"Dense unique flak fixture bounds meshes and records suppressed components")
	fx.advance(8.)
	expect(_active(fx,"burst").is_empty() and _active(fx,"muzzle_smoke").is_empty() and fx.get_child_count()==30,"Old fire and flak expire without allocating beyond pool")
	measurements.stress = stats
	fx.free()
