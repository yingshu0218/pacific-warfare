extends SceneTree
const FIX: Script=preload("res://tests/bombing/fixture.gd")
const PROBE: Script=preload("res://tests/bombing/lifecycle_probe.gd")
var checks: int=0
var failures: int=0
var evidence: Array=[]
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks+=1;evidence.append({"passed":ok,"label":label});print("BOMB01_CHECK ",ok," ",label)
	if not ok: failures+=1
func cancel(world: SimulationWorld, order_id: String) -> void:
	var c: BattleCommand=BattleCommand.new()
	c.command_id="cancel_"+str(world.tick);c.issuer_id="test_commander";c.faction_id="us";c.source="human";c.kind=BattleCommand.CANCEL_ORDER;c.payload={"order_id":order_id,"reason":"test_cancel"}
	expect(world.submit_command(c).accepted,"cancel through unified command")
func run() -> void:
	var area: Dictionary={"center_m":[0.,0.,0.],"radius_m":300.}
	# Two real B25 airframes use retained formation slots and straight finite runs.
	for lost: bool in [false,true]:
		var a: Dictionary=FIX.arena([FIX.spawn("lead","us",Vector3(0,1800,5500),"us_b25j_1944_07",Vector3(0,0,-95)),FIX.spawn("wing","us",Vector3(240,1800,5580),"us_b25j_1944_07",Vector3(0,0,-95))])
		var world: SimulationWorld=a.world
		expect(FIX.order(world,["lead","wing"],"level","",area).accepted,"formation command accepted")
		var minimum: float=INF;var events: Array=[];var release_heading: Dictionary={}
		for tick: int in 100*60:
			if lost and tick==25*60: world.get_unit("lead").active=false # controlled recipient-loss input, no target health editing
			world.step_ticks(1)
			if world.get_unit("lead").active: minimum=minf(minimum,world.get_unit("lead").position_m.distance_to(world.get_unit("wing").position_m))
			for event: BattleEvent in world.drain_events():
				if event.kind=="bomb_released": events.append(event.snapshot())
		var wing_releases: Array=events.filter(func(e: Dictionary) -> bool: return e.entity_id=="wing")
		expect(wing_releases.size()==6,"wing finite six-bomb train after leader loss" if lost else "wing finite six-bomb train")
		expect(minimum>100,"formation keeps physical clearance, min %.2fm"%minimum)
		var max_yaw: float=0.0;var interval_ok: bool=true
		for i: int in wing_releases.size():
			var e: Dictionary=wing_releases[i]
			max_yaw=maxf(max_yaw,absf(AircraftFlightMath.heading(e.data.velocity_mps)))
			if i>0: interval_ok=interval_ok and absf(float(e.time_s)-float(wing_releases[i-1].time_s)-.25)<.018
		expect(interval_ok and max_yaw<deg_to_rad(2),"actual straight bomb train with finite .25s intervals")
		expect(int(world.get_unit("wing").module_data.bomb_rack.remaining)==0,"inventory consumed once, no refill on leader change")
		FIX.dispose(a)
	# Cancellation and reassignment on the SAME aircraft release old requests/state.
	var a: Dictionary=FIX.arena([FIX.spawn("bomber","us",Vector3(0,1800,5500),"us_b25j_1944_07",Vector3(0,0,-95))],true,false,null,true)
	var world: SimulationWorld=a.world
	var probe: RefCounted=PROBE.new(FIX.parameters(),a.stores)
	a.tasks.set("mission_delegate",probe);a.delegate=probe
	world.reset()
	expect(int(probe.calls.reset)==1 and a.tasks.bombing_delegate==null,"typed OPS bridge reset once, parent delegate null")
	expect(FIX.order(world,["bomber"],"level","",area).accepted,"actual CarrierMissionDelegate accepts bombing on OPS bridge")
	world.step_ticks(120)
	expect(int(probe.calls.accept)==1 and int(probe.calls.step)==120,"OPS accept once and exactly one pilot step per mission tick")
	# Controlled contradictory high altitude / on-deck state proves the formal
	# OPS field is authoritative; it is NOT a B25 carrier-fit qualification.
	var operations: RefCounted=a.operations
	operations.roster["bomber"]={"phase":"mission","on_deck":true}
	operations.call("_publish",world.get_unit("bomber"))
	var guard: String=load("res://scripts/bombing/stores.gd").call("release_guard",world,world.get_unit("bomber"),"bomb_0",FIX.parameters().aircraft.us_b25j_1944_07,world.get_unit("bomber").module_data.bomb_rack)
	expect(guard=="not_airborne","actual OPS-published carrier_ops.on_deck blocks release even at1800m")
	operations.roster.erase("bomber");world.get_unit("bomber").module_data.erase("carrier_ops")
	cancel(world,"bomb_0");world.step_ticks(1)
	expect(int(probe.calls.released)==1 and not a.delegate.states.has("bomber") and a.stores.requests.is_empty(),"OPS cancel releases delegate and pending bomb requests exactly once")
	expect(not world.get_unit("bomber").module_data.has("carrier_delegated_mission"),"cancel clears delegated OPS ownership flag")
	expect(FIX.order(world,["bomber"],"level","",area).accepted,"same aircraft accepts fresh attack after cancel")
	world.step_ticks(120)
	expect(int(probe.calls.accept)==2 and a.delegate.states.bomber.order_id=="bomb_121","reassignment has a fresh task identity")
	cancel(world,"bomb_121");world.step_ticks(1)
	expect(int(probe.calls.released)==2,"second cancel releases only the new mission")
	FIX.dispose(a);probe=null
	# Incorrect fighter roles are rejected by the one aircraft executor.
	a=FIX.arena([FIX.spawn("bomber","us",Vector3(0,1800,5500),"us_b25j_1944_07",Vector3(0,0,-95)),FIX.spawn("enemy","jp",Vector3(100,1800,4000),"jp_a6m5a_1944",Vector3(0,0,100))]);world=a.world
	var wrong: BattleOrder=BattleOrder.from_data({"order_id":"wrong_role","issuer_id":"test_commander","faction_id":"us","recipient_ids":["bomber"],"order_type":"intercept","target_id":"enemy"})
	expect(world.submit_order(wrong).accepted,"role request enters common command validation")
	world.step_ticks(1)
	var rejected: bool=false
	for event: BattleEvent in world.drain_events():
		if event.kind=="order_status" and str(event.data.get("reason","")).begins_with("bomber_role_forbids"):rejected=true
	for record: Dictionary in world.orders_snapshot():
		if record.order_id=="wrong_role" and record.reason.begins_with("bomber_role_forbids"):rejected=true
	expect(rejected and world.get_unit("bomber").active_order_id.is_empty(),"actual bomber intercept rejected without dogfight ownership")
	FIX.dispose(a)
	# Missed/low/damage/fuel/empty aborts are bounded and cannot manufacture bombs.
	for reason: String in ["low","damage","empty","fuel"]:
		a=FIX.arena([FIX.spawn("bomber","us",Vector3(0,2400,1600),"us_sb2c4_1944",Vector3(0,0,-85))]);world=a.world
		if reason=="low": world.get_unit("bomber").position_m.y=400.
		if reason=="damage": world.get_unit("bomber").module_data.damage.propulsion_factor=.4
		if reason=="empty": world.get_unit("bomber").module_data.bomb_rack.remaining=0
		if reason=="fuel": world.get_unit("bomber").module_data.aircraft_motion.fuel_kg=30.
		expect(FIX.order(world,["bomber"],"dive","",area).accepted,"controlled abort order accepted: "+reason)
		world.step_ticks(600)
		var s: Dictionary=world.get_unit("bomber").module_data.get("bombing",{})
		expect(not str(s.get("abort_reason","")).is_empty() and int(world.get_unit("bomber").module_data.bomb_rack.released)==0,"actual abort with zero release: "+reason)
		FIX.dispose(a)
	# Long approach really crosses240s; timeout may not repeatedly seize egress.
	a=FIX.arena([FIX.spawn("bomber","us",Vector3(0,1800,55000),"us_b25j_1944_07",Vector3(0,0,-95))]);world=a.world
	expect(FIX.order(world,["bomber"],"level","",area).accepted,"long approach accepted for actual240s timeout regression")
	var timed_out: bool=false;var egress: bool=false;var returned: bool=false
	for i: int in 650*60:
		world.step_ticks(1)
		for event: BattleEvent in world.drain_events():
			if event.kind!="bombing_phase":continue
			if event.data.reason=="attack_timeout":timed_out=true
			if event.data.phase=="egress":egress=true
			if event.data.phase=="return":returned=true
	expect(timed_out and egress and returned,"after actual240s timeout, continuous egress reaches return without pullout reset loop")
	expect(int(world.get_unit("bomber").module_data.bomb_rack.released)==0,"timeout cannot manufacture a bomb release")
	FIX.dispose(a)
	var f: FileAccess=FileAccess.open("res://.local/tasks.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"\t"));f.close()
	call_deferred("_exit_test",0 if failures==0 else 1)
func _exit_test(code: int) -> void:quit(code)
