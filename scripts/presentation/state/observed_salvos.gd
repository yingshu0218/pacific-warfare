extends RefCounted
## Appends authoritative *past* position samples only. No launch maths or target positions.
const MAX_SALVOS: int = 24
const MAX_TRACKS: int = 144
const MAX_POINTS: int = 280
const SAMPLE_STEP: int = 5
const TERMINALS: Array[String] = ["hit", "surface_impact", "airburst", "projectile_expired"]
var groups: Array[Dictionary] = []
var tracks: Dictionary = {}

func clear() -> void:
	groups.clear()
	tracks.clear()

func record(events: Array[BattleEvent], positions: Dictionary, tick: int, time_s: float) -> void:
	var pending: Dictionary = {}
	for event: BattleEvent in events:
		if event.kind == "fired" and event.data.get("source_domain") == "ship" and event.data.get("mount_role") == "main":
			var key: String = event.entity_id + ":" + event.target_id
			if not pending.has(key): pending[key] = []
			pending[key].append(event)
		elif event.kind == "salvo":
			var shots: Array = pending.get(event.entity_id + ":" + event.target_id, [])
			if shots.is_empty(): continue
			var group: Dictionary = {"id":event.event_id,"source":event.entity_id,"time_s":event.time_s,"ids":[]}
			groups.append(group)
			var mounts: Array = event.data.get("mount_ids",[])
			for shot: BattleEvent in shots:
				if not mounts.has(shot.weapon_id.get_slice("/",1)): continue
				var id: String = str(shot.data.get("projectile_id",""))
				if id.is_empty() or tracks.has(id): continue
				group.ids.append(id)
				tracks[id] = {"points":PackedVector3Array([shot.position_m]),"times":PackedFloat64Array([shot.time_s]),"terminal":""}
			while groups.size() > MAX_SALVOS or tracks.size() > MAX_TRACKS:
				for old_id: String in groups.pop_front().ids: tracks.erase(old_id)
		elif event.kind in TERMINALS:
			var id: String = str(event.data.get("projectile_id",""))
			if not tracks.has(id) or not str(tracks[id].terminal).is_empty(): continue
			_append(tracks[id],event.position_m,event.time_s)
			var surface: String = str(event.data.get("surface",""))
			tracks[id].terminal = "sea" if surface == "sea" else ("airburst" if event.kind == "airburst" else ("hit" if event.kind == "hit" else ("land" if event.kind == "surface_impact" else "expired")))
	if tick % SAMPLE_STEP == 0:
		for id: String in tracks:
			var track: Dictionary = tracks[id]
			if str(track.terminal).is_empty() and positions.has(id):
				_append(track,positions[id],time_s)

func _append(track: Dictionary, point: Vector3, time_s: float) -> void:
	var times: PackedFloat64Array = track.times
	var points: PackedVector3Array = track.points
	if times.size() > 0 and time_s <= times[-1]+0.0000001:
		points[-1] = point
	else:
		if points.size() >= MAX_POINTS:
			# Keep actual endpoints. No interpolation, extrapolation or trajectory reconstruction.
			points.remove_at(1)
			times.remove_at(1)
		points.append(point)
		times.append(time_s)
	track.points = points
	track.times = times

func latest(source: String, shown_time_s: float, rank: int = 0) -> Dictionary:
	for index: int in range(groups.size()-1,-1,-1):
		var group: Dictionary = groups[index]
		if group.source == source and float(group.time_s) <= shown_time_s+0.0000001 and not group.ids.is_empty():
			if rank == 0: return group
			rank -= 1
	return {}

func visible_tracks(group: Dictionary, shown_time_s: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in group.get("ids",[]):
		if not tracks.has(id): continue
		var track: Dictionary = tracks[id]
		var points: PackedVector3Array = track.points
		var times: PackedFloat64Array = track.times
		var count: int = times.size()
		while count > 0 and times[count-1] > shown_time_s+0.0000001: count -= 1
		if count == 0: continue
		result.append({"id":id,"points":points.slice(0,count),"terminal":track.terminal if count == times.size() else ""})
	return result
