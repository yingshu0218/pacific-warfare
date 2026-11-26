extends "res://tests/fixtures/combat_test.gd"

class SurfaceProducer extends SimulationModule:
	var pending: bool=true
	var surface: String="sea"
	var velocity: Vector3=Vector3(70,-3,0)
	func _init() -> void:
		module_id="test_surface_producer"
		priority=400
	func fixed_update(world_ref: RefCounted,_delta_s: float) -> void:
		if not pending:return
		var world: SimulationWorld=world_ref as SimulationWorld
		world.emit_event("unit_surface_contact","shooter","",Vector3(3,0,-7),{"surface":surface,"velocity_mps":velocity,"reason":"forced_ditch"})
		pending=false

func run_test() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(3,1,-7))])
	var p: SurfaceProducer=SurfaceProducer.new()
	a.world.register_module(p)
	a.world.step_ticks(1)
	var damage: Dictionary=a.world.get_unit("shooter").module_data.damage
	expect(not a.world.get_unit("shooter").active and damage.phase=="wreck" and damage.structure==0.,"S04-style real high-speed touch uniformly ends flight and creates wreck")
	var events: Array[BattleEvent]=FIX.events(a.world,"unit_impact")
	expect(events.size()==1 and events[0].position_m==Vector3(3,0,-7) and events[0].data.surface=="sea" and events[0].data.destroyed,"Normalized single sea impact preserves producer's real position and velocity classification")
	p.pending=true
	a.world.step_ticks(1)
	expect(FIX.events(a.world,"unit_impact").is_empty(),"Repeated contact on existing wreck cannot generate second impact")
	a=FIX.arena([FIX.spawn("shooter","us",Vector3(3,1,-7))])
	p=SurfaceProducer.new()
	p.velocity=Vector3(10,-1,0)
	a.world.register_module(p)
	a.world.step_ticks(1)
	events=FIX.events(a.world,"unit_impact")
	expect(events.size()==1 and not events[0].data.destroyed and a.world.get_unit("shooter").module_data.damage.structure>0.,"Soft forced ditch exits air combat but is distinguished from structural destruction")
	var c: CombatConfig=FIX.config()
	c.data.environment.solids=[{"id":"island","surface":"ground","center_m":[0,0,0],"half_extents_m":[30,3,30]}]
	a=FIX.arena([FIX.spawn("shooter","us",Vector3(200,100,0)),FIX.spawn("enemy","jp",Vector3(0,100,0))],c)
	(a.launcher as FIX.Launcher).pending=[{"ammo":"us_406mm_mk8_ap","position":Vector3(0,100,-20),"direction":Vector3.BACK,"gravity":0.}]
	a.world.step_ticks(500)
	events=FIX.events(a.world,"unit_impact")
	expect(events.size()==1 and events[0].data.surface=="ground" and absf(events[0].position_m.y-3.)<.001,"S05 free-fall crash sweeps into actual island top before sea, producing one real ground impact")
	finish("unit surface contact")
