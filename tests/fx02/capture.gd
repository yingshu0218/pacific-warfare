extends SceneTree

## Native-only fixed camera samples of unmodified carrier harbor simulation.
const HARBOR: PackedScene = preload("res://showcase/carrier_harbor.tscn")
const STEP_S: float = 1./30.
const WINDOW_S: float = 9.
const OUT: String = "res://.local/fx02/evidence"
const FAMILIES: Array[String] = ["muzzle", "ship_hit", "land_hit", "flak", "water"]
var game: FirstPlayableGame
var shots: Dictionary = {}
var first_events: Dictionary = {}
var pool_peak: int = 0
var most_flak: Dictionary = {}
var scan_only: bool = false

func _initialize() -> void:
	scan_only = "--scan" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	if not scan_only:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		AudioServer.set_bus_mute(0,true)
	var directory: String = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	game = HARBOR.instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	if not game.running:
		push_error("FX02 carrier harbor failed to start")
		quit(1)
		return
	game.hud.hide()
	if not scan_only: await process_frame
	for frame: int in 4200:
		game._process(STEP_S)
		var now: float = game.session.presentation_time_s
		pool_peak = maxi(pool_peak,game.effects.peak_visible)
		if frame%3==0: _sample_load(now)
		for event: BattleEvent in game.presentation_events:
			var family: String = _family(event)
			if family.is_empty() or shots.has(family): continue
			first_events[family] = event.snapshot()
			shots[family] = _open_shot(family,event,directory)
		if not scan_only:
			for family: String in shots:
				var shot: Dictionary = shots[family]
				var age: float = now-float(shot.event_s)
				if age>WINDOW_S or now-float(shot.last_s)<float(shot.interval_s)-.00001: continue
				var error: Error = await _render_frame(shot,now,age)
				if error != OK:
					push_error("FX02 could not write %s frame: %s" % [family,error_string(error)])
					quit(1)
					return
		if _finished(now): break
	var audit: FileAccess = FileAccess.open(directory.path_join("scan.json" if scan_only else "harbor.json"),FileAccess.WRITE)
	audit.store_string(JSON.stringify({"entry":"res://showcase/carrier_harbor.tscn","scenario":game.scenario_path,
		"visual_scope":"Native Compatibility, fixed manual observation poses, default autonomous battle",
		"presentation_s":game.session.presentation_time_s,"size_px":[960,540],"peak_visible":pool_peak,
		"effects":game.effects.statistics(),"most_flak":most_flak,"events":first_events,"shots":shots},"	")+"\n")
	audit.close()
	print("FX02 carrier harbor at %.3f s. Clips %s. Peak visible %d." % [game.session.presentation_time_s,shots.keys(),pool_peak])
	var needed: bool = shots.has("muzzle") and shots.has("flak") and shots.has("water") and (shots.has("ship_hit") or shots.has("land_hit"))
	game.queue_free()
	await process_frame
	quit(0 if needed else 1)

func _sample_load(now: float) -> void:
	var stats: Dictionary = game.effects.statistics()
	var counts: Dictionary = stats.active_by_kind
	if int(counts.get("burst",0)) > int(most_flak.get("active_by_kind",{}).get("burst",0)):
		most_flak = {"presentation_s":now,"active_by_kind":counts,"visible_instances":stats.visible_instances}

func _finished(now: float) -> bool:
	if shots.size() < FAMILIES.size(): return false
	for shot: Dictionary in shots.values():
		if now-float(shot.event_s) < WINDOW_S: return false
	return true

func _family(event: BattleEvent) -> String:
	var caliber: float = float(event.data.get("caliber_m",0.))
	var surface: String = str(event.data.get("surface",""))
	if event.kind == "fired" and caliber>=.3 and event.data.get("source_domain") == "ship": return "muzzle"
	if event.kind == "airburst" and caliber>=.09 and event.data.get("reason") == "time_fuze" and event.position_m.y>100.: return "flak"
	if caliber<.1 or event.kind not in ["hit","surface_impact"]: return ""
	if event.data.get("release_mode") == "gravity_release": return ""
	if surface == "ship" and caliber>=.3: return "ship_hit"
	if surface in ["ground","building"]: return "land_hit"
	if surface == "sea" and caliber>=.3: return "water"
	return ""

func _open_shot(family: String, event: BattleEvent, directory: String) -> Dictionary:
	var at: Vector3 = event.position_m
	var eye: Vector3
	match family:
		"muzzle", "ship_hit":
			var id: String = event.entity_id if family=="muzzle" else event.target_id
			var unit: Dictionary = game.session.presentation_units[id]
			var center: Vector3 = unit.position_m
			var axis: Vector3 = event.data.get("muzzle_direction",at-center)
			axis.y = 0.
			var side: Vector3 = axis.normalized()
			if family=="muzzle":
				var spread: Vector3 = side.cross(Vector3.UP)*.82+side*.56
				eye = at+spread*455.+Vector3.UP*65.
				at = at.lerp(center+Vector3.UP*12.,.55)
			else:
				var ship_basis: Basis = Basis.from_euler(unit.rotation_rad)
				var broadside: Vector3 = ship_basis.x
				if (at-center).dot(broadside)<0.: broadside = -broadside
				eye = at+broadside*270.+ship_basis.z*35.+Vector3.UP*54.
				at = at.lerp(center+Vector3.UP*12.,.28)
		"land_hit":
			eye = at+Vector3(-136,70,109)
		"flak":
			eye = at+Vector3(-64,-34,224)
		_:
			eye = at+Vector3(-230,48,244)
	at += Vector3.UP*(9. if family!="flak" else 1.)
	var target: String = directory.path_join(family)
	if not scan_only: DirAccess.make_dir_recursive_absolute(target)
	return {"directory":target,"event_s":event.time_s,"event_sequence":event.sequence,
		"eye_m":SimData.array3(eye),"target_m":SimData.array3(at),"fov_deg":48.,"distance_m":eye.distance_to(at),
		"last_s":-INF,"interval_s":STEP_S,"frames":[]}

func _render_frame(shot: Dictionary, now: float, age: float) -> Error:
	var camera: ObserverCamera = game.camera
	camera.make_current()
	camera.near = 3.
	camera.fov = shot.fov_deg
	camera.global_position = SimData.vec3(shot.eye_m)
	camera.look_at(SimData.vec3(shot.target_m))
	camera.force_update_transform()
	game.effects.advance(0.)
	game.environment_view.update_observer(camera.global_position)
	await process_frame
	RenderingServer.force_draw(false,0.)
	var filename: String = "%04d.png" % (shot.frames as Array).size()
	var error: Error = root.get_texture().get_image().save_png(str(shot.directory).path_join(filename))
	shot.last_s = now
	shot.interval_s = 1./7.5 if age>.16 else STEP_S
	var in_view: Dictionary = {}
	for slot: Dictionary in game.effects.slots:
		if not slot.active: continue
		var mesh: MeshInstance3D = slot.mesh
		if mesh.visible and camera.is_position_in_frustum(mesh.global_position):
			in_view[slot.kind] = int(in_view.get(slot.kind,0))+1
	shot.frames.append({"file":filename,"presentation_s":now,"age_s":age,"in_frustum":in_view})
	return error
