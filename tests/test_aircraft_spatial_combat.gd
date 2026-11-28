extends SceneTree
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for kind: String in ["two","four","standard","current"]:
		var seconds: int = 240 if kind in ["standard","current"] else 160
		var world: SimulationWorld = AircraftSpatialFixture.build(kind)
		var trace: AircraftSpatialRecorder = AircraftSpatialRecorder.new()
		trace.setup(world)
		for tick: int in range(seconds*60):
			world.step_ticks(1)
			trace.collect(world,world.drain_events(),tick%15 == 0)
		var result: Dictionary = trace.result(world)
		result["case"] = kind
		result["baseline"] = false
		var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-spatial/"+kind+"-after.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"))
		var summary: Dictionary = result.summary
		check(int(summary.air_fired) > 20,kind+" real fixed-gun bursts")
		check(int(summary.air_enemy_hits) > 0,kind+" actual projectile collisions")
		check(summary.air_fired == summary.inventory_used,kind+" actual ammunition matches fired events")
		check(float(summary.max_pose_velocity_error_rad) < deg_to_rad(7.0),kind+" authority body and flight path stay within the free-flight trim envelope")
		check(float(summary.max_gun_forward_error_rad) < 0.035,kind+" bullets follow real 3D fixed-gun forward")
		check(float(summary.min_friend_m) > 20,kind+" friend safety: "+str(summary.min_friend_m))
		var up: Dictionary = {"jp":false,"us":false}
		var down: Dictionary = {"jp":false,"us":false}
		var angular_time: float = 0.0
		var maneuvers: Dictionary = {}
		for id: String in summary.units:
			var row: Dictionary = summary.units[id]
			var faction: String = world.get_unit(id).faction_id
			up[faction] = bool(up[faction]) or float(row.max_up_deg) > 20
			down[faction] = bool(down[faction]) or float(row.max_down_deg) < -15
			angular_time += float(row.pitch_over_15_s)
			check(float(row.max_load_g) <= 5.501,kind+" per-aircraft load bound")
			for mode: String in row.maneuvers:
				maneuvers[mode] = float(maneuvers.get(mode,0))+float(row.maneuvers[mode])
		check(up.jp and up.us and down.jp and down.us,kind+" both sides climb and dive substantially")
		check(angular_time > 15,kind+" sustained 3D trajectories, not a one-frame pose")
		var vertical_response: bool = maneuvers.has("zoom_climb") or maneuvers.has("diving_break")
		if kind in ["standard","current"]:
			# Natural commander assignments may withdraw damaged fighters before a tail
			# break is needed. A measured energy-based high yo-yo is also a pull-up.
			vertical_response = vertical_response or float(maneuvers.get("high_yoyo",0)) > 1.0
		check(maneuvers.has("dive_attack") and vertical_response,kind+" real dive and energy-based vertical response")
		print("S04 spatial ",kind," seconds=",seconds," shots=",summary.air_fired," hits=",summary.air_hits," min_friend=",summary.min_friend_m," time_pitch_over15=",angular_time," maneuvers=",maneuvers)
	print("S04 spatial combat ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
