extends "res://tests/fixtures/combat_test.gd"

func run_test() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(100,100,0)),FIX.spawn("enemy","jp",Vector3(0,100,-40))])
	var world: SimulationWorld=a.world
	(a.launcher as FIX.Launcher).pending=[{"position":Vector3(0,100,-60),"direction":Vector3.BACK,"gravity":0.}]
	world.step_ticks(5)
	var d: Dictionary=world.get_unit("enemy").module_data.damage
	expect(float(d.structure)<90 and float(d.propulsion_factor)<1.,"Physical engine hit changes structure and propulsion capacity")
	var once: float=d.structure
	world.step_ticks(30)
	expect(is_equal_approx(d.structure,once),"Single ball impact does not repeat damage on later ticks")
	# Large AP against thin aircraft is lethal by actual energy, not scheduled damage.
	(a.launcher as FIX.Launcher).pending=[{"ammo":"us_406mm_mk8_ap","position":Vector3(0,100,0),"gravity":0.}]
	world.step_ticks(8)
	expect(not world.get_unit("enemy").active and d.phase=="crashing" and d.propulsion_factor==0.,"Lethal physical hit ends combat capability and enters crashing phase")
	world.step_ticks(2100)
	expect(d.phase=="removed", "Crash -> wreck -> removed completes within bounded lifecycle")
	var c: CombatConfig=FIX.config()
	var profile: Dictionary=c.data.unit_profiles.jp_yamato_1944_04
	var a2: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(200,100,0)),FIX.spawn("enemy","jp",Vector3.ZERO,"jp_yamato_1944_04")],c)
	(a2.launcher as FIX.Launcher).pending=[{"position":Vector3(40,1,0),"direction":Vector3.LEFT,"gravity":0.}]
	a2.world.step_ticks(20)
	expect(is_equal_approx(a2.world.get_unit("enemy").module_data.damage.structure,float(profile.structure)),"Rifle-calibre bullet cannot accumulate through Yamato armored belt")
	# Actual exposed mount collision: shot into outboard AA station at 5 cm/sweep-safe probe.
	var socket: MountSocket
	for mount: MountSocket in (a2.frame.definitions.enemy as UnitDefinition).mounts:
		if mount.role=="dedicated_aa" and mount.position_m.x>10 and (a2.frame.guns[mount.weapon_definition_id] as WeaponDefinition).barrel_count==3:
			socket=mount
			break
	expect(socket!=null,"Actual outboard AA station available for disability test")
	if socket!=null:
		var hit_point: Vector3=socket.position_m+Vector3(0,.7,0)
		(a2.launcher as FIX.Launcher).pending=[{"ammo":"us_127mm_5in38_shell","position":hit_point+Vector3.RIGHT*10,"direction":Vector3.LEFT,"gravity":0.}]
		a2.world.step_ticks(10)
		var damage: Dictionary=a2.world.get_unit("enemy").module_data.damage
		expect(not a2.world.get_unit("enemy").weapons[socket.id].enabled and damage.disabled_mounts.has(socket.id),"Exposed weapon impact disables the actual mount")
	if socket!=null:
		for ammo_id: String in ["us_127mm_5in38_shell","us_406mm_mk8_ap"]:
			var settings_ratio: CombatConfig=FIX.config()
			settings_ratio.data.unit_profiles.jp_yamato_1944_04.weapon_durability=1000000.
			var ratio_arena: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(200,100,0)),FIX.spawn("enemy","jp",Vector3.ZERO,"jp_yamato_1944_04")],settings_ratio)
			var point: Vector3=socket.position_m+Vector3(0,.7,0)
			(ratio_arena.launcher as FIX.Launcher).pending=[{"ammo":ammo_id,"position":point+Vector3.RIGHT*10,"direction":Vector3.LEFT,"gravity":0.}]
			ratio_arena.world.step_ticks(10)
			var actual: float=0.
			for event: BattleEvent in ratio_arena.world.drain_events():
				if event.kind=="damaged" and event.data.part_id=="weapon:"+socket.id:actual+=float(event.data.amount)
			var lost: float=1.-float(ratio_arena.world.get_unit("enemy").module_data.damage.parts["weapon:"+socket.id])
			expect(actual>0 and absf(lost*1000000./actual-1.)<.0001,"Same exposed AA mount durability is independent of incoming 127mm versus 406mm caliber")
	# Ship directors are separate from steering, propulsion and individual mounts.
	var settings: CombatConfig=FIX.config()
	settings.data.unit_profiles.jp_yamato_1944_04.part_durability=1.
	var disabled: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(200,100,0)),FIX.spawn("enemy","jp",Vector3.ZERO,"jp_yamato_1944_04")],settings)
	(disabled.launcher as FIX.Launcher).pending=[{"ammo":"us_127mm_5in38_shell","position":Vector3(60,28,3),"direction":Vector3.LEFT,"gravity":0.}]
	disabled.world.step_ticks(6000)
	var ship_damage: Dictionary=disabled.world.get_unit("enemy").module_data.damage
	expect(ship_damage.phase=="operational" and ship_damage.structure>5000 and ship_damage.fire_control_factor==0 and ship_damage.control_factor==1 and disabled.world.get_unit("enemy").position_m.y==0.,"Bridge/director loss degrades fire control only; 100 seconds never causes automatic sinking or global disable")
	var salvo: Array[Dictionary]=[]
	for index: int in range(10):salvo.append({"ammo":"us_406mm_mk8_ap","position":Vector3(60,.1,0),"direction":Vector3.LEFT,"gravity":0.})
	(disabled.launcher as FIX.Launcher).pending=salvo
	disabled.world.step_ticks(12)
	expect(ship_damage.phase=="sinking" and ship_damage.ship.flotation==0.,"Enough real waterline AP contacts exhaust watertight reserve and cause sinking")
	finish("damage")
