extends SceneTree
const FIX: Script = preload("res://tests/bombing/fixture.gd")
var checks: int = 0
var failures: int = 0
var evidence: Array = []
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	evidence.append({"passed":ok,"label":label})
	print("BOMB01_CHECK ",ok," ",label)
	if not ok: failures += 1
func _arena(extra: Array = [], custom: CombatConfig = null) -> Dictionary:
	var spawns: Array = [FIX.spawn("bomber","us",Vector3(1000,2000,1000),"us_b25j_1944_07")]
	spawns.append_array(extra)
	var c: CombatConfig = FIX.config() if custom == null else custom
	c.data.environment.solids = c.data.environment.get("solids",[])
	return FIX.arena(spawns,false,false,c)
func _release(a: Dictionary, position: Vector3, velocity: Vector3, armed: bool = true, drag: float = -1.0, delay: float = -1.0) -> AmmoDefinition:
	var world: SimulationWorld = a.world
	var unit: UnitState = world.get_unit("bomber")
	unit.velocity_mps = velocity
	var ammo: AmmoDefinition = world.ammo_definition("us_an_m64_tnt_tm1950")
	if not armed:
		ammo.arming_s = 100.0
		ammo.arming_distance_m = 10000.0
	if drag >= 0: ammo.drag_per_m = drag
	if delay >= 0: ammo.impact_delay_s = delay
	expect(a.projectiles.release_bomb(world,unit,"controlled_rack",0,ammo,position,"controlled_probe"),"controlled release uses shared CombatProjectiles")
	return ammo
func _events(world: SimulationWorld, kind: String) -> Array:
	return world.drain_events().filter(func(e: BattleEvent) -> bool: return e.kind == kind)
func run() -> void:
	var a: Dictionary = _arena()
	var world: SimulationWorld = a.world
	var ammo: AmmoDefinition = _release(a,Vector3(0,100,0),Vector3(20,0,-7),true,0.0,0.0)
	var round: CombatProjectiles.Round = a.projectiles.rounds.values()[0]
	expect(round.velocity_mps.is_equal_approx(Vector3(20,0,-7)),"bomb inherits actual mother velocity with zero muzzle speed")
	world.step_ticks(120)
	expect(absf(round.position_m.y-(100-0.5*9.80665*4)) < 0.002,"two-second zero-drag gravity matches independent analytic height")
	expect(absf(round.position_m.x-40) < 0.001,"no steering or artificial downward muzzle speed")
	world.drain_events()
	world.step_ticks(180)
	var contacts: Array = _events(world,"bomb_contact")
	var fall: float = sqrt(200.0/9.80665)
	expect(contacts.size()==1 and contacts[0].data.surface=="sea" and absf(contacts[0].position_m.x-20*fall)<.002,"exact first sea crossing, analytic range, one contact")
	expect(a.projectiles.rounds.is_empty() and a.projectiles.terminated==1,"one terminal resolution reclaims projectile")
	FIX.dispose(a)
	# Arming has two independent requirements; an unarmed first impact never retries.
	a = _arena(); world = a.world
	_release(a,Vector3(0,20,0),Vector3.ZERO,false,0.0)
	world.step_ticks(600)
	var all: Array[BattleEvent] = world.drain_events()
	expect(all.filter(func(e: BattleEvent) -> bool: return e.kind=="bomb_explosion").is_empty(),"unarmed impact is a dud, no later explosion")
	expect(all.filter(func(e: BattleEvent) -> bool: return e.kind=="bomb_contact").size()==1 and a.projectiles.terminated==1,"unarmed first contact cannot reach a second surface")
	FIX.dispose(a)
	# Thin roof must intercept before underlying sea, even inside one movement tick.
	var c: CombatConfig = FIX.config()
	c.data.environment.solids = [{"id":"roof","surface":"building","center_m":[0.,15.,0.],"half_extents_m":[10.,.01,10.]}]
	a = _arena([],c); world = a.world
	_release(a,Vector3(0,40,0),Vector3(0,-1000,0),false,0.0)
	world.step_ticks(10); contacts=_events(world,"bomb_contact")
	expect(contacts.size()==1 and contacts[0].target_id=="roof" and absf(contacts[0].position_m.y-15.01)<.001,"shared swept collision picks thin roof before sea")
	FIX.dispose(a)
	# Near targets and a friend; exact damage is a game approximation, not historical.
	var target_type: String = "us_40mm_m1_m2a1_1944"
	var spawns: Array = [FIX.spawn("near","jp",Vector3(18,0,0),target_type),FIX.spawn("far","jp",Vector3(-48,0,0),target_type),FIX.spawn("friend","us",Vector3(0,0,20),target_type)]
	a = _arena(spawns); world = a.world
	var before: float = world.get_unit("near").module_data.damage.structure
	_release(a,Vector3(0,200,0),Vector3.ZERO,true,0.0,0.1)
	world.step_ticks(500); all = world.drain_events()
	var blasts: Array = all.filter(func(e: BattleEvent) -> bool: return e.kind=="bomb_explosion")
	var hits: Array = all.filter(func(e: BattleEvent) -> bool: return e.kind=="damaged")
	expect(blasts.size()==1,"armed delayed explosion occurs exactly once")
	var near_damage: float = 0.; var far_damage: float = 0.; var near_count: int = 0
	for event: BattleEvent in hits:
		if event.target_id=="near": near_damage=float(event.data.amount);near_count+=1
		if event.target_id=="far": far_damage=float(event.data.amount)
	expect(near_damage > far_damage and far_damage > 0.0 and near_count==1,"range falloff applies once per ground entity")
	expect(world.get_unit("friend").module_data.damage.structure==before,"friendly-fire off excludes nearby friend from blast damage")
	FIX.dispose(a)
	c = FIX.config();c.data.environment.friendly_fire=true
	a = _arena(spawns,c);world=a.world
	_release(a,Vector3(0,200,0),Vector3.ZERO,true,0.0,0.0);world.step_ticks(500)
	expect(float(world.get_unit("friend").module_data.damage.structure)<before,"explicit friendly-fire applies same blast to friend")
	FIX.dispose(a)
	c=FIX.config();c.data.environment.solids=[{"id":"shield","surface":"building","center_m":[9.,10.,0.],"half_extents_m":[.1,12.,14.]}]
	a=_arena(spawns,c);world=a.world
	_release(a,Vector3(0,200,0),Vector3.ZERO,true,0.0,0.0);world.step_ticks(500)
	expect(float(world.get_unit("near").module_data.damage.structure)==before,"building proxy occludes blast; no wall penetration")
	FIX.dispose(a)
	a = _arena();world=a.world
	_release(a,Vector3(1000,2050,1000),Vector3.ZERO,false,0.0)
	world.step_ticks(250);contacts=_events(world,"bomb_contact")
	expect(contacts.size()==1 and contacts[0].target_id=="bomber","fully cleared bomb can physically collide with its source again")
	FIX.dispose(a)
	# The centre is outside this small source, but the rear body still overlaps.
	c=FIX.config()
	c.data.unit_profiles.us_b25j_1944_07.boxes=[{"part":"control","center_m":[0.,0.,0.],"half_extents_m":[.5,.5,.5],"armor_mm":0.0}]
	a=FIX.arena([FIX.spawn("bomber","us",Vector3(0,100,0),"us_b25j_1944_07")],false,false,c);world=a.world
	_release(a,Vector3(0,100,-.9),Vector3(0,0,-100),false,0.0)
	round=a.projectiles.rounds.values()[0]
	expect(not round.cleared_self,"outside centre does not clear an overlapping full bomb body")
	world.step_ticks(2)
	expect(round.cleared_self and _events(world,"bomb_contact").is_empty(),"actual free separation clears the full body without a source impact")
	FIX.dispose(a)
	# D4Y crutch attitude is a release condition, separate from inherited velocity.
	a=_arena();world=a.world
	var source: UnitState=world.get_unit("bomber");source.velocity_mps=Vector3(0,0,-80)
	ammo=world.ammo_definition("us_an_m64_tnt_tm1950");ammo.drag_per_m=0.0
	expect(a.projectiles.release_bomb(world,source,"crutch_probe",0,ammo,Vector3(0,100,0),"probe",deg_to_rad(34)),"tilted release enters the shared projectile path")
	round=a.projectiles.rounds.values()[0]
	expect(round.forward_m.angle_to(Vector3.FORWARD)>deg_to_rad(33.9) and round.velocity_mps.is_equal_approx(source.velocity_mps),"crutch orientation survives birth while velocity remains the actual mother velocity")
	var birth_forward: Vector3=round.forward_m
	world.step_ticks(1)
	expect(round.forward_m.angle_to(birth_forward)<=1.6/60.0+.0001 and absf(round.velocity_mps.y+9.80665/60.0)<.0001,"finite simulated attitude alignment does not alter gravity or steer velocity")
	FIX.dispose(a)
	# Original gun rules remain strict while bombs have a separate definition type.
	var catalog: DefinitionCatalog=DefinitionCatalog.new()
	var bad: Dictionary=FIX.parameters().ammunition.us_an_m64_tnt_tm1950.duplicate(true)
	bad.release_mode="gun"
	expect(not catalog.load_data([], [bad]).is_empty(),"ordinary gun ammo still rejects zero muzzle speed")
	bad.release_mode="gravity_release";bad.muzzle_speed_mps=10.0
	expect(not catalog.load_data([], [bad]).is_empty(),"gravity release rejects a fake nonzero muzzle")
	_finish()
func _finish() -> void:
	var out: String="res://.local/mechanisms.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var f: FileAccess=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"\t"));f.close()
	print("BOMB01_MECHANISMS ",checks," checks ",failures," failures")
	call_deferred("_exit_test",0 if failures==0 else 1)

func _exit_test(code: int) -> void:
	quit(code)
