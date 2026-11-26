extends SceneTree

const FIXTURE: Script = preload("res://tests/fixtures/simulation_fixture.gd")
var failures: int = 0

class OrderProbe extends SimulationModule:
	var ended: Dictionary = {}
	var updates: Dictionary = {}
	var complete_after_ticks: int = 0
	var domain: String = ""
	var released_ids: Array[String] = []
	func _init() -> void:
		module_id = "test_order_executor"
		priority = 100
	func supported_order_types() -> PackedStringArray:
		return ["patrol", "engage", "escort", "intercept", "retreat"]
	func order_domains() -> PackedStringArray:
		return ["ship", "aircraft"] if domain.is_empty() else PackedStringArray([domain])
	func reset(_world: RefCounted) -> void:
		ended.clear()
		updates.clear()
		released_ids.clear()
	func accept_order(world_ref: RefCounted, order: BattleOrder, entity_ids: Array[String]) -> Dictionary:
		var world: SimulationWorld = world_ref as SimulationWorld
		if order.order_type == "engage":
			for id: String in entity_ids:
				if world.unit_definition(world.get_unit(id).definition_id).domain != "ship":
					return {"accepted": false, "reason": "test_executor_requires_ship"}
		return {"accepted": true, "reason": "test_executor_accepted"}
	func fixed_update(world_ref: RefCounted, _delta_s: float) -> void:
		var world: SimulationWorld = world_ref as SimulationWorld
		for record: Dictionary in world.orders_snapshot():
			if record.status in BattleOrder.TERMINAL:
				continue
			var owned: Array[String] = world.owned_order_unit_ids(record.order_id, domain)
			if owned.is_empty():
				continue
			for id: String in owned:
				if record.execution[id].status == "received":
					world.report_order_unit_status(record.order_id, id, "executing", "test_execution_started")
			updates[record.order_id] = int(updates.get(record.order_id, 0)) + 1
			for id: String in owned:
				world.report_order_unit_progress(record.order_id, id, "test updates %d" % updates[record.order_id], "actual_unit_test_update_count")
			world.report_order_progress(record.order_id, "test updates %d" % updates[record.order_id], "actual_test_update_count")
			if complete_after_ticks > 0 and int(updates[record.order_id]) >= complete_after_ticks:
				for id: String in owned:
					world.report_order_unit_status(record.order_id, id, "completed", "test_counter_reached")
		world.set_contacts("us", [{"entity_id": "yamato_01", "last_position_m": [90.0, 0.0, 80.0], "last_seen_tick": 0}])
	func on_order_ended(_world: RefCounted, order: BattleOrder) -> void:
		ended[order.order_id] = order.status
	func on_order_units_released(_world: RefCounted, _order: BattleOrder, ids: Array[String], _reason: String) -> void:
		released_ids.append_array(ids)
	func snapshot_state() -> Dictionary:
		return {"updates": updates.duplicate(true), "ended": ended.duplicate(true), "released_ids": released_ids.duplicate()}

func _initialize() -> void:
	call_deferred("run_test")

func expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func make_world(with_orders: bool = true) -> SimulationWorld:
	var result: SimulationWorld = SimulationWorld.new()
	expect(result.configure(FIXTURE.catalog(), FIXTURE.scenario()).is_empty(), "Configured command test world")
	if with_orders:
		expect(result.register_module(OrderProbe.new()).accepted, "Registered controlled executor")
	return result

func order_by_id(world: SimulationWorld, id: String) -> Dictionary:
	for record: Dictionary in world.orders_snapshot():
		if record.order_id == id:
			return record
	return {}

func run_test() -> void:
	var world: SimulationWorld = make_world()
	var first: BattleCommand = FIXTURE.command("first", BattleCommand.CEASE_FIRE, {"enabled": false})
	var second: BattleCommand = FIXTURE.command("second", BattleCommand.CEASE_FIRE, {"enabled": true})
	first.execute_tick = 2
	second.execute_tick = 2
	expect(world.submit_command(first).accepted and world.submit_command(second).accepted, "Valid commands queued")
	expect(world.submit_command(second).duplicate, "Repeated identical submission is idempotent")
	second.payload.enabled = false
	expect(world.submit_command(second).reason == "duplicate_id_conflict", "Same request ID with altered input rejected")
	world.step_ticks(1)
	expect(not world.get_unit("f6f_01").cease_fire, "Future command not applied early")
	world.step_ticks(1)
	expect(world.get_unit("f6f_01").cease_fire, "Same-tick commands retain submission order and copied payload")
	var applied: Array[String] = []
	for event: BattleEvent in world.drain_events():
		if event.kind == "command_applied":
			applied.append(event.data.command_id)
	expect(applied == ["first", "second"], "Duplicate command only applied once")
	var wrong: BattleCommand = FIXTURE.command("wrong_faction", BattleCommand.CEASE_FIRE, {"enabled": true}, "yamato_01")
	expect(world.submit_command(wrong).reason == "wrong_faction", "Cannot command hostile entity")
	expect(world.submit_command(wrong).duplicate, "Identical rejected command also deduplicates")
	var target: BattleCommand = FIXTURE.command("target", BattleCommand.SET_TARGET, {"target_id": "yamato_01"})
	expect(world.submit_command(target).accepted, "Target intent queued through same command path")
	world.get_unit("yamato_01").active = false
	world.step_ticks(1)
	expect(world.get_unit("f6f_01").target_id.is_empty(), "Target invalidated before execution is rejected without stale reference")
	world.reset()
	expect(not world.submit_order(FIXTURE.order("no_handler"), world.tick).accepted, "Commands scheduled in the past rejected")
	var unsupported: SimulationWorld = make_world(false)
	expect(unsupported.submit_order(FIXTURE.order("unsupported")).reason == "order_executor_not_registered", "No pretend execution without task module")
	var order: BattleOrder = FIXTURE.order("patrol_01")
	expect(world.submit_order(order).accepted and world.submit_order(order).duplicate, "Order helper uses idempotent common queue")
	order.area.radius_m = 1.0
	world.set_paused(true)
	world.advance(100.0)
	expect(world.orders_snapshot().is_empty(), "Queued high-level order does not dispatch while paused")
	world.set_paused(false)
	world.step_ticks(1)
	var active: Dictionary = order_by_id(world, "patrol_01")
	expect(active.status == "executing" and active.issued_tick == 1 and active.received_tick == 1, "Real dispatch and executor transition recorded at fixed tick")
	expect(active.area.radius_m == 2000.0 and active.history.size() == 3, "Order request detached and issued/received/executing history preserved")
	expect(world.get_unit("f6f_02").active_order_id == "patrol_01", "Formation recipient fans out to both units")
	var own: Dictionary = world.commander_snapshot("us")
	var enemy: Dictionary = world.commander_snapshot("jp")
	expect(not own.units.has("yamato_01") and enemy.orders.is_empty(), "Commander input never exposes hostile live state or hostile orders")
	expect(own.contacts[0].last_position_m == [90.0, 0.0, 80.0], "Commander receives supplied last contact, not exact enemy position")
	own.orders[0].progress = "forged observer data"
	expect(order_by_id(world, "patrol_01").progress != "forged observer data", "Read views cannot forge task progress")
	var human_order: BattleOrder = FIXTURE.order("patrol_02", "human")
	expect(world.submit_order(human_order).accepted, "Human source passes same order validation/distribution")
	world.step_ticks(1)
	expect(order_by_id(world, "patrol_01").status == "superseded" and order_by_id(world, "patrol_01").replacement_order_id == "patrol_02", "New accepted task supersedes prior task with stable replacement link")
	expect(world.get_unit("f6f_01").active_order_id == "patrol_02", "Old task no longer owns recipients")
	var updates_before: int = world.snapshot().modules.test_order_executor.updates.patrol_01
	world.step_ticks(2)
	expect(world.snapshot().modules.test_order_executor.updates.patrol_01 == updates_before, "Superseded task receives no further executor updates")
	var cancel: BattleCommand = FIXTURE.command("cancel_02", BattleCommand.CANCEL_ORDER, {"order_id": "patrol_02", "reason": "test_human_cancel"})
	cancel.source = "human"
	expect(world.submit_command(cancel).accepted, "Cancellation uses common authorization and fixed queue")
	world.step_ticks(1)
	expect(order_by_id(world, "patrol_02").status == "cancelled" and world.get_unit("f6f_01").active_order_id.is_empty(), "Cancellation clears task ownership and notifies executor")
	expect(world.snapshot().modules.test_order_executor.ended.patrol_02 == "cancelled", "Executor cleanup callback called")
	expect(not world.transition_order("patrol_02", "executing", "illegal_resurrection"), "Terminal/out-of-tick transition cannot revive cancelled task")
	var incapable: BattleOrder = FIXTURE.order("incapable")
	incapable.order_type = "engage"
	incapable.target_id = "yamato_01"
	expect(world.submit_order(incapable).accepted, "Structurally valid order may queue for capability decision")
	world.step_ticks(1)
	expect(order_by_id(world, "incapable").status == "failed" and order_by_id(world, "incapable").reason == "test_executor_requires_ship", "Executor capability failure visible; not marked executing")
	var lifecycle_events: Array[String] = []
	for event: BattleEvent in world.drain_events():
		if event.kind == "order_status_changed":
			lifecycle_events.append(event.data.status)
	expect(lifecycle_events.has("superseded") and lifecycle_events.has("cancelled") and lifecycle_events.has("failed"), "Observer receives actual lifecycle events")
	world.reset()
	expect(world.orders_snapshot().is_empty() and world.drain_events().is_empty() and world.commander_snapshot("us").contacts.is_empty(), "Reset clears order history, contacts and event queues")
	var completion: SimulationWorld = SimulationWorld.new()
	completion.configure(FIXTURE.catalog(), FIXTURE.scenario())
	var executor: OrderProbe = OrderProbe.new()
	executor.complete_after_ticks = 3
	completion.register_module(executor)
	completion.submit_order(FIXTURE.order("completes"))
	completion.step_ticks(3)
	expect(order_by_id(completion, "completes").status == "completed" and completion.get_unit("f6f_02").task.is_empty(), "Controlled execution can finish and release all recipients")
	test_partial_reassignment()
	test_mixed_domain_routing()
	test_target_semantics()
	print("PASS command scheduling/idempotency/authority and high-level order lifecycle/view separation" if failures == 0 else "FAIL commands: %d" % failures)
	quit(0 if failures == 0 else 1)

func test_partial_reassignment() -> void:
	var world: SimulationWorld = make_world()
	world.submit_order(FIXTURE.order("pair_patrol"))
	world.step_ticks(1)
	var replacement: BattleOrder = FIXTURE.order("solo_retreat", "human")
	replacement.recipient_ids = ["f6f_01"]
	replacement.order_type = "retreat"
	world.submit_order(replacement)
	world.step_ticks(1)
	var previous: Dictionary = order_by_id(world, "pair_patrol")
	expect(previous.status == "executing" and previous.assigned_unit_ids == ["f6f_02"], "Partial reassignment preserves untransferred member's executing task")
	expect(previous.execution.f6f_01.status == "superseded" and previous.execution.f6f_01.replacement_order_id == "solo_retreat", "UI can trace unit-level replacement without terminating entire order")
	expect(world.get_unit("f6f_02").active_order_id == "pair_patrol" and world.get_unit("f6f_01").active_order_id == "solo_retreat", "Each member retains correct task ownership")
	var before: int = world.snapshot().modules.test_order_executor.updates.pair_patrol
	world.step_ticks(2)
	expect(world.snapshot().modules.test_order_executor.updates.pair_patrol == before + 2, "Old task continues actual updates for remaining member")
	var cancel: BattleCommand = FIXTURE.command("cancel_partial", BattleCommand.CANCEL_ORDER, {"order_id": "pair_patrol", "reason": "cancel_remaining"})
	world.submit_command(cancel)
	world.step_ticks(1)
	expect(world.get_unit("f6f_01").active_order_id == "solo_retreat" and world.get_unit("f6f_02").active_order_id.is_empty(), "Cancelling old order cannot clear member now owned by new order")
	world.get_unit("f6f_01").active = false
	world.step_ticks(1)
	expect(order_by_id(world, "solo_retreat").status == "failed" and world.get_unit("f6f_01").active_order_id.is_empty(), "Loss of last assigned member fails task and releases ownership")

func test_mixed_domain_routing() -> void:
	var data: Dictionary = FIXTURE.scenario()
	data.spawns.append({"id": "friendly_ship", "unit_definition_id": "jp_yamato_1944_04", "faction_id": "us", "position_m": [300.0, 0.0, 0.0]})
	data.groups.append({"id": "mixed_group", "faction_id": "us", "member_ids": ["friendly_ship", "f6f_01", "f6f_02"]})
	var world: SimulationWorld = SimulationWorld.new()
	world.configure(FIXTURE.catalog(), data)
	var air: OrderProbe = OrderProbe.new()
	air.module_id = "air_executor"
	air.domain = "aircraft"
	air.complete_after_ticks = 1
	var ships: OrderProbe = OrderProbe.new()
	ships.module_id = "ship_executor"
	ships.domain = "ship"
	ships.complete_after_ticks = 3
	expect(world.register_module(air).accepted and world.register_module(ships).accepted, "Air and ship executors register same patrol/escort/etc without conflict")
	var duplicate: OrderProbe = OrderProbe.new()
	duplicate.module_id = "conflicting_air_executor"
	duplicate.domain = "aircraft"
	expect(not world.register_module(duplicate).accepted, "Duplicate executor for same type/domain is rejected")
	var order: BattleOrder = FIXTURE.order("mixed_patrol")
	order.recipient_ids = ["mixed_group"]
	expect(world.submit_order(order).accepted, "Mixed ship/air formation receives one stable high-level order")
	world.step_ticks(1)
	var state: Dictionary = order_by_id(world, "mixed_patrol")
	expect(state.status == "executing" and state.assigned_unit_ids == ["friendly_ship"], "Air completion does not finish ship assignment")
	expect(state.execution.f6f_01.module_id == "air_executor" and state.execution.friendly_ship.module_id == "ship_executor", "Domain routing recorded per assigned unit")
	expect(state.execution.friendly_ship.progress == "test updates 1", "Per-unit progress is retained separately from other domain summaries")
	expect(air.released_ids == ["f6f_01", "f6f_02"] and ships.released_ids.is_empty(), "Only owning domain executor receives released subset")
	world.step_ticks(2)
	expect(order_by_id(world, "mixed_patrol").status == "completed", "Shared order completes only after both domains actually finish")

func test_target_semantics() -> void:
	var world: SimulationWorld = make_world()
	for kind: String in ["engage", "intercept"]:
		var order: BattleOrder = FIXTURE.order("friendly_" + kind)
		order.order_type = kind
		order.target_id = "f6f_02"
		expect(world.submit_order(order).reason == "order_requires_enemy_target", kind + " rejects friendly target")
	var escort: BattleOrder = FIXTURE.order("enemy_escort")
	escort.order_type = "escort"
	escort.target_id = "yamato_01"
	expect(world.submit_order(escort).reason == "escort_requires_friendly_target", "Escort rejects enemy target")
	var intercept: BattleOrder = FIXTURE.order("ship_intercept")
	intercept.order_type = "intercept"
	intercept.target_id = "yamato_01"
	expect(world.submit_order(intercept).reason == "intercept_requires_aircraft_target", "Aircraft interception rejects ship target")
