extends SceneTree

class ContactDropout extends SimulationModule:
	func _init() -> void:module_id="controlled_test_sensor_dropout";priority=150
	func fixed_update(world_ref: RefCounted,_dt: float) -> void:
		var world: SimulationWorld=world_ref as SimulationWorld
		if world.time_s()<5:return
		# Controlled missing sensor input, never an enemy pose/damage injection.
		world.shared_state.get("combat_contacts",{}).get("us",{}).erase("target")
		world.set_contacts("us",[])

var checks: Array=[]
var failures: int=0
var output: String="res://variants.json"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"label":label})
	if not ok:failures+=1;printerr("CHECK FAILED ",label)

func run() -> void:
	var results: Array=[]
	for mode: String in ["near","far","low_fuel","empty","lost_contact"]:
		var s: FirstPlayableSession=FirstPlayableSession.new()
		var path: String="res://data/scenarios/s14_attack_b25.json" if mode in ["near","lost_contact"] else "res://tests/s14_bombing/fixtures/"+mode+".json"
		check(s.load_battle(path).is_empty(),mode+" explicit scenario inputs validate")
		if mode=="lost_contact":s.world.register_module(ContactDropout.new())
		var events: Array=[];var first_order: float=-1
		for tick: int in range(60*(210 if mode=="far" else 120)):
			s.world.step_ticks(1)
			if tick%30!=0:continue
			for event: BattleEvent in s.consume_world():
				if event.kind.begins_with("bomb") or event.kind in ["damaged","damage_phase","unit_impact"]:events.append(event.snapshot())
			for order: Dictionary in s.orders:
				if order.order_type=="bombing" and first_order<0:first_order=float(order.issued_tick)/60.0
		var releases: Array=events.filter(func(e: Dictionary)->bool:return e.kind=="bomb_released")
		var reasons: Array=[]
		for event: Dictionary in events:
			if event.kind=="bombing_phase" and event.data.phase=="pullout":reasons.append(event.data.reason)
		if mode in ["low_fuel","empty","lost_contact"]:
			check(releases.is_empty(),mode+" actual input prevents release")
			check(reasons.has({"low_fuel":"fuel_reserve","empty":"empty_load","lost_contact":"target_lost"}[mode]),mode+" actual reason reported by sole mission delegate")
			check(not s.world.orders_snapshot().any(func(o: Dictionary)->bool:return o.order_type=="retreat" and o.recipient_ids.has("bomber")),mode+" no generic fighter retreat steals pullout/egress")
		results.append({"mode":mode,"first_order_s":first_order,"released":releases.size(),"abort_reasons":reasons,"events":events})
	check(float(results[1].first_order_s)>float(results[0].first_order_s)+30,"far approach delays own contact-driven order, not an elapsed-time show")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(clean({"checks":checks,"failed":failures,"cases":results}),"\t"))
	print("VARIANTS checks=",checks.size()," failed=",failures);quit(0 if failures==0 else 1)

static func clean(value: Variant) -> Variant:
	if value is Vector3:return SimData.array3(value)
	if value is Dictionary:
		var result: Dictionary={}
		for key: String in value:result[key]=clean(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value:result.append(clean(item))
		return result
	return value
