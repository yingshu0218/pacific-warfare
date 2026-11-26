extends SceneTree

const FIX: Script=preload("res://.local/repairs/20261112_morning/rx01/fixture/fixture.gd")
const HISTORY: Script=preload("res://scripts/presentation/state/pose_history.gd")
const VIEW: Script=preload("res://scripts/showcase/bombing/projectile_view.gd")
var checks: int=0
var failures: int=0
var records: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func sample(session: FirstPlayableSession, history: SimulationModule, world: SimulationWorld, alpha: float) -> Dictionary:
	session.presentation_bombs=history.call("interpolate_bombs",alpha)
	return history.call("interpolate",world.snapshot().units,alpha)
func run() -> void:
	for type: String in ["us_sb2c4_1944","jp_d4y2_model12_1944_10","jp_g4m1_1942_07","us_b25j_1944_07"]:
		var p: Dictionary=FIX.parameters().aircraft[type]
		var a: Dictionary=FIX.arena([FIX.spawn("bomber","us",Vector3(0,float(p.entry_altitude_m),5500),type,Vector3(0,0,-float(p.attack_mps)))])
		var world: SimulationWorld=a.world
		var history: SimulationModule=HISTORY.new()
		expect(world.register_module(history).accepted,type+" readonly final-tick sampler registered")
		expect(FIX.order(world,["bomber"],str(p.mode),"",{"center_m":[0.,0.,0.],"radius_m":300.}).accepted,type+" real bombing order accepted")
		var release: BattleEvent
		for tick: int in 9000:
			world.step_ticks(1)
			for event: BattleEvent in world.drain_events():
				if event.kind=="bomb_released" and release==null:release=event
			if release!=null:break
		expect(release!=null,type+" normal task/flight/store chain actually releases a finite bomb")
		if release==null:FIX.dispose(a);continue
		var id: String=release.data.projectile_id
		var slot: int=int(release.data.slot)
		var session: FirstPlayableSession=FirstPlayableSession.new()
		session.world=world
		var model: Node3D=(load(world.unit_definition(type).model_scene) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var view: Node3D=VIEW.new();root.add_child(view)
		var models: Dictionary={"bomber":model}
		var physical: Dictionary=world.snapshot()
		var early_ok: bool=true
		for alpha: float in [0.,.25,.5,.999]:
			var units: Dictionary=sample(session,history,world,alpha)
			model.call("apply_state",units.bomber)
			view.call("present",session,models)
			early_ok=early_ok and session.presentation_bombs.is_empty() and (view.get("visuals") as Dictionary).is_empty() and bool(units.bomber.module_data.bomb_rack.slots[slot].loaded) and (model.call("bomb_template",slot) as Node3D).visible
		expect(early_ok,type+" before birth: attached slot retained, no detached body even though physical inventory has decremented")
		var birth: Dictionary=sample(session,history,world,1.)
		model.call("apply_state",birth.bomber);view.call("present",session,models)
		var visuals: Dictionary=view.get("visuals")
		var birth_error: float=INF
		if visuals.has(id):birth_error=(visuals[id] as Node3D).global_position.distance_to(release.position_m)
		expect(visuals.has(id) and birth_error<.005 and not bool(birth.bomber.module_data.bomb_rack.slots[slot].loaded) and not (model.call("bomb_template",slot) as Node3D).visible,type+" birth endpoint switches attached to detached at the actual release point")
		expect(world.snapshot()==physical,type+" presentation samples/templates never write physical rounds, rack inventory, RNG or unit state")
		world.step_ticks(1);world.drain_events()
		var motion_error: float=0.
		for alpha: float in [0.,.25,.5,.75,1.]:
			var units: Dictionary=sample(session,history,world,alpha)
			model.call("apply_state",units.bomber);view.call("present",session,models)
			visuals=view.get("visuals")
			if not visuals.has(id) or not session.presentation_bombs.has(id):motion_error=INF;break
			var row: Dictionary=session.presentation_bombs[id]
			var body: Node3D=visuals[id]
			motion_error=maxf(motion_error,body.position.distance_to(row.position_m))
			motion_error=maxf(motion_error,body.basis.get_rotation_quaternion().angle_to(Basis.from_euler(row.rotation_rad).get_rotation_quaternion()))
		expect(motion_error<.001,type+" first airborne tick uses the exact same position and orientation sample as aircraft and camera")
		var terminal: BattleEvent
		for tick: int in 9000:
			world.step_ticks(1)
			for event: BattleEvent in world.drain_events():
				if event.kind in ["hit","surface_impact","projectile_expired"] and event.data.get("projectile_id","")==id:terminal=event
			if terminal!=null:break
		expect(terminal!=null,type+" bomb reaches a real terminal contact without presentation steering")
		var end_ok: bool=terminal!=null
		if terminal!=null:
			for alpha: float in [0.,.5,.999]:
				sample(session,history,world,alpha);view.call("present",session,models)
				end_ok=end_ok and (view.get("visuals") as Dictionary).has(id)
			sample(session,history,world,1.);view.call("present",session,models)
			end_ok=end_ok and not (view.get("visuals") as Dictionary).has(id)
		expect(end_ok,type+" remains visible through terminal interpolation, disappears exactly at the physical terminal endpoint")
		records.append({"type":type,"release":release.snapshot(),"birth_error_m":birth_error,"first_airborne_sample_error":motion_error,"termination":terminal.snapshot() if terminal!=null else {}})
		view.free();model.free();session.world=null
		FIX.dispose(a)
	var file: FileAccess=FileAccess.open("res://.local/repairs/20261112_morning/rx01/checks/bomb-presentation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":FIX.json_data(records)},"\t"));file.close()
	print("RX01 bomb presentation ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
