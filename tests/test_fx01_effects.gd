extends "res://tests/fixtures/combat_test.gd"

var audit: Dictionary = {"scope":"Controlled real projectile tests and explicit read-model/stress fixtures; not natural battle"}

func make_effects(capacity: int = 144) -> CombatEffects:
	var effects: CombatEffects = CombatEffects.new()
	effects.effect_capacity=capacity
	effects.sound_enabled=false
	effects.sound_capacity=0
	root.add_child(effects)
	effects.clear(1)
	return effects

func run_test() -> void:
	_water_and_pool()
	_burst_scales()
	_batch_and_tracer_end()
	_air_tracer_presentation()
	_emitters_and_impact()
	_trail_and_engine_audio()
	_current_pose_attachment()
	_runtime_fixture()
	var file: FileAccess=FileAccess.open("res://docs/showcase/evidence/FX01/effects_checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(audit,"\t"))
	file.close()
	finish("FX01 event visuals")

func _water_and_pool() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(500,100,0))])
	(a.launcher as FIX.Launcher).pending=[{"ammo":"us_406mm_mk8_ap","position":Vector3(0,100,0),"direction":Vector3.DOWN}]
	var effects: CombatEffects=make_effects(24)
	var replay: Array[BattleEvent]=[]
	for tick_index: int in 30:
		a.world.step_ticks(1)
		var events: Array[BattleEvent]=a.world.drain_events()
		replay.append_array(events)
		effects.advance(1./60.)
		effects.consume(events,1)
	var water: Dictionary={}
	var foam: Dictionary={}
	for slot: Dictionary in effects.slots:
		if slot.active and slot.kind=="water" and slot.jet==0:water=slot
		if slot.active and slot.kind=="foam":foam=slot
	expect(not water.is_empty() and not foam.is_empty(),"Real sea intersection spawns profiled water and independent expanding foam")
	if water.is_empty() or foam.is_empty():return
	var impact: BattleEvent
	for event: BattleEvent in replay:
		if event.kind=="surface_impact":impact=event
	expect(impact!=null and impact.data.surface=="sea" and water.position==impact.position_m,"Water base uses the actual sea intersection")
	var first_height: float=(water.mesh as MeshInstance3D).scale.y
	var first_width: float=(foam.mesh as MeshInstance3D).scale.x
	effects.advance(.7)
	var peak_height: float=(water.mesh as MeshInstance3D).scale.y
	expect(peak_height>first_height and is_zero_approx((water.mesh as MeshInstance3D).position.y),"Column rises while base stays exactly at y=0")
	var before_pause: Transform3D=(water.mesh as MeshInstance3D).transform
	var opacity: float=water.opacity
	effects.advance(0)
	expect((water.mesh as MeshInstance3D).transform==before_pause and water.opacity==opacity,"Pause freezes water geometry and opacity")
	effects.advance(1.3)
	expect((water.mesh as MeshInstance3D).scale.y<peak_height and water.opacity<1.,"Water falls and fades rather than disappearing at peak")
	expect((foam.mesh as MeshInstance3D).scale.x>first_width and is_equal_approx((foam.mesh as MeshInstance3D).position.y,.08),"Foam expands along the sea surface")
	expect(water.material!=foam.material,"Simultaneous effects have isolated fade materials")
	var foam_fade: Variant=(foam.material as ShaderMaterial).get_shader_parameter("fade")
	(water.material as ShaderMaterial).set_shader_parameter("fade",.123)
	expect((foam.material as ShaderMaterial).get_shader_parameter("fade")==foam_fade,"Changing one fade cannot contaminate another instance")
	var shown: int=effects.shown_events
	effects.consume(replay,1)
	expect(effects.shown_events==shown,"Real projectile event batch is generation/sequence deduplicated")
	for index: int in 120:
		(a.launcher as FIX.Launcher).pending.append({"ammo":"us_406mm_mk8_ap","position":Vector3(index*2,100,0),"direction":Vector3.DOWN})
	a.world.step_ticks(30)
	effects.consume(a.world.drain_events(),1)
	var actual_meshes: int=0
	for child: Node in effects.get_children():
		if child is MeshInstance3D:actual_meshes+=1
	expect(actual_meshes<=24 and actual_meshes==effects.statistics().render_instances and effects.statistics().visible_instances<=24,"Overflow limits actual render nodes as well as logical slots")
	expect(effects.dropped_visuals>0,"Real impact stress explicitly records dropped visual components")
	var resource_ids: Array[int]=[]
	for slot: Dictionary in effects.slots:resource_ids.append((slot.material as ShaderMaterial).get_instance_id())
	effects.clear(2)
	var repeated: Array[BattleEvent]=[]
	for event: BattleEvent in replay:repeated.append(event.copy())
	effects.consume(repeated,2)
	var after_ids: Array[int]=[]
	for slot: Dictionary in effects.slots:after_ids.append((slot.material as ShaderMaterial).get_instance_id())
	expect(resource_ids==after_ids,"Reset reuses allocated materials without per-frame/per-generation allocation")
	audit.pool=effects.statistics()
	effects.effects_enabled=false
	effects.advance(.1)
	expect(effects.statistics().active==0 and effects.statistics().visible_instances==0,"Effects toggle hides every actual slot")
	effects.free()

func _runtime_fixture() -> void:
	var runtime: Script=preload("res://tests/fixtures/fx01_runtime_fixture.gd")
	var spawns: Array=[FIX.spawn("shooter","us",Vector3(500,100,0))]
	var original: Dictionary=FIX.arena(spawns)
	var release_safe: Dictionary=runtime.arena(spawns)
	var one: Array=[]
	var two: Array=[]
	for a: Dictionary in [original,release_safe]:
		(a.launcher as FIX.Launcher).pending=[{"ammo":"us_406mm_mk8_ap","position":Vector3(0,100,0),"direction":Vector3.DOWN}]
	for index: int in 60:
		original.world.step_ticks(1);release_safe.world.step_ticks(1)
		for event: BattleEvent in original.world.drain_events():one.append(event.snapshot())
		for event: BattleEvent in release_safe.world.drain_events():two.append(event.snapshot())
	expect(one.size()>1 and one==two and original.world.snapshot()==release_safe.world.snapshot(),"Release-safe setup executes the same real modules, projectile events and state as the debug fixture")
	audit.release_safe_fixture={"identical_events":one==two,"identical_state":original.world.snapshot()==release_safe.world.snapshot(),"events":one.size()}

func _trail_and_engine_audio() -> void:
	# Explicit copied-state contract fixture, independent of DM01's evolving flight.
	var arena: Dictionary=FIX.arena([FIX.spawn("plane","us",Vector3(0,120,0),"us_f6f5_1944",Vector3(150,0,0))])
	var unit: Dictionary=arena.world.get_unit("plane").snapshot()
	unit.module_data.damage.effect_emitters=[{"id":"engine","part_id":"engine","kind":"smoke","anchor_m":Vector3(0,.8,-2.8),"intensity":.9,"size_m":3.}]
	var effects: CombatEffects=make_effects()
	for frame: int in 24:
		unit.position_m.x=150.*float(frame)*.1
		effects.apply_snapshot({"units":{"plane":unit}})
		effects.advance(.1)
	var points: Array[Vector3]=[]
	for slot: Dictionary in effects.slots:
		if slot.active and slot.kind=="smoke":points.append(slot.position)
	points.sort_custom(func(a: Vector3,b: Vector3) -> bool:return a.x<b.x)
	var gap: float=0
	for index: int in points.size()-1:gap=maxf(gap,points[index].distance_to(points[index+1]))
	expect(points.size()>40 and gap<3.3,"150 m/s copied real-position stream interpolates bounded smoke spacing, avoiding 45 m beads")
	expect(effects.statistics().render_instances<=144,"Dense moving smoke retains the actual shared instance cap")
	audit.trail={"speed_mps":150,"active_smoke":points.size(),"maximum_source_gap_m":gap,"max_subsamples_per_emitter":16}
	effects.sound_enabled=true
	effects.apply_snapshot({"units":{"plane":unit}})
	expect(effects.engine_sources.size()==1 and effects.engine_sources[0].playing,"Healthy active plane retains its existing engine loop")
	unit.module_data.damage.propulsion_factor=0.
	effects.apply_snapshot({"units":{"plane":unit}})
	expect(not effects.engine_sources[0].playing,"Fully failed engine stops its loop while aircraft remains active and gliding")
	effects.free()
	var ground: CombatEffects=make_effects()
	unit.definition_id="us_40mm_m1_m2a1_1944"
	unit.module_data.damage.propulsion_factor=1.
	ground.sound_enabled=true
	ground.apply_snapshot({"units":{"ground":unit}})
	expect(ground.engine_sources.is_empty(),"Fixed ground unit never allocates or plays an engine loop")
	ground.free()

func _current_pose_attachment() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("plane","us",Vector3(0,370,0))])
	var view: Dictionary=a.world.get_unit("plane").snapshot()
	view.module_data.damage.effect_emitters=[{"id":"engine_fire","part_id":"engine","kind":"fire","anchor_m":Vector3(0,.65,-2.8),"intensity":.6,"size_m":1.3},{"id":"engine_smoke","part_id":"engine","kind":"smoke","anchor_m":Vector3(0,.8,-2.8),"intensity":.9,"size_m":2.4}]
	var effects: CombatEffects=make_effects()
	var maximum_fire_error: float=0.
	var maximum_smoke_error: float=0.
	var checked: int=0
	for frame: int in 46:
		# Exact DM01/production order at 15fps and 96.2m/s, including turns.
		effects.advance(4./60.)
		effects.consume([],1)
		view.position_m+=Vector3(0,0,-96.2*4./60.)
		view.rotation_rad=Vector3(.02*frame,.003*frame,0)
		effects.apply_snapshot({"units":{"plane":view}})
		var pose: Transform3D=Transform3D(Basis.from_euler(view.rotation_rad),view.position_m)
		for slot: Dictionary in effects.slots:
			if slot.active and slot.owner_id=="plane":
				maximum_fire_error=maxf(maximum_fire_error,(slot.mesh as MeshInstance3D).position.distance_to(pose*Vector3(0,.65,-2.8)))
				checked+=1
		var history: Dictionary=effects.emitter_history.get("plane/engine_smoke",{})
		if not history.is_empty():maximum_smoke_error=maxf(maximum_smoke_error,(history.point as Vector3).distance_to(pose*Vector3(0,.8,-2.8)))
	expect(checked>45 and maximum_fire_error<.0001,"Existing attached engine flames stay on current part pose at 15fps; never drift onto tail")
	expect(maximum_smoke_error<.0001,"New smoke samples use current snapshot, not one-frame-old 6.4m-behind pose")
	audit.current_pose={"presentation_ticks":4,"speed_mps":96.2,"frames":46,"attached_fire_samples":checked,"maximum_fire_anchor_error_m":maximum_fire_error,"maximum_smoke_source_error_m":maximum_smoke_error}
	effects.free()

func _burst_scales() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(500,100,0))])
	(a.launcher as FIX.Launcher).pending=[{"ammo":"us_127mm_5in38_shell","position":Vector3(-198,700,0),"direction":Vector3.RIGHT,"fuze":.25},{"ammo":"s10_us_40mm_mkii_het_sd","position":Vector3(-7435.596,700,30),"direction":Vector3.RIGHT}]
	var bursts: Array[BattleEvent]=[]
	for index: int in 520:
		a.world.step_ticks(1)
		for event: BattleEvent in a.world.drain_events():
			if event.kind=="airburst":bursts.append(event)
	expect(bursts.size()==2,"Controlled real rounds produce both time fuze and fixed self-destruct")
	if bursts.size()!=2:return
	var heavy: CombatEffects=make_effects()
	var light: CombatEffects=make_effects()
	heavy.consume([bursts[0]],1)
	light.consume([bursts[1]],1)
	var heavy_size: float=0
	var light_size: float=0
	var heavy_life: float=0
	var light_life: float=0
	for slot: Dictionary in heavy.slots:
		if slot.kind=="burst":heavy_size=maxf(heavy_size,slot.size);heavy_life=maxf(heavy_life,slot.life)
	for slot: Dictionary in light.slots:
		if slot.kind=="self_destruct":light_size=maxf(light_size,slot.size);light_life=maxf(light_life,slot.life)
	expect(bursts[1].data.reason=="tracer_self_destruct" and absf(float(bursts[1].data.age_s)-8.5)<.02,"M1 real event retains fixed 8.5 second self-destruct, not an intercept fuze")
	expect(heavy_size>light_size*4 and heavy_life>light_life*3,"M1 self-destruct is visibly smaller and shorter than heavy flak")
	heavy.advance(.2)
	var cloud: Dictionary={}
	for slot: Dictionary in heavy.slots:
		if slot.kind=="burst":cloud=slot;break
	var early_scale: float=(cloud.mesh as MeshInstance3D).scale.x
	var early_position: Vector3=(cloud.mesh as MeshInstance3D).position
	heavy.advance(4.8)
	expect((cloud.mesh as MeshInstance3D).scale.x>early_scale and (cloud.mesh as MeshInstance3D).position.x>early_position.x and cloud.opacity<1.,"Heavy black cloud expands, drifts and smoothly fades over several seconds")
	audit.airburst={"heavy_size_m":heavy_size,"self_destruct_size_m":light_size,"heavy_life_s":heavy_life,"self_destruct_life_s":light_life,"self_destruct_age_s":bursts[1].data.age_s}
	heavy.free();light.free()

func _batch_and_tracer_end() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(500,100,0))])
	(a.launcher as FIX.Launcher).pending=[{"ammo":"us_406mm_mk8_ap","position":Vector3(0,1000,0),"direction":Vector3.RIGHT}]
	a.world.step_ticks(1)
	var fired: BattleEvent
	for event: BattleEvent in a.world.drain_events():
		if event.kind=="fired":fired=event
	var one: CombatEffects=make_effects()
	var batched: CombatEffects=make_effects()
	one.consume([fired],1)
	for index: int in 60:one.advance(1./60.)
	batched.advance(fired.time_s+1.)
	batched.consume([fired],1)
	var p1: Vector3
	var p2: Vector3
	var tail: float=0
	for slot: Dictionary in one.slots:
		if slot.active and slot.kind=="shell":p1=(slot.mesh as MeshInstance3D).position;tail=(slot.mesh as MeshInstance3D).scale.z
	for slot: Dictionary in batched.slots:
		if slot.active and slot.kind=="shell":p2=(slot.mesh as MeshInstance3D).position
	var actual: Vector3=fired.position_m+(fired.data.velocity_mps as Vector3)+Vector3.DOWN*float(fired.data.gravity_mps2)*.5
	expect(p1.distance_to(actual)<.001 and p2.distance_to(actual)<.001,"Delayed fired batch and 60 regular advances use the same real ballistic age")
	var recent: Vector3 = fired.position_m+(fired.data.velocity_mps as Vector3)*.965+Vector3.DOWN*float(fired.data.gravity_mps2)*.5*.965*.965
	expect(absf(tail-actual.distance_to(recent))<.001,"Heavy-shell mark draws only its most recent 35 ms of flight")
	one.free();batched.free()
	var hit_arena: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(500,100,0)),FIX.spawn("enemy","jp",Vector3(0,100,-100))])
	(hit_arena.launcher as FIX.Launcher).pending=[{"ammo":"us_127mm_5in38_shell","position":Vector3(0,100,0)}]
	hit_arena.world.step_ticks(20)
	var hit_events: Array[BattleEvent]=hit_arena.world.drain_events()
	var effects: CombatEffects=make_effects()
	effects.consume(hit_events,1)
	var has_hit: bool=false
	for event: BattleEvent in hit_events:
		if event.kind=="hit":has_hit=true
	var tracers: int=0
	for slot: Dictionary in effects.slots:
		if slot.active and slot.kind=="tracer":tracers+=1
	expect(has_hit and tracers==0,"Real hit in same consumed batch ends the tracer immediately")
	effects.free()

func _air_tracer_presentation() -> void:
	var a: Dictionary = FIX.arena([FIX.spawn("shooter","us",Vector3(500,100,0))])
	for i: int in 12:
		(a.launcher as FIX.Launcher).pending.append({"ammo":"us_127mm_m2_ball","position":Vector3(i,100,0),"direction":Vector3.FORWARD})
	a.world.step_ticks(1)
	var events: Array[BattleEvent] = a.world.drain_events()
	var marked: Array[BattleEvent] = []
	for event: BattleEvent in events:
		if event.kind == "fired" and bool(event.data.tracer): marked.append(event)
	var effects: CombatEffects = make_effects()
	effects.consume(events,1)
	effects.advance(.1)
	var displayed: int = 0
	var follows_ballistics: bool = true
	for slot: Dictionary in effects.slots:
		if not slot.active or slot.kind != "tracer": continue
		displayed += 1
		var mesh: MeshInstance3D = slot.mesh
		var age: float = float(slot.age)
		var back_age: float = age - CombatEffects.AIR_TRACER_TAIL_S
		var velocity: Vector3 = slot.velocity
		var gravity: Vector3 = Vector3.DOWN * float(slot.gravity)
		var head: Vector3 = slot.position + velocity*age + gravity*.5*age*age
		var tail: Vector3 = slot.position + velocity*back_age + gravity*.5*back_age*back_age
		follows_ballistics = follows_ballistics and bool(slot.air_tracer) and bool((slot.material as ShaderMaterial).get_shader_parameter("air_tracer"))
		follows_ballistics = follows_ballistics and mesh.position.distance_to(head)<.001 and (mesh.transform * Vector3.BACK).distance_to(tail)<.001
	expect(marked.size() > 1 and displayed == marked.size(), "Aircraft effects retain all simulation-flagged tracers and never promote ordinary rounds")
	expect(displayed > 0 and follows_ballistics, "Brightened tracer head and short trailing span still track the real projectile")
	effects.clear(2)
	var ship_round: BattleEvent = marked.front().copy()
	ship_round.data["source_domain"] = "ship"
	effects.consume([ship_round],2)
	var reused_baseline: bool = false
	for slot: Dictionary in effects.slots:
		if slot.active and slot.kind == "tracer":
			reused_baseline = not bool(slot.air_tracer) and not bool((slot.material as ShaderMaterial).get_shader_parameter("air_tracer"))
	expect(reused_baseline, "Pooled material resets the aircraft tracer signature for other users")
	effects.free()

func _emitters_and_impact() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(500,100,0)),FIX.spawn("enemy","jp",Vector3(0,12,0))])
	(a.launcher as FIX.Launcher).pending=[{"ammo":"us_406mm_mk8_ap","position":Vector3(0,12,20)}]
	var impacts: Array[BattleEvent]=[]
	for index: int in 240:
		a.world.step_ticks(1)
		for event: BattleEvent in a.world.drain_events():
			if event.kind=="unit_impact":impacts.append(event)
	expect(impacts.size()==1 and impacts[0].data.surface=="sea","Actual lethal hit -> crashing -> real sea contact produces one normalized unit_impact")
	var effects: CombatEffects=make_effects(20)
	var unit: Dictionary=a.world.get_unit("enemy").snapshot()
	unit.module_data.damage.effect_emitters=[{"id":"engine","part_id":"engine","kind":"smoke","anchor_m":[0,.5,-2.5],"intensity":.8,"size_m":3.}]
	unit.position_m=Vector3(20,50,10)
	unit.rotation_rad=Vector3(0,PI*.5,0)
	var pristine: Dictionary=unit.duplicate(true)
	effects.apply_snapshot({"units":{"enemy":unit}})
	effects.advance(.1)
	var emitter: Dictionary={}
	for slot: Dictionary in effects.slots:
		if slot.get("emitter_id","")=="engine":emitter=slot
	expect(not emitter.is_empty() and (emitter.position as Vector3).distance_to(Vector3(17.5,50.5,10))<.001,"Explicit DM engine emitter follows the real part-local anchor and unit pose")
	expect(unit==pristine,"Reading DM emitter cannot alter its supplied damage snapshot")
	if not impacts.is_empty():effects.consume(impacts,1)
	effects.advance(8.)
	expect(effects.statistics().active==0,"Real sea impact stops new air smoke even if an old pre-impact snapshot is repeated")
	effects.clear(2)
	effects.apply_snapshot({"units":{"enemy":pristine}})
	effects.advance(.1)
	expect(effects.statistics().active>0,"Generation clear restores clean persistent emission after sea impact")
	effects.free()
