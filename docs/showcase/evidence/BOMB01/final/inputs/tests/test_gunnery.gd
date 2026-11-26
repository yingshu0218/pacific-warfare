extends "res://tests/fixtures/combat_test.gd"

func run_test() -> void:
	var r: Vector3=Vector3(0,0,-1000)
	var v: Vector3=Vector3(120,0,0)
	var solution: Dictionary=CombatFireControl.intercept(Vector3.ZERO,Vector3.ZERO,r,v,800,9.80665,20)
	expect(not solution.is_empty() and solution.direction.x>0.1 and solution.direction.y>0.,"Lateral target produces real lead and ballistic elevation")
	var t: float=solution.get("time_s",0.)
	var projectile: Vector3=solution.get("direction",Vector3.ZERO)*800*t+Vector3.DOWN*4.903325*t*t
	expect(projectile.distance_to(r+v*t)<.002,"Computed projectile position meets independent constant-speed target solution within 2 mm")
	expect(CombatFireControl.intercept(Vector3.ZERO,Vector3.ZERO,Vector3(500,0,0),Vector3(900,0,0),800,0,20).is_empty(),"Target receding faster than projectile has no solution")
	var origin: Vector3=Vector3(0,10,0)
	solution=CombatFireControl.intercept(origin,Vector3(10,0,0),Vector3(0,10,-1000),Vector3(10,0,0),800,0,10)
	expect(not solution.is_empty() and absf(solution.direction.x)<.00001,"Inherited shooter velocity is removed from relative lead")
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","jp",Vector3.ZERO,"jp_yamato_1944_04"),FIX.spawn("enemy","us",Vector3(4000,0,0),"us_iowa_bb61_1944_12_28")])
	var world: SimulationWorld=a.world
	world.get_unit("shooter").module_data.combat_intent={"fire":true}
	FIX.target(world,"shooter","enemy")
	world.step_ticks(1)
	expect(world.get_unit("shooter").module_data.combat_runtime.mount_status.main_01=="traversing", "Real turret not initially pointed at beam target cannot immediately fire")
	expect(absf(world.get_unit("shooter").weapons.main_01.train_rad)<=deg_to_rad(2.)/60.+.00001,"Historical 2 deg/s train rate bounds one tick")
	# An independent box at the actual gun's local muzzle blocks its full firing path.
	var unit: UnitState=world.get_unit("shooter")
	unit.weapons.main_01.train_rad=-PI*.5
	(a.frame.proxies.shooter as Array).append({"part":"structure","center_m":[12,12,-50],"half_extents_m":[2,10,10],"armor_mm":25.})
	world.step_ticks(45)
	expect(unit.module_data.combat_runtime.mount_status.main_01=="masked", "Host structure blocks the barrel/muzzle path even when solution and train are valid")
	# Fixed aircraft weapons do not swivel or fire behind the airframe.
	a=FIX.arena([FIX.spawn("shooter","us",Vector3(0,100,0)),FIX.spawn("enemy","jp",Vector3(0,100,300))])
	world=a.world
	world.get_unit("shooter").module_data.combat_intent={"fire":true,"burst_until_tick":100}
	FIX.target(world,"shooter","enemy")
	world.step_ticks(30)
	expect(FIX.events(world,"fired").is_empty(), "Aircraft fixed gun never fires into rear hemisphere despite valid contact")
	world.get_unit("enemy").position_m=Vector3(0,100,-500)
	world.step_ticks(90)
	var shots: Array[BattleEvent]=FIX.events(world,"fired")
	expect(not shots.is_empty(),"Forward enemy permits actual short aircraft burst")
	for shot: BattleEvent in shots:
		expect(shot.tick<=100 and absf(shot.position_m.x)>=2.3,"Every aircraft shot lies inside burst window and at actual wing muzzle")
	var before: int=a.projectiles.next_id
	world.step_ticks(60)
	expect(a.projectiles.next_id==before,"Expired burst cannot continue firing")
	var zero: Dictionary=FIX.arena([FIX.spawn("shooter","jp",Vector3(0,100,0),"jp_a6m5a_1944"),FIX.spawn("enemy","us",Vector3(0,100,-400))])
	zero.world.get_unit("shooter").module_data.combat_intent={"fire":true,"burst_until_tick":12}
	FIX.target(zero.world,"shooter","enemy")
	zero.world.step_ticks(20)
	var zero_mounts: Dictionary={}
	for shot: BattleEvent in zero.world.drain_events():
		if shot.kind!="fired":continue
		zero_mounts[shot.weapon_id]=true
		if "/cowl_" in shot.weapon_id:
			expect(absf(shot.position_m.y-100.56)<.0001 and absf(shot.position_m.z+3.94)<.0001,"A6M synchronized nose shot begins at real flight-origin cowl muzzle")
	expect(zero_mounts.size()==4,"Both A6M cowl channels and both wing cannon fire without being masked by solid engine proxy")
	finish("gunnery")
