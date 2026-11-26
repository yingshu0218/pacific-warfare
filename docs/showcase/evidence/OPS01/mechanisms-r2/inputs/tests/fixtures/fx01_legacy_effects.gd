extends Node3D

## Rendering-only bounded consumer. Caller supplies simulation-scaled elapsed time.
@export var effect_capacity: int = 144
@export var sound_capacity: int = 8
var effects_enabled: bool = true
var sound_enabled: bool = true
var generation: int = -1
var last_sequence: int = 0
var dropped_visuals: int = 0
var shown_events: int = 0
var slots: Array[Dictionary] = []
var sounds: Array[AudioStreamPlayer3D] = []
var streams: Dictionary = {}
var materials: Dictionary = {}
var sphere: SphereMesh
var cylinder: CylinderMesh
var unit_views: Dictionary = {}
var engine_sources: Array[AudioStreamPlayer3D] = []
var smoke_timer_s: float = 0.0
var elapsed_s: float = 0.0
var departed_units: Dictionary = {}
var damage_anchors: Dictionary = {}

func _ready() -> void:
	_prepare()

func _prepare() -> void:
	if sphere != null: return
	var parameters: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/showcase.json"))
	if parameters is Dictionary:
		for id: String in parameters.get("unit_profiles",{}):
			damage_anchors[id]=parameters.unit_profiles[id].get("damage_effects",{}).duplicate(true)
	else:
		push_error("CombatEffects requires valid combat presentation profiles")
	sphere = SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.radius = 0.5
	sphere.height = 1.0
	cylinder = CylinderMesh.new()
	cylinder.radial_segments = 8
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	for kind: String in ["heavy","light","impact","engine"]:
		streams[kind] = CombatAudioBank.synthesize(kind)
	for kind: String in ["flash","smoke","tracer","water","dust","burst","fire","spark"]:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = false
		var colors: Dictionary = {"flash":Color(1,.7,.16,.9),"smoke":Color(.22,.24,.26,.5),"tracer":Color(1,.48,.08,1),"water":Color(.72,.88,1,.7),"dust":Color(.6,.43,.27,.65),"burst":Color(.12,.13,.14,.8),"fire":Color(1,.25,.025,.85),"spark":Color(1,.92,.6,1)}
		material.albedo_color = colors[kind]
		if kind in ["flash","tracer","fire","spark"]:
			material.emission_enabled = true
			material.emission = colors[kind]
		materials[kind] = material

func consume(events: Array[BattleEvent], new_generation: int) -> void:
	_prepare()
	if generation != new_generation:
		clear(new_generation)
	for event: BattleEvent in events:
		if event.sequence <= last_sequence: continue
		last_sequence = event.sequence
		if event.kind in ["aircraft_exit", "ship_exit"]:
			# Keep delayed pre-exit snapshots from restarting a persistent emitter.
			departed_units[event.entity_id] = true
		elif event.kind == "fired":
			var caliber: float = float(event.data.caliber_m)
			var size: float = clampf(caliber * 12, .12, 6.)
			_emit("flash",event.position_m,Vector3.ZERO,size,.09)
			_emit("smoke",event.position_m,Vector3.UP*2,size*.7,.7)
			if bool(event.data.tracer):
				var slot: Dictionary = _emit("tracer",event.position_m,event.data.velocity_mps,maxf(.035,caliber*.8),minf(8,maxf(.2,float(event.data.flight_time_s))))
				if not slot.is_empty():
					slot["projectile_id"] = event.data.projectile_id
					slot["gravity"] = float(event.data.gravity_mps2)
			_play(event.position_m,"heavy" if caliber > .1 else "light",0.)
		elif event.kind in ["hit","surface_impact","airburst","projectile_expired"]:
			_end_tracer(str(event.data.projectile_id))
			var caliber: float = float(event.data.caliber_m)
			var size: float = clampf(caliber*28,.25,14.)
			if event.kind == "airburst":
				_emit("burst",event.position_m,Vector3.UP,size,.9)
				_emit("flash",event.position_m,Vector3.ZERO,size*.35,.08)
				_play(event.position_m,"impact",-2.)
			elif event.kind == "surface_impact":
				var sea: bool = event.data.surface == "sea"
				_emit("water" if sea else "dust",event.position_m,Vector3.UP*size*.7,size,1.8 if sea else 1.4)
				if sea:
					_emit("foam",event.position_m,Vector3.ZERO,size*.6,1.7)
				_play(event.position_m,"impact",-2.)
			elif event.kind == "hit":
				_emit("spark",event.position_m,Vector3.UP*size,size*.25,.15)
				_emit("smoke",event.position_m,Vector3.UP*2,size*.6,.8)
				_play(event.position_m,"impact",-3.)
		elif event.kind == "disabled":
			if bool(event.data.get("destroyed",true)):_emit("fire",event.position_m,Vector3.UP*2,5.,1.)
		elif event.kind == "unit_impact":
			var sea: bool = event.data.surface=="sea"
			var size: float = clampf(float(event.data.get("size_m",10.))*.4,1,10)
			_emit("water" if sea else "dust",event.position_m,Vector3.UP,size,1.8)
			if sea:_emit("foam",event.position_m,Vector3.ZERO,size*.6,1.7)
			_play(event.position_m,"impact",0.)
		shown_events += 1

func _emit(kind: String, point: Vector3, velocity: Vector3, size: float, life: float) -> Dictionary:
	if not effects_enabled: return {}
	var slot: Dictionary = {}
	for candidate: Dictionary in slots:
		if not candidate.active:
			slot = candidate
			break
	if slot.is_empty():
		if slots.size() >= effect_capacity:
			dropped_visuals += 1
			# Preserve legible impact/burst feedback when tracer flashes fill the pool.
			if kind in ["water","dust","burst","fire"]:
				for candidate: Dictionary in slots:
					if candidate.kind in ["flash","smoke","tracer","spark","foam"]:
						slot = candidate
						break
			if slot.is_empty(): return {}
		else:
			var mesh: MeshInstance3D = MeshInstance3D.new()
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh)
			slot = {"mesh":mesh}
			slots.append(slot)
	slot.merge({"active":true,"kind":kind,"position":point,"velocity":velocity,"size":maxf(size,.01),"age":0.,"life":maxf(life,.01),"gravity":0.,"projectile_id":""},true)
	var mesh: MeshInstance3D = slot.mesh
	mesh.mesh = cylinder if kind == "water" else sphere
	mesh.material_override = materials["water" if kind == "foam" else kind]
	mesh.visible = true
	mesh.position = point
	mesh.scale = Vector3.ONE * size
	return slot

func advance(delta_s: float) -> void:
	elapsed_s += maxf(0,delta_s)
	for slot: Dictionary in slots:
		if not slot.active: continue
		slot.age += delta_s
		var mesh: MeshInstance3D = slot.mesh
		if not effects_enabled or float(slot.age) >= float(slot.life):
			slot.active = false
			mesh.visible = false
			continue
		var age: float = float(slot.age)
		var alpha: float = age / float(slot.life)
		mesh.position = slot.position + (slot.velocity as Vector3) * age + Vector3.DOWN * float(slot.gravity) * .5 * age * age
		var size: float = float(slot.size)
		if slot.kind == "tracer":
			var direction: Vector3 = (slot.velocity as Vector3) + Vector3.DOWN * float(slot.gravity) * age
			if direction.length_squared() > .001:
				mesh.basis = Basis.looking_at(direction.normalized(),Vector3.RIGHT if absf(direction.normalized().y)>.99 else Vector3.UP)
			mesh.scale = Vector3(size,size,clampf(direction.length()*.018,1,25))
		elif slot.kind == "water":
			var height: float = size * sin(PI*alpha) * 3.
			mesh.scale = Vector3(size*(.6+alpha),maxf(.02,height),size*(.6+alpha))
			# Anchor the base to the actual sea intersection; do not lift the whole plume.
			mesh.position = slot.position + Vector3.UP * (height*.5-.05)
		elif slot.kind == "foam":
			mesh.position = slot.position + Vector3.UP*.07
			mesh.scale = Vector3(size*(1+alpha*3),.12,size*(1+alpha*3))
		elif slot.kind in ["smoke","burst","dust"]:
			mesh.scale = Vector3.ONE * size * (.5+alpha*1.7) * (1.-alpha*.5)
		else:
			mesh.scale = Vector3.ONE * maxf(.01,size*(1.-alpha))
	smoke_timer_s -= delta_s
	if smoke_timer_s <= 0 and delta_s > 0:
		smoke_timer_s = .3
		for id: String in unit_views:
			var unit: Dictionary = unit_views[id]
			var module_data: Dictionary = unit.get("module_data",{})
			if departed_units.has(id) or not CombatPresence.is_present(module_data): continue
			var d: Dictionary = module_data.get("damage",{})
			var point: Vector3 = unit.position_m
			var anchors: Dictionary = damage_anchors.get(str(unit.get("definition_id","")),{})
			var pose: Transform3D = Transform3D(Basis.from_euler(unit.get("rotation_rad",Vector3.ZERO)),point)
			var fire_point: Vector3 = pose * SimData.vec3(anchors.get("fire_anchor_m",[0,3,0]))
			var smoke_point: Vector3 = pose * SimData.vec3(anchors.get("smoke_anchor_m",[0,5,0]))
			var severity: float = float(d.get("fire",0.))
			if severity > .01:
				_emit("fire",fire_point,Vector3.UP,1+severity*4,.5)
				_emit("smoke",smoke_point,Vector3(1,4,0),2+severity*5,3.)
			if d.get("phase","") == "crashing":
				_emit("smoke",point,Vector3.UP,1.5,2.)

func apply_snapshot(snapshot: Dictionary) -> void:
	unit_views = snapshot.get("units",{}).duplicate(true)
	_prepare()
	var ids: Array = unit_views.keys()
	ids.sort()
	var index: int = 0
	for id: String in ids:
		var unit: Dictionary = unit_views[id]
		if not unit.active or departed_units.has(id) or not CombatPresence.is_present(unit.get("module_data",{})): continue
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
	shown_events = 0
	unit_views.clear()
	departed_units.clear()
	for slot: Dictionary in slots:
		slot.active = false
		(slot.mesh as MeshInstance3D).visible = false
	for player: AudioStreamPlayer3D in sounds: player.stop()
	for player: AudioStreamPlayer3D in engine_sources: player.stop()

func statistics() -> Dictionary:
	var active: int = 0
	for slot: Dictionary in slots:
		if slot.active: active += 1
	return {"allocated":slots.size(),"active":active,"dropped":dropped_visuals,"last_sequence":last_sequence,"shown_events":shown_events,"sound_sources":sounds.size(),"engine_sources":engine_sources.size()}
