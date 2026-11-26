extends "res://tests/fixtures/combat_test.gd"

class TimerProbe extends SimulationModule:
	var report: Dictionary
	var phase: String
	func _init(label_value: String, order: int, measurements: Dictionary) -> void:
		module_id="test_timer_"+label_value
		priority=order
		phase=label_value
		report=measurements
	func fixed_update(_world: RefCounted,_delta_s: float) -> void:
		var now: int=Time.get_ticks_usec()
		if report.has("last"):report[phase]=int(report.get(phase,0))+now-int(report.last)
		report.last=now

func run_test() -> void:
	var c: CombatConfig=FIX.config()
	var bad: Dictionary=c.data.duplicate(true)
	bad.unit_profiles.us_f6f5_1944.boxes[0].center_m=["bad",0,0]
	var rejected: CombatConfig=CombatConfig.new()
	expect(not rejected.load_data(bad).is_empty(),"Malformed geometry rejected before installing modules")
	bad=c.data.duplicate(true)
	bad.ammo_profiles.us_127mm_m2_ball.muzzle_speed_mps=-1
	expect(not rejected.load_data(bad).is_empty(),"Negative ammunition override rejected")
	var spawns: Array=[FIX.spawn("yamato","jp",Vector3(-2000,0,0),"jp_yamato_1944_04"),FIX.spawn("yukikaze","jp",Vector3(-2200,0,350),"jp_yukikaze_1942_06"),FIX.spawn("iowa","us",Vector3(2000,0,0),"us_iowa_bb61_1944_12_28"),FIX.spawn("fletcher","us",Vector3(2200,0,350),"us_fletcher_dd445_1942_07_18")]
	for faction: String in ["jp","us"]:
		for index: int in range(4):
			var x: float=2000 if faction=="jp" else -2000
			spawns.append(FIX.spawn(faction+"_air_"+str(index),faction,Vector3(x+(-650 if index%2==0 else 650),220+index*25,-500+index*320),"jp_a6m5a_1944" if faction=="jp" else "us_f6f5_1944"))
	# Capacity witness: same actual mounts/stocks/cadences, durable targets maintain load.
	for id: String in c.data.unit_profiles:
		c.data.unit_profiles[id].structure=100000000.
		c.data.unit_profiles[id].part_durability=100000000.
		c.data.unit_profiles[id].weapon_durability=100000000.
	var world: SimulationWorld=SimulationWorld.new()
	expect(world.configure(FIX.catalog(),{"id":"s05_capacity_witness","seed":505,"tick_hz":60,"factions":["jp","us"],"spawns":spawns,"groups":[]}).is_empty(),"All four formal ships and eight aircraft definitions configure")
	expect(CombatSuite.install(world,c).is_empty(),"Public suite installs all combat modules")
	var before: Dictionary=world.snapshot()
	expect(not CombatSuite.install(world,c).is_empty() and world.snapshot()==before,"Duplicate installation rejected atomically without resetting state")
	var measurements: Dictionary={}
	for pair: Array in [["host",79],["frame",81],["contacts",101],["targeting",451],["weapons",501],["projectiles",601],["damage",651]]:
		world.register_module(TimerProbe.new(pair[0],pair[1],measurements))
	var initial: int=0
	for id: String in world.unit_ids():
		var unit: UnitState=world.get_unit(id)
		for gun: WeaponState in unit.weapons.values():
			for rounds: int in gun.remaining_rounds:initial+=rounds
		if id in ["yamato","yukikaze","iowa","fletcher"]:
			unit.module_data.combat_intent={"fire":true,"allow_aa":true}
			FIX.target(world,id,"iowa" if unit.faction_id=="jp" else "yamato")
	var peak: int=0
	var fired: int=0
	var counts: Dictionary={}
	var fired_mounts: Dictionary={}
	var started: int=Time.get_ticks_msec()
	for tick_index: int in range(3600):
		world.step_ticks(1)
		if tick_index%600==599:print("S05 maintained load tick ",tick_index+1)
		# Reading the projectile module via snapshot only once per second avoids full copies in hot path.
		if tick_index%60==0:
			peak=maxi(peak,world.snapshot().modules.combat_projectiles.rounds.size())
		for event: BattleEvent in world.drain_events():
			counts[event.kind]=int(counts.get(event.kind,0))+1
			if event.kind=="fired":
				fired+=1
				fired_mounts[event.weapon_id]=true
	var remaining: int=0
	var reported: int=0
	for id: String in world.unit_ids():
		var unit: UnitState=world.get_unit(id)
		for gun: WeaponState in unit.weapons.values():
			for rounds: int in gun.remaining_rounds:remaining+=rounds
		if id in ["yamato","yukikaze","iowa","fletcher"]:
			reported+=unit.module_data.combat_runtime.mount_status.size()
	var stats: Dictionary=world.snapshot().modules.combat_projectiles
	expect(initial-remaining==fired,"All four complete batteries conserve every fired barrel round")
	expect(reported==112,"All 97 capital-ship and 15 destroyer mounts participate in runtime assessment")
	expect(stats.capacity_rejections==0 and peak<8192,"60-second maintained 4-ship/8-plane AA load has no capacity suppression")
	expect(fired_mounts.size()>45 and counts.get("airburst",0)>10 and counts.get("surface_impact",0)>10,"Many actual mounts deliver both timed flak and real environmental interactions")
	measurements.erase("last")
	var result: Dictionary={"module_wall_us":measurements,"ticks":world.tick,"simulated_s":60,"wall_s":float(Time.get_ticks_msec()-started)/1000.,"rounds_fired":fired,"peak_projectiles":stats.peak_active,"peak_projectiles_sampled_1hz":peak,"final_projectiles":stats.rounds.size(),"capacity_rejections":stats.capacity_rejections,"assessed_ship_mounts":reported,"fired_mounts":fired_mounts.keys(),"events":counts,"scope":"Capacity witness with durable targets, not completed behavior/UI Showcase"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/showcase/evidence/S05"))
	var file: FileAccess=FileAccess.open("res://docs/showcase/evidence/S05/capacity_witness.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print(JSON.stringify(result))
	world.reset()
	expect(world.tick==0 and world.snapshot().modules.combat_projectiles.launched==0,"Public suite reset clears projectiles, damage and inventory accounting")
	finish("integration")
