extends Node3D

## Explicit controlled witness: real original ammunition, fixed launch probes.
## No forced hit, prewritten effect events, injected health or natural-battle claim.
const FIX: Script=preload("res://tests/fixtures/combat_fixture.gd")
const RUNTIME: Script=preload("res://tests/fixtures/fx01_runtime_fixture.gd")
const LEGACY: Script=preload("res://tests/fixtures/fx01_legacy_effects.gd")
var arena: Dictionary
var effects: Variant
var case_name: String=""
var age_s: float=0.
var event_log: Array[Dictionary]=[]
var models: Dictionary={}
var baseline: bool=false
var frame: int=0
var pending_events: Array[BattleEvent]=[]
var last_presented_s: float=0.

func configure(old_visuals: bool) -> void:
	baseline=old_visuals
	effects=LEGACY.new() if baseline else CombatEffects.new()
	effects.sound_enabled=false
	effects.sound_capacity=0
	effects.effect_capacity=144
	add_child(effects)

func start(value: String) -> void:
	case_name=value
	age_s=0.
	frame=0
	event_log.clear()
	pending_events.clear()
	last_presented_s=0.
	for model: Node3D in models.values(): model.free()
	models.clear()
	var spawns: Array=[FIX.spawn("shooter","us",Vector3(500,700,500))]
	if value=="tracer":
		spawns=[FIX.spawn("shooter","us",Vector3(0,70,80)),FIX.spawn("target","jp",Vector3(0,70,-120),"jp_a6m5a_1944")]
	if value=="smoke":
		spawns=[FIX.spawn("shooter","jp",Vector3(500,700,500)),FIX.spawn("plane","us",Vector3(0,120,0),"us_f6f5_1944",Vector3(150,0,0))]
	arena=RUNTIME.arena(spawns)
	effects.clear(arena.world.generation)
	if value=="water":
		(arena.launcher as FIX.Launcher).pending=[{"ammo":"us_406mm_mk8_ap","position":Vector3(-18,100,0),"direction":Vector3.DOWN},{"ammo":"us_127mm_5in38_shell","position":Vector3(16,90,0),"direction":Vector3.DOWN}]
	elif value=="flak":
		(arena.launcher as FIX.Launcher).pending=[{"ammo":"s10_us_40mm_mkii_het_sd","position":Vector3(25.-7435.596,534.265,0),"direction":Vector3.RIGHT}]
		# Real fixed self-destruct is pre-rolled; do not replace its 8.5s with a target fuze.
		for index: int in 498:_step()
		_present()
		age_s=0.
		frame=0
	if value in ["tracer","smoke"]:
		for id: String in arena.world.unit_ids():
			if value=="smoke" and id=="shooter":continue
			var unit: UnitState=arena.world.get_unit(id)
			var model: Node3D=(load(arena.world.unit_definition(unit.definition_id).model_scene) as PackedScene).instantiate() as Node3D
			add_child(model)
			model.call("apply_state",unit.snapshot())
			models[id]=model

func step_ticks(count: int) -> void:
	for index: int in count:
		if case_name=="smoke" and frame in [0,6,12,18,24,30,36,42]:
			(arena.launcher as FIX.Launcher).pending.append({"ammo":"jp_20mm_type99_2_shell","position":Vector3(150.*(float(frame)+2.85)/60.,120,-30),"direction":Vector3.BACK})
		if case_name=="flak" and frame in [0,18,40]:
			(arena.launcher as FIX.Launcher).pending.append({"ammo":"us_127mm_5in38_shell","position":Vector3(-198.+float(frame)*.65,180.+float(frame)*.3,0),"direction":Vector3.RIGHT,"fuze":.25})
		if case_name=="tracer" and frame<150 and frame%6==0:
			var unit: UnitState=arena.world.get_unit("shooter")
			var definition: UnitDefinition=arena.world.unit_definition(unit.definition_id)
			# Use all six actual F6F sockets, preserving their real mounting and gravity.
			for mount: MountSocket in definition.mounts:
				var muzzle: Transform3D=unit.world_transform()*mount.local_muzzle_transform(0,0,0)
				(arena.launcher as FIX.Launcher).pending.append({"ammo":"us_127mm_m2_ball","position":muzzle.origin,"direction":-muzzle.basis.z})
		_step()
		age_s+=1./60.
		frame+=1
	_present()
	for id: String in models:
		(models[id] as Node3D).call("apply_state",arena.world.get_unit(id).snapshot())

func _step() -> void:
	arena.world.step_ticks(1)
	var events: Array[BattleEvent]=arena.world.drain_events()
	pending_events.append_array(events)
	for event: BattleEvent in events:event_log.append(event.snapshot())

func _present() -> void:
	var now: float=arena.world.time_s()
	effects.advance(now-last_presented_s)
	effects.consume(pending_events,arena.world.generation)
	last_presented_s=now
	pending_events.clear()
	if case_name=="smoke":
		var view: Dictionary=arena.world.get_unit("plane").snapshot()
		var severity: float=float(view.module_data.damage.fire)
		# Read-model adapter only: intensity comes from actual cumulative engine hits.
		view.module_data.damage["effect_emitters"]=[{"id":"engine","part_id":"engine","kind":"smoke","anchor_m":Vector3(0,.8,-2.8),"intensity":1.-float(view.module_data.damage.propulsion_factor),"size_m":3.},{"id":"engine_fire","part_id":"engine","kind":"fire","anchor_m":Vector3(0,.65,-2.8),"intensity":severity,"size_m":1.3}] if severity>0 else []
		effects.apply_snapshot({"units":{"plane":view}})

func camera_pose(camera: Camera3D, far_view: bool=false) -> void:
	if case_name=="water":
		camera.position=Vector3(240,75,280) if far_view else Vector3(68,32,95)
		camera.look_at(Vector3(0,12,0))
	elif case_name=="flak":
		camera.position=Vector3(220,130,250) if far_view else Vector3(45,165,65)
		camera.look_at(Vector3(18,184,0))
	elif case_name=="tracer":
		camera.position=Vector3(95,112,20) if far_view else Vector3(18,78,-25)
		camera.look_at(Vector3(0,70,-45))
	else:
		var point: Vector3=arena.world.get_unit("plane").position_m
		camera.position=point+Vector3(90,35,180)
		camera.look_at(point+Vector3(-100,0,0))
	camera.near=.1
	camera.far=70000.

func snapshot() -> Dictionary:
	var counts: Dictionary={}
	for event: Dictionary in event_log:counts[event.kind]=int(counts.get(event.kind,0))+1
	return {"case":case_name,"age_s":age_s,"world_tick":arena.world.tick,"event_counts":counts,"effects":effects.statistics(),"world_state":arena.world.snapshot()}
