extends "res://tests/fixtures/combat_test.gd"

func probe(spawns: Array, shots: Array, c: CombatConfig = null, ticks: int = 20) -> Dictionary:
	var arena: Dictionary = FIX.arena(spawns,c)
	(arena.launcher as FIX.Launcher).pending.assign(shots)
	(arena.world as SimulationWorld).step_ticks(ticks)
	return arena

func run_test() -> void:
	var spawns: Array = [FIX.spawn("shooter","us",Vector3(100,100,0)), FIX.spawn("near_friend","us",Vector3(0,100,-30)),FIX.spawn("far_enemy","jp",Vector3(0,100,-80))]
	var a: Dictionary = probe(spawns,[{"position":Vector3(0,100,0),"gravity":0.,"speed":12000.}])
	var hits: Array[BattleEvent] = FIX.events(a.world,"hit")
	expect(hits.size()==1 and hits[0].target_id=="near_friend" and hits[0].position_m.z > -35, "12 km/s sweep stops at nearer friendly instead of nominated/far enemy")
	expect(hits.size()==1 and hits[0].data.friendly and not hits[0].data.damage_allowed, "Friendly interception is physical but default friendly damage disabled")
	expect(is_equal_approx(a.world.get_unit("near_friend").module_data.damage.structure,90.), "Friendly hit does not remove structure")
	var c: CombatConfig = FIX.config()
	c.data.environment.friendly_fire=true
	a=probe(spawns,[{"position":Vector3(0,100,0),"gravity":0.,"speed":12000.}],c)
	expect(float(a.world.get_unit("near_friend").module_data.damage.structure)<90, "Explicit friendly-fire mode applies intercepted projectile damage")
	c=FIX.config()
	c.data.environment.solids=[{"id":"thin_wall","surface":"building","center_m":[0,100,-20],"half_extents_m":[10,10,.01]}]
	a=probe(spawns,[{"position":Vector3(0,100,0),"gravity":0.,"speed":12000.}],c)
	var impacts: Array[BattleEvent]=FIX.events(a.world,"surface_impact")
	expect(impacts.size()==1 and impacts[0].data.surface=="building" and absf(impacts[0].position_m.z+19.99)<.01, "Centimetre wall first hit recovered at analytic entry position")
	# Target crosses x=0 between endpoints; neither endpoint overlaps the bullet line.
	a=probe([FIX.spawn("shooter","us",Vector3(100,100,0)),FIX.spawn("crossing","jp",Vector3(-30,100,-50),"us_f6f5_1944",Vector3(1200,0,0))],[{"position":Vector3(0,100,0),"gravity":0.,"speed":6000.}],null,3)
	hits=FIX.events(a.world,"hit")
	expect(hits.size()==1 and hits[0].target_id=="crossing", "Relative-motion sweep detects crossing unit absent from static endpoint checks")
	a=probe([FIX.spawn("shooter","us",Vector3(100,100,0))],[{"position":Vector3(0,5,0),"direction":Vector3.DOWN,"speed":600.,"gravity":0.}],null,4)
	impacts=FIX.events(a.world,"surface_impact")
	expect(impacts.size()==1 and impacts[0].data.surface=="sea" and absf(impacts[0].position_m.y)<.0001, "Ocean impact reaches y=0 once at exact path crossing")
	c=FIX.config()
	c.data.environment.solids=[{"id":"island","surface":"ground","center_m":[0,0,0],"half_extents_m":[10,2,10]}]
	a=probe([FIX.spawn("shooter","us",Vector3(100,100,0))],[{"position":Vector3(0,5,0),"direction":Vector3.DOWN,"speed":600.,"gravity":0.}],c,4)
	impacts=FIX.events(a.world,"surface_impact")
	expect(impacts.size()==1 and impacts[0].data.surface=="ground" and absf(impacts[0].position_m.y-2)<.0001, "Island top classified ground before the underlying sea plane")
	a=probe([FIX.spawn("shooter","us",Vector3(100,100,0))],[{"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,0),"speed":600.,"gravity":0.,"fuze":.01}],null,30)
	var bursts: Array[BattleEvent]=FIX.events(a.world,"airburst")
	expect(bursts.size()==1 and absf(bursts[0].position_m.z+6)<.001 and a.projectiles.terminated==1 and a.projectiles.rounds.is_empty(), "Sub-tick timed fuze bursts at 6 metres once and releases projectile")
	c=FIX.config()
	c.data.environment.solids=[{"id":"fuze_wall","surface":"building","center_m":[0,100,-6],"half_extents_m":[10,10,.01]}]
	a=probe([FIX.spawn("shooter","us",Vector3(100,100,0))],[{"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,0),"speed":600.,"gravity":0.,"fuze":.01}],c,20)
	var all_events: Array[BattleEvent]=a.world.drain_events()
	var terminal_count: int=0
	for event: BattleEvent in all_events:
		if event.kind in ["surface_impact","airburst"]: terminal_count+=1
	expect(terminal_count==1 and a.projectiles.terminated==1, "Impact at/before fuze never double-resolves")
	expect(is_equal_approx(CombatGeometry.segment_box(Vector3(-5,0,0),Vector3(5,0,0),Vector3.ZERO,Vector3.ONE),.4), "Slab geometry matches independent 4/10 analytic fraction")
	a=probe([FIX.spawn("shooter","us",Vector3(0,100,0))],[{"position":Vector3(0,100,0),"direction":Vector3.UP,"speed":120.,"gravity":60.,"lifetime":10.}],null,260)
	hits=FIX.events(a.world,"hit")
	expect(hits.size()==1 and hits[0].target_id=="shooter" and a.projectiles.terminated==1,"Initial self-exclusion ends after exit; returning ballistic round can hit its own shooter")
	var air_spawns: Array=[FIX.spawn("shooter","us",Vector3(100,200,0)),FIX.spawn("near_air","jp",Vector3(15,100,0)),FIX.spawn("far_air","jp",Vector3(40,100,0))]
	a=probe(air_spawns,[{"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,0),"direction":Vector3.UP,"speed":10.,"gravity":0.,"fuze":.1}],null,15)
	expect(float(a.world.get_unit("near_air").module_data.damage.structure)<90 and is_equal_approx(a.world.get_unit("far_air").module_data.damage.structure,90.),"Timed flak damage falls off and cannot reach aircraft beyond configured radius")
	c=FIX.config()
	c.data.environment.solids=[{"id":"blast_wall","surface":"building","center_m":[7.5,100,0],"half_extents_m":[.1,20,20]}]
	a=probe(air_spawns,[{"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,0),"direction":Vector3.UP,"speed":10.,"gravity":0.,"fuze":.1}],c,15)
	expect(is_equal_approx(a.world.get_unit("near_air").module_data.damage.structure,90.),"Solid barrier blocks flak fragments even when burst and target are in radius")
	finish("projectile impact")
