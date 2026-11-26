extends SceneTree

const PILOTS: Array[String] = ["pilot_a", "pilot_b"]
const CONTACT_ID: String = "contact"
const CONTACT_POSITION: Vector3 = Vector3(0, 1500, -800)
const CONTACT_VELOCITY: Vector3 = Vector3(0, 0, -105)

var failures: int = 0

func _initialize() -> void:
	_verify_contact_lock(false)
	_verify_contact_lock(true)
	print("AIR01 target locks: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _verify_contact_lock(lose_after_queue: bool) -> void:
	var world: SimulationWorld = AircraftFixture.world([
		AircraftFixture.spawn(PILOTS[0], "jp", Vector3(-200, 1500, 0)),
		AircraftFixture.spawn(PILOTS[1], "jp", Vector3(200, 1500, 0)),
		AircraftFixture.spawn(CONTACT_ID, "us", CONTACT_POSITION, "us_f6f5_1944"),
	])
	var label: String = "queued rejection" if lose_after_queue else "submission rejection"
	for pilot: String in PILOTS:
		AircraftFixture.order(world, pilot + "_intercept", [pilot], "intercept", CONTACT_ID)
	world.step_ticks(1)
	var first_version: int = world.tick
	_publish_contact(world, first_version)
	if lose_after_queue:
		world.step_ticks(1)
		var pending: Dictionary = world.snapshot().modules.aircraft_tasks.queued_target_locks
		_check(pending.size() == PILOTS.size(), label + " queued before fixture loss")
	# The test changes actual state while preserving the pilots' last observation.
	world.get_unit(CONTACT_ID).active = false
	_check(_rejections(world, 20) == {PILOTS[0]:1, PILOTS[1]:1}, label + " once per pilot for the first version")
	_publish_contact(world, first_version)
	_check(_rejections(world, 10).is_empty(), label + " copy of the same observation cannot retry")
	var second_version: int = world.tick
	_publish_contact(world, second_version)
	_check(_rejections(world, 20) == {PILOTS[0]:1, PILOTS[1]:1}, label + " exactly one retry per pilot on a newer observation")
	_publish_contact(world, first_version)
	_check(_rejections(world, 10).is_empty(), label + " older observation cannot retry")
	# A controlled return to valid target state is invisible until a new observation.
	world.get_unit(CONTACT_ID).active = true
	_publish_contact(world, second_version)
	_check(_rejections(world, 4).is_empty(), label + " hidden state change produces no new rejection")
	for pilot: String in PILOTS:
		_check(world.get_unit(pilot).target_id.is_empty(), label + " held until observed again: " + pilot)
	_publish_contact(world, world.tick)
	_check(_rejections(world, 4).is_empty(), label + " fresh valid observation locks normally")
	for pilot: String in PILOTS:
		_check(world.get_unit(pilot).target_id == CONTACT_ID, label + " lock applied: " + pilot)

func _publish_contact(world: SimulationWorld, observed_tick: int) -> void:
	AircraftFixture.contacts(world, "jp", [AircraftFixture.contact(CONTACT_ID, CONTACT_POSITION, CONTACT_VELOCITY, observed_tick)])

func _rejections(world: SimulationWorld, steps: int) -> Dictionary:
	world.step_ticks(steps)
	var result: Dictionary = {}
	for event: BattleEvent in world.drain_events():
		if event.kind != "command_rejected": continue
		var request: Dictionary = event.data.request
		_check(request.kind == BattleCommand.SET_TARGET and request.payload.get("target_id") == CONTACT_ID and event.data.reason == "invalid_enemy_target", "only legitimate stale lock rejection")
		result[request.entity_id] = int(result.get(request.entity_id, 0)) + 1
	return result

func _check(ok: bool, message: String) -> void:
	if ok: return
	failures += 1
	push_error("AIR01 target locks: " + message)
