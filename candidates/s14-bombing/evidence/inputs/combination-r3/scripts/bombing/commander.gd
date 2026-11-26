class_name BombingCommander
extends SimulationModule

## Scenario goals and ordinary decision cadence; no hit/loss timetable or poses.
## The only enemy information read here is the faction's real contact records.
var goals: Array
var dispatched: Dictionary = {}
var serial: int = 0
var next_decision_s: Dictionary = {}
func _init(requests: Array) -> void:
	module_id="bombing_commander"
	priority=250
	goals=requests.duplicate(true)
func reset(world_ref: RefCounted) -> void:
	dispatched.clear();next_decision_s.clear();serial=0
	var world: SimulationWorld=world_ref as SimulationWorld
	for goal: Dictionary in goals:
		if goal.order_type!="bombing" or str(goal.get("target_id","")).length()>0: continue
		if not world.shared_state.has("bombing_known_areas"):world.shared_state["bombing_known_areas"]={}
		if not world.shared_state.bombing_known_areas.has(goal.faction_id):world.shared_state.bombing_known_areas[goal.faction_id]={}
		world.shared_state.bombing_known_areas[goal.faction_id][goal.area_id]=goal.area.duplicate(true)
func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	var world: SimulationWorld=world_ref as SimulationWorld
	for goal: Dictionary in goals:
		if world.time_s() < float(next_decision_s.get(str(goal.id),0.0)):continue
		next_decision_s[str(goal.id)] = world.time_s()+1.0
		if dispatched.has(str(goal.id)):
			if goal.order_type == "bombing": continue # One finite sortie, not unlimited re-arming.
			var active: Dictionary = {}
			for order: Dictionary in world.orders_snapshot():
				if order.order_id == dispatched[str(goal.id)]: active=order;break
			if not active.is_empty() and active.status not in BattleOrder.TERMINAL and not CombatContacts.find(world,str(goal.faction_id),str(active.target_id)).is_empty():continue
			# Lost/finished nomination: rescore only real currently observed contacts.
			dispatched.erase(str(goal.id))
		var alive: Array=[]
		for id: String in goal.unit_ids:
			var unit: UnitState=world.get_unit(id)
			if unit==null or not unit.active or unit.faction_id!=goal.faction_id:continue
			if goal.order_type=="intercept":
				var count: int=0
				for weapon: WeaponState in unit.weapons.values():
					for rounds: int in weapon.remaining_rounds:count+=rounds
				if count==0 or float(unit.module_data.get("aircraft_motion",{}).get("fuel_kg",0))<80.0:continue
			alive.append(id)
		if alive.is_empty():continue
		var target_id: String=str(goal.get("target_id",""))
		if goal.order_type=="intercept":
			var point: Vector3=world.get_unit(alive[0]).position_m
			if not target_id.is_empty():
				var nominated: Dictionary=CombatContacts.find(world,str(goal.faction_id),target_id)
				if nominated.is_empty() or nominated.domain != "aircraft":continue
			var best: float=INF
			for contact: Dictionary in world.shared_state.get("combat_contacts",{}).get(goal.faction_id,{}).values():
				if not contact.fresh or not contact.valid or contact.domain!="aircraft":continue
				if not str(goal.get("target_id","")).is_empty() and contact.entity_id != goal.target_id:continue
				var distance: float=point.distance_squared_to(contact.position_m)
				if distance<best:best=distance;target_id=str(contact.entity_id)
			if target_id.is_empty():continue
		elif not target_id.is_empty() and CombatContacts.find(world,str(goal.faction_id),target_id).is_empty():continue
		serial+=1
		var data: Dictionary={"order_id":"bombing_commander_%d"%serial,"issuer_id":"commander_"+str(goal.faction_id),"source":"ai","faction_id":goal.faction_id,"recipient_ids":alive,"order_type":goal.order_type,"target_id":target_id,"intent":"Attack assigned area" if goal.order_type=="bombing" else "Intercept own observed aircraft contact"}
		if goal.order_type=="bombing":
			data["bombing"]={"mode":goal.mode}
			if target_id.is_empty():data["area"]=goal.area.duplicate(true);data.bombing["area_id"]=goal.area_id
		var receipt: Dictionary=world.submit_order(BattleOrder.from_data(data))
		if receipt.accepted:dispatched[str(goal.id)]=data.order_id
func snapshot_state() -> Dictionary:
	return {"dispatched":dispatched.duplicate(true)}
