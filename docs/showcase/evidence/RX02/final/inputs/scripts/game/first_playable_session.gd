class_name FirstPlayableSession
extends RefCounted

## The only scene-side writer advances the clock or resets it. No combat decisions here.
const SCENARIO: String = "res://data/scenarios/first_playable.json"
const FLEET_SUITE: String = "res://scripts/behaviors/fleet_formations/fleet_suite.gd"
const POSE_HISTORY: Script = preload("res://scripts/presentation/state/pose_history.gd")
var carrier_operations: SimulationModule
var bomb_stores: BombStores
var bombing_delegate: BombingMissionDelegate
var world: SimulationWorld
var catalog: DefinitionCatalog
var scenario: Dictionary = {}
var units: Dictionary = {}
var presentation_units: Dictionary = {}
var presentation_bombs: Dictionary = {}
var presentation_time_s: float = 0.0
var presentation_alpha: float = 1.0
var _pose_history: POSE_HISTORY
var _presentation_tick: int = -1
var orders: Array[Dictionary] = []
var journal: Array[Dictionary] = []
var counts: Dictionary = {}
var phases: Dictionary = {}
var event_samples: Dictionary = {}
var definition_index: Dictionary = {}
var outcomes: Dictionary = {}
var last_sequence: int = 0
var last_combat_s: float = 0.0
var ended_reason: String = ""
var generation: int = -1
var _orders_tick: int = -999
var _execution_signatures: Dictionary = {}

func load_battle(path: String = SCENARIO) -> PackedStringArray:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return ["scenario_invalid"]
	scenario = parsed
	catalog = DefinitionCatalog.new()
	var errors: PackedStringArray = catalog.load_files(_json_files("res://data/units"), _json_files("res://data/ammunition"), _json_files("res://data/units/weapons"))
	if not errors.is_empty(): return errors
	errors = GroundDeployments.expand(scenario,catalog)
	if not errors.is_empty(): return errors
	var previous_generation: int = world.generation if world != null else 0
	world = SimulationWorld.new()
	world.generation = previous_generation
	errors = world.configure(catalog, scenario)
	if not errors.is_empty(): return errors
	definition_index.clear()
	for id: String in world.unit_ids():
		var definition_id: String = world.get_unit(id).definition_id
		if definition_index.has(definition_id): continue
		var definition: UnitDefinition = catalog.unit(definition_id)
		var roles: Dictionary = {}
		for mount: MountSocket in definition.mounts: roles[mount.id] = mount.role
		definition_index[definition_id] = {"domain":definition.domain, "roles":roles}
	var terrain_path: String = str(scenario.environment.get("terrain_path", ""))
	if not terrain_path.is_empty():
		errors = BattlefieldTerrain.install(world, terrain_path)
		if not errors.is_empty(): return errors
	carrier_operations = null
	bomb_stores = null
	bombing_delegate = null
	if scenario.has("bombing_goals"):
		errors = _install_combat()
		if not errors.is_empty(): return errors
		var bomb_install: Dictionary = load("res://scripts/showcase/bombing/installer.gd").prepare(world)
		if not bomb_install.errors.is_empty(): return bomb_install.errors
		bomb_stores = bomb_install.stores
		bombing_delegate = bomb_install.delegate
	if scenario.has("carrier_operations"):
		var installer: Script = load("res://scripts/showcase/expansion/operations_installer.gd")
		var installed: Dictionary = installer.install(world,scenario.carrier_operations,bombing_delegate)
		errors = installed.errors
		carrier_operations = installed.operations
	elif bombing_delegate != null:
		var tasks: AircraftTasks = AircraftTasks.new()
		tasks.bombing_delegate = bombing_delegate
		for module: SimulationModule in [tasks,AircraftMotion.new()]:
			var receipt: Dictionary = world.register_module(module)
			if not receipt.accepted: return ["bombing_aircraft_install:"+str(receipt.reason)]
	elif scenario.has("aircraft_tasks_script"):
		var executor: Script = load(str(scenario.aircraft_tasks_script))
		if executor == null: return ["aircraft_executor_unavailable"]
		for module: SimulationModule in [executor.new(), AircraftMotion.new()]:
			var receipt: Dictionary = world.register_module(module)
			if not receipt.accepted: return ["aircraft_install:" + str(receipt.reason)]
	else:
		errors = AircraftSuite.install(world)
	if not errors.is_empty(): return errors
	if not scenario.has("bombing_goals"):
		errors = _install_combat()
		if not errors.is_empty(): return errors
	errors = GroundSuite.install(world)
	if not errors.is_empty(): return errors
	var fleet: FleetConfig = FleetConfig.new()
	errors = fleet.load_file()
	if not errors.is_empty(): return errors
	if scenario.has("fleet_profiles_path"):
		var additions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(scenario.fleet_profiles_path)))
		fleet.data.profiles.merge(additions,false)
	fleet.data.navigation.solids = scenario.environment.solids.duplicate(true)
	for faction: String in scenario.get("fleet_overrides", {}).get("commanders", {}):
		fleet.data.commanders[faction].merge(scenario.fleet_overrides.commanders[faction], true)
	if not ResourceLoader.exists(FLEET_SUITE): return ["fleet_suite_unavailable"]
	var installer: Script = load(FLEET_SUITE)
	errors = installer.install(world, fleet, true)
	if errors.is_empty() and scenario.has("bombing_goals"):
		for goal: Dictionary in scenario.bombing_goals:
			if str(goal.order_type) != "bombing": return ["bombing_commander_must_not_own_fighter_orders"]
		var receipt: Dictionary = world.register_module(BombingCommander.new(scenario.bombing_goals))
		if not receipt.accepted: return ["bombing_commander_install:"+str(receipt.reason)]
	if not errors.is_empty(): return errors
	_pose_history = POSE_HISTORY.new()
	var pose_receipt: Dictionary = world.register_module(_pose_history)
	if not pose_receipt.accepted: return ["presentation_sampler_registration_failed"]
	_clear_view()
	return errors

func restart() -> bool:
	if world == null or not world.reset(): return false
	_clear_view()
	return true

func _clear_view() -> void:
	units.clear()
	presentation_units.clear()
	presentation_bombs.clear()
	_presentation_tick = -1
	orders.clear()
	journal.clear()
	counts.clear()
	phases.clear()
	event_samples.clear()
	outcomes.clear()
	_execution_signatures.clear()
	last_sequence = 0
	last_combat_s = 0.0
	ended_reason = ""
	generation = world.generation
	_orders_tick = -999
	refresh_view(true)

func advance(delta_s: float, tick_budget: int = 16) -> Array[BattleEvent]:
	if ended_reason.is_empty(): world.advance(delta_s, tick_budget)
	return consume_world(true)

func consume_world(interpolate: bool = false) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = world.drain_events()
	consume(events)
	refresh_view(false,interpolate)
	_check_end()
	return events

func consume(events: Array[BattleEvent]) -> void:
	for event: BattleEvent in events:
		if event.sequence <= last_sequence: continue
		last_sequence = event.sequence
		counts[event.kind] = int(counts.get(event.kind, 0)) + 1
		if event.kind in ["fired", "hit", "damaged", "salvo", "airburst", "surface_impact", "disabled", "damage_phase", "aircraft_exit", "ship_exit"]:
			if not event_samples.has(event.kind): event_samples[event.kind] = event.snapshot()
		if event.kind in ["fired", "hit", "damaged"]: last_combat_s = event.time_s
		if event.kind == "fired":
			var definition: Dictionary = definition_index[world.get_unit(event.entity_id).definition_id]
			var category: String = "aircraft_fire" if definition.domain == "aircraft" else ("main_gun_fire" if definition.roles.get(event.weapon_id.get_slice("/", 1), "") == "main" else "ship_support_fire")
			if definition.domain=="ground":category="coastal_gun_fire" if definition.roles.get(event.weapon_id.get_slice("/",1),"")=="main" else "ground_aa_fire"
			counts[category] = int(counts.get(category, 0)) + 1
			if not event_samples.has(category): event_samples[category] = event.snapshot()
		if event.kind == "damage_phase":
			var phase: String = event.data.get("phase", "")
			if phase == "sinking": outcomes[event.entity_id] = "sinking"
			elif phase == "crashing": outcomes[event.entity_id] = "crashed"
			elif phase == "wreck" and definition_index[world.get_unit(event.entity_id).definition_id].domain == "ship": outcomes[event.entity_id] = "sunk"
			elif phase == "disabled" and not outcomes.has(event.entity_id): outcomes[event.entity_id] = "disabled"
			if event.data.get("domain","")=="ground":
				if phase=="wreck":outcomes[event.entity_id]="ground_destroyed"
				elif phase=="disabled":outcomes[event.entity_id]="ground_disabled"
		elif event.kind == "unit_impact":
			outcomes[event.entity_id] = "crashed" if bool(event.data.get("destroyed", false)) else "ditched"
		elif event.kind in ["aircraft_exit", "ship_exit"]: outcomes[event.entity_id] = "withdrawn"
		if event.kind in ["order_issued", "order_status_changed", "order_assignments_changed", "order_execution_changed"]:
			var record: Dictionary = event.data
			if event.kind == "order_execution_changed":
				var execution: Dictionary = record.get("execution", {}).get(event.entity_id, {})
				var signature: String = str(execution.get("status", "")) + ":" + str(execution.get("reason", ""))
				var key: String = str(record.get("order_id", "")) + ":" + event.entity_id
				if _execution_signatures.get(key, "") == signature: continue
				_execution_signatures[key] = signature
			journal.append({"kind":event.kind, "time_s":event.time_s, "entity_id":event.entity_id, "record":record.duplicate(true), "position_m":event.position_m, "sequence":event.sequence})
		elif event.kind == "command_rejected" and event.data.get("kind", "") in [BattleCommand.ISSUE_ORDER, BattleCommand.CANCEL_ORDER]:
			journal.append({"kind":event.kind, "time_s":event.time_s, "entity_id":event.entity_id, "record":event.data.duplicate(true), "position_m":event.position_m, "sequence":event.sequence})
		while journal.size() > 240: journal.pop_front()

func refresh_view(force_orders: bool = false, interpolate: bool = false) -> Dictionary:
	# One copied unit view per frame; never copy the projectile snapshot in the hot path.
	for id: String in world.unit_ids():
		var view: Dictionary = world.get_unit(id).snapshot()
		units[id] = view
		var task: Dictionary = view.task.get(definition_index[view.definition_id].domain, {})
		if not task.is_empty():
			var key: String = id + ":" + str(task.get("phase", "")) + ":" + str(task.get("reason", ""))
			phases[key] = true
	if force_orders or world.tick - _orders_tick >= 30:
		orders = world.orders_snapshot()
		_orders_tick = world.tick
	_refresh_presentation(interpolate)
	return {"generation":generation, "tick":world.tick, "time_s":world.time_s(), "units":units}

func _refresh_presentation(interpolate: bool) -> void:
	if _pose_history == null: return
	# Pausing holds the already displayed sub-tick pose, without a forward snap.
	if interpolate and world.paused and _presentation_tick == world.tick: return
	presentation_alpha = world.interpolation_alpha() if interpolate else 1.0
	presentation_units = _pose_history.interpolate(units,presentation_alpha)
	presentation_bombs = _pose_history.interpolate_bombs(presentation_alpha)
	presentation_time_s = lerpf(float(_pose_history.previous_tick),float(_pose_history.current_tick),presentation_alpha)*world.fixed_delta_s()
	_presentation_tick = world.tick

func finish(reason: String = "manual") -> void:
	if not ended_reason.is_empty(): return
	ended_reason = reason
	world.set_paused(true)
	refresh_view(true,true)

func _check_end() -> void:
	if not ended_reason.is_empty(): return
	var now: float = world.time_s()
	var settings: Dictionary = scenario.presentation
	if now >= float(settings.duration_s):
		finish("duration")
		return
	if now < float(settings.minimum_duration_s): return
	var capable: Dictionary = {"jp":0, "us":0}
	for view: Dictionary in units.values():
		if view.active: capable[view.faction_id] += 1
	if int(capable.jp) == 0 or int(capable.us) == 0:
		finish("force_depleted")
		return
	if now - last_combat_s < float(settings.disengaged_after_s): return
	var min_distance: float = INF
	for a: Dictionary in units.values():
		if not a.active or a.faction_id != "jp": continue
		for b: Dictionary in units.values():
			if b.active and b.faction_id == "us": min_distance = minf(min_distance, (a.position_m as Vector3).distance_to(b.position_m))
	if min_distance > 16000.0: finish("disengaged")
	elif not orders.is_empty() and orders.all(func(o: Dictionary) -> bool: return o.status in BattleOrder.TERMINAL): finish("tasks_finished")

func report() -> Dictionary:
	var result: Dictionary = {}
	for faction: String in ["jp", "us"]:
		var row: Dictionary = {"ships":0, "aircraft":0, "ground":0, "ground_destroyed":0, "ground_disabled":0, "sinking":0, "sunk":0, "crashed":0, "disabled":0, "ditched":0, "withdrawn":0, "rounds_left":0, "rounds_used":0, "fuel_used_kg":0.0}
		for view: Dictionary in units.values():
			if view.faction_id != faction: continue
			var domain: String = definition_index[view.definition_id].domain
			if view.active: row[{"ship":"ships","aircraft":"aircraft","ground":"ground"}[domain]] += 1
			var outcome: String = outcomes.get(view.id, "")
			if row.has(outcome): row[outcome] += 1
			row.fuel_used_kg += float(view.module_data.get("aircraft_motion", {}).get("fuel_used_kg", 0.0))
			row.rounds_used += int(view.module_data.get("combat_runtime", {}).get("shots_fired", 0))
			for gun: Dictionary in view.weapons.values():
				for remaining: int in gun.remaining_rounds: row.rounds_left += remaining
		result[faction] = row
	return result

static func _json_files(directory: String) -> Array[String]:
	var result: Array[String] = []
	for file: String in DirAccess.get_files_at(directory):
		if file.ends_with(".json"): result.append(directory.path_join(file))
	result.sort()
	return result

func _install_combat() -> PackedStringArray:
	var combat: CombatConfig = CombatConfig.new()
	var errors: PackedStringArray = combat.load_file("res://data/combat/showcase.json")
	if not errors.is_empty(): return errors
	if scenario.has("combat_overlay_path"):
		var overlay: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(scenario.combat_overlay_path)))
		if not overlay is Dictionary: return ["combat_overlay_invalid"]
		for key: String in ["unit_profiles", "weapon_profiles", "ammo_profiles"]:
			combat.data[key].merge(overlay.get(key, {}), false)
		for id: String in scenario.get("combat_profile_override_ids",[]):
			if not overlay.get("unit_profiles",{}).has(id): return ["missing_explicit_combat_override:"+id]
			combat.data.unit_profiles[id] = overlay.unit_profiles[id].duplicate(true)
		errors = combat.load_data(combat.data)
		if not errors.is_empty(): return errors
	# Explicit environment is shared by collision and fleet coastline navigation.
	combat.data.environment = scenario.environment.duplicate(true)
	errors = CombatSuite.install(world, combat)
	if not errors.is_empty(): return errors
	return errors
