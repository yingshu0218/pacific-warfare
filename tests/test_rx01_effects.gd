extends "res://tests/fixtures/combat_test.gd"

func run_test() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3.ZERO,"us_iowa_bb61_1944_12_28")])
	(a.launcher as FIX.Launcher).pending=[{"ammo":"us_406mm_mk8_ap","position":Vector3(0,500,0),"direction":Vector3.BACK}]
	a.world.step_ticks(1)
	var events: Array[BattleEvent]=a.world.drain_events()
	var source: BattleEvent
	for event: BattleEvent in events:
		if event.kind=="fired":source=event
	expect(source!=null and source.data.mount_role=="main" and source.data.source_domain=="ship" and float(source.data.lifetime_s)>0,"Actual fired event publishes source role and the real lifetime")
	if source==null:finish("RX01 effects");return
	# Change only the observer's tracer flag to cover non-tracer AP presentation.
	var observed: BattleEvent=source.copy()
	observed.data.tracer=false
	var effects: CombatEffects=CombatEffects.new()
	effects.sound_enabled=false;effects.effect_capacity=384
	root.add_child(effects)
	var camera: Camera3D=Camera3D.new()
	root.add_child(camera);camera.current=true;camera.fov=48
	camera.position=Vector3(400,600,1600);camera.look_at(Vector3(0,500,762))
	effects.consume([observed],a.world.generation)
	effects.advance(1.)
	a.world.step_ticks(60)
	var round: CombatProjectiles.Round=a.projectiles.rounds.values()[0]
	var flight: Dictionary={}
	for slot: Dictionary in effects.slots:
		if slot.active and slot.projectile_id==source.data.projectile_id:flight=slot
	expect(not flight.is_empty() and flight.kind=="shell","A non-tracer main round always receives one shell observer mark")
	if not flight.is_empty():
		var mesh: MeshInstance3D=flight.mesh
		expect(mesh.position.distance_to(round.position_m)<.02,"Bright head follows the actual simulated projectile at the same ballistic age")
		var previous_age: float=round.age_s-.035
		var previous: Vector3=source.position_m+(source.data.velocity_mps as Vector3)*previous_age+Vector3.DOWN*float(source.data.gravity_mps2)*.5*previous_age*previous_age
		expect(mesh.to_global(Vector3.BACK).distance_to(previous)<.02,"Short tail ends on the round's own recent path, never a target or hit line")
		var depth: float=-(camera.global_transform.affine_inverse()*mesh.global_position).z
		var mpp: float=2.*depth*tan(deg_to_rad(camera.fov)*.5)/root.get_visible_rect().size.y
		expect(mesh.scale.x/mpp>=2.19 and mesh.scale.x<=6.0 and round.caliber_m==float(source.data.caliber_m),"Finite pixel compensation improves observation while collision caliber stays physical")
		var before: Dictionary=a.world.snapshot()
		var point: Vector3=mesh.position
		var shown: int=effects.shown_events
		effects.consume([observed],a.world.generation)
		effects.advance(0.)
		expect(mesh.position==point and effects.shown_events==shown and before==a.world.snapshot(),"Pause and event replay neither move the round nor change simulation or duplicate its mark")
	a.world.step_ticks(900)
	var terminal: Array[BattleEvent]=a.world.drain_events()
	effects.consume(terminal,a.world.generation)
	expect(not effects.slots.any(func(s: Dictionary)->bool:return s.active and s.projectile_id==source.data.projectile_id),"Actual first sea contact removes the shell flight mark")
	expect(effects.slots.any(func(s: Dictionary)->bool:return s.active and s.kind=="water") and effects.slots.any(func(s: Dictionary)->bool:return s.active and s.kind=="foam"),"Existing water column and foam remain tied to the actual terminal contact")
	# Render-only stress: repeated copies of a real terminal event are given unique
	# sequences/ids, solely to exercise the 384 resource ceiling and its counters.
	effects.clear(a.world.generation+1)
	var stress: Array[BattleEvent]=[]
	for index: int in 200:
		var event: BattleEvent=BattleEvent.new()
		event.kind="airburst";event.sequence=index+1;event.time_s=0.;event.position_m=Vector3(0,500,-500)
		event.data={"projectile_id":"stress_%d"%index,"caliber_m":.127,"reason":"time_fuze"}
		stress.append(event)
	effects.consume(stress,a.world.generation+1)
	var stats: Dictionary=effects.statistics()
	expect(stats.allocated==384 and stats.render_instances==384 and stats.materials==384 and stats.active<=384,"384 budget bounds real meshes and unique materials under heavy flak pressure")
	expect(stats.rejected_by_kind.get("burst",0)>0 and stats.requested_by_kind.get("burst",0)==600 and stats.active_by_kind.get("burst",0)>0,"Per-kind counters distinguish actual retained black flak from rejected pool requests")
	var file: FileAccess=FileAccess.open("res://.local/repairs/20261112_morning/rx01/checks/effects.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"stress_scope":"render budget only, not a simulated battle","statistics":stats},"\t"));file.close()
	effects.free();camera.free()
	finish("RX01 effects")
