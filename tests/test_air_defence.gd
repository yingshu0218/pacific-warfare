extends "res://tests/fixtures/combat_test.gd"

func run_test() -> void:
	var c: CombatConfig=FIX.config()
	# Non-destructible airborne witnesses isolate AA cadence/assignment from damage.
	c.data.unit_profiles.us_f6f5_1944.structure=1000000.
	c.data.unit_profiles.us_f6f5_1944.part_durability=1000000.
	c.data.unit_profiles.us_f6f5_1944.aircraft_damage.wing_durability=1000000.
	c.data.unit_profiles.us_f6f5_1944.aircraft_damage.tail_durability=1000000.
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3.ZERO,"us_iowa_bb61_1944_12_28"),FIX.spawn("enemy_a","jp",Vector3(900,300,-300)),FIX.spawn("enemy_b","jp",Vector3(-900,300,300))],c)
	var world: SimulationWorld=a.world
	var shooter: UnitState=world.get_unit("shooter")
	var before: Dictionary={}
	for weapon: WeaponState in shooter.weapons.values():
		before[weapon.id]=weapon.remaining_rounds.duplicate()
	shooter.module_data.combat_intent={"fire":false,"allow_aa":true}
	world.step_ticks(480)
	var runtime: Dictionary=shooter.module_data.combat_runtime
	var selected: Dictionary={}
	for mount_id: String in runtime.mount_targets:
		var id: String=runtime.mount_targets[mount_id]
		if not id.is_empty():selected[id]=true
	expect(selected.has("enemy_a") and selected.has("enemy_b"),"AA assigns fire to both threatening contacts rather than concentrating all mounts")
	var old: Dictionary=runtime.mount_targets.duplicate()
	world.step_ticks(30)
	expect(runtime.mount_targets==old,"Target cooldown prevents rapid equal-threat oscillation")
	world.step_ticks(240)
	var shots: Dictionary={}
	var bursts: int=0
	var light_shots: int=0
	var main_shots: int=0
	var fired_targets: Dictionary={}
	var simultaneous: bool=false
	var fired_ticks: Dictionary={}
	for event: BattleEvent in world.drain_events():
		if event.kind=="fired" and event.entity_id=="shooter":
			shots[event.weapon_id]=int(shots.get(event.weapon_id,0))+1
			fired_targets[event.target_id]=true
			fired_ticks[event.target_id]=event.tick
			if fired_ticks.has("enemy_a") and fired_ticks.has("enemy_b"):
				simultaneous=simultaneous or absi(int(fired_ticks.enemy_a)-int(fired_ticks.enemy_b))<=60
			if float(event.data.caliber_m)<.05:light_shots+=1
			if float(event.data.caliber_m)>.3:main_shots+=1
		if event.kind=="airburst":
			bursts+=1
			expect(float(event.data.caliber_m)>.1,"Every timed airburst comes from heavy AA, never MG/20/40mm")
	expect(light_shots>10 and bursts>0 and main_shots==0,"Light direct-fire network and real heavy timed flak operate with separate roles")
	expect(shots.size()>8,"Multiple actual Iowa mounts participate; no cosmetic single emitter")
	expect(fired_targets.has("enemy_a") and fired_targets.has("enemy_b") and simultaneous,"Both beam contacts receive actual AA fire in the same one-second window")
	var conserved: bool=true
	for weapon: WeaponState in shooter.weapons.values():
		var used: int=0
		for barrel: int in weapon.remaining_rounds.size():
			used+=int(before[weapon.id][barrel])-weapon.remaining_rounds[barrel]
		conserved=conserved and used==int(shots.get(weapon.id,0))
	expect(conserved,"Both AA networks debit actual mount inventories once per fired event")
	var disabled_mount: String="secondary_01_port"
	expect(int(shots.get("shooter/"+disabled_mount,0))>0,"The port station fired before the fixture disables it")
	shooter.weapons[disabled_mount].enabled=false
	world.step_ticks(300)
	var disabled_fired: bool=false
	for event: BattleEvent in world.drain_events():
		if event.kind=="fired" and event.weapon_id=="shooter/"+disabled_mount:disabled_fired=true
	expect(not disabled_fired and runtime.mount_targets[disabled_mount].is_empty(),"Disabled AA/dual-purpose station releases its assignment and stops firing")
	expect(a.projectiles.capacity_rejections==0 and a.projectiles.rounds.size()<8192,"Standard single capital battery does not silently reach projectile capacity")
	finish("air defence")
