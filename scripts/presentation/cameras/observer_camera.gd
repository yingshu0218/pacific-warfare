class_name ObserverCamera
extends Camera3D

## Observer data only. This class never receives a world or a mutable UnitState.
const AIR_SHOTS: Dictionary = {
	"bombing_run":"轰炸编队", "bomber_intercept":"战斗机拦截轰炸机", "fighter_dogfight":"战斗机狗斗",
	"bomb_released":"炸弹离架", "bomb_explosion":"炸弹命中", "bomber_defense":"轰炸机背部炮塔还击",
}
const FIGHTER_HOLD_S: float = 6.0
const FIGHTER_NEAR_M: float = 43.0
const FIGHTER_PITCH_RAD: float = 0.18
const FIGHTER_COMBAT_PHASES: Array[String] = ["approach", "aim", "burst", "evade", "extend"]
var terrain: Dictionary = {}
var mode: String = "auto"
var air_focus: bool = false
var manual_free: bool = false
var followed_id: String = ""
var shot_label: String = "战场全景"
var focus: Vector3 = Vector3.ZERO
var distance_m: float = 700.0
var yaw: float = 0.65
var pitch: float = 0.35
var hold_s: float = 0.0
var last_cut_s: float = -100.0
var generation: int = -1
var views: Dictionary = {}
var metadata: Dictionary = {}
var shot_event: Dictionary = {}
var shot_serial: int = 0
var _candidate: Dictionary = {}
var _air_candidates: Dictionary = {}
var _dragging: bool = false
var _snap: bool = true
var _auto_index: int = 0
var _observed_fires: Dictionary = {}
var _air_shot_times: Dictionary = {}
var _recorded_air_passes: Dictionary = {}
var _shown_bombing_orders: Dictionary = {}
var _last_surface_shot_s: float = -100.0
var _following_salvo: bool = false
var _ship_focus_times: Dictionary = {}
var _orbit_offset: Vector3 = Vector3.ZERO
var _pressed_keys: Dictionary = {}
var _fighter_cut_s: float = -INF
var _fighter_sample_s: float = -INF
var _fighter_center_offset: Vector3 = Vector3.ZERO
var _fighter_secondary_id: String = ""
var _fighter_relation: String = ""
var _fighter_previous_opponent: String = ""
var _fighter_named_sequence: int = -1

func _ready() -> void:
	current = true
	fov = 48.0
	near = 0.8
	far = 70000.0
	position = Vector3(600, 300, 600)

func reset_view(new_generation: int, definitions: Dictionary) -> void:
	generation = new_generation
	metadata = definitions.duplicate(true)
	views = {}
	_candidate.clear()
	_air_candidates.clear()
	shot_event.clear()
	shot_serial = 0
	mode = "auto"
	air_focus = false
	manual_free = false
	followed_id = ""
	shot_label = "战场全景"
	hold_s = 0.0
	last_cut_s = -100.0
	_auto_index = 0
	_observed_fires.clear()
	_air_shot_times.clear()
	_recorded_air_passes.clear()
	_shown_bombing_orders.clear()
	_ship_focus_times.clear()
	_last_surface_shot_s = -100.0
	_following_salvo = false
	_reset_fighter_shot()
	release_input()
	_snap = true

func consume(events: Array[BattleEvent]) -> void:
	if mode != "auto": return
	if not events.is_empty(): _expire_candidates(events[0].time_s)
	for event: BattleEvent in events:
		var source_air: bool = _is_aircraft(event.entity_id)
		if event.kind == "bomb_released":
			_offer_air_shot(event.entity_id, "", event.kind, 12, event.time_s, event.position_m, event.sequence)
			continue
		if event.kind == "bomb_explosion":
			_offer_air_shot("", "", event.kind, 13, event.time_s, event.position_m, event.sequence, str(event.data.get("surface", "")))
			continue
		if event.kind == "fired" and source_air and event.data.get("mount_role") == "dedicated_aa":
			_offer_air_shot(event.entity_id, event.target_id, "bomber_defense", 12, event.time_s, event.position_m, event.sequence)
			continue
		if event.kind == "fired" and event.data.get("mount_role") == "aircraft_fixed" and source_air and not _is_bomber(event.entity_id) and _is_aircraft(event.target_id):
			var scene_kind: String = "bomber_intercept" if _is_bomber(event.target_id) else "fighter_dogfight"
			_offer_air_shot(event.entity_id, event.target_id, scene_kind, 11, event.time_s, event.position_m, event.sequence)
			continue
		if air_focus and not source_air and event.kind != "airburst": continue
		var importance: int = 0
		if event.kind == "salvo" and event.data.get("mount_ids",[]).any(func(id: String) -> bool: return metadata.get(event.entity_id,{}).get("main_mounts",{}).has(id)): importance = 5
		elif event.kind == "fired" and metadata.get(event.entity_id, {}).get("domain", "") == "aircraft": importance = 4
		elif event.kind == "fired" and metadata.get(event.entity_id, {}).get("domain", "") == "ground": importance = 4
		elif event.kind == "fired" and metadata.get(event.entity_id, {}).get("domain", "") == "ship":
			importance = (7 if float(event.data.get("caliber_m",0))>=.2 else 5) if str(event.data.get("mount_role","")) == "main" else 4
		elif event.kind == "disabled": importance = 6
		elif event.kind == "damage_phase" and event.data.get("phase", "") in ["sinking", "crashing", "disabled"]: importance = 6
		elif event.kind == "damaged": importance = 4 if float(event.data.get("amount", 0.0)) >= 20.0 else 1
		elif event.kind == "airburst": importance = 2
		elif event.kind == "surface_impact" and float(event.data.get("caliber_m", 0)) >= 0.3: importance = 5
		if importance > int(_candidate.get("importance", 0)) or (importance > 0 and importance == int(_candidate.get("importance", 0)) and event.time_s - float(_candidate.get("time_s", 0.0)) > 1.0):
			var id: String = event.target_id if event.kind == "damaged" else event.entity_id
			if event.kind in ["surface_impact", "airburst"]: id = ""
			_candidate = {"id":id, "position_m":event.position_m, "importance":importance, "kind":event.kind, "time_s":event.time_s, "sequence":event.sequence,"surface":str(event.data.get("surface","")),"mount_role":str(event.data.get("mount_role","")),"target_id":event.target_id}

func set_mode(value: String) -> void:
	adopt_current_view()
	air_focus = value == "air"
	mode = "auto" if air_focus else value
	manual_free = value == "free"
	release_input()
	_candidate.clear()
	_air_candidates.clear()
	shot_event.clear()
	hold_s = 0.0
	_following_salvo = false
	last_cut_s = -100.0
	if mode == "fighter":
		_reset_fighter_shot()
		followed_id = ""
		shot_label = "等待可跟拍的战斗机"
	if air_focus:
		_air_shot_times.clear()
		_recorded_air_passes.clear()
		_shown_bombing_orders.clear()
	if mode == "free":
		followed_id = ""
		shot_label = "自由观察"

func follow(id: String) -> void:
	release_input()
	mode = "follow"
	air_focus = false
	manual_free = false
	followed_id = id
	shot_label = "机群跟随" if metadata.get(id, {}).get("domain", "") == "aircraft" else "舰队跟随"
	if metadata.get(id,{}).get("domain","")=="ground":shot_label="岸防阵地"
	fit_unit(id)

func locate(point: Vector3, ids: Array[String] = []) -> void:
	release_input()
	mode = "free"
	air_focus = false
	manual_free = false
	followed_id = ""
	shot_label = "指令相关位置"
	var first: bool = true
	var bounds: AABB = AABB(point, Vector3.ZERO)
	for id: String in ids:
		if not views.has(id): continue
		if first:
			bounds = AABB(views[id].position_m, Vector3.ZERO)
			first = false
		else: bounds = bounds.expand(views[id].position_m)
	focus = point if first else bounds.get_center()
	distance_m = clampf(bounds.size.length() * 1.4 + 300.0, 200.0, 16000.0)
	_snap = true

func locate_map(point: Dictionary) -> void:
	locate(SimData.vec3(point.focus_m))
	distance_m = float(point.distance_m)
	yaw = float(point.yaw_rad)
	pitch = float(point.pitch_rad)
	shot_label = str(point.label)

func fit_unit(id: String) -> void:
	if not views.has(id): return
	var meta: Dictionary = metadata.get(id, {})
	var air: bool = meta.get("domain", "ship") == "aircraft"
	distance_m = 42.0 if air else maxf(130.0, float(meta.get("length", 260)) * 1.55)
	pitch = 0.18 if air else 0.32
	if meta.get("domain","")=="ground":distance_m=18.0;pitch=.22
	yaw = float((views[id].rotation_rad as Vector3).y) + 0.9
	_snap = true

func update_view(delta_s: float, simulation_s: float, unit_views: Dictionary, paused: bool) -> void:
	views = unit_views
	if mode == "fighter":
		_update_fighter_shot(delta_s, simulation_s)
		return
	if mode == "auto":
		_expire_candidates(simulation_s)
		for id: String in views:
			var unit: Dictionary = views[id]
			var air_task: Dictionary = unit.task.get("aircraft", {})
			var target_id: String = air_task.get("target_id", "")
			if unit.active and _is_aircraft(id):
				var bombing: Dictionary = unit.module_data.get("bombing", {})
				var order_id: String = str(bombing.get("order_id", ""))
				if not order_id.is_empty() and bombing.get("phase", "") in ["inbound", "stabilize", "roll_in", "dive"] and not _shown_bombing_orders.has(order_id):
					_offer_air_shot(id, "", "bombing_run", 6, simulation_s, unit.position_m, 0, "", order_id)
				if not _is_bomber(id) and air_task.get("phase", "") in ["approach", "aim", "burst", "evade", "extend"] and _is_aircraft(target_id) and views[target_id].active:
					var separation: float = (unit.position_m as Vector3).distance_to(views[target_id].position_m)
					if separation <= 1300.0:
						var scene_kind: String = "bomber_intercept" if _is_bomber(target_id) else "fighter_dogfight"
						_offer_air_shot(id, target_id, scene_kind, 8 if separation < 650.0 else 7, simulation_s, unit.position_m)
			if air_focus and not _is_aircraft(id): continue
			if views[id].active and float(metadata[id].get("length", 0.0)) >= 180.0 and simulation_s - float(_ship_focus_times.get(id, -100.0)) > 25.0 and int(_candidate.get("importance", 0)) < 5:
				var ready: Dictionary = _gunnery_ready(id)
				if not ready.is_empty(): _candidate = ready.merged({"id":id, "position_m":views[id].position_m, "importance":5, "kind":"gunnery_ready", "time_s":simulation_s})
			var fire: float = float(views[id].module_data.get("damage", {}).get("fire", 0.0))
			if fire < 0.05: _observed_fires.erase(id)
			if fire >= 0.12 and _shown(views[id]) and not _observed_fires.has(id) and int(_candidate.get("importance", 0)) < 4:
				_candidate = {"id":id, "position_m":views[id].position_m, "importance":4, "kind":"persistent_damage", "time_s":simulation_s}
		hold_s -= delta_s
		var waiting_for_impact: bool = _following_salvo and hold_s > -6.0
		var candidate: Dictionary = _select_shot(simulation_s, waiting_for_impact)
		var kind: String = str(candidate.get("kind", ""))
		var air_shot: bool = AIR_SHOTS.has(kind)
		if not candidate.is_empty():
			shot_event = candidate
			shot_serial += 1
			if kind == "persistent_damage": _observed_fires[candidate.id] = true
			if air_shot:
				_air_shot_times[kind] = simulation_s
				_air_candidates.erase(kind)
				if kind == "bombing_run": _shown_bombing_orders[candidate.order_id] = true
				if kind in ["bomber_intercept", "fighter_dogfight"] and int(candidate.sequence) > 0:
					_recorded_air_passes[kind] = true
			else:
				_candidate = {}
				if _is_surface_gunnery(candidate): _last_surface_shot_s = simulation_s
			if kind in ["salvo", "gunnery_ready"]: _ship_focus_times[candidate.id] = simulation_s
			_following_salvo = kind in ["salvo", "gunnery_ready"]
			var id: String = candidate.id
			if kind == "bomber_intercept" and int(candidate.sequence) == 0:
				# On approach, the bomber is the visible subject. Once aircraft
				# actually fire, the event shot follows the firing aircraft.
				id = candidate.target_id
			if views.has(id) and _shown(views[id]):
				followed_id = id
				fit_unit(id)
				if candidate.kind in ["salvo", "gunnery_ready"]: distance_m *= 0.7
				shot_label = {"salvo":"主炮跟拍", "gunnery_ready":"主炮跟拍", "fired":"近距空战", "air_engagement":"近距空战", "damaged":"命中与伤情", "disabled":"战斗失能", "airburst":"防空交战", "surface_impact":"重炮落弹", "damage_phase":"伤情变化", "persistent_damage":"持续火情"}.get(candidate.kind, "交战跟随")
				if metadata[id].domain=="ground" and candidate.kind=="fired":shot_label="岸防炮组射击"
				if metadata[id].domain=="ship" and candidate.kind=="fired":
					shot_label="主炮射击" if candidate.mount_role=="main" else ("防空炮射击" if str(candidate.mount_role).begins_with("aa") or metadata.get(str(candidate.target_id),{}).get("domain","")=="aircraft" else "舰炮射击")
				if air_shot:
					shot_label = str(AIR_SHOTS[kind])
					if _is_bomber(id) and kind != "bomber_defense":
						distance_m = maxf(58.0, float(metadata[id].length) * 3.7)
			else:
				followed_id = ""
				focus = candidate.position_m
				distance_m = 100.0 if candidate.kind == "airburst" else 170.0
				pitch = 0.3
				shot_label = "防空空爆" if candidate.kind == "airburst" else "重炮落弹"
				if kind == "bomb_explosion":
					shot_label = "炸弹落水" if candidate.surface == "sea" else "炸弹弹着"
					distance_m = 115.0
				_snap = true
			last_cut_s = simulation_s
			hold_s = 5.5 if air_shot else 9.0
		elif hold_s <= 0.0 and not paused and not waiting_for_impact:
			shot_serial += 1
			_following_salvo = false
			shot_event = {}
			var ids: Array[String] = []
			for id: String in views:
				if views[id].active and (not air_focus or (_is_aircraft(id) and not bool(views[id].module_data.get("carrier_ops", {}).get("on_deck", false)))):
					ids.append(id)
			ids.sort()
			if not ids.is_empty():
				if _auto_index % 4 == 0 and not air_focus:
					followed_id = ""
					var bounds: AABB = AABB(views[ids[0]].position_m, Vector3.ZERO)
					for id: String in ids: bounds = bounds.expand(views[id].position_m)
					focus = bounds.get_center()
					distance_m = clampf(bounds.size.length() * 1.2, 1800.0, 18000.0)
					pitch = 0.55
					shot_label = "战场全景"
					_snap = true
				else:
					followed_id = ids[_auto_index % ids.size()]
					fit_unit(followed_id)
					shot_label = "机群跟随" if metadata[followed_id].domain == "aircraft" else "舰队跟随"
					if metadata[followed_id].domain=="ground":shot_label="岸防阵地"
				_auto_index += 1
			hold_s = 14.0
		if shot_event.get("kind", "") == "surface_impact" and simulation_s - float(shot_event.time_s) > 1.8: shot_label = "落弹海域" if shot_event.get("surface","")=="sea" else "落弹岸区"
		if shot_event.get("kind", "") == "airburst" and simulation_s - float(shot_event.time_s) > 0.9: shot_label = "防空空域"
	if not followed_id.is_empty():
		if not views.has(followed_id) or not _shown(views[followed_id]):
			followed_id = ""
			shot_label = "单位已退出 · 保留最后位置"
			if mode == "follow": mode = "free"
		else:
			var unit: Dictionary = views[followed_id]
			focus = unit.position_m + Vector3.UP * (2.0 if metadata[followed_id].domain == "aircraft" else 10.0)
			if metadata[followed_id].domain=="ground":focus=unit.position_m+Vector3.UP*1.3
	if mode == "free": _move_free(delta_s)
	near = clampf(distance_m * 0.008, 0.8, 80.0)
	var orbit: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance_m
	if not followed_id.is_empty() and metadata.get(followed_id, {}).get("domain", "") == "aircraft":
		var velocity: Vector3 = views[followed_id].velocity_mps
		if velocity.length() > 1.0 and mode == "auto":
			# Side/behind offset follows actual flight direction, including climbs and dives.
			var forward: Vector3 = velocity.normalized()
			var side: Vector3 = forward.cross(Vector3.UP).normalized()
			if side.length() < 0.1: side = Vector3.RIGHT
			orbit = (-forward * 0.65 + side * 0.85 + Vector3.UP * 0.25).normalized() * distance_m
		if mode == "auto" and shot_event.get("kind", "") in ["bomber_intercept", "fighter_dogfight"]:
			var opponent_id: String = shot_event.id if followed_id == shot_event.target_id else shot_event.target_id
			var opponent: Dictionary = views.get(opponent_id, {})
			if not opponent.is_empty() and bool(opponent.active):
				var offset: Vector3 = (opponent.position_m as Vector3) - focus
				# Frame both aircraft during the firing pass, and keep the near
				# aircraft readable during longer approaches and breaks.
				var blend: float = 0.45 * (1.0 - smoothstep(450.0, 1050.0, offset.length()))
				focus += offset * blend
				orbit = orbit.normalized() * (distance_m + offset.length() * blend * 1.9)
	var desired: Vector3 = focus + orbit
	if mode == "free" and manual_free:
		# Manual free-look rotates in place. Terrain limits move the eye AND
		# its look target together, preserving the direction and takeover pose.
		var correction: float = maxf(0.0,TerrainQueries.height_data(terrain,desired,true)+8.0-desired.y)
		desired.y += correction;focus.y += correction
		position = desired;_orbit_offset = orbit;_snap = false
		if position.distance_squared_to(focus)>1.0:look_at(focus,Vector3.UP)
		return
	desired = _safe_position(desired, focus)
	# Keep the camera outside all visible hull bounding spheres (never model-dependent collision).
	for id: String in views:
		if metadata[id].domain != "ship" or not _shown(views[id]): continue
		var center: Vector3 = views[id].position_m + Vector3.UP * 12.0
		var radius: float = float(metadata[id].length) * 0.58 + 16.0
		var away: Vector3 = desired - center
		if away.length() < radius: desired = center + away.normalized() * radius if away.length() > 0.1 else center + Vector3.UP * radius
	# Track the same rendered focus exactly. Smooth only the relative orbit;
	# smoothing the absolute camera while the model steps created relative jitter.
	var offset: Vector3 = desired-focus
	_orbit_offset = offset if _snap else _orbit_offset.lerp(offset, 1.0 - exp(-delta_s * 5.0))
	position = focus+_orbit_offset
	position = _safe_position(position, focus)
	_orbit_offset = position-focus
	_snap = false
	if position.distance_squared_to(focus) > 1.0: look_at(focus, Vector3.UP)

func _reset_fighter_shot() -> void:
	_fighter_cut_s = -INF
	_fighter_sample_s = -INF
	_fighter_center_offset = Vector3.ZERO
	_fighter_secondary_id = ""
	_fighter_relation = ""
	_fighter_previous_opponent = ""
	_fighter_named_sequence = -1

func _airborne_fighter(id: String) -> bool:
	if not bool(metadata.get(id, {}).get("fighter", false)) or not views.has(id): return false
	var unit: Dictionary = views[id]
	var modules: Dictionary = unit.module_data
	return bool(unit.active) and modules.has("aircraft_motion") and not bool(modules.get("carrier_ops", {}).get("on_deck", false)) \
		and modules.get("damage", {}).get("phase", "operational") == "operational" \
		and not bool(modules.aircraft_motion.get("surface_contact", false)) and not bool(modules.aircraft_motion.get("exited", false)) \
		and float(modules.aircraft_motion.get("height_agl_m", unit.position_m.y)) > 8.0 \
		and modules.get("aircraft_training", {}).get("status", "") != "executing"

func _fighter_opponent(unit: Dictionary) -> String:
	var task: Dictionary = unit.task.get("aircraft", {})
	var target: String = str(task.get("target_id", ""))
	if task.get("phase", "") not in FIGHTER_COMBAT_PHASES or not _airborne_fighter(target): return ""
	return target if views[target].faction_id != unit.faction_id else ""

func _fighter_priority(unit: Dictionary) -> int:
	if unit.module_data.aircraft_motion.get("autonomous_maneuver", {}).get("status", "") == "executing":
		return 4
	return 2 if not _fighter_opponent(unit).is_empty() else 0

func _pick_fighter(prior: String, prior_valid: bool) -> String:
	var best: String = prior if prior_valid else ""
	var best_score: int = _fighter_priority(views[prior]) if prior_valid else -1
	for id: String in views:
		if id == prior or not _airborne_fighter(id): continue
		var score: int = _fighter_priority(views[id])
		if not prior_valid and id == _fighter_previous_opponent: score += 1
		if score > best_score:
			best = id
			best_score = score
	return best

func _update_fighter_shot(delta_s: float, now: float) -> void:
	var valid: bool = _airborne_fighter(followed_id)
	var next: String = followed_id
	if not valid or now - _fighter_cut_s >= FIGHTER_HOLD_S:
		next = _pick_fighter(followed_id, valid)
	var cut: bool = next != followed_id
	if cut:
		followed_id = next
		_fighter_cut_s = now
		_fighter_named_sequence = -1
		shot_serial += 1
	if followed_id.is_empty():
		shot_label = "暂无可跟拍的战斗机"
		_fighter_secondary_id = ""
		_fighter_relation = ""
		_fighter_previous_opponent = ""
		return
	# A stopped presentation clock freezes the lens, including its damping.
	if not cut and now == _fighter_sample_s: return
	_fighter_sample_s = now
	var unit: Dictionary = views[followed_id]
	var opponent: String = _fighter_opponent(unit)
	if cut or not opponent.is_empty(): _fighter_previous_opponent = opponent
	var task: Dictionary = unit.task.get("aircraft", {})
	var phase: String = str(task.get("phase", ""))
	var activity: String = "在空"
	if not opponent.is_empty():
		activity = "接敌" if phase == "approach" else "交战"
	elif phase in ["withdraw", "return", "recover"]:
		activity = "脱离"
	var motion_label: String = _fighter_motion_label(unit.module_data.aircraft_motion.get("autonomous_maneuver", {}))
	if not motion_label.is_empty(): activity = motion_label
	shot_label = "%s · %s" % [metadata[followed_id].get("name", followed_id), activity]
	var center: Vector3 = unit.position_m
	var velocity: Vector3 = unit.velocity_mps
	var angle: float = AircraftFlightMath.heading(velocity, yaw - 1.12) + 1.12
	var dt: float = minf(delta_s, 0.05)
	yaw = angle if cut else rotate_toward(yaw, lerp_angle(yaw, angle, 1.0 - exp(-dt * 2.0)), dt * 0.65)
	var heading: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var orbit: Vector3 = heading * cos(FIGHTER_PITCH_RAD) + Vector3.UP * sin(FIGHTER_PITCH_RAD)
	var right: Vector3 = Vector3.UP.cross(heading)
	var up: Vector3 = orbit.cross(right)
	var secondary: Dictionary = _fighter_companion(unit, opponent)
	var offset: Vector3 = secondary.get("offset", Vector3.ZERO)
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var tan_half_fov: float = tan(deg_to_rad(fov) * 0.5)
	var horizontal_span: float = absf(offset.dot(right)) / (0.74 * tan_half_fov * viewport.aspect())
	var vertical_span: float = absf(offset.dot(up)) / (0.67 * tan_half_fov)
	var room: float = maxf(horizontal_span, vertical_span) * 0.5 + absf(offset.dot(orbit)) * 0.5 + 19.0
	var blend: float = (1.0 - smoothstep(135.0, 173.0, room)) if not secondary.is_empty() else 0.0
	var smooth: float = 1.0 if cut else 1.0 - exp(-dt * 6.0)
	# Leave more viewport room for the higher or lower aircraft during a crossing.
	var center_weight: float = lerpf(0.5, 0.62, smoothstep(15.0, 95.0, absf(offset.dot(up))))
	_fighter_center_offset = _fighter_center_offset.lerp(offset * (center_weight * blend), smooth)
	distance_m = lerpf(distance_m, lerpf(FIGHTER_NEAR_M, maxf(FIGHTER_NEAR_M, room), blend), smooth)
	focus = center + _fighter_center_offset
	position = _safe_position(focus + orbit * distance_m, focus)
	near = 0.8
	look_at(focus, Vector3.UP)
	_fighter_secondary_id = str(secondary.get("id", "")) if blend > 0.2 else ""
	_fighter_relation = str(secondary.get("relation", "")) if not _fighter_secondary_id.is_empty() else ""
	if _fighter_secondary_visible():
		var relation: String = {"opponent":"对手", "leader":"长机", "wingman":"僚机"}[_fighter_relation]
		shot_label += " / " + relation

func _fighter_motion_label(motion: Dictionary) -> String:
	if motion.get("status", "") != "executing":
		_fighter_named_sequence = -1
		return ""
	var sequence: int = int(motion.sequence)
	var label: String = ""
	var confirmed: bool = false
	match str(motion.kind):
		"rising_arc":
			label = "爬升转弯"
			confirmed = float(motion.peak_gain_m) >= 20.0 and float(motion.arc_turn_rad) >= deg_to_rad(12.0)
		"bank_reversal":
			label = "反向转弯"
			var initial: float = float(motion.initial_turn_rad)
			confirmed = float(motion.opposite_turn_rad) >= deg_to_rad(12.0) or (
				initial >= deg_to_rad(29.0) and absf(float(motion.heading_change_rad)) <= initial - deg_to_rad(12.0))
		"axial_roll":
			label = "轴向滚转"
			confirmed = float(motion.peak_roll_rad) >= deg_to_rad(25.0)
		"oblique_roll_arc":
			label = "斜向滚转弧"
			confirmed = float(motion.peak_roll_rad) >= deg_to_rad(25.0) and (
				float(motion.height_span_m) >= 40.0 and float(motion.peak_lateral_offset_m) >= 25.0)
	if confirmed: _fighter_named_sequence = sequence
	if _fighter_named_sequence != sequence: return ""
	return label + "改出" if motion.phase == "recover" else label

func _fighter_companion(unit: Dictionary, opponent: String) -> Dictionary:
	var center: Vector3 = unit.position_m
	if not opponent.is_empty():
		var offset: Vector3 = views[opponent].position_m - center
		if offset.length_squared() < 255.0 * 255.0:
			return {"id":opponent, "offset":offset, "relation":"opponent"}
	var leader: String = unit.module_data.get("air_formation", {}).get("pair_leader_id", "")
	if leader.is_empty(): return {}
	var closest: Dictionary = {}
	var limit_m: float = 300.0
	for id: String in views:
		if id == followed_id or not _airborne_fighter(id): continue
		var candidate: Dictionary = views[id]
		if candidate.module_data.get("air_formation", {}).get("pair_leader_id", "") != leader: continue
		var offset: Vector3 = candidate.position_m - center
		var span: float = offset.length()
		if span >= limit_m: continue
		limit_m = span
		closest = {"id":id, "offset":offset, "relation":"leader" if id == leader else "wingman"}
	return closest

func _fighter_secondary_visible() -> bool:
	if not views.has(_fighter_secondary_id): return false
	var point: Vector3 = views[_fighter_secondary_id].position_m
	if is_position_behind(point): return false
	# Keep the second aircraft clear of the top bar, bottom controls and frame edges.
	var viewport: Rect2 = get_viewport().get_visible_rect()
	var safe: Rect2 = viewport.grow_individual(-viewport.size.x * 0.08, -viewport.size.y * 0.23,
		-viewport.size.x * 0.08, -viewport.size.y * 0.17)
	return safe.has_point(unproject_position(point))

func fighter_frame() -> Dictionary:
	var frame: Dictionary = {"id":followed_id, "secondary_id":_fighter_secondary_id, "relation":_fighter_relation,
		"shot_serial":shot_serial, "label":shot_label, "camera_roll_rad":global_rotation.z}
	if followed_id.is_empty() or not views.has(followed_id): return frame
	var unit: Dictionary = views[followed_id]
	var body: Basis = Basis.from_euler(unit.rotation_rad)
	frame["rotation_rad"] = SimData.array3(unit.rotation_rad)
	frame["velocity_mps"] = SimData.array3(unit.velocity_mps)
	frame["bank_rad"] = AircraftFlightMath.signed_roll(AircraftFlightMath.level_up(-body.z, body.y), body.y, -body.z)
	var task: Dictionary = unit.task.get("aircraft", {})
	frame["task_phase"] = str(task.get("phase", ""))
	frame["maneuver_phase"] = str(task.get("maneuver_phase", ""))
	var motion: Dictionary = unit.module_data.aircraft_motion.get("autonomous_maneuver", {})
	if not motion.is_empty():
		frame["autonomous_maneuver"] = {"kind":motion.kind, "phase":motion.phase, "status":motion.status,
			"sequence":motion.sequence, "verified_label":_fighter_named_sequence == int(motion.sequence),
			"started_s":motion.started_s, "ended_s":motion.ended_s, "heading_change_rad":motion.heading_change_rad,
			"body_roll_rad":motion.body_roll_rad, "height_change_m":motion.height_change_m,
			"height_span_m":motion.get("height_span_m", 0.0), "peak_lateral_offset_m":motion.get("peak_lateral_offset_m", 0.0)}
	frame["opponent_id"] = _fighter_opponent(unit)
	if views.has(_fighter_secondary_id):
		var point: Vector3 = views[_fighter_secondary_id].position_m
		var screen: Vector2 = unproject_position(point)
		frame["secondary_m"] = SimData.array3(point)
		frame["secondary_px"] = [screen.x, screen.y]
		frame["secondary_in_frame"] = _fighter_secondary_visible()
	return frame

func _safe_position(candidate: Vector3, target: Vector3) -> Vector3:
	candidate.y = maxf(candidate.y,TerrainQueries.height_data(terrain,candidate,true)+8.0)
	# Lift the entire sightline over the exact terrain/building surface. Start a
	# little above a ground impact so the contact point itself is not an obstacle.
	var origin: Vector3 = target+Vector3.UP*3.0
	for attempt: int in 8:
		var hit: Dictionary = TerrainQueries.hit_data(terrain,origin,candidate,false)
		if hit.is_empty(): break
		var t: float = maxf(.08,float(hit.fraction))
		var need: float = (float(hit.position_m.y)+12.0-origin.y)/t+origin.y
		candidate.y = maxf(candidate.y+35.0,need)
	return candidate

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: int = _key(event)
		if not event.pressed: release_key(event);return false
		if is_movement_key(event) or key == KEY_SHIFT:
			_pressed_keys[key] = true
			if event.shift_pressed: _pressed_keys[KEY_SHIFT] = true
			return true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			return true
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if mode in ["auto", "fighter"]: set_mode("free")
			distance_m = clampf(distance_m * (0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.18), 18.0, 20000.0)
			return true
	elif event is InputEventMouseMotion and _dragging and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		if mode in ["auto", "fighter"]:
			set_mode("free")
			_dragging = true # This motion is part of the still-held right-button gesture.
		yaw = wrapf(yaw-event.relative.x*.005,-PI,PI)
		pitch = clampf(pitch + event.relative.y * 0.004, -1.48, 1.48)
		if mode == "free" and manual_free:
			var orbit: Vector3 = Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance_m
			focus = position-orbit
			_orbit_offset = orbit
		return true
	return false

func adopt_current_view() -> void:
	var offset: Vector3 = position-focus
	if offset.length() < .01: return
	_orbit_offset = offset
	distance_m = offset.length()
	yaw = atan2(offset.x,offset.z)
	pitch = asin(clampf(offset.y/distance_m,-1.0,1.0))

func release_input() -> void:
	_dragging = false
	_pressed_keys.clear()

func end_drag() -> void:
	_dragging = false

func release_key(event: InputEventKey) -> void:
	_pressed_keys.erase(_key(event))

static func _key(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != 0 else event.keycode

static func is_movement_key(event: InputEventKey) -> bool:
	return _key(event) in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_Q,KEY_E]

func _move_free(delta_s: float) -> void:
	var movement: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3(-sin(yaw),0,-cos(yaw))
	var side: Vector3 = Vector3(cos(yaw),0,-sin(yaw))
	if _pressed_keys.has(KEY_W) or _pressed_keys.has(KEY_UP): movement += forward
	if _pressed_keys.has(KEY_S) or _pressed_keys.has(KEY_DOWN): movement -= forward
	if _pressed_keys.has(KEY_A) or _pressed_keys.has(KEY_LEFT): movement -= side
	if _pressed_keys.has(KEY_D) or _pressed_keys.has(KEY_RIGHT): movement += side
	if _pressed_keys.has(KEY_Q): movement += Vector3.UP
	if _pressed_keys.has(KEY_E): movement -= Vector3.UP
	var speed: float = clampf(distance_m*.75,5.0,6000.0)
	if _pressed_keys.has(KEY_SHIFT): speed *= 4.0
	focus += movement.limit_length() * speed * delta_s
	if not manual_free: focus.y = maxf(0.0, focus.y)

func _shown(view: Dictionary) -> bool:
	return bool(view.active) or view.module_data.get("damage", {}).get("phase", "") in ["disabled", "sinking", "crashing", "wreck"]

func _is_aircraft(id: String) -> bool:
	return views.has(id) and metadata.get(id, {}).get("domain", "") == "aircraft"

func _is_bomber(id: String) -> bool:
	return views.get(id, {}).get("module_data", {}).has("bomb_rack")

func _offer_air_shot(id: String, target: String, kind: String, importance: int, now: float, point: Vector3, sequence: int = 0, surface: String = "", order_id: String = "") -> void:
	var prior: Dictionary = _air_candidates.get(kind, {})
	if importance < int(prior.get("importance", 0)): return
	if importance == int(prior.get("importance", 0)) and now <= float(prior.time_s): return
	_air_candidates[kind] = {"id":id, "target_id":target, "kind":kind, "importance":importance, "time_s":now,
		"position_m":point, "sequence":sequence, "surface":surface, "order_id":order_id}

func _expire_candidates(now: float) -> void:
	var kind: String = _candidate.get("kind", "")
	var freshness_s: float = 0.08 if kind == "salvo" else (0.6 if kind in ["airburst", "surface_impact"] else 3.0)
	if not _candidate.is_empty() and now - float(_candidate.time_s) > freshness_s: _candidate = {}
	for air_kind: String in _air_candidates.keys():
		var cue: Dictionary = _air_candidates[air_kind]
		var subject: Dictionary = views.get(cue.id, {})
		if not str(cue.id).is_empty() and (subject.is_empty() or not _shown(subject)):
			_air_candidates.erase(air_kind)
			continue
		# Geometry is renewed every frame. A gun burst can lead to a continuing
		# pursuit shot, while an explosion must cut as its effect starts.
		var age_limit: float = 0.65 if air_kind == "bomb_explosion" else (1.4 if int(cue.sequence) > 0 else 0.12)
		if now - float(cue.time_s) > age_limit: _air_candidates.erase(air_kind)

func _is_surface_gunnery(cue: Dictionary) -> bool:
	return str(cue.get("kind", "")) in ["salvo", "gunnery_ready", "surface_impact"] or cue.get("mount_role", "") == "main"

func _select_shot(now: float, waiting_for_impact: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = 0
	var current_kind: String = str(shot_event.get("kind", ""))
	var since_cut: float = now - last_cut_s
	if not _candidate.is_empty():
		var importance: int = int(_candidate.importance)
		var surface: bool = _is_surface_gunnery(_candidate)
		var opening_salvo: bool = importance >= 7 and shot_event.is_empty()
		var surface_due: bool = surface and now - _last_surface_shot_s >= 14.0
		var priority: bool = importance >= 5 and importance > int(shot_event.get("importance", 0))
		var take_surface: bool = surface_due and not waiting_for_impact and since_cut >= 3.0
		var available: bool = since_cut >= (3.0 if priority else 7.0) and (hold_s <= 0.0 or priority)
		if opening_salvo or take_surface or (available and (not waiting_for_impact or importance >= 5)):
			best = _candidate
			best_score = importance + (7 if surface_due else 0)
	if since_cut < 2.5: return best
	for kind: String in _air_candidates:
		var cue: Dictionary = _air_candidates[kind]
		var shown: bool = _air_shot_times.has(kind)
		var elapsed: float = now - float(_air_shot_times.get(kind, -100.0))
		var gap: float = 3.0 if kind == "bombing_run" else 12.0
		var event_cue: bool = int(cue.sequence) > 0
		var first_firing_pass: bool = event_cue and kind in ["bomber_intercept", "fighter_dogfight"] and not _recorded_air_passes.has(kind)
		if not first_firing_pass and (elapsed < gap or (kind == current_kind and hold_s > 0.0)): continue
		# Give uncovered action a chance during overlap. A confirmed burst can
		# take over an approach shot after the minimum hold.
		if shown and not event_cue and hold_s > 0.0: continue
		var score: int = int(cue.importance) + (4 if not shown or first_firing_pass else 0)
		if score > best_score:
			best = cue
			best_score = score
	return best

func _gunnery_ready(id: String) -> Dictionary:
	var unit: Dictionary = views[id]
	var runtime: Dictionary = unit.module_data.get("combat_runtime", {})
	for mount_id: String in metadata[id].get("main_mounts", {}):
		var gun: Dictionary = unit.weapons.get(mount_id, {})
		var status: String = runtime.get("mount_status", {}).get(mount_id, "")
		var target_id: String = runtime.get("mount_targets", {}).get(mount_id, "")
		if gun.is_empty() or not gun.enabled or float(gun.cycle_remaining_s) > 2.5 or status not in ["ready", "traversing", "reloading"] or not views.has(target_id) or not views[target_id].active: continue
		if not gun.remaining_rounds.any(func(n: int) -> bool: return n > 0): continue
		var yaw_value: float = unit.rotation_rad.y + float(metadata[id].main_mounts[mount_id]) + float(gun.train_rad)
		var forward: Vector3 = Basis(Vector3.UP, yaw_value) * Vector3.FORWARD
		var delta: Vector3 = views[target_id].position_m - unit.position_m
		var angle: float = absf(Vector2(forward.x, forward.z).angle_to(Vector2(delta.x, delta.z)))
		if angle <= deg_to_rad(9.0): return {"mount_id":mount_id, "target_id":target_id, "mount_status":status, "remaining_s":gun.cycle_remaining_s, "alignment_rad":angle}
	return {}

static func describe_unit(definition: UnitDefinition) -> Dictionary:
	var main: Dictionary = {}
	for socket: MountSocket in definition.mounts:
		if socket.role == "main": main[socket.id] = socket.base_yaw_rad
	return {"domain":definition.domain, "length":definition.dimensions_m.z, "main_mounts":main,
		"fighter":definition.id in ["us_f6f5_1944", "jp_a6m5a_1944"]}
