extends "res://tests/bombing/data_fixture.gd"

static func arena(spawns: Array, flight_enabled: bool = true, terrain: bool = false, custom: CombatConfig = null, ops: bool = false, combat: bool = false) -> Dictionary:
	var builder: Script=load("res://tests/bombing/runtime_fixture.gd")
	return builder.call("arena",spawns,flight_enabled,terrain,custom,ops,combat)

## Break test-owned module links and release states before SceneTree shutdown.
static func dispose(arena: Dictionary) -> void:
	if arena.has("tasks"): (arena.tasks as AircraftTasks).bombing_delegate = null
	if arena.get("operations") != null: arena.tasks.set("mission_delegate",null)
	if arena.has("delegate"): arena.delegate.set("stores",null)
	if arena.has("stores"): arena.stores.set("projectiles",null)
	arena.clear()
