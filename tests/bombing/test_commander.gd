extends SceneTree
const FIX: Script=preload("res://tests/bombing/fixture.gd")
var failures: int=0
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"label":label});print("BOMB01_CHECK ",ok," ",label)
	if not ok:failures+=1
func run() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("fighter","us",Vector3(0,1800,0),"us_f6f5_1944",Vector3(0,0,-100)),FIX.spawn("unseen","jp",Vector3(0,1800,-22000),"jp_g4m1_1942_07",Vector3(0,0,-87))])
	var world: SimulationWorld=a.world
	assert(world.register_module(load("res://scripts/bombing/commander.gd").new([{"id":"guard","order_type":"intercept","faction_id":"us","unit_ids":["fighter"],"target_id":"unseen"}])).accepted)
	world.step_ticks(120)
	expect(world.orders_snapshot().is_empty(),"explicit enemy ID without own fresh contact cannot dispatch interception")
	FIX.dispose(a)
	a=FIX.arena([FIX.spawn("fighter","us",Vector3(0,1800,6500),"us_f6f5_1944",Vector3(0,0,-143)),FIX.spawn("near","jp",Vector3(0,1800,5500),"jp_g4m1_1942_07",Vector3(0,0,-87)),FIX.spawn("other","jp",Vector3(400,1800,5000),"jp_g4m1_1942_07",Vector3(0,0,-87))]);world=a.world
	assert(world.register_module(load("res://scripts/bombing/commander.gd").new([{"id":"guard","order_type":"intercept","faction_id":"us","unit_ids":["fighter"]}])).accepted)
	world.step_ticks(120)
	expect(world.orders_snapshot().size()>=1 and world.orders_snapshot()[0].target_id=="near","interceptor nominates nearest own observed contact")
	world.get_unit("near").active=false # controlled external loss, not an AI world-state read
	world.step_ticks(600)
	var retargeted: bool=false
	for order: Dictionary in world.orders_snapshot():
		if order.target_id=="other":retargeted=true
	expect(retargeted,"persistent interception reacquires remaining contact after first target loss")
	FIX.dispose(a)
	var file: FileAccess=FileAccess.open("res://.local/commander.json",FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	call_deferred("_exit",0 if failures==0 else 1)
func _exit(code: int) -> void:quit(code)
