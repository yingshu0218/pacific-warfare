extends "res://tests/fixtures/combat_test.gd"

func gun_world() -> Dictionary:
	var c: CombatConfig=FIX.config()
	# Durable witness isolates inventory/cadence from the separately tested damage chain.
	c.data.unit_profiles.us_iowa_bb61_1944_12_28.structure=1000000.
	c.data.unit_profiles.us_iowa_bb61_1944_12_28.part_durability=1000000.
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","jp",Vector3.ZERO,"jp_yamato_1944_04"),FIX.spawn("enemy","us",Vector3(4000,0,0),"us_iowa_bb61_1944_12_28")],c)
	var world: SimulationWorld=a.world
	var unit: UnitState=world.get_unit("shooter")
	unit.module_data.combat_intent={"fire":true,"allow_aa":false}
	FIX.target(world,"shooter","enemy")
	for mount: MountSocket in (a.frame.definitions.shooter as UnitDefinition).mounts:
		if mount.role=="main":
			var state: WeaponState=unit.weapons[mount.id]
			state.train_rad=wrapf(-PI*.5-mount.base_yaw_rad,-PI,PI)
	unit.weapons.main_01.remaining_rounds.assign([2,1,0])
	unit.weapons.main_02.remaining_rounds.assign([2,2,2])
	unit.weapons.main_02.cycle_remaining_s=12.
	unit.weapons.main_03.enabled=false
	return a

func fixed_axis_case() -> void:
	var drift: Vector3 = Vector3(8,0,-95)
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(0,100,0),"us_f6f5_1944",drift),
		FIX.spawn("enemy","jp",Vector3(0,100,-560),"jp_a6m5a_1944",drift)])
	var world: SimulationWorld=a.world
	var shooter: UnitState=world.get_unit("shooter")
	shooter.module_data.combat_intent={"fire":true,"burst_until_tick":60}
	FIX.target(world,"shooter","enemy")
	var sockets: Dictionary={}
	for mount: MountSocket in (a.frame.definitions.shooter as UnitDefinition).mounts:
		sockets[mount.id]=mount
	world.step_ticks(16)
	var observed: int=0
	var exact: bool=true
	for event: BattleEvent in world.drain_events():
		if event.kind!="fired" or event.entity_id!="shooter":continue
		observed+=1
		var mount: MountSocket=sockets[event.weapon_id.get_slice("/",1)]
		var axis: Vector3=-(shooter.world_transform()*mount.local_muzzle_transform(int(event.data.barrel_index),0,0)).basis.z.normalized()
		var relative: Vector3=(event.data.velocity_mps as Vector3)-drift
		exact=exact and axis.distance_to(event.data.muzzle_direction)<.00001 and axis.distance_to(relative.normalized())<.00001
	expect(observed>1 and exact,"Fixed aircraft rounds leave each muzzle strictly along its barrel, before adding platform motion")
	world.reset()
	shooter=world.get_unit("shooter")
	world.get_unit("enemy").position_m += Vector3(230,0,0)
	shooter.module_data.combat_intent={"fire":true,"burst_until_tick":60}
	FIX.target(world,"shooter","enemy")
	world.step_ticks(16)
	expect(not world.drain_events().any(func(event: BattleEvent)->bool: return event.kind=="fired" and event.entity_id=="shooter"),"Side target does not fire the fixed guns by itself")

func run_test() -> void:
	var a: Dictionary=gun_world()
	var world: SimulationWorld=a.world
	world.step_ticks(3000)
	var events: Array[BattleEvent]=world.drain_events()
	var shots: Array[BattleEvent]=[]
	var salvos: Array[BattleEvent]=[]
	for event: BattleEvent in events:
		if event.kind=="fired" and "/main_" in event.weapon_id:shots.append(event)
		if event.kind=="salvo":salvos.append(event)
	expect(shots.size()==9,"Actual Yamato ready barrels fire exactly their 9 allocated rounds, disabled aft mount excluded")
	if shots.size()!=9: print(world.get_unit("shooter").module_data.combat_runtime)
	for event: BattleEvent in shots:
		var mount_id: String=event.weapon_id.get_slice("/",1)
		var mount: MountSocket
		for socket: MountSocket in (a.frame.definitions.shooter as UnitDefinition).mounts:
			if socket.id==mount_id:mount=socket
		expect(mount!=null and int(event.data.barrel_index)<mount.muzzle_positions_m.size(),"Fired event names real barrel socket")
		var expected_muzzle: Vector3=world.get_unit("shooter").world_transform()*mount.local_muzzle_transform(int(event.data.barrel_index),float(event.data.train_rad),float(event.data.elevation_rad)).origin
		expect(event.position_m.distance_to(expected_muzzle)<.0003,"Every event starts at exact typed socket muzzle under actual train/elevation")
	expect(world.get_unit("shooter").weapons.main_01.remaining_rounds==[0,0,0] and world.get_unit("shooter").weapons.main_02.remaining_rounds==[0,0,0],"Per-barrel inventory reaches exactly zero without borrowing")
	expect(not salvos.is_empty() and salvos[0].data.mount_ids==["main_01"] and salvos[0].data.rounds==2,"Salvo contains only ready guns and charged barrels")
	var times: Array[int]=[]
	for event: BattleEvent in shots:
		if event.weapon_id=="shooter/main_01" and int(event.data.barrel_index)==0:times.append(event.tick)
	expect(times.size()==2 and times[1]-times[0]>=2100,"35-second Yamato cycle enforced at 60 Hz")
	var fast: Dictionary=gun_world()
	var slow: Dictionary=gun_world()
	for index: int in range(120):
		fast.world.advance(.1)
		fast.world.drain_events()
	for index: int in range(288):slow.world.advance(1./24.)
	expect(fast.world.snapshot()==slow.world.snapshot(),"Different render frame steps and event drain frequencies produce identical inventory, projectiles and damage")
	var c: CombatConfig=FIX.config()
	c.data.limits.projectiles=1
	var limited: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(0,100,0)),FIX.spawn("enemy","jp",Vector3(0,100,-600))],c)
	limited.world.get_unit("shooter").module_data.combat_intent={"fire":true,"burst_until_tick":60}
	FIX.target(limited.world,"shooter","enemy")
	limited.world.step_ticks(12)
	var total: int=0
	for event: BattleEvent in limited.world.drain_events():
		if event.kind=="fired": total+=1
	var remaining: int=0
	for weapon: WeaponState in limited.world.get_unit("shooter").weapons.values():
		remaining+=weapon.remaining_rounds[0]
	expect(total==1 and remaining==2399 and limited.projectiles.capacity_rejections>0,"Physical projectile capacity is observable; refused shots do not consume ammunition")
	fixed_axis_case()
	finish("weapon cycle")
