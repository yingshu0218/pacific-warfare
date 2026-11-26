class_name CombatEffects
extends Node3D

## Rendering-only bounded consumer. Caller supplies simulation-scaled elapsed time.
const GEOMETRY: Script = preload("res://scripts/presentation/effects/combat_effect_geometry.gd")
const SURFACE: Shader = preload("res://scripts/presentation/effects/effect_surface.gdshader")
@export var effect_capacity: int = 144
@export var sound_capacity: int = 8
var effects_enabled: bool = true
var sound_enabled: bool = true
var generation: int = -1
var last_sequence: int = 0
var dropped_visuals: int = 0
var preempted_visuals: int = 0
var shown_events: int = 0
var peak_visible: int = 0
var slots: Array[Dictionary] = []
var sounds: Array[AudioStreamPlayer3D] = []
var streams: Dictionary = {}
var meshes: Dictionary = {}
var unit_views: Dictionary = {}
var engine_sources: Array[AudioStreamPlayer3D] = []
var smoke_timer_s: float = 0.0
var elapsed_s: float = 0.0
var departed_units: Dictionary = {}
var sea_contacts: Dictionary = {}
var emitter_history: Dictionary = {}
var damage_anchors: Dictionary = {}
var unit_domains: Dictionary = {}
var emission_time_s: float = 0.0
var emission_seed: float = 0.0
var component_index: int = 0
var last_persistent_time_s: float = -INF

func _ready() -> void:
	_prepare()

func _prepare() -> void:
	if not meshes.is_empty(): return
	var parameters: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/showcase.json"))
	if parameters is Dictionary:
		for id: String in parameters.get("unit_profiles",{}):
			damage_anchors[id]=parameters.unit_profiles[id].get("damage_effects",{}).duplicate(true)
			var path: String = "res://data/units/"+id+".json"
			if FileAccess.file_exists(path):
				var definition: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				if definition is Dictionary: unit_domains[id]=str(definition.get("domain",""))
	else:
		push_error("CombatEffects requires valid combat presentation profiles")
	meshes = GEOMETRY.meshes()
	for kind: String in ["heavy","light","impact","engine"]:
		streams[kind] = CombatAudioBank.synthesize(kind)

func consume(events: Array[BattleEvent], new_generation: int) -> void:
	_prepare()
	if generation != new_generation: clear(new_generation)
	# Timestamps keep a batched old fired event at the real current ballistic age.
	for event: BattleEvent in events: elapsed_s = maxf(elapsed_s,event.time_s)
	for event: BattleEvent in events:
		if event.sequence <= last_sequence: continue
		last_sequence = event.sequence
		emission_time_s = event.time_s
		emission_seed = float(event.sequence)*.131
		component_index = 0
		if event.kind in ["aircraft_exit", "ship_exit"]:
			departed_units[event.entity_id] = true
		elif event.kind == "fired":
			var caliber: float = float(event.data.caliber_m)
			var size: float = clampf(caliber * 10, .12, 4.)
			_emit("flash",event.position_m,Vector3.ZERO,size,.09)
			_emit("smoke",event.position_m,Vector3.UP*.8,size*.65,.65)
			if bool(event.data.tracer):
				var slot: Dictionary = _emit("tracer",event.position_m,event.data.velocity_mps,clampf(caliber*.7,.075,.12),90.)
				if not slot.is_empty():
					slot["projectile_id"] = event.data.projectile_id
					slot["gravity"] = float(event.data.gravity_mps2)
					_draw_slot(slot)
			_play(event.position_m,"heavy" if caliber > .1 else "light",0.)
		elif event.kind in ["hit","surface_impact","airburst","projectile_expired"]:
			_end_tracer(str(event.data.projectile_id))
			var caliber: float = float(event.data.caliber_m)
			var size: float = clampf(caliber*28,.25,14.)
			if event.kind == "airburst":
				_airburst(event.position_m,caliber,str(event.data.get("reason","time_fuze")))
				_play(event.position_m,"impact",-2.)
			elif event.kind == "surface_impact":
				if event.data.surface == "sea": _splash(event.position_m,clampf(caliber*25,.7,13.))
				else: _emit("dust",event.position_m,Vector3(1,1,0),size,2.8)
				_play(event.position_m,"impact",-2.)
			elif event.kind == "hit":
				_emit("spark",event.position_m,Vector3.UP*size,size*.3,.15)
				_emit("smoke",event.position_m,Vector3.UP*2,size*.6,1.2)
				_play(event.position_m,"impact",-3.)
		elif event.kind == "disabled":
			if bool(event.data.get("destroyed",true)): _emit("fire",event.position_m,Vector3.UP*2,5.,1.)
		elif event.kind == "unit_impact":
			var size: float = clampf(float(event.data.get("size_m",10.))*.55,1,11)
			if event.data.surface == "sea":
				sea_contacts[event.entity_id] = true
				_splash(event.position_m,size)
			else: _emit("dust",event.position_m,Vector3(1,1,0),size,3.)
			_play(event.position_m,"impact",0.)
		shown_events += 1
	_update_peak()

func _splash(point: Vector3, size: float) -> void:
	# Profiled meshes grow and fall from the intersection; only mist is ballistic.
	var main: Dictionary = _emit("water",point,Vector3.ZERO,size,2.6+size*.025)
	if not main.is_empty(): main["jet"] = 0
	for side: int in [-1,1]:
		var jet: Dictionary = _emit("water",point+Vector3(float(side)*size*.18,0,0),Vector3.ZERO,size*.55,2.2+size*.025)
		if not jet.is_empty(): jet["jet"] = side
	for side: int in [-1,1]:
		_emit("mist",point+Vector3(float(side)*size*.3,size*.4,0),Vector3(float(side)*size*.45,size*.9,0),size*1.4,2.1)
	_emit("foam",point,Vector3.ZERO,size*1.5,6.)

func _airburst(point: Vector3, caliber: float, reason: String) -> void:
	var sd: bool = reason == "tracer_self_destruct"
	var size: float = clampf(caliber*(18. if sd else 50.),.5,1.4 if sd else 10.)
	_emit("flash",point,Vector3.ZERO,size*.3,.08)
	for index: int in (1 if sd else 3):
		var offset: Vector3 = Vector3(sin(float(index)*2.5+emission_seed),cos(float(index)*2.1),sin(float(index)*3.7)) * size*.22
		var slot: Dictionary = _emit("burst",point+offset,Vector3(1.8,.6,.4),size*(.95+float(index)*.16),1.8 if sd else 6.5+float(index)*.35)
		if not slot.is_empty(): slot["reason"] = reason

func _priority(kind: String) -> int:
	if kind in ["water","foam","burst"]: return 3
	if kind in ["fire","dust","mist"]: return 2
	if kind == "tracer": return 1
	return 0

func _emit(kind: String, point: Vector3, velocity: Vector3, size: float, life: float) -> Dictionary:
	if not effects_enabled or elapsed_s-emission_time_s >= life: return {}
	var slot: Dictionary = {}
	for candidate: Dictionary in slots:
		if not candidate.active:
			slot = candidate
			break
	if slot.is_empty():
		if slots.size() >= effect_capacity:
			dropped_visuals += 1
			var lowest: int = _priority(kind)
			for candidate: Dictionary in slots:
				if int(candidate.priority)<lowest:
					slot = candidate
					lowest = int(candidate.priority)
			# Fast smoke trails retain the newest bounded segment when saturated.
			if slot.is_empty() and kind=="smoke":
				var oldest: float = INF
				for candidate: Dictionary in slots:
					if candidate.kind=="smoke" and float(candidate.born_s)<oldest:
						slot=candidate
						oldest=float(candidate.born_s)
			if slot.is_empty(): return {}
			preempted_visuals += 1
		else:
			var mesh: MeshInstance3D = MeshInstance3D.new()
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = SURFACE
			mesh.material_override = material
			add_child(mesh)
			slot = {"mesh":mesh,"material":material}
			slots.append(slot)
	slot.merge({"active":true,"kind":kind,"position":point,"velocity":velocity,"size":maxf(size,.01),"age":maxf(0,elapsed_s-emission_time_s),"born_s":emission_time_s,"life":maxf(life,.01),"gravity":0.,"projectile_id":"","priority":_priority(kind),"jet":0,"seed":fposmod(emission_seed+component_index*.371,1.),"reason":"","emitter_id":"","part_id":"","owner_id":"","anchor_m":Vector3.ZERO},true)
	component_index += 1
	var mesh: MeshInstance3D = slot.mesh
	mesh.mesh = meshes["water" if kind=="water" else "foam" if kind=="foam" else "tracer" if kind=="tracer" else "cloud"]
	var mode: int = 1 if kind=="water" else 2 if kind=="foam" else 3 if kind=="tracer" else 4 if kind=="fire" else 5 if kind in ["flash","spark"] else 0
	var color: Color = Color(.15,.16,.17,.88)
	match kind:
		"water", "mist", "foam": color=Color(.78,.88,.91,.8)
		"burst": color=Color(.075,.08,.085,.93)
		"dust": color=Color(.53,.42,.29,.68)
		"tracer": color=Color(1,.48,.075,1)
		"fire": color=Color(1,.23,.025,.9)
		"flash", "spark": color=Color(1,.85,.28,1)
	var material: ShaderMaterial = slot.material
	material.set_shader_parameter("effect_mode",mode)
	material.set_shader_parameter("tint",color)
	material.set_shader_parameter("seed",slot.seed)
	material.set_shader_parameter("trail_axis",Vector3.ZERO)
	material.set_shader_parameter("trail_stretch",1.)
	material.set_shader_parameter("water_fade_m",2.5 if kind=="mist" else .75 if kind in ["smoke","burst","dust"] else .25 if kind=="fire" else 0.)
	mesh.visible = true
	_draw_slot(slot)
	return slot

func _draw_slot(slot: Dictionary) -> void:
	var mesh: MeshInstance3D = slot.mesh
	var age: float = float(slot.age)
	var phase: float = clampf(age/float(slot.life),0,1)
	var size: float = float(slot.size)
	var point: Vector3 = slot.position+(slot.velocity as Vector3)*age+Vector3.DOWN*float(slot.gravity)*.5*age*age
	var fade: float = 1.-smoothstep(.5,1.,phase)
	mesh.basis = Basis.IDENTITY
	mesh.position = point
	if slot.kind == "tracer":
		var direction: Vector3 = (slot.velocity as Vector3)+Vector3.DOWN*float(slot.gravity)*age
		if direction.length_squared() > .001:
			mesh.basis = Basis.looking_at(direction.normalized(),Vector3.RIGHT if absf(direction.normalized().y)>.99 else Vector3.UP)
		mesh.scale = Vector3(size,size,clampf(direction.length()*.006,.8,6.))
		fade = 1.
	elif slot.kind == "water":
		var rise_fall: float = pow(maxf(0,sin(PI*phase)),.85)
		var height: float = maxf(.02,size*3.3*rise_fall)
		mesh.rotation.z = float(slot.jet)*.18*rise_fall
		mesh.scale = Vector3(size*(.75+phase*.5),height,size*(.75+phase*.5))
		mesh.position = slot.position
		fade *= smoothstep(0,.08,phase)
	elif slot.kind == "foam":
		mesh.position = slot.position+Vector3.UP*.08
		mesh.scale = Vector3(size*(.6+phase*3.4),1,size*(.6+phase*3.4))
		fade *= smoothstep(0,.06,phase)
	elif slot.kind in ["smoke","burst","dust","mist"]:
		var growth: float = .65+(1.-exp(-age*3.))*1.0+phase*.7
		mesh.scale = Vector3.ONE*size*growth
		fade *= smoothstep(0,.003 if slot.kind=="smoke" else .05,phase)
		if slot.kind == "mist":
			mesh.position.y = maxf(float(slot.position.y),point.y-age*age*size*.4)
	else:
		mesh.scale = Vector3.ONE*maxf(.01,size*(1.-phase))
	var material: ShaderMaterial = slot.material
	material.set_shader_parameter("fade",fade)
	material.set_shader_parameter("phase",phase)
	slot["opacity"] = fade

func advance(delta_s: float) -> void:
	_prepare()
	var dt: float = maxf(0,delta_s)
	elapsed_s += dt
	for slot: Dictionary in slots:
		if not slot.active: continue
		slot.age = maxf(0,elapsed_s-float(slot.born_s))
		if not effects_enabled or float(slot.age)>=float(slot.life):
			slot.active = false
			(slot.mesh as MeshInstance3D).visible = false
			continue
		if dt>0: _draw_slot(slot)
	smoke_timer_s -= dt
	_update_peak()

func _persistent(id: String, unit: Dictionary, due: bool) -> void:
	var module_data: Dictionary = unit.get("module_data",{})
	if departed_units.has(id) or sea_contacts.has(id) or not CombatPresence.is_present(module_data): return
	var damage: Dictionary = module_data.get("damage",{})
	var pose: Transform3D = Transform3D(Basis.from_euler(unit.get("rotation_rad",Vector3.ZERO)),unit.position_m)
	emission_seed = float(absi(id.hash())%997)/997.
	component_index = 0
	if damage.has("effect_emitters"):
		var count: int = 0
		for emitter: Dictionary in damage.effect_emitters:
			count += 1
			if count>4: break
			var local_point: Variant = emitter.get("anchor_m")
			if not bool(emitter.get("enabled",true)): continue
			if local_point is Vector3:
				if not (local_point as Vector3).is_finite(): continue
			elif SimData.valid_vector(local_point): local_point=SimData.vec3(local_point)
			else: continue
			var kind: String = str(emitter.get("kind",""))
			var intensity: float = clampf(float(emitter.get("intensity",0.)),0,1)
			if kind not in ["smoke","fire"] or intensity<=.01: continue
			if kind=="fire" and not due:continue
			var slot: Dictionary
			var size: float = clampf(float(emitter.get("size_m",1.)),.2,8.)
			if kind=="smoke": slot=_smoke_trail(id+"/"+str(emitter.get("id",count)),pose*(local_point as Vector3),size,4.5,Color(.10,.11,.12,.4+intensity*.5))
			else: slot=_emit(kind,pose*(local_point as Vector3),Vector3.UP,size,.6)
			if not slot.is_empty():
				slot["emitter_id"] = str(emitter.get("id",""))
				slot["part_id"] = str(emitter.get("part_id",""))
				(slot.material as ShaderMaterial).set_shader_parameter("tint",Color(.10,.11,.12,.4+intensity*.5) if kind=="smoke" else Color(1,.23,.025,.4+intensity*.5))
				if kind=="fire":_attach_fire(slot,id,local_point)
		return
	var anchors: Dictionary = damage_anchors.get(str(unit.get("definition_id","")),{})
	var severity: float = float(damage.get("fire",0.))
	if severity > .01:
		if due:
			var local_point: Vector3=SimData.vec3(anchors.get("fire_anchor_m",[0,3,0]))
			var slot: Dictionary=_emit("fire",pose*local_point,Vector3.ZERO,1+severity*4,.5)
			if not slot.is_empty():_attach_fire(slot,id,local_point)
		_smoke_trail(id+"/legacy_fire",pose*SimData.vec3(anchors.get("smoke_anchor_m",[0,5,0])),2+severity*5,3.,Color(.15,.16,.17,.88))
	elif damage.get("phase","") == "crashing":
		_smoke_trail(id+"/legacy_crash",unit.position_m,2.5,3.,Color(.10,.11,.12,.88))

func _smoke_trail(key: String, point: Vector3, size: float, life: float, color: Color) -> Dictionary:
	var now: float = elapsed_s
	var previous: Dictionary = emitter_history.get(key,{})
	var count: int = 1
	var from: Vector3 = point
	var begin: float = now
	if not previous.is_empty() and now-float(previous.time_s)<.7:
		from=previous.point
		begin=float(previous.time_s)
		if from.distance_to(point)<maxf(1.,size*.8) and now-begin<.3:return {}
		count=clampi(ceili(from.distance_to(point)/maxf(1.,size*.8)),1,16)
	var result: Dictionary = {}
	for index: int in count:
		var fraction: float = float(index+1)/count
		emission_time_s=lerpf(begin,now,fraction)
		result=_emit("smoke",from.lerp(point,fraction),Vector3(1.8,1.4,.4),size,life)
		if not result.is_empty():
			var material: ShaderMaterial = result.material
			material.set_shader_parameter("tint",color)
			if from.distance_to(point)>size*.25:
				material.set_shader_parameter("trail_axis",(point-from).normalized())
				material.set_shader_parameter("trail_stretch",1.8)
	emission_time_s=now
	emitter_history[key]={"point":point,"time_s":now}
	return result

func _attach_fire(slot: Dictionary, id: String, anchor: Vector3) -> void:
	slot["owner_id"]=id
	slot["anchor_m"]=anchor
	slot["velocity"]=Vector3.ZERO

func _current_sources() -> void:
	# Host order is advance -> consume -> apply_snapshot. Emit from THIS pose,
	# never from the previous frame's body transform while aging old smoke.
	if last_persistent_time_s!=elapsed_s:
		var due: bool=smoke_timer_s<=0
		if due:smoke_timer_s=.3
		emission_time_s=elapsed_s
		for id: String in unit_views:_persistent(id,unit_views[id],due)
		last_persistent_time_s=elapsed_s
	for slot: Dictionary in slots:
		if not slot.active or str(slot.owner_id).is_empty():continue
		var id: String=slot.owner_id
		var view: Dictionary=unit_views.get(id,{})
		if view.is_empty() or departed_units.has(id) or sea_contacts.has(id) or not CombatPresence.is_present(view.get("module_data",{})):
			slot.active=false
			(slot.mesh as MeshInstance3D).visible=false
			continue
		slot.position=Transform3D(Basis.from_euler(view.get("rotation_rad",Vector3.ZERO)),view.position_m)*(slot.anchor_m as Vector3)
		_draw_slot(slot)
	_update_peak()

func _update_peak() -> void:
	var count: int = 0
	for slot: Dictionary in slots:
		if slot.active: count+=1
	peak_visible = maxi(peak_visible,count)

func apply_snapshot(snapshot: Dictionary) -> void:
	unit_views = snapshot.get("units",{}).duplicate(true)
	_prepare()
	_current_sources()
	var ids: Array = unit_views.keys()
	ids.sort()
	var index: int = 0
	for id: String in ids:
		var unit: Dictionary = unit_views[id]
		if not unit.active or departed_units.has(id) or not CombatPresence.is_present(unit.get("module_data",{})): continue
		var data: Dictionary = unit.get("module_data",{})
		if unit_domains.get(str(unit.get("definition_id","")),"")=="ground" or data.has("ground_initial"): continue
		if float(data.get("damage",{}).get("propulsion_factor",1.))<=.001: continue
		if index >= 4: break
		if engine_sources.size() <= index:
			var engine: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			# Fixed Web template sample playback retains many native audio nodes.
			# The engine mixer keeps the same spatial audio in a bounded output graph.
			if OS.has_feature("web"): engine.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			engine.stream = streams.engine
			engine.unit_size = 80
			engine.max_distance = 1800
			engine.volume_db = -28
			add_child(engine)
			engine_sources.append(engine)
		var engine: AudioStreamPlayer3D = engine_sources[index]
		engine.position = unit.position_m
		engine.pitch_scale = .8 + minf((unit.velocity_mps as Vector3).length()/300.,.5)
		if sound_enabled and not engine.playing: engine.play()
		if not sound_enabled: engine.stop()
		index += 1
	for extra: int in range(index,engine_sources.size()): engine_sources[extra].stop()

func _play(point: Vector3, kind: String, volume_db: float) -> void:
	if not sound_enabled: return
	var player: AudioStreamPlayer3D
	for candidate: AudioStreamPlayer3D in sounds:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		if sounds.size() >= sound_capacity: return
		player = AudioStreamPlayer3D.new()
		if OS.has_feature("web"): player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.unit_size = 90
		player.max_distance = 10000
		add_child(player)
		sounds.append(player)
	player.position = point
	player.stream = streams[kind]
	player.volume_db = volume_db - 7.
	player.pitch_scale = 1.
	player.play()

func _end_tracer(id: String) -> void:
	for slot: Dictionary in slots:
		if slot.active and slot.projectile_id == id:
			slot.active = false
			(slot.mesh as MeshInstance3D).visible = false

func clear(new_generation: int = -1) -> void:
	generation = new_generation
	last_sequence = 0
	dropped_visuals = 0
	preempted_visuals = 0
	peak_visible = 0
	shown_events = 0
	elapsed_s = 0.
	emission_time_s = 0.
	smoke_timer_s = 0.
	last_persistent_time_s = -INF
	unit_views.clear()
	departed_units.clear()
	sea_contacts.clear()
	emitter_history.clear()
	for slot: Dictionary in slots:
		slot.active = false
		(slot.mesh as MeshInstance3D).visible = false
	for player: AudioStreamPlayer3D in sounds: player.stop()
	for player: AudioStreamPlayer3D in engine_sources: player.stop()

func statistics() -> Dictionary:
	var active: int = 0
	var actual_visible: int = 0
	for slot: Dictionary in slots:
		if slot.active: active += 1
		if (slot.mesh as MeshInstance3D).visible: actual_visible+=1
	return {"allocated":slots.size(),"active":active,"render_instances":slots.size(),"visible_instances":actual_visible,"materials":slots.size(),"peak_visible":peak_visible,"dropped":dropped_visuals,"preempted":preempted_visuals,"last_sequence":last_sequence,"shown_events":shown_events,"sound_sources":sounds.size(),"engine_sources":engine_sources.size()}
