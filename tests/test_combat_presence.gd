extends "res://tests/fixtures/combat_test.gd"

const AIR: Script = preload("res://tests/fixtures/aircraft_fixture.gd")
const FLEET: Script = preload("res://tests/fixtures/fleet_fixture.gd")
var evidence: Dictionary = {}

class ExitAt extends SimulationModule:
	var exit_tick: int
	var domain: String
	var unit_id: String
	var damage_at_exit: Dictionary = {}
	func _init(id: String, kind: String, due: int, order: int) -> void:
		module_id = "test_exit_at"
		priority = order
		unit_id = id
		domain = kind
		exit_tick = due
	func fixed_update(world_ref: RefCounted, _dt: float) -> void:
		var world: SimulationWorld = world_ref as SimulationWorld
		if world.tick != exit_tick: return
		var unit: UnitState = world.get_unit(unit_id)
		unit.active = false
		unit.module_data[domain + "_motion"] = {"exited": true}
		damage_at_exit = unit.module_data.damage.duplicate(true)
		world.emit_event(domain + "_exit", unit_id, "", unit.position_m, {"destroyed": false, "reason": "test_actual_exit"})
		# A delayed producer must not resurrect a departed plane as an impact wreck.
		world.emit_event("unit_surface_contact", unit_id, "", Vector3.ZERO, {"surface": "sea", "velocity_mps": Vector3(80,-10,0), "reason": "late_pre_exit_contact"})

func depart(unit: UnitState, domain: String) -> void:
	unit.active = false
	unit.module_data[domain + "_motion"] = {"exited": true}

func run_test() -> void:
	for domain: String in ["aircraft", "ship"]:
		_absence_and_contacts(domain)
		_pending_events(domain)
		_occlusion(domain)
		_airburst(domain)
		_effects(domain)
		_real_exit(domain)
	_inactive_bodies()
	_departed_shooter_rounds()
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S05/departed_boundary.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	finish("combat presence and departure")

func _absence_and_contacts(domain: String) -> void:
	var definition: String = "jp_a6m5a_1944" if domain == "aircraft" else "jp_yukikaze_1942_06"
	var a: Dictionary = FIX.arena([FIX.spawn("shooter","us",Vector3(0,100,0)), FIX.spawn("departed","jp",Vector3(0,100,-100),definition), FIX.spawn("behind","jp",Vector3(0,100,-190))])
	var world: SimulationWorld = a.world
	world.step_ticks(1)
	world.drain_events()
	var unit: UnitState = world.get_unit("departed")
	var observed: Dictionary = CombatContacts.find(world,"us",unit.id)
	expect(not observed.is_empty(),domain+" observed before exit")
	depart(unit,domain)
	var damage_before: Dictionary = unit.module_data.damage.duplicate(true)
	(a.launcher as FIX.Launcher).pending.append({"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,-20),"speed":12000.,"gravity":0.,"lifetime":1.})
	world.step_ticks(3)
	var ghost_hits: int = 0
	var behind_hits: int = 0
	var ghost_damage: int = 0
	for event: BattleEvent in world.drain_events():
		if event.target_id==unit.id and event.kind=="hit":ghost_hits+=1
		if event.target_id==unit.id and event.kind=="damaged":ghost_damage+=1
		if event.target_id=="behind" and event.kind=="hit":behind_hits+=1
	expect(ghost_hits==0 and ghost_damage==0 and unit.module_data.damage==damage_before,domain+" exit removes physical hit/damage target without altering its damage record")
	expect(behind_hits==1,domain+" exit cannot shield a real unit behind the former proxy")
	expect(not a.projectiles.collision_units.any(func(entry: Dictionary) -> bool:return entry.id==unit.id),domain+" absent unit omitted from actual collision grid")
	var last: Dictionary = CombatContacts.find(world,"us",unit.id)
	expect(not last.is_empty() and last.observed_tick==observed.observed_tick and last.position_m==observed.position_m,domain+" departure does not leak global exit into last-known intelligence")
	world.step_ticks(240)
	last=CombatContacts.find(world,"us",unit.id,false)
	expect(not last.is_empty() and not last.fresh and last.observed_tick==observed.observed_tick,domain+" last contact becomes stale by time, not authoritative exit")
	world.step_ticks(1000)
	expect(CombatContacts.find(world,"us",unit.id,false).is_empty(),domain+" stale contact expires normally")
	world.reset()
	unit=world.get_unit("departed")
	expect(unit.active and CombatPresence.is_present(unit.module_data),domain+" reset restores original physical presence")
	(a.launcher as FIX.Launcher).pending.append({"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,-20),"speed":12000.,"gravity":0.})
	world.step_ticks(2)
	var restored_hits: int = 0
	for event: BattleEvent in world.drain_events():
		if event.kind=="hit" and event.target_id==unit.id:restored_hits+=1
	expect(restored_hits==1,domain+" reset target is physically hittable again")
	evidence[domain+"_direct"]={"hits_after_exit":ghost_hits,"damage_after_exit":ghost_damage,"behind_hits":behind_hits,"reset_hits":restored_hits}

func _pending_events(domain: String) -> void:
	var definition: String="jp_a6m5a_1944" if domain=="aircraft" else "jp_yukikaze_1942_06"
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(100,100,0)),FIX.spawn("departed","jp",Vector3(0,100,-100),definition)])
	var world: SimulationWorld=a.world
	var unit: UnitState=world.get_unit("departed")
	unit.module_data.damage.fire=.8
	unit.module_data.damage.flooding=.2
	var exit: ExitAt=ExitAt.new(unit.id,domain,2,620)
	world.register_module(exit)
	(a.launcher as FIX.Launcher).pending.append({"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,-20),"speed":12000.,"gravity":0.})
	world.step_ticks(2)
	var queued_hits: int=0
	var new_damage: int=0
	var post_exit_loss: int=0
	for event: BattleEvent in world.drain_events():
		if event.kind=="hit" and event.target_id==unit.id:queued_hits+=1
		if event.kind=="damaged" and event.target_id==unit.id:new_damage+=1
		if event.entity_id==unit.id and event.kind in ["disabled","unit_impact","damage_phase"]:post_exit_loss+=1
	expect(queued_hits==1,domain+" witness actually queues a real physical hit before the late same-tick exit")
	expect(new_damage==0 and post_exit_loss==0 and unit.module_data.damage==exit.damage_at_exit,domain+" current departure state supersedes queued hit/surface-contact damage before module650")
	world.step_ticks(1200)
	expect(unit.module_data.damage==exit.damage_at_exit,domain+" old fire/flooding cannot burn through structure or change phase after departure")
	evidence[domain+"_queued"]={"real_hit_before_exit":queued_hits,"applied_damage_after_exit":new_damage,"loss_events_after_exit":post_exit_loss,"structure_at_exit":exit.damage_at_exit.structure,"structure_20s_later":unit.module_data.damage.structure}

func _inactive_bodies() -> void:
	for phase: String in ["disabled","sinking","wreck"]:
		var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(100,100,0)),FIX.spawn("body","jp",Vector3(0,100,-100),"jp_yukikaze_1942_06")])
		var unit: UnitState=a.world.get_unit("body")
		unit.active=false
		unit.module_data.damage.phase=phase
		var before: float=unit.module_data.damage.structure
		(a.launcher as FIX.Launcher).pending.append({"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,-20),"speed":12000.,"gravity":0.})
		a.world.step_ticks(2)
		var hits: int=0
		for event: BattleEvent in a.world.drain_events():
			if event.kind=="hit" and event.target_id==unit.id:hits+=1
		expect(CombatPresence.is_present(unit.module_data) and hits==1,"Inactive "+phase+" body still blocks the real projectile")
		if phase=="disabled":expect(float(unit.module_data.damage.structure)<before,"Inactive floating disabled ship can still take allowed structural damage")
		else:expect(unit.module_data.damage.structure==before,"Already lost "+phase+" body blocks without reopening completed damage phase")
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(100,100,0)),FIX.spawn("body","jp",Vector3(0,100,-100),"jp_yukikaze_1942_06")])
	var unit: UnitState=a.world.get_unit("body")
	unit.active=false
	unit.module_data.damage.phase="disabled"
	unit.module_data.damage.fire=.8
	unit.module_data.damage.flooding=.2
	var before: float=unit.module_data.damage.structure
	a.world.step_ticks(60)
	expect(float(unit.module_data.damage.structure)<before,"Non-departed inactive disabled ship still suffers its real fire/flooding")

func _occlusion(domain: String) -> void:
	var definition: String="jp_a6m5a_1944" if domain=="aircraft" else "jp_yukikaze_1942_06"
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(0,100,0)),FIX.spawn("blocker","jp",Vector3(0,100,-500),definition),FIX.spawn("hidden","jp",Vector3(0,100,-1000))])
	a.world.step_ticks(1)
	expect(CombatContacts.find(a.world,"us","hidden").is_empty(),domain+" body actually occludes the optical/radar sight line before exit")
	depart(a.world.get_unit("blocker"),domain)
	a.world.step_ticks(30)
	expect(not CombatContacts.find(a.world,"us","hidden").is_empty(),domain+" departed body does not occlude a newly visible real target")

func _airburst(domain: String) -> void:
	var definition: String="jp_a6m5a_1944" if domain=="aircraft" else "jp_yukikaze_1942_06"
	var spawn_data: Array=[FIX.spawn("shooter","us",Vector3(200,200,0)),FIX.spawn("blocker","jp",Vector3(5,100,0),definition),FIX.spawn("near","jp",Vector3(15,100,0))]
	for exited: bool in [false,true]:
		var a: Dictionary=FIX.arena(spawn_data)
		var blocker: UnitState=a.world.get_unit("blocker")
		blocker.active=false
		if exited:depart(blocker,domain)
		var ghost_structure: float=blocker.module_data.damage.structure
		(a.launcher as FIX.Launcher).pending.append({"ammo":"us_127mm_5in38_shell","position":Vector3(-5,100,0),"direction":Vector3.UP,"speed":10.,"gravity":0.,"fuze":.1})
		a.world.step_ticks(15)
		var bursts: Array[BattleEvent]=[]
		for event: BattleEvent in a.world.drain_events():
			if event.kind=="airburst":bursts.append(event)
		expect(bursts.size()==1 and absf(bursts[0].position_m.y-101)<.001,domain+" timed fuze keeps its physical path/time independent of target departure")
		var hurt: bool=float(a.world.get_unit("near").module_data.damage.structure)<90.
		expect(hurt==exited,domain+" airburst fragments pass through exited proxy but remain blocked by a non-departed inactive body")
		expect(blocker.module_data.damage.structure==ghost_structure,domain+" exited/inactive blocker is not treated as live aircraft burst target")

func _departed_shooter_rounds() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(100,100,0)),FIX.spawn("enemy","jp",Vector3(0,100,-100))])
	(a.launcher as FIX.Launcher).pending.append({"position":Vector3(0,100,-20),"speed":12000.,"gravity":0.})
	a.world.step_ticks(1)
	expect(a.projectiles.rounds.size()==1,"Witness has a real round in flight before its shooter exits")
	depart(a.world.get_unit("shooter"),"aircraft")
	(a.launcher as FIX.Launcher).pending.append({"position":Vector3(0,100,-20),"speed":12000.,"gravity":0.})
	a.world.step_ticks(1)
	var hits: int=0
	for event: BattleEvent in a.world.drain_events():
		if event.kind=="hit" and event.target_id=="enemy":hits+=1
	expect(hits==1 and a.projectiles.next_id==1,"Leaving shooter retains pre-exit projectile; attempts to launch after exit are refused")

func _real_exit(domain: String) -> void:
	var definition: String="jp_a6m5a_1944" if domain=="aircraft" else "jp_yukikaze_1942_06"
	var point: Vector3=Vector3(0,100,-100) if domain=="aircraft" else Vector3(0,0,-100)
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(100,100,0)),FIX.spawn("departed","jp",point,definition)],null,false)
	var world: SimulationWorld=a.world
	if domain=="aircraft":
		expect(AircraftSuite.install(world).is_empty(),"Real S04 suite installs with formal combat modules")
		var recipients: Array[String]=["departed"]
		AIR.order(world,"actual_retreat",recipients,"retreat","",point,200.)
	else:
		expect(FleetSuite.install(world,null,false).is_empty(),"Real S06 suite installs with formal combat modules")
		FLEET.order(world,"actual_retreat",["departed"],"retreat","",point,200.)
	var unit: UnitState=world.get_unit("departed")
	unit.module_data.damage.fire=.7
	var initial: Dictionary=unit.module_data.damage.duplicate(true)
	(a.launcher as FIX.Launcher).pending.append({"ammo":"us_127mm_5in38_shell","position":Vector3(0,100 if domain=="aircraft" else 1,-20),"speed":12000.,"gravity":0.})
	world.step_ticks(4)
	var exits: int=0
	var hits: int=0
	var damage_events: int=0
	for event: BattleEvent in world.drain_events():
		if event.kind==domain+"_exit" and event.entity_id==unit.id:
			exits+=1
			expect(not event.data.destroyed,"Real "+domain+" exit is not a destruction event")
		if event.target_id==unit.id and event.kind=="hit":hits+=1
		if event.target_id==unit.id and event.kind=="damaged":damage_events+=1
	expect(exits==1 and not unit.active and CombatPresence.has_exited(unit.module_data),"Real "+domain+" task reaches frozen exit interface without injected exited flag")
	expect(hits==0 and damage_events==0 and unit.module_data.damage==initial,"Real "+domain+" exit is immune to later rounds and ongoing fire")
	world.reset()
	expect(world.get_unit(unit.id).active and CombatPresence.is_present(world.get_unit(unit.id).module_data),"Real "+domain+" suite reset restores flags and damage")
	evidence[domain+"_formal_path"]={"exit_events":exits,"hits_after_exit":hits,"damage_after_exit":damage_events,"structure_before":initial.structure,"structure_after":unit.module_data.damage.structure}

func _effects(domain: String) -> void:
	var effects: CombatEffects=CombatEffects.new()
	effects.sound_enabled=false
	root.add_child(effects)
	effects.consume([],1)
	var view: Dictionary={"id":"u","active":true,"position_m":Vector3(0,100,0),"velocity_mps":Vector3.ZERO,"module_data":{"damage":{"phase":"operational","fire":.8}}}
	effects.apply_snapshot({"units":{"u":view}})
	effects.advance(.1)
	expect(effects.statistics().active>0,"Persistent smoke/fire exists before "+domain+" exit")
	var stale_view: Dictionary=view.duplicate(true)
	view.active=false
	view.module_data[domain+"_motion"]={"exited":true}
	effects.apply_snapshot({"units":{"u":view}})
	effects.advance(.1)
	expect(effects.statistics().active>0,"Existing smoke may naturally linger briefly after "+domain+" exit")
	effects.advance(4.)
	expect(effects.statistics().active==0,"Current "+domain+" exited snapshot cannot emit fresh ghost fire/smoke")
	var exit: BattleEvent=BattleEvent.new()
	exit.sequence=1
	exit.entity_id="u"
	exit.kind=domain+"_exit"
	effects.consume([exit],1)
	effects.apply_snapshot({"units":{"u":stale_view}})
	effects.advance(4.)
	expect(effects.statistics().active==0,"Consumed "+domain+" exit event fences out delayed pre-exit snapshots")
	effects.consume([],2)
	effects.apply_snapshot({"units":{"u":stale_view}})
	effects.advance(1.)
	expect(effects.statistics().active>0,"Generation reset clears "+domain+" departure emitter fence")
	effects.free()
