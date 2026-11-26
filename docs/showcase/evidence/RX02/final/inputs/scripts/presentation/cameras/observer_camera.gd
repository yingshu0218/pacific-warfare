class_name ObserverCamera
extends Camera3D

## Observer data only. This class never receives a world or a mutable UnitState.
var terrain: Dictionary = {}
var mode: String = "auto"
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
var _dragging: bool = false
var _snap: bool = true
var _auto_index: int = 0
var _observed_fires: Dictionary = {}
var _air_focus_times: Dictionary = {}
var _following_salvo: bool = false
var _ship_focus_times: Dictionary = {}
var _orbit_offset: Vector3 = Vector3.ZERO
var _pressed_keys: Dictionary = {}

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
	shot_event.clear()
	shot_serial = 0
	mode = "auto"
	manual_free = false
	followed_id = ""
	shot_label = "战场全景"
	hold_s = 0.0
	last_cut_s = -100.0
	_auto_index = 0
	_observed_fires.clear()
	_air_focus_times.clear()
	_ship_focus_times.clear()
	_following_salvo = false
	release_input()
	_snap = true

func consume(events: Array[BattleEvent]) -> void:
	if mode != "auto": return
	for event: BattleEvent in events:
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
	mode = value
	manual_free = value == "free"
	release_input()
	_candidate.clear()
	hold_s = 0.0
	if mode == "free":
		followed_id = ""
		shot_label = "自由观察"

func follow(id: String) -> void:
	release_input()
	mode = "follow"
	manual_free = false
	followed_id = id
	shot_label = "机群跟随" if metadata.get(id, {}).get("domain", "") == "aircraft" else "舰队跟随"
	if metadata.get(id,{}).get("domain","")=="ground":shot_label="岸防阵地"
	fit_unit(id)

func locate(point: Vector3, ids: Array[String] = []) -> void:
	release_input()
	mode = "free"
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
	if mode == "auto":
		for id: String in views:
			var air_task: Dictionary = views[id].task.get("aircraft", {})
			var target_id: String = air_task.get("target_id", "")
			if air_task.get("phase", "") in ["approach", "aim", "burst"] and float(air_task.get("distance_m", INF)) <= 1600.0 and views[id].active and views.has(target_id) and views[target_id].active and simulation_s - float(_air_focus_times.get(id, -100.0)) > 45.0 and int(_candidate.get("importance", 0)) < 5:
				# Frame an actual close engagement before its brief burst, without commanding it.
				_candidate = {"id":id, "position_m":views[id].position_m, "importance":5, "kind":"air_engagement", "time_s":simulation_s, "target_id":target_id, "phase":air_task.phase}
			if views[id].active and float(metadata[id].get("length", 0.0)) >= 180.0 and simulation_s - float(_ship_focus_times.get(id, -100.0)) > 25.0 and int(_candidate.get("importance", 0)) < 5:
				var ready: Dictionary = _gunnery_ready(id)
				if not ready.is_empty(): _candidate = ready.merged({"id":id, "position_m":views[id].position_m, "importance":5, "kind":"gunnery_ready", "time_s":simulation_s})
			var fire: float = float(views[id].module_data.get("damage", {}).get("fire", 0.0))
			if fire < 0.05: _observed_fires.erase(id)
			if fire >= 0.12 and _shown(views[id]) and not _observed_fires.has(id) and int(_candidate.get("importance", 0)) < 4:
				_candidate = {"id":id, "position_m":views[id].position_m, "importance":4, "kind":"persistent_damage", "time_s":simulation_s}
		hold_s -= delta_s
		var kind: String = _candidate.get("kind", "")
		var freshness_s: float = 0.08 if kind == "salvo" else (0.6 if kind in ["airburst", "surface_impact"] else 3.0)
		if not _candidate.is_empty() and simulation_s - float(_candidate.time_s) > freshness_s: _candidate.clear()
		# A salvo follow gets at most six extra seconds for its actual impact event.
		var waiting_for_impact: bool = _following_salvo and hold_s > -6.0
		var replace_idle: bool = shot_event.is_empty() and int(_candidate.get("importance",0))>=4
		var main_priority: bool = int(_candidate.get("importance",0))>=5 and int(_candidate.get("importance",0))>int(shot_event.get("importance",0))
		# A first heavy-gun release may interrupt a lower-priority view once.
		# Equal-priority turrets/bursts retain the existing stable shot hold.
		var cut_interval: float = (0.0 if int(_candidate.get("importance",0))>=7 else 3.0) if main_priority else 7.0
		if not _candidate.is_empty() and (hold_s <= 0.0 or replace_idle or main_priority) and simulation_s - last_cut_s >= cut_interval and (not waiting_for_impact or int(_candidate.importance) >= 5):
			shot_event = _candidate.duplicate(true)
			shot_serial += 1
			if _candidate.kind == "persistent_damage": _observed_fires[_candidate.id] = true
			if _candidate.kind == "air_engagement": _air_focus_times[_candidate.id] = simulation_s
			if _candidate.kind in ["salvo", "gunnery_ready"]: _ship_focus_times[_candidate.id] = simulation_s
			_following_salvo = _candidate.kind in ["salvo", "gunnery_ready"]
			var id: String = _candidate.id
			if views.has(id) and _shown(views[id]):
				followed_id = id
				fit_unit(id)
				if _candidate.kind in ["salvo", "gunnery_ready"]: distance_m *= 0.7
				shot_label = {"salvo":"主炮跟拍", "gunnery_ready":"主炮跟拍", "fired":"近距空战", "air_engagement":"近距空战", "damaged":"命中与伤情", "disabled":"战斗失能", "airburst":"防空交战", "surface_impact":"重炮落弹", "damage_phase":"伤情变化", "persistent_damage":"持续火情"}.get(_candidate.kind, "交战跟随")
				if metadata[id].domain=="ground" and _candidate.kind=="fired":shot_label="岸防炮组射击"
				if metadata[id].domain=="ship" and _candidate.kind=="fired":
					shot_label="主炮射击" if _candidate.mount_role=="main" else ("防空炮射击" if str(_candidate.mount_role).begins_with("aa") or metadata.get(str(_candidate.target_id),{}).get("domain","")=="aircraft" else "舰炮射击")
			else:
				followed_id = ""
				focus = _candidate.position_m
				distance_m = 100.0 if _candidate.kind == "airburst" else 170.0
				pitch = 0.3
				shot_label = "防空空爆" if _candidate.kind == "airburst" else "重炮落弹"
				_snap = true
			last_cut_s = simulation_s
			hold_s = 9.0
			_candidate.clear()
		elif hold_s <= 0.0 and not paused and not waiting_for_impact:
			shot_serial += 1
			_following_salvo = false
			shot_event = {}
			var ids: Array[String] = []
			for id: String in views:
				if views[id].active: ids.append(id)
			ids.sort()
			if not ids.is_empty():
				if _auto_index % 4 == 0:
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
			if mode == "auto": set_mode("free")
			distance_m = clampf(distance_m * (0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.18), 18.0, 20000.0)
			return true
	elif event is InputEventMouseMotion and _dragging and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		if mode == "auto":
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
	return {"domain":definition.domain, "length":definition.dimensions_m.z, "main_mounts":main}
