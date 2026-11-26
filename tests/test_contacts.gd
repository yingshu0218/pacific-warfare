extends "res://tests/fixtures/combat_test.gd"

func run_test() -> void:
	var arena: Dictionary = FIX.arena([FIX.spawn("shooter", "us", Vector3(0,100,0)), FIX.spawn("enemy", "jp", Vector3(0,100,-500))])
	var world: SimulationWorld = arena.world
	expect(CombatContacts.find(world, "us", "enemy").is_empty(), "No observation before scan; no enemy position through helper")
	world.step_ticks(1)
	var contact: Dictionary = CombatContacts.find(world, "us", "enemy")
	expect(not contact.is_empty() and contact.position_m == Vector3(0,100,-500) and contact.observed_tick == 1, "Visual observation has exact observation position and tick")
	expect(CombatContacts.find(world,"us","shooter").is_empty(), "Never publishes own units as enemy contacts")
	contact.position_m = Vector3.ZERO
	expect(CombatContacts.find(world,"us","enemy").position_m.z == -500, "Contact helper returns detached data")
	world.get_unit("enemy").position_m = Vector3(100000,100,0)
	world.step_ticks(210)
	contact = CombatContacts.find(world,"us","enemy", false)
	expect(not contact.is_empty() and not contact.fresh and contact.position_m.z == -500 and contact.observed_tick == 1, "Lost contact retains old geometry and timestamp, stale after 3 seconds")
	expect(CombatContacts.find(world,"us","enemy").is_empty(), "Fire control cannot use stale contact")
	world.step_ticks(1000)
	expect(CombatContacts.find(world,"us","enemy",false).is_empty(), "Contact removed after 20 second expiry")
	world.reset()
	expect(CombatContacts.find(world,"us","enemy",false).is_empty(), "Reset clears contact index and generation")
	var other: Dictionary = FIX.arena([FIX.spawn("shooter","us",Vector3(0,100,0))])
	expect(CombatContacts.find(other.world,"us","enemy").is_empty(), "Multiple worlds never share cached intelligence")
	var c: CombatConfig = FIX.config()
	c.data.environment.solids = [{"id":"ridge","surface":"ground","center_m":[0,100,-250],"half_extents_m":[50,100,1]}]
	arena = FIX.arena([FIX.spawn("shooter","us",Vector3(0,100,0)),FIX.spawn("enemy","jp",Vector3(0,100,-500))],c)
	(arena.world as SimulationWorld).step_ticks(1)
	expect(CombatContacts.find(arena.world,"us","enemy").is_empty(), "Thin terrain ridge obstructs visual/radar line of sight")
	finish("contacts")
