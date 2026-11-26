extends "res://tests/fixtures/combat_test.gd"
## Controlled same-map witnesses. No production accuracy/range/health overrides.
var audit: Dictionary = {"scope":"Controlled poses/targets and ammunition depletion on frozen S09 terrain; not the default battle","checks":[]}

func expect(condition: bool, description: String) -> void:
	super.expect(condition,description)
	audit.checks.append({"description":description,"passed":condition})

func arena(type: String, site: String, target: Dictionary) -> Dictionary:
	var catalog: DefinitionCatalog = FIX.catalog()
	var scenario: Dictionary = {"id":"s10_controlled","seed":1010,"tick_hz":60,"factions":["jp","us"],"spawns":[target],"groups":[],"environment":{"terrain_path":"res://data/maps/island_harbor.json"},"ground_deployments":[{"id":"battery","site_id":site,"unit_definition_id":type,"faction_id":"us"}]}
	expect(GroundDeployments.expand(scenario,catalog).is_empty(),"Stable site resolves selected equipment")
	var world: SimulationWorld = SimulationWorld.new()
	expect(world.configure(catalog,scenario).is_empty(),"Real ground catalog configures")
	expect(BattlefieldTerrain.install(world,scenario.environment.terrain_path).is_empty(),"Same frozen terrain installs")
	var config: CombatConfig = FIX.config()
	var frame: CombatFrame = CombatFrame.new(config)
	var contacts: CombatContacts = CombatContacts.new(config,frame)
	var flight: CombatProjectiles = CombatProjectiles.new(config,frame)
	var launcher: FIX.Launcher = FIX.Launcher.new(flight)
	for module: SimulationModule in [frame,contacts,CombatTargeting.new(config,frame,contacts),CombatWeapons.new(config,frame,contacts,flight),flight,CombatDamage.new(config,frame),launcher]:expect(world.register_module(module).accepted,"Combat module registers")
	expect(GroundSuite.install(world).is_empty(),"Ground installation validates bearing, clearance and domain executor")
	return {"world":world,"frame":frame,"contacts":contacts,"flight":flight,"launcher":launcher,"scenario":scenario}

func order(world: SimulationWorld, id: String, kind: String, target: String="") -> void:
	var request: BattleOrder = BattleOrder.from_data({"order_id":id,"issuer_id":"human_test","source":"human","faction_id":"us","recipient_ids":["battery"],"order_type":kind,"target_id":target,"area":{"center_m":SimData.array3(world.get_unit("battery").position_m),"radius_m":18000},"intent":"controlled_test"})
	expect(world.submit_order(request).accepted,"Human uses same order validation and dispatch as AI")

func run_test() -> void:
	var coast: Dictionary = arena("us_5in51_mk13mod4_1945","harbor_coast_01",FIX.spawn("enemy","jp",Vector3(-1550,0,-1200),"jp_yukikaze_1942_06"))
	var world: SimulationWorld = coast.world
	order(world,"coast_engage","engage","enemy")
	var battery: UnitState = world.get_unit("battery")
	var fixed_position: Vector3 = battery.position_m
	var weapon: WeaponState = battery.weapons.gun_01
	weapon.remaining_rounds[0]=2
	var events: Array[BattleEvent] = []
	for tick: int in range(2400):world.step_ticks(1);events.append_array(world.drain_events())
	var fired: Array[BattleEvent] = events.filter(func(e: BattleEvent)->bool:return e.kind=="fired" and e.entity_id=="battery")
	expect(fired.size()==2 and weapon.remaining_rounds[0]==0,"Finite inventory accounts for exactly two physical coast rounds then stops")
	expect(battery.module_data.combat_runtime.mount_status.gun_01=="empty","Exhausted battery reports empty instead of silently firing")
	expect(battery.position_m==fixed_position and battery.velocity_mps==Vector3.ZERO,"Ground unit never translates or consumes fuel")
	for event: BattleEvent in fired:
		var mount: MountSocket = world.unit_definition(battery.definition_id).mounts[0]
		var expected: Transform3D = battery.world_transform()*mount.local_muzzle_transform(0,event.data.train_rad,event.data.elevation_rad)
		expect(expected.origin.distance_to(event.position_m)<.001 and (-expected.basis.z).dot(event.data.muzzle_direction)>.9999,"Physical fired origin and direction match typed model socket")
	expect(events.any(func(e: BattleEvent)->bool:return e.kind=="hit" and e.entity_id=="battery"),"Coast ballistic sweep physically intersects enemy ship")
	# Stock restored only in this controlled test; cease-fire goes through command bus.
	weapon.remaining_rounds[0]=4
	var cease: BattleCommand = BattleCommand.new()
	cease.command_id="test_hold";cease.issuer_id="human_test";cease.source="human";cease.faction_id="us";cease.entity_id="battery";cease.kind=BattleCommand.CEASE_FIRE;cease.payload={"enabled":true}
	expect(world.submit_command(cease).accepted,"Cease fire uses unified command entry")
	world.step_ticks(120)
	expect(not world.drain_events().any(func(e: BattleEvent)->bool:return e.kind=="fired" and e.entity_id=="battery"),"Cease fire suppresses actual projectiles")
	world.get_unit("enemy").position_m=Vector3(-4500,32,-6000)
	battery.cease_fire=false
	world.step_ticks(210)
	expect(battery.module_data.combat_runtime.mount_status.gun_01 in ["arc","terrain_masked","out_of_range","no_contact","hold_fire"],"Rear mountain target cannot bypass finite site arc or terrain")
	var displaced: Vector3 = battery.position_m
	battery.position_m.y+=.5
	expect(not GroundDeployments.validate(world).is_empty(),"Unsupported hovering deployment gives readable rejection")
	battery.position_m=displaced
	audit.coast_fired=fired.map(func(e: BattleEvent)->Dictionary:return e.snapshot())
	# Actual incoming round disables one mount, then real structural hit destroys it.
	var point: Vector3 = battery.world_transform()*Vector3(0,1.1,0)
	(coast.launcher as FIX.Launcher).pending=[{"shooter":"enemy","ammo":"us_127mm_5in38_shell","position":point+Vector3.RIGHT*10,"direction":Vector3.LEFT,"gravity":0.0}]
	world.step_ticks(12)
	expect(not weapon.enabled and not battery.active and battery.module_data.damage.phase=="disabled","Real exposed-weapon hit disables ground battery at its original position")
	var disabled_at: Vector3 = battery.position_m
	var stock: int = weapon.remaining_rounds[0]
	world.step_ticks(180)
	expect(battery.position_m==disabled_at and weapon.remaining_rounds[0]==stock and battery.module_data.damage.flooding==0,"Disabled ground does not sink/crash/move/fire or flood")
	(coast.launcher as FIX.Launcher).pending=[{"shooter":"enemy","ammo":"us_406mm_mk8_ap","position":point+Vector3.RIGHT*10,"direction":Vector3.LEFT,"gravity":0.0}]
	world.step_ticks(12)
	expect(battery.module_data.damage.phase=="wreck" and battery.position_m==disabled_at,"Disabled mount remains physically hittable and becomes ground wreck")
	expect(CombatPresence.is_present(battery.module_data),"Wreck remains a collision/occlusion object")
	world.step_ticks(1810)
	expect(battery.module_data.damage.phase=="removed" and not CombatPresence.is_present(battery.module_data),"Wreck lifetime releases physical presence without sinking")
	# AA under a known cross-range contact, static only for this ballistics witness.
	var aa: Dictionary = arena("us_40mm_m1_m2a1_1944","harbor_aa_01",FIX.spawn("enemy","jp",Vector3(-4000,450,-2800),"jp_a6m5a_1944"))
	world=aa.world;battery=world.get_unit("battery");weapon=battery.weapons.gun_01
	order(world,"aa_sector","patrol")
	var initial: int = weapon.remaining_rounds[0]
	var aa_events: Array[BattleEvent] = []
	for tick: int in range(1800):world.step_ticks(1);aa_events.append_array(world.drain_events())
	expect(aa_events.any(func(e: BattleEvent)->bool:return e.kind=="fired" and e.entity_id=="battery"),"Sector watch detects and actually fires at aircraft within2743.2m")
	expect(aa_events.any(func(e: BattleEvent)->bool:return e.kind=="damaged" and e.entity_id=="battery"),"M1 physical impact damages aircraft without intercept-timed flak")
	var consumed: int = aa_events.filter(func(e: BattleEvent)->bool:return e.kind=="fired" and e.entity_id=="battery").size()
	expect(initial-weapon.remaining_rounds[0]==consumed,"AA inventory conserves each single-barrel shot")
	var bursts: Array[BattleEvent] = aa_events.filter(func(e: BattleEvent)->bool:return e.kind=="airburst" and e.entity_id=="battery")
	expect(bursts.all(func(e: BattleEvent)->bool:return e.data.reason=="tracer_self_destruct" and absf(float(e.data.age_s)-8.5)<.0001 and e.data.radius_m==2.0),"M1 self-destruction uses fixed8.5s tracer life, never computed intercept time")
	audit.aa_samples=aa_events.filter(func(e: BattleEvent)->bool:return e.kind in ["damaged","airburst"]).slice(0,5).map(func(e: BattleEvent)->Dictionary:return e.snapshot())
	world.reset()
	battery=world.get_unit("battery");weapon=battery.weapons.gun_01
	world.get_unit("enemy").position_m=battery.position_m+Vector3(10,1000,0)
	order(world,"aa_overhead","patrol")
	world.step_ticks(120)
	expect(weapon.elevation_rad<=deg_to_rad(85.0)+.0001 and battery.module_data.combat_runtime.mount_status.gun_01=="arc","AA site85deg cap intersects mechanical90deg instead of ignoring map limit")
	# Intelligence test: planner has no enemy state to discover on its own.
	var view: Dictionary = world.commander_snapshot("us")
	view.orders=[];view.contacts=[]
	var proposals: Array[Dictionary] = GroundCommander.plan(view)
	expect(proposals.size()==1 and proposals[0].target_id=="" and proposals[0].order_type=="patrol","Ground planner with no contacts can only issue sector watch")
	expect(world.reset() and world.get_unit("battery").weapons.gun_01.remaining_rounds[0]==240,"Reset restores actual ground stock and clears tasks/projectiles")
	expect(world.snapshot().modules.combat_projectiles.rounds.is_empty() and world.snapshot().modules.ground_tasks.targets.is_empty(),"Reset clears ground target caches and all in-flight rounds")
	audit.failures=failures;audit.check_count=checks
	FileAccess.open("res://docs/showcase/evidence/S10/mechanisms.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"\t"))
	finish("ground")
