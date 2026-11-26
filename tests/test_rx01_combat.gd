extends SceneTree

const FIX: Script = preload("res://tests/fixtures/combat_fixture.gd")
const OUTPUT: String = "res://.local/repairs/20261112_morning/rx01/checks/combat.json"
var checks: int = 0
var failures: int = 0
var evidence: Array[Dictionary] = []

class Replay extends SimulationModule:
	var contacts: Array[Dictionary] = []
	func _init(records: Array[Dictionary]) -> void:
		module_id = "rx01_recorded_contact_replay"
		priority = 625
		contacts = records
	func fixed_update(world_ref: RefCounted, _dt: float) -> void:
		var world: SimulationWorld = world_ref as SimulationWorld
		for contact: Dictionary in contacts:
			world.emit_event("hit","shooter","recorded_406mm",contact.local_position_m,contact,"enemy")
		contacts.clear()

func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	evidence.append({"passed":ok,"label":label})
	if not ok:
		failures += 1
		push_error(label)
func vec(text: String) -> Vector3:
	var fields: PackedStringArray=text.trim_prefix("(").trim_suffix(")").split(",")
	return Vector3(fields[0].to_float(),fields[1].to_float(),fields[2].to_float())
func arena() -> Dictionary:
	return FIX.arena([FIX.spawn("shooter","us",Vector3(4500,0,0),"us_iowa_bb61_1944_12_28"),FIX.spawn("enemy","jp",Vector3.ZERO,"jp_yamato_1944_04")])
func launch(a: Dictionary, point: Vector3, count: int, ammo: String="us_406mm_mk8_ap") -> void:
	var shots: Array[Dictionary]=[]
	for index: int in count: shots.append({"ammo":ammo,"position":point,"direction":Vector3.LEFT,"gravity":0.})
	(a.launcher as FIX.Launcher).pending=shots
func events_of(events: Array[BattleEvent], kind: String) -> Array[BattleEvent]:
	var found: Array[BattleEvent]=[]
	for event: BattleEvent in events:
		if event.kind==kind: found.append(event)
	return found
func recorded_salvo() -> void:
	var path: String="res://.local/repairs/20261112_morning/rx01/before/harbor.json"
	if not FileAccess.file_exists(path): expect(false,"RX01 frozen natural contact evidence is required");return
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var contacts: Array[Dictionary]=[]
	for row: Dictionary in report.ship_damage:
		if row.target_id!="jp_bb":continue
		var contact: Dictionary=row.contact.data.duplicate(true)
		contact.local_position_m=vec(contact.local_position_m)
		contact.velocity_mps=vec(contact.velocity_mps)
		contact.target_velocity_mps=vec(contact.target_velocity_mps)
		contacts.append(contact)
	var a: Dictionary=arena()
	var receipt: Dictionary=a.world.register_module(Replay.new(contacts))
	expect(receipt.accepted,"Captured natural contacts enter the ordinary damage event mailbox")
	a.world.step_ticks(1)
	var actual: Array[BattleEvent]=events_of(a.world.drain_events(),"damaged")
	var damage: Dictionary=a.world.get_unit("enemy").module_data.damage
	var raw: float=0.
	var applied: float=0.
	for event: BattleEvent in actual: raw+=float(event.data.amount);applied+=float(event.data.structure_amount)
	expect(actual.size()==7 and raw>6000. and absf(applied-raw*.25)<.01,"Same seven real 410mm-belt contacts keep their energy/armor damage; only localized structural transfer changes")
	expect(damage.structure>4400 and damage.ship.flotation==6000 and damage.flooding==0 and damage.propulsion_factor==1.,"Above-water side hits do not invent breaches or destroy the submerged propulsion plant")
	a.world.step_ticks(6000)
	expect(damage.phase=="operational" and a.world.get_unit("enemy").position_m.y==0.,"Captured first volley leaves a functional afloat battleship after another 100 seconds")
	evidence.append({"case":"recorded_first_volley","source":path,"raw_damage":raw,"structural_loss":applied,"damage":damage.duplicate(true)})
func afloat_and_breached() -> void:
	var a: Dictionary=arena()
	launch(a,Vector3(60,4,-50),32)
	a.world.step_ticks(12)
	var first: Array[BattleEvent]=a.world.drain_events()
	var damage: Dictionary=a.world.get_unit("enemy").module_data.damage
	expect(damage.structure==0 and damage.phase=="disabled" and damage.ship.flotation==6000 and damage.flooding==0,"Enough real above-water hull hits exhaust combat structure while retaining flotation")
	a.world.step_ticks(6000)
	var later: Array[BattleEvent]=a.world.drain_events()
	expect(damage.phase=="disabled" and a.world.get_unit("enemy").position_m.y==0. and events_of(first,"disabled").size()==1 and events_of(later,"disabled").is_empty(),"Afloat mission kill remains buoyant without repeated disable events or a death timer")
	launch(a,Vector3(60,.1,0),10)
	a.world.step_ticks(12)
	var contacts: Array[BattleEvent]=a.world.drain_events()
	expect(damage.phase=="sinking" and damage.ship.flotation==0 and damage.ship.breach_hits>0 and damage.flooding>0,"Actual first waterline contacts can exhaust flotation on an already disabled hull")
	var once: int=events_of(contacts,"damaged").size()
	a.world.step_ticks(30)
	expect(once>0 and events_of(a.world.drain_events(),"damaged").is_empty(),"Terminated AP contacts never repeat damage on later ticks")
	evidence.append({"case":"afloat_then_breached","waterline_contacts":events_of(contacts,"hit").size(),"damage":damage.duplicate(true)})
func submerged_lifecycle() -> void:
	var a: Dictionary=arena()
	launch(a,Vector3(60,.1,0),10)
	a.world.step_ticks(12)
	var unit: UnitState=a.world.get_unit("enemy")
	var d: Dictionary=unit.module_data.damage
	a.world.drain_events()
	a.world.step_ticks(2700)
	expect(d.phase=="sinking" and unit.position_m.y+float(d.ship.submerge_depth_m)>-2.,"45-second animation minimum cannot stop a still-emergent battleship or schedule its removal")
	var bounded_ticks: int=ceili((float(d.ship.submerge_depth_m)+4.)/.4*60.)
	var submerged_events: Array[BattleEvent]=[]
	for tick: int in bounded_ticks:
		a.world.step_ticks(1)
		submerged_events.append_array(a.world.drain_events())
		if d.phase=="wreck":break
	expect(d.phase=="wreck" and unit.position_m.y+float(d.ship.submerge_depth_m)<=-2.,"Wreck begins only after the catalog/proxy/list extent is conservatively underwater")
	var underwater: Vector3=unit.position_m
	a.world.step_ticks(1801)
	expect(d.phase=="removed" and unit.position_m==underwater,"Finite wreck retirement occurs entirely below the sea, without a visible popup")
	evidence.append({"case":"submerged_lifecycle","submerge_depth_m":d.ship.submerge_depth_m,"wreck_root_m":underwater,"phase_events":events_of(submerged_events,"damage_phase").map(func(e: BattleEvent)->Dictionary:return e.snapshot())})
func independent_modules() -> void:
	var control: Dictionary=arena()
	launch(control,Vector3(60,28,3),15,"us_127mm_5in38_shell")
	control.world.step_ticks(12)
	var ship: UnitState=control.world.get_unit("enemy")
	var d: Dictionary=ship.module_data.damage
	expect(d.parts.control==0 and d.fire_control_factor==0 and d.control_factor==1 and d.propulsion_factor==1 and ship.active,"Real bridge hits lose fire control while preserving propulsion and steering")
	expect(ship.weapons.values().all(func(w: WeaponState)->bool:return w.enabled),"Director failure leaves every undamaged local weapon usable")
	for part: String in ["engine","steering"]:
		var a: Dictionary=arena()
		launch(a,Vector3(60,1,0 if part=="engine" else 121),2)
		a.world.step_ticks(15)
		var events: Array[BattleEvent]=a.world.drain_events()
		ship=a.world.get_unit("enemy");d=ship.module_data.damage
		var hits: Array[BattleEvent]=events_of(events,"damaged")
		expect(hits.size()==2 and hits.all(func(e: BattleEvent)->bool:return e.data.part_id==part and e.position_m.y>0),"Actual above-sea swept AP can reach "+part+"; no underwater injection or sea pass-through")
		expect(float(d.parts[part])==0 and ship.active and d.phase=="operational" and d.fire_control_factor==1 and d.ship.flotation==6000,"Loss of "+part+" remains a functional module failure on an afloat combat unit")
		expect((d.propulsion_factor==0 and d.control_factor==1) if part=="engine" else (d.propulsion_factor==1 and d.control_factor==0),part+" changes its own motion input only")
		evidence.append({"case":"reachable_"+part,"hits":hits.map(func(e: BattleEvent)->Dictionary:return e.snapshot()),"damage":d.duplicate(true)})
func battery(hit_count: int) -> Dictionary:
	var a: Dictionary=arena()
	a.world.get_unit("shooter").module_data.combat_intent={"fire":false,"allow_aa":false}
	a.world.get_unit("enemy").module_data.combat_intent={"fire":true,"allow_aa":false}
	FIX.target(a.world,"enemy","shooter")
	var mount: MountSocket=(a.frame.definitions.enemy as UnitDefinition).mounts[0]
	a["tested_mount"]=mount.id
	a["initial_train"]=(a.world.get_unit("enemy").weapons[mount.id] as WeaponState).train_rad
	if hit_count>0: launch(a,mount.position_m+Vector3(30,3,0),hit_count)
	return a
func mount_degradation() -> void:
	var healthy: Dictionary=battery(0)
	var damaged: Dictionary=battery(1)
	for a: Dictionary in [healthy,damaged]: a.world.step_ticks(180)
	var id: String=damaged.tested_mount
	var ship: UnitState=damaged.world.get_unit("enemy")
	var health: float=ship.module_data.damage.parts["weapon:"+id]
	var h_train: float=absf((healthy.world.get_unit("enemy").weapons[id] as WeaponState).train_rad-float(healthy.initial_train))
	var d_train: float=absf((ship.weapons[id] as WeaponState).train_rad-float(damaged.initial_train))
	expect(health>0 and health<.95 and (ship.weapons[id] as WeaponState).enabled and d_train<h_train*.95,"One real AP hit partially damages a heavy turret and measurably slows its actual traverse")
	var fires: Array[Array]=[]
	var reloads: Array[float]=[]
	for a: Dictionary in [healthy,damaged]:
		var times: Array[float]=[]
		var reload_sample: float=-1.
		for tick: int in 6000:
			a.world.step_ticks(1)
			for event: BattleEvent in a.world.drain_events():
				if event.kind=="fired" and event.weapon_id=="enemy/"+id and int(event.data.barrel_index)==0:times.append(event.time_s)
			if times.size()==1 and reload_sample<0 and a.world.time_s()>=times[0]+10.: reload_sample=(a.world.get_unit("enemy").weapons[id] as WeaponState).cycle_remaining_s
		fires.append(times)
		reloads.append(reload_sample)
	expect(fires[0].size()>=2 and not fires[1].is_empty() and float(fires[1][0])>float(fires[0][0])+1.,"Damaged turret retains real firing but takes longer to acquire the same target")
	expect(reloads[0]>0 and reloads[1]>reloads[0]+1.5,"Ten seconds after each actual first shot, the damaged turret has more real reload work remaining")
	if fires[0].size()>=2 and fires[1].size()>=2:
		expect(float(fires[1][1])-float(fires[1][0])>(float(fires[0][1])-float(fires[0][0]))*1.15,"Same damaged turret reloads more slowly without changing shell velocity or mass")
	evidence.append({"case":"partial_turret","health":health,"healthy_fires_s":fires[0],"damaged_fires_s":fires[1],"reload_after_10s":reloads,"healthy_train_rad":h_train,"damaged_train_rad":d_train})
	var lost: Dictionary=battery(4)
	lost.world.step_ticks(15)
	ship=lost.world.get_unit("enemy")
	expect(not (ship.weapons[id] as WeaponState).enabled and ship.module_data.damage.parts["weapon:"+id]==0 and ship.active,"Enough actual turret hits disable only that mount at zero health")
	var other_fired: bool=false
	var dead_fired: bool=false
	for tick: int in 6000:
		lost.world.step_ticks(1)
		for event: BattleEvent in lost.world.drain_events():
			if event.kind=="fired" and event.entity_id=="enemy":
				if event.weapon_id=="enemy/"+id:dead_fired=true
				elif str(event.data.mount_role)=="main":other_fired=true
	expect(other_fired and not dead_fired,"Other main turrets continue real fire after the one destroyed turret stops")
func director_quality() -> void:
	var comparisons: Array[Dictionary]=[]
	for injured: bool in [false,true]:
		var a: Dictionary=battery(0)
		if injured:launch(a,Vector3(60,28,3),15,"us_127mm_5in38_shell")
		var errors: Array[float]=[]
		var fired: int=0
		for tick: int in 6000:
			a.world.step_ticks(1)
			for event: BattleEvent in a.world.drain_events():
				if event.kind!="fired" or event.entity_id!="enemy" or event.data.mount_role!="main":continue
				var mount: MountSocket
				for candidate: MountSocket in (a.frame.definitions.enemy as UnitDefinition).mounts:
					if candidate.id==event.weapon_id.get_slice("/",1):mount=candidate;break
				var muzzle: Transform3D=mount.local_muzzle_transform(int(event.data.barrel_index),float(event.data.train_rad),float(event.data.elevation_rad))
				var nominal: Vector3=-muzzle.basis.z.normalized()
				errors.append(nominal.angle_to(event.data.muzzle_direction))
				fired+=1
		var total: float=0.
		for error: float in errors:total+=error
		comparisons.append({"injured":injured,"main_rounds":fired,"mean_direction_error_rad":total/maxi(1,errors.size()),"fire_control_quality":a.world.get_unit("enemy").module_data.combat_runtime.fire_control_quality})
	expect(comparisons[0].main_rounds>0 and comparisons[1].main_rounds>0 and comparisons[1].fire_control_quality==0,"Actual bridge destruction retains independent main-gun fire under degraded director quality")
	expect(float(comparisons[1].mean_direction_error_rad)>float(comparisons[0].mean_direction_error_rad)*2.,"Real fired directions show degraded director accuracy rather than a cosmetic quality field")
	evidence.append({"case":"director_quality","comparisons":comparisons})
func config_consistency() -> void:
	var a: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/s14_expansion.json"))
	var b: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/s14_bombing.json"))
	for id: String in ["us_essex_cv9_1944_04_15","jp_shokaku_1941_08_23"]:
		expect(a.unit_profiles[id].ship_damage==b.unit_profiles[id].ship_damage,"Same carrier damage rules in operations and bombing: "+id)
	for bad: Variant in [-.1,1.1,"invalid"]:
		var input: Dictionary=FIX.config().data
		input.unit_profiles.jp_yamato_1944_04.ship_damage.above_water_hull_transfer=bad
		expect(not CombatConfig.new().load_data(input).is_empty(),"Invalid ship transfer rejected by normal config validation: "+str(bad))
	var bad_durability: Dictionary=FIX.config().data
	bad_durability.unit_profiles.jp_yamato_1944_04.main_weapon_durability=0.
	expect(not CombatConfig.new().load_data(bad_durability).is_empty(),"Zero heavy-turret durability rejected before combat")
func run() -> void:
	recorded_salvo()
	afloat_and_breached()
	submerged_lifecycle()
	independent_modules()
	mount_degradation()
	director_quality()
	config_consistency()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file: FileAccess=FileAccess.open(OUTPUT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"\t"));file.close()
	print("RX01 combat: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
