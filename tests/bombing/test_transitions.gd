extends SceneTree
const FIX: Script=preload("res://tests/bombing/fixture.gd")
var checks: Array=[]
var failures: int=0
var records: Array=[]
var area: Dictionary={"center_m":[0.,0.,0.],"radius_m":300.}

func _initialize() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"label":label});print("BOMB01_CHECK ",ok," ",label)
	if not ok:failures+=1
func sea() -> Dictionary:
	var a: Dictionary=FIX.arena([FIX.spawn("bomber","us",Vector3(0,1800,5500),"us_b25j_1944_07",Vector3(0,0,-95))])
	assert(FIX.order(a.world,["bomber"],"level","",area).accepted)
	return a
func run() -> void:
	var a: Dictionary=sea();var first: int=-1
	for i: int in 100*60:
		a.world.step_ticks(1)
		for event: BattleEvent in a.world.drain_events():
			if event.kind=="bomb_released":first=event.tick
		if first>=0:break
	expect(first>0,"probe finds a natural release window without a release schedule")
	FIX.dispose(a)
	for condition: String in ["cancel","fuel"]:
		a=sea();var world: SimulationWorld=a.world
		world.step_ticks(first-2)
		var old: String=world.get_unit("bomber").active_order_id
		if condition=="cancel":
			var command: BattleCommand=BattleCommand.new();command.command_id="near_window_cancel";command.issuer_id="test_commander";command.faction_id="us";command.kind=BattleCommand.CANCEL_ORDER;command.payload={"order_id":old,"reason":"controlled_near_window_cancel"}
			expect(world.submit_command(command).accepted,"unified cancellation accepted immediately before natural release")
		else:world.get_unit("bomber").module_data.aircraft_motion.fuel_kg=30.0 # Controlled resource input.
		world.step_ticks(600)
		var unit: UnitState=world.get_unit("bomber")
		expect(int(unit.module_data.bomb_rack.released)==0 and a.stores.requests.is_empty(),condition+" immediately before window causes zero releases and clears requests")
		if condition=="cancel":
			expect(not a.delegate.states.has("bomber") and unit.active_order_id.is_empty(),"near-window cancellation releases the sole task owner")
			expect(FIX.order(world,["bomber"],"level","",area).accepted,"same aircraft can be reassigned after near-window cancellation")
			world.step_ticks(1)
			expect(a.delegate.states.bomber.order_id!=old and int(unit.module_data.bomb_rack.remaining)==6,"reassignment has fresh state and the original finite inventory")
		else:expect(unit.module_data.bombing.abort_reason=="fuel_reserve","real low-fuel condition reports its own abort reason")
		FIX.dispose(a)
	# A legal initial state too close to stabilise must miss rather than get a shot.
	a=FIX.arena([FIX.spawn("bomber","us",Vector3(0,1800,100),"us_b25j_1944_07",Vector3(0,0,-95))])
	assert(FIX.order(a.world,["bomber"],"level","",area).accepted);a.world.step_ticks(900)
	var short: UnitState=a.world.get_unit("bomber")
	expect(int(short.module_data.bomb_rack.released)==0 and short.module_data.bombing.abort_reason in ["target_passed","missed_release_window"],"insufficient actual stable run misses the target with no manufactured release")
	FIX.dispose(a)
	# The same goal at two actual distances changes detection and dispatch time.
	var times: Array=[]
	for distance: float in [5500.0,17000.0]:
		a=FIX.arena([FIX.spawn("bomber","us",Vector3(0,1800,distance),"us_b25j_1944_07",Vector3(0,0,-95)),FIX.spawn("target","jp",Vector3.ZERO,"jp_yukikaze_1942_06")])
		var world: SimulationWorld=a.world
		assert(world.register_module(load("res://scripts/bombing/commander.gd").new([{"id":"strike","order_type":"bombing","faction_id":"us","unit_ids":["bomber"],"target_id":"target","mode":"level"}])).accepted)
		var contact_s: float=-1;var command_s: float=-1;var release_s: float=-1
		for i: int in 190*60:
			world.step_ticks(1)
			if contact_s<0 and not CombatContacts.find(world,"us","target").is_empty():contact_s=world.time_s()
			if command_s<0 and not world.orders_snapshot().is_empty():command_s=world.time_s()
			for event: BattleEvent in world.drain_events():
				if event.kind=="bomb_released" and release_s<0:release_s=world.time_s()
			if release_s>=0:break
		var row: Dictionary={"distance_m":distance,"contact_s":contact_s,"command_s":command_s,"release_s":release_s};times.append(row);records.append(row)
		expect(contact_s>=0 and command_s>=contact_s and release_s>command_s,"real contact precedes command and natural release at distance "+str(distance))
		FIX.dispose(a)
	expect(float(times[1].command_s)>float(times[0].command_s)+10.0 and float(times[1].release_s)>float(times[0].release_s)+60.0,"changed initial distance delays detection, dispatch and actual release")
	# Controlled loss of the observer's sensors lets the actual contact expire.
	a=FIX.arena([FIX.spawn("bomber","us",Vector3(0,1800,5500),"us_b25j_1944_07",Vector3(0,0,-95)),FIX.spawn("target","jp",Vector3.ZERO,"jp_yukikaze_1942_06")])
	assert(a.world.register_module(load("res://scripts/bombing/commander.gd").new([{"id":"strike","order_type":"bombing","faction_id":"us","unit_ids":["bomber"],"target_id":"target","mode":"level"}])).accepted)
	a.world.step_ticks(120)
	a.config.data.unit_profiles.us_b25j_1944_07.visual_m=0.0;a.config.data.unit_profiles.us_b25j_1944_07.radar_ship_m=0.0
	a.world.step_ticks(1200)
	var lost: UnitState=a.world.get_unit("bomber")
	expect(CombatContacts.find(a.world,"us","target").is_empty() and lost.module_data.bombing.abort_reason=="target_lost" and int(lost.module_data.bomb_rack.released)==0,"expired own contact aborts the real attack without enemy truth or replacement bombs")
	FIX.dispose(a)
	var file: FileAccess=FileAccess.open("res://.local/transitions.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"));file.close()
	call_deferred("quit",0 if failures==0 else 1)
