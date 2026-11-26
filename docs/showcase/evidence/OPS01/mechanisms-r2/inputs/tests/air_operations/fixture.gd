extends RefCounted

const TASK_BRIDGE: Script = preload("res://scripts/air_operations/task_bridge.gd")
const FLIGHT_BRIDGE: Script = preload("res://scripts/air_operations/flight_bridge.gd")
const DECK_MOTION: Script = preload("res://scripts/air_operations/deck_motion.gd")
const WRECK_SUPPORT: Script = preload("res://scripts/air_operations/deck_contact_support.gd")
const CARRIER: String = "us_essex_cv9_1944_04_15"

static func build(count: int = 1) -> Dictionary:
	assert(count in [1,2],"OPS01 first-stage fixture supports one or two F6Fs")
	var catalog: DefinitionCatalog = AircraftFixture.catalog()
	# Private definition is intentionally not registered under data/units.
	catalog._units[CARRIER] = {"id":CARRIER,"display_name":"USS Essex CV-9 / OPS private noncombat fixture","country_id":"us","domain":"ship","service_entry_year":1942,"configuration_date":"1944-04-15","dimensions_m":[44.98,40.5,265.786],"model_scene":"res://naval/essex_cv9_1944_04_15/essex.tscn","weapon_definitions":[],"mounts":[],"historical_fixed_armament":[],"dedicated_aa_historical":[],"dedicated_aa_game":[],"source":{"status":"provisional","scope":"OPS movement/visual fixture only; historical weapons remain CV01, not admitted combat"}}
	var spawns: Array = [{"id":"essex","unit_definition_id":CARRIER,"faction_id":"us","position_m":[0,0,0],"velocity_mps":[0,0,-15.0],"rotation_rad":[0,0,0],"module_data":{"ship_control":{"goal_m":Vector3(0,0,-1000000),"speed_mps":15.0}}}]
	for i: int in range(count):
		var spawn: Dictionary = AircraftFixture.spawn("hellcat_%d"%(i+1),"us",Vector3(-3,18.15,75+i*30),"us_f6f5_1944",0,15.0)
		spawn.module_data["carrier_initial"] = {"carrier_id":"essex"}
		spawns.append(spawn)
	var world: SimulationWorld = SimulationWorld.new()
	assert(world.configure(catalog,{"id":"OPS01_stage1","seed":11011,"tick_hz":60,"factions":["us","jp"],"spawns":spawns}).is_empty())
	var ops: CarrierOperations = CarrierOperations.new()
	var tasks: AircraftTasks = TASK_BRIDGE.new()
	tasks.set("operations",ops)
	var flight: AircraftMotion = FLIGHT_BRIDGE.new()
	flight.set("operations",ops)
	var ground: SimulationModule = DECK_MOTION.new()
	ground.set("operations",ops)
	var fleet: FleetConfig = FleetConfig.new()
	assert(fleet.load_file().is_empty())
	fleet.data.profiles[CARRIER] = {"historical_max_knots":32.7,"cruise_mps":15.0,"acceleration_mps2":0.08,"braking_mps2":0.12,"coast_drag_mps2":0.02,"turn_radius_m":950.0,"yaw_acceleration_degps2":0.015,"engagement_range_m":10000.0,"flag_rank":1}
	for module: SimulationModule in [tasks,ops,flight,ShipMotion.new(fleet),ground]: assert(world.register_module(module).accepted)
	var fixture: Dictionary = {"world":world,"operations":ops,"tasks":tasks,"flight":flight,"ground":ground}
	fixture["damage"] = damage_modules(fixture)
	var support: SimulationModule = WRECK_SUPPORT.new(); support.set("operations",ops)
	assert(world.register_module(support).accepted)
	world.reset()
	# Same fleet integrator, continuously advancing goal, no movement animation.
	world.get_unit("essex").module_data["ship_control"] = {"goal_m":Vector3(0,0,-1000000),"speed_mps":15.0}
	return fixture

static func damage_modules(fixture: Dictionary) -> CombatDamage:
	if fixture.has("damage"): return fixture.damage as CombatDamage
	var config: CombatConfig = CombatConfig.new()
	assert(config.load_file("res://data/combat/showcase.json").is_empty())
	# Noncombat carrier test profile only initializes damage ownership. It is
	# neither a gun/collision admission nor a historical protection model.
	config.data.unit_profiles[CARRIER] = {"structure":10000.0,"boxes":[]}
	var frame: CombatFrame = CombatFrame.new(config)
	assert((fixture.world as SimulationWorld).register_module(frame).accepted)
	var damage: CombatDamage = CombatDamage.new(config,frame)
	assert((fixture.world as SimulationWorld).register_module(damage).accepted)
	return damage

static func sortie(world: SimulationWorld, ids: Array, order_id: String = "carrier_patrol", source: String = "ai") -> Dictionary:
	var order: BattleOrder = BattleOrder.new()
	order.order_id = order_id; order.issuer_id = "carrier_commander"; order.faction_id = "us"
	order.source = source
	order.recipient_ids.assign(ids); order.order_type = "patrol"; order.target_id = "essex"
	order.area = {"center_m":[-1000,700,-3500],"radius_m":1200.0}
	order.intent = "carrier_sortie_patrol_return"
	return world.submit_order(order)

static func cancel(world: SimulationWorld, order_id: String) -> Dictionary:
	var command: BattleCommand = BattleCommand.new()
	command.command_id = "cancel_"+order_id; command.issuer_id = "carrier_commander"; command.source = "human"; command.faction_id = "us"
	command.kind = BattleCommand.CANCEL_ORDER; command.payload = {"order_id":order_id,"reason":"observer_cancelled_sortie"}
	return world.submit_command(command)

static func json_data(value: Variant) -> Variant:
	if value is Vector3: return SimData.array3(value)
	if value is Dictionary:
		var out: Dictionary = {}
		for key: String in value: out[key] = json_data(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value: out.append(json_data(item))
		return out
	return value
