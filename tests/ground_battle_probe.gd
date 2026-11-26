extends SceneTree
## Unmodified default map battle: no target/pose/health injections.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var inputs: Dictionary = source_hashes()
	var seconds: int = 180
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):seconds=int(arg.get_slice("=",1))
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle("res://data/scenarios/island_harbor_defence.json")
	if not errors.is_empty():push_error(str(errors));quit(1);return
	var started: int = Time.get_ticks_msec()
	var interactions: Dictionary = {}
	var samples: Dictionary = {}
	var peak: int = 0
	var ground_status: Dictionary = {}
	var ground_initial: Dictionary = {}
	var shore_rounds: Dictionary = {}
	var ground_flight: Array = []
	var self_destruct_ages: Array = []
	for id: String in session.units:
		if session.definition_index[session.units[id].definition_id].domain=="ground":ground_initial[id]=session.units[id]
	for tick: int in range(seconds*60):
		session.world.step_ticks(1)
		for event: BattleEvent in session.consume_world():
			if event.kind not in ["fired","hit","damaged","airburst","surface_impact","damage_phase","disabled"]:continue
			var domain: String = session.definition_index[session.units[event.entity_id].definition_id].domain if session.units.has(event.entity_id) else ""
			var target_domain: String = session.definition_index[session.units[event.target_id].definition_id].domain if session.units.has(event.target_id) else ""
			var key: String = event.kind+":"+domain+">"+target_domain
			interactions[key]=int(interactions.get(key,0))+1
			if not samples.has(key):samples[key]=event.snapshot()
			if event.kind=="fired" and domain=="ship" and target_domain=="ground":shore_rounds[event.data.projectile_id]={"fired":event.snapshot()}
			elif event.kind in ["hit","surface_impact","airburst"] and shore_rounds.has(event.data.get("projectile_id","")):shore_rounds[event.data.projectile_id]["outcome"]=event.snapshot()
			if event.kind=="fired" and domain=="ground":
				var contact: Dictionary = CombatContacts.find(session.world,session.units[event.entity_id].faction_id,event.target_id)
				ground_flight.append({"time_s":event.time_s,"source":event.entity_id,"target":event.target_id,"distance_m":event.position_m.distance_to(contact.position_m) if not contact.is_empty() else -1,"computed_intercept_s":event.data.flight_time_s})
			if event.kind=="airburst" and domain=="ground":self_destruct_ages.append(event.data.get("age_s",-1))
		if tick%60==0:
			peak=maxi(peak,session.world.snapshot().modules.combat_projectiles.rounds.size())
			for id: String in ground_initial:
				var u: UnitState = session.world.get_unit(id)
				var status: String = str(u.module_data.combat_runtime.mount_status)
				ground_status[id+":"+status]=int(ground_status.get(id+":"+status,0))+1
		if tick%3600==3599:print("S10_BATTLE ",(tick+1)/60,"s ",interactions)
	session.refresh_view(true)
	var output: Dictionary = {"scenario":session.scenario.id,"seconds":session.world.time_s(),"wall_s":float(Time.get_ticks_msec()-started)/1000.,"interactions":interactions,"first_samples":samples,"ground_initial":ground_initial,"ground_status_seconds":ground_status,"report":session.report(),"units":session.units,"orders":session.orders,"journal":session.journal,"projectiles":session.world.snapshot().modules.combat_projectiles,"peak_sampled_projectiles":peak}
	output.source_hashes_start=inputs;output.source_hashes_end=source_hashes()
	output.ship_shore_rounds=shore_rounds;output.ground_fire_ranges=ground_flight;output.ground_self_destruct_ages=self_destruct_ages
	output.same_combat_inputs=inputs==output.source_hashes_end
	FileAccess.open("res://docs/showcase/evidence/S10/default_battle.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("S10_DEFAULT_BATTLE ",interactions)
	quit(0)

func source_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	var paths: Array[String] = ["res://data/scenarios/island_harbor_defence.json","res://data/combat/showcase.json","res://data/maps/island_harbor.json","res://scripts/game/first_playable_session.gd","res://scripts/ground/ground_deployments.gd","res://scripts/ground/ground_tasks.gd","res://scripts/ground/ground_commander.gd","res://scripts/simulation/weapons/combat_weapons.gd","res://scripts/simulation/projectiles/combat_projectiles.gd","res://scripts/simulation/damage/combat_damage.gd","res://scripts/command/air_defence/combat_targeting.gd"]
	for directory: String in ["res://data/units","res://data/ammunition","res://data/units/weapons"]:
		for file: String in DirAccess.get_files_at(directory):
			if file.ends_with(".json"):paths.append(directory.path_join(file))
	for path: String in paths:hashes[path]=FileAccess.get_file_as_string(path).sha256_text()
	return hashes
