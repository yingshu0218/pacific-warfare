class_name GroundTasks
extends SimulationModule
## Fixed positions: patrol = air/sea sector watch, engage = specified contact.
var serial: int = 0
var signatures: Dictionary = {}
var targets: Dictionary = {}
var last_contact_s: Dictionary = {}

func _init() -> void:
	module_id="ground_tasks";priority=315

func supported_order_types() -> PackedStringArray: return ["patrol","engage"]
func order_domains() -> PackedStringArray: return ["ground"]

func accept_order(world_ref: RefCounted, order: BattleOrder, ids: Array[String]) -> Dictionary:
	var world: SimulationWorld = world_ref as SimulationWorld
	if order.order_type=="engage":
		var domain: String = world.unit_definition(world.get_unit(order.target_id).definition_id).domain
		for id: String in ids:
			var role: String = world.get_unit(id).module_data.ground_initial.role
			if domain != ("ship" if role=="coastal_gun" else "aircraft"): return {"accepted":false,"reason":"ground_incompatible_target"}
	return {"accepted":true,"reason":"ground_executor_capable"}

func reset(world_ref: RefCounted) -> void:
	serial=0;signatures.clear();targets.clear();last_contact_s.clear()
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if world.unit_definition(unit.definition_id).domain=="ground":
			unit.module_data["combat_intent"]={"fire":false,"allow_aa":false}
			unit.task.erase("ground")

func on_order_units_released(world_ref: RefCounted, _order: BattleOrder, ids: Array[String], _reason: String) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in ids:
		var unit: UnitState = world.get_unit(id)
		unit.module_data["combat_intent"]={"fire":false,"allow_aa":false}
		unit.task.erase("ground");signatures.erase(id);last_contact_s.erase(id)
		_set_target(world,unit,"")

func fixed_update(world_ref: RefCounted, _dt: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for order: Dictionary in world.orders_snapshot():
		for id: String in world.owned_order_unit_ids(order.order_id,"ground"):
			var unit: UnitState = world.get_unit(id)
			var coastal: bool = unit.module_data.ground_initial.role=="coastal_gun"
			var domain: String = "ship" if coastal else "aircraft"
			var contact: Dictionary = {}
			if order.order_type=="engage": contact=CombatContacts.find(world,unit.faction_id,order.target_id)
			else:
				var closest: float = INF
				for seen: Dictionary in world.shared_state.get("combat_contacts",{}).get(unit.faction_id,{}).values():
					if not seen.valid or not seen.fresh or seen.domain!=domain: continue
					if not order.area.is_empty() and (seen.position_m as Vector3).distance_to(SimData.vec3(order.area.center_m))>float(order.area.radius_m): continue
					var distance: float = unit.position_m.distance_to(seen.position_m)
					if distance<closest: closest=distance;contact=seen
			if not last_contact_s.has(id):last_contact_s[id]=world.time_s()
			if not contact.is_empty():last_contact_s[id]=world.time_s()
			elif order.order_type=="engage" and world.time_s()-float(last_contact_s[id])>32.0:
				world.report_order_unit_status(order.order_id,id,"failed","contact_not_reacquired","search_exhausted")
				continue
			var rounds: int = 0
			for weapon: WeaponState in unit.weapons.values():
				if weapon.enabled:
					for count: int in weapon.remaining_rounds: rounds+=count
			var target: String = str(contact.get("entity_id","")) if rounds>0 else ""
			_set_target(world,unit,target)
			unit.module_data["combat_intent"]={"fire":not target.is_empty(),"allow_aa":not coastal and not target.is_empty(),"lock_target":true}
			var statuses: Dictionary = unit.module_data.get("combat_runtime",{}).get("mount_status",{})
			var reason: String = "sector_watch" if contact.is_empty() else "tracking_contact"
			var phase: String = "shore_watch" if coastal else "area_air_defence"
			if rounds==0:reason="no_ammunition";phase="ground_blocked"
			elif unit.cease_fire:reason="hold_fire";phase="ground_blocked"
			elif not target.is_empty():
				phase="ground_engage"
				for status: String in statuses.values():
					if status in ["arc","terrain_masked","masked","out_of_range","traversing","reloading","fired"]:reason=status;break
			unit.task["ground"]={"order_id":order.order_id,"phase":phase,"reason":reason,"target_id":target,"site_id":unit.module_data.ground_initial.site_id}
			var signature: String = order.order_id+":"+phase+":"+reason
			if signatures.get(id,"")!=signature:
				signatures[id]=signature
				world.report_order_unit_status(order.order_id,id,"executing",reason,phase)

func _set_target(world: SimulationWorld, unit: UnitState, target: String) -> void:
	if not unit.active: targets.erase(unit.id);return
	if str(targets.get(unit.id,unit.target_id))==target:return
	serial+=1
	var command: BattleCommand = BattleCommand.new()
	command.command_id="ground_target:%d:%s"%[serial,unit.id]
	command.issuer_id=module_id;command.faction_id=unit.faction_id;command.entity_id=unit.id
	command.kind=BattleCommand.SET_TARGET;command.payload={"target_id":target}
	if world.submit_command(command).accepted:targets[unit.id]=target

func snapshot_state() -> Dictionary:
	return {"serial":serial,"signatures":signatures.duplicate(true),"targets":targets.duplicate(true),"last_contact_s":last_contact_s.duplicate(true)}
