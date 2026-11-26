class_name ShowcaseGuide
extends RefCounted

## Read-only camera director. Stable world-up preserves visible roll/horizon.
var mode: String = "guided"
var active: bool = true
var current: String = ""
var last_cut: String = ""
var selected_gallery: int = 0
var training_subject: String = ""
var cycle_phase: String = ""

func reset(exercise: String) -> void:
	mode = exercise
	active = true
	current = ""
	last_cut = ""

func update(camera: ObserverCamera, views: Dictionary, now: float, dt: float, gallery: ShowcaseWeaponGallery) -> Dictionary:
	if not active: return {}
	var section: String = mode
	if mode.begins_with("train_"): section = "training"
	if mode == "guided":
		if now < 7: section = "pair"
		elif now < 15: section = "ward"
		elif now < 47: section = "ships"
		elif now < 63: section = "ground"
		elif now < 88: section = "four"
		elif now < 120: section = "maneuver"
		elif now < 150: section = "regroup"
		elif now < 185: section = "escort"
		elif now < 210: section = "gallery"
		else:
			active = false
			camera.set_mode("auto")
			return {"section":"natural","label":"导览结束 · 继续自然观战"}
	current = section
	var ids: Array[String] = []
	var label: String = ""
	match section:
		"training":
			ids = [training_subject]
			label = "飞行训练 · 稳定地平线"
		"pair":
			ids = ["us_pair_demo_1","us_pair_demo_2"]
			label = "双机编组观察"
		"four", "regroup":
			ids = ["us_air_1","us_air_2","us_air_3","us_air_4"]
			label = "四机编组观察" if section == "four" else "四机当前任务观察"
			# Wide four-plane context alternates with legible pair views; no model
			# scaling or rigid binding compensates for real formation separation.
			var view_time: float = fmod(now,30.0)
			if view_time >= 5 and view_time < 15: ids = ["us_air_1","us_air_2"]; label = "四机 · 第一双机近景"
			elif view_time >= 15 and view_time < 25: ids = ["us_air_3","us_air_4"]; label = "四机 · 第二双机近景"
			elif view_time >= 25: ids = ["us_air_1"]; label = "四机 · 长机近景"
			if cycle_phase in ["regrouping","regrouped"]: label = "四机 · "+("实际集结" if cycle_phase == "regrouping" else "集结已完成")
			if ids.size() == 2 and (views[ids[0]].position_m as Vector3).distance_to(views[ids[1]].position_m) > 650:
				ids.resize(1)
		"maneuver":
			var candidate: String = "us_pair_demo_1" if mode == "maneuver" else "us_air_1"
			for id: String in [candidate,"us_air_1","us_air_2","us_air_3","us_air_4"]:
				var phase: String = str(views[id].task.get("aircraft",{}).get("maneuver_phase",""))
				if phase in ["split_s_roll","split_s_pull","break_turn_roll","break_turn_pull","roll_reversal_roll","roll_reversal_pull"]:
					candidate = id
					break
			ids = [candidate]
			label = "飞机当前姿态观察"
		"ward", "escort":
			var view_time: float = fmod(now,30.0)
			ids = ["us_sb2c_1"]
			label = "SB2C-4 · 航路观察"
			if section == "escort" and view_time >= 10 and view_time < 21:
				ids = ["us_air_3","us_air_4"]
				label = "护航编组 · 第二双机近景"
				if (views[ids[0]].position_m as Vector3).distance_to(views[ids[1]].position_m) > 650: ids.resize(1)
			elif section == "escort" and view_time >= 21 and view_time < 26:
				ids = ["us_sb2c_1","us_air_1","us_air_3"]
				label = "护航 · 保护对象与两组位置关系"
			elif section == "escort" and view_time >= 26:
				ids = ["us_air_1"]
				label = "护航编组 · 长机近景"
		"ships", "fire":
			var elapsed: float = now-15 if section == "ships" else now
			ids = [["jp_bb","us_bb","jp_dd","us_dd"][int(elapsed/(8 if section == "ships" else 12))%4]]
			label = "军舰当前任务观察"
		"ground":
			ids = [["us_coast_01","us_aa_01"][int((now-47)/8)%2]]
			label = "岸炮与防空阵地观察"
		"gallery":
			if gallery.entries.is_empty(): return {}
			var index: int = selected_gallery if mode == "gallery" else clampi(int((now-185)/5),0,gallery.entries.size()-1)
			var entry: Dictionary = gallery.entries[index]
			camera.mode = "free"
			camera.followed_id = ""
			camera.focus = entry.focus_m
			camera.distance_m = entry.distance
			camera.near = .08
			camera.yaw = .68
			camera.pitch = .26
			camera.shot_label = entry.name
			camera._snap = last_cut != entry.id
			last_cut = entry.id
			return {"section":section,"label":entry.name + " · 仅兵器检视"}
	var alive: Array[String] = []
	for id: String in ids:
		if views.has(id) and (views[id].active or views[id].module_data.get("damage",{}).get("phase","") in ["crashing","wreck"]): alive.append(id)
	if alive.is_empty():
		# Keep advancing the guide. A lost subject never cancels all later types.
		for id: String in views:
			if views[id].active: alive.append(id); break
		if alive.is_empty():
			return {"section":section,"label":"演示对象均已退出 · 保留战场位置"}
		label = "本段对象已退出 · 暂看 " + str(camera.metadata[alive[0]].get("name",alive[0]))
	camera.mode = "free"
	camera.followed_id = ""
	camera.views = views
	var bounds: AABB = AABB(views[alive[0]].position_m,Vector3.ZERO)
	for id: String in alive: bounds = bounds.expand(views[id].position_m)
	var focus: Vector3 = bounds.get_center()
	var air: bool = camera.metadata[alive[0]].domain == "aircraft"
	var span: float = bounds.size.length()
	var length: float = float(camera.metadata[alive[0]].get("length",12))
	var distance: float = maxf(52.0,span*1.15+28.0) if air else maxf(18.0,length*1.50)
	if air and alive.size()==1:
		distance = 34.0 if section=="training" else (38.0 if alive[0].begins_with("us_sb2c_") else 42.0)
	var cut: String = section+":"+str(alive)
	if air:
		# The orbit heading can follow slow horizontal track, never aircraft roll.
		var velocity: Vector3 = views[alive[0]].velocity_mps
		var desired_yaw: float = atan2(-velocity.x,-velocity.z)+.80
		if alive.size() > 1:
			# View across the actual group axis, rather than down it: both planes
			# then have similar depth/scale and the nearer one cannot hide its mate.
			var longest: Vector3 = Vector3.ZERO
			for a: String in alive:
				for b: String in alive:
					var difference: Vector3 = views[a].position_m-views[b].position_m
					difference.y = 0
					if difference.length_squared() > longest.length_squared(): longest = difference
			if longest.length() > 10:
				var across: Vector3 = longest.normalized().cross(Vector3.UP)
				if across.dot(-velocity) < 0: across = -across
				desired_yaw = atan2(across.x,across.z)
		if Vector2(velocity.x,velocity.z).length() > 30:
			camera.yaw = desired_yaw if last_cut != cut else rotate_toward(camera.yaw,desired_yaw,dt*.22)
		camera.pitch = .17 if alive.size()==1 else .26
	else:
		camera.yaw = float((views[alive[0]].rotation_rad as Vector3).y)+1.1
		camera.pitch = .26
		focus += Vector3.UP*(10 if length > 100 else 1.4)
	camera.focus = focus
	camera.distance_m = distance
	camera._snap = last_cut != cut
	camera.shot_label = label
	last_cut = cut
	return {"section":section,"label":label,"ids":alive}
