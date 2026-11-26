extends SceneTree

## Actual production default scenario, unchanged seed, no launches or state injection.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle("res://data/scenarios/island_harbor_defence.json")
	if not errors.is_empty():
		push_error(str(errors));quit(1);return
	var counts: Dictionary = {}
	var parts: Dictionary = {}
	var event_records: Array[Dictionary] = []
	var samples: Array[Dictionary] = []
	var maximum_pieces: int = 0
	for tick: int in 10800:
		session.world.step_ticks(1)
		var events: Array[BattleEvent] = session.consume_world()
		for event: BattleEvent in events:
			counts[event.kind] = int(counts.get(event.kind,0))+1
			if event.kind == "hit" and session.world.unit_definition(session.world.get_unit(event.target_id).definition_id).domain == "aircraft":
				parts[event.data.part_id] = int(parts.get(event.data.part_id,0))+1
			if event.kind in ["aircraft_part_detached","aircraft_breakup","unit_surface_contact","unit_impact","damage_phase","disabled"]: event_records.append(event.snapshot())
		for id: String in session.world.unit_ids():
			var unit: UnitState = session.world.get_unit(id)
			if unit.module_data.damage.has("aircraft"):
				maximum_pieces = maxi(maximum_pieces,unit.module_data.damage.aircraft.fragments.size())
		if tick%600 == 0:
			var units: Dictionary = {}
			for id: String in session.world.unit_ids(): units[id] = session.world.get_unit(id).snapshot()
			samples.append({"time_s":session.world.time_s(),"units":units})
	var passed: bool = int(counts.get("fired",0)) > 0 and int(counts.get("hit",0)) > 0 and maximum_pieces <= 3
	var result: Dictionary = {"scope":"Unmodified default island_harbor_defence, 180 seconds fixed seed, production commander/weapon/ballistics/damage; no controlled damage injection; not a rendering or 10-minute S08 run.","passed":passed,"counts":counts,"aircraft_hit_parts":parts,"maximum_fragments_per_unit":maximum_pieces,"report":session.report(),"events":event_records,"samples":samples}
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/DM01/natural-default.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(AircraftDamageFixture.json_data(result),"\t"))
	print("DM01 natural default ","PASS" if passed else "FAIL"," ticks=",session.world.tick," hits=",counts.get("hit",0)," aircraft parts=",parts," max fragments=",maximum_pieces)
	quit(0 if passed else 1)
