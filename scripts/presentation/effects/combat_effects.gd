class_name CombatEffects
extends Node3D

## Rendering-only bounded consumer. Caller supplies simulation-scaled elapsed time.
const GEOMETRY: Script = preload("res://scripts/presentation/effects/combat_effect_geometry.gd")
const SURFACE: Shader = preload("res://scripts/presentation/effects/effect_surface.gdshader")
const HARBOR_WIND: Vector2 = CloudSeaEnvironment.WIND
const EVENT_SMOKE: Array[String] = ["muzzle_smoke", "impact_smoke", "impact_dust", "burst", "self_destruct"]
const DIRECTIONAL_FLASH: Array[String] = ["muzzle_flash", "blast_flash"]
const SHELL_CALIBER_M: float = .075
enum BudgetGroup { SHARED, MUZZLE, SHELL, TRACER }
const RESERVED_SHARE: Array[float] = [0., .18, .08, .12]
@export var effect_capacity: int = 144
@export var sound_capacity: int = 8
var effects_enabled: bool = true
var sound_enabled: bool = true
var generation: int = -1
var last_sequence: int = 0
var dropped_visuals: int = 0
var preempted_visuals: int = 0
var requested_by_kind: Dictionary = {}
var rejected_by_kind: Dictionary = {}
var evicted_by_kind: Dictionary = {}
var shown_events: int = 0
var peak_visible: int = 0
var slots: Array[Dictionary] = []
var active_by_group: PackedInt32Array = PackedInt32Array([0,0,0,0])
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
	# The simulation outbox is ordered by sequence. Age every effect against
	# the same clock, including when a late batch contains several ticks.
	var previous_time_s: float = elapsed_s
	for event: BattleEvent in events:
		if event.sequence > last_sequence:
			elapsed_s = maxf(elapsed_s,event.time_s)
	if elapsed_s > previous_time_s:
		var catch_up_s: float = elapsed_s-previous_time_s
		_update_slots(catch_up_s)
		smoke_timer_s -= catch_up_s
	for event: BattleEvent in events:
		if event.sequence <= last_sequence: continue
		last_sequence = event.sequence
		emission_time_s = event.time_s
		emission_seed = float(event.sequence)*.131
		component_index = 0
		_consume_event(event)
		shown_events += 1
	_update_peak()

func _consume_event(event: BattleEvent) -> void:
	match event.kind:
		"aircraft_exit", "ship_exit":
			departed_units[event.entity_id] = true
		"fired":
			_fired(event)
		"hit", "surface_impact", "airburst", "projectile_expired":
			_end_tracer(str(event.data.projectile_id))
			# An armed bomb sends both the ballistic terminal and the authoritative
			# detonation. BombingEffects consumes the latter once via this cursor.
			if event.data.get("release_mode") == "gravity_release" and bool(event.data.get("armed",false)):
				return
			_projectile_terminal(event)
		"disabled":
			# Persistent flames come from actual fire/DM state below.
			if event.data.get("phase", "") not in ["disabled", "sinking"] and bool(event.data.get("destroyed",true)):
				_emit("fire",event.position_m,Vector3.UP*2,5.,1.)
		"unit_impact":
			var size: float = clampf(float(event.data.get("size_m",10.))*.55,1,11)
			if event.data.surface == "sea":
				sea_contacts[event.entity_id] = true
				_splash(event.position_m,size)
			else:
				_emit("dust",event.position_m,Vector3(1,1,0),size,3.)
			_play(event.position_m,"impact",0.)

func _fired(event: BattleEvent) -> void:
	var caliber: float = float(event.data.caliber_m)
	var ship_gun: bool = event.data.get("source_domain") == "ship"
	var main_shell: bool = caliber >= .3 or (ship_gun and event.data.get("mount_role") == "main")
	var point: Vector3 = event.position_m
	if caliber >= SHELL_CALIBER_M and event.data.get("source_domain") in ["ship", "ground"]:
		# The launch event reports the actual barrel tip and the world launch axis.
		# Round velocity also includes the ship velocity, so don't use it here.
		var axis: Vector3 = (event.data.get("muzzle_direction",Vector3.ZERO) as Vector3).normalized()
		var width: float = clampf(caliber*53.,4.,25.)
		var flash: Dictionary = _emit("muzzle_flash",point,axis*width*2.0,width,.16)
		_set_axis(flash,axis)
		var smoke: Dictionary = _emit("muzzle_smoke",point,axis*width*1.1+Vector3.UP*1.3,width,7.5 if main_shell else 4.4)
		_set_axis(smoke,axis)
		if main_shell:
			# A second, slower lobe keeps the origin of each barrel's plume readable.
			_emit("muzzle_smoke",point,axis*width*.36+Vector3.UP*2.5,width*.72,6.0)
	else:
		_emit("flash",point,Vector3.ZERO,clampf(caliber*10,.12,4.),.09)
	# Main-shell marks and tracers follow the fired round's actual ballistic path.
	if main_shell or bool(event.data.tracer):
		var slot: Dictionary = _emit("shell" if main_shell else "tracer",point,event.data.velocity_mps,clampf(caliber*.7,.075,.32),float(event.data.get("lifetime_s",90.)))
		if not slot.is_empty():
			slot["projectile_id"] = event.data.projectile_id
			slot["gravity"] = float(event.data.gravity_mps2)
			_draw_slot(slot)
	_play(point,"heavy" if caliber > .1 else "light",0.)

func _set_axis(slot: Dictionary, axis: Vector3) -> void:
	if slot.is_empty(): return
	(slot.material as ShaderMaterial).set_shader_parameter("trail_axis",axis)

func _projectile_terminal(event: BattleEvent) -> void:
	var caliber: float = float(event.data.caliber_m)
	var point: Vector3 = event.position_m
	var surface: String = str(event.data.get("surface",""))
	match event.kind:
		"airburst":
			_airburst(point,caliber,str(event.data.get("reason","time_fuze")))
		"surface_impact", "hit":
			if surface == "sea":
				_splash(point,clampf(caliber*25,.7,13.))
			elif caliber >= SHELL_CALIBER_M and surface in ["ship","ground","building"]:
				var normal: Vector3 = event.data.get("normal",Vector3.UP)
				_contact_blast(point,surface,clampf(caliber*53.,4.,26.),normal)
			elif event.kind == "hit":
				_emit("spark",point,Vector3.UP*caliber,clampf(caliber*8.,.2,2.2),.15)
			else:
				_emit("dust",point,Vector3.UP,clampf(caliber*18.,.25,2.),1.1)
		_:
			return
	_play(point,"impact",-2.)

func _contact_blast(point: Vector3, surface: String, width: float, normal: Vector3) -> void:
	var on_ship: bool = surface == "ship"
	var out: Vector3 = (normal + Vector3.UP).normalized()
	_emit("blast_flash",point,Vector3.ZERO,width,.22)
	_emit("blast_sparks",point,out*width*1.1,width*(1.8 if on_ship else 1.4),.48)
	var primary: String = "impact_smoke" if on_ship else "impact_dust"
	_emit(primary,point,out*width*.48+Vector3.UP*2.0,width,9. if on_ship else 7.)
	# Larger land contacts show a spreading dust skirt and a darker upper core.
	if width >= 10.:
		var secondary_size: float = width*(.63 if on_ship else .72)
		_emit("impact_smoke",point,Vector3.UP*(width*.29+3.),secondary_size,9.)

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
	if reason == "tracer_self_destruct":
		var width: float = clampf(caliber*18.,.5,1.4)
		_emit("flash",point,Vector3.ZERO,width,.1)
		_emit("self_destruct",point,Vector3.UP*.45,width,1.45)
		return
	var width: float = clampf(caliber*76.,1.8,16.)
	_emit("blast_flash",point,Vector3.ZERO,width*.78,.19)
	for index: int in 3:
		var angle: float = emission_seed*TAU+float(index)*TAU/3.
		var spread: Vector3 = Vector3(cos(angle),sin(angle+.9)*.7,sin(angle))
		var slot: Dictionary = _emit("burst",point,spread*width*.95+Vector3.UP*.58,width*(1.12-float(index)*.18),6.7+float(index)*.38)
		if not slot.is_empty(): slot["reason"] = reason

func _priority(kind: String) -> int:
	if kind in ["water","foam","burst","impact_smoke","impact_dust","blast_flash"]: return 3
	if kind in ["fire","dust","mist","muzzle_smoke","muzzle_flash","blast_sparks"]: return 2
	if kind in ["tracer", "shell"]: return 1
	return 0

func _budget_group(kind: String) -> int:
	match kind:
		"muzzle_flash", "muzzle_smoke": return BudgetGroup.MUZZLE
		"shell": return BudgetGroup.SHELL
		"tracer": return BudgetGroup.TRACER
	return BudgetGroup.SHARED

func _take_saturated_slot(kind: String, group: int) -> Dictionary:
	var slot: Dictionary = {}
	var reserve: int = int(effect_capacity*RESERVED_SHARE[group])
	var claiming_reserve: bool = active_by_group[group] < reserve
	var lowest: int = 4 if claiming_reserve else _priority(kind)
	for candidate: Dictionary in slots:
		var other: int = candidate.group
		if int(candidate.priority)>=lowest: continue
		if other!=BudgetGroup.SHARED and active_by_group[other]<=int(effect_capacity*RESERVED_SHARE[other]): continue
		slot = candidate
		lowest = int(candidate.priority)
	if not slot.is_empty(): return slot
	# Keep the latest damage trail and recycle thinning event smoke of the same kind.
	if kind=="smoke" or kind in EVENT_SMOKE:
		var oldest: float = INF
		for candidate: Dictionary in slots:
			if candidate.kind != kind or float(candidate.born_s) >= oldest: continue
			if kind != "smoke" and float(candidate.age) < float(candidate.life)*.58: continue
			slot = candidate
			oldest = float(candidate.born_s)
	return slot

func _hide_slot(slot: Dictionary) -> void:
	active_by_group[int(slot.group)] -= 1
	slot.active = false
	(slot.mesh as MeshInstance3D).visible = false

func _emit(kind: String, point: Vector3, velocity: Vector3, size: float, life: float) -> Dictionary:
	if not effects_enabled or elapsed_s-emission_time_s >= life: return {}
	requested_by_kind[kind] = int(requested_by_kind.get(kind,0))+1
	var group: int = _budget_group(kind)
	var slot: Dictionary = {}
	for candidate: Dictionary in slots:
		if not candidate.active:
			slot = candidate
			break
	if slot.is_empty():
		if slots.size() >= effect_capacity:
			dropped_visuals += 1
			slot = _take_saturated_slot(kind,group)
			if slot.is_empty():
				rejected_by_kind[kind] = int(rejected_by_kind.get(kind,0))+1
				return {}
			evicted_by_kind[slot.kind] = int(evicted_by_kind.get(slot.kind,0))+1
			preempted_visuals += 1
			_hide_slot(slot)
		else:
			var mesh: MeshInstance3D = MeshInstance3D.new()
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = SURFACE
			mesh.material_override = material
			add_child(mesh)
			slot = {"mesh":mesh,"material":material}
			slots.append(slot)
	active_by_group[group] += 1
	slot.merge({"active":true,"kind":kind,"group":group,"position":point,"velocity":velocity,"size":maxf(size,.01),"age":maxf(0,elapsed_s-emission_time_s),"born_s":emission_time_s,"life":maxf(life,.01),"gravity":0.,"projectile_id":"","priority":_priority(kind),"jet":0,"seed":fposmod(emission_seed+component_index*.371,1.),"reason":"","emitter_id":"","part_id":"","owner_id":"","anchor_m":Vector3.ZERO},true)
	component_index += 1
	var mesh: MeshInstance3D = slot.mesh
	var geometry: String = "water" if kind=="water" else "foam" if kind=="foam" else "tracer" if kind in ["tracer", "shell"] else "cloud"
	mesh.mesh = meshes[geometry]
	# Shader billboards may rotate or stretch beyond the flat quad's local bounds.
	mesh.custom_aabb = AABB(Vector3.ONE*-.92,Vector3.ONE*1.84) if geometry=="cloud" else AABB()
	var mode: int = 0
	var color: Color = Color(.15,.16,.17,.88)
	match kind:
		"water", "foam", "mist":
			mode = 1 if kind=="water" else 2 if kind=="foam" else 0
			color = Color(.78,.88,.91,.8)
		"tracer", "shell":
			mode = 3
			color = Color(1,.48,.075,1) if kind=="tracer" else Color(1,.82,.42,1)
		"fire":
			mode = 4
			color = Color(1,.23,.025,.9)
		"flash", "spark":
			mode = 5
			color = Color(1,.85,.28,1)
		"muzzle_smoke":
			mode = 6
			color = Color(.55,.48,.39,.92)
		"burst":
			mode = 7
			color = Color(.14,.15,.16,.96)
		"impact_smoke", "impact_dust":
			mode = 8
			color = Color(.22,.23,.25,.97) if kind=="impact_smoke" else Color(.59,.47,.33,.88)
		"muzzle_flash", "blast_flash":
			mode = 9
			color = Color(1,.45,.075,1)
		"blast_sparks":
			mode = 10
			color = Color(1,.57,.19,1)
		"self_destruct":
			color = Color(.28,.29,.30,.7)
		"dust":
			color = Color(.53,.42,.29,.68)
	var material: ShaderMaterial = slot.material
	material.render_priority = 2 if mode==9 else 1 if mode==10 else 0
	material.set_shader_parameter("effect_mode",mode)
	material.set_shader_parameter("tint",color)
	material.set_shader_parameter("seed",slot.seed)
	material.set_shader_parameter("trail_axis",Vector3.ZERO)
	material.set_shader_parameter("trail_stretch",1.)
	material.set_shader_parameter("water_fade_m",2.5 if kind=="mist" else .75 if kind in EVENT_SMOKE or kind in ["smoke","dust"] else .25 if kind=="fire" else 0.)
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
	if slot.kind in ["tracer", "shell"]:
		# Only the round's recent flight, ending at its true current position.
		# With configured gravity the chord deviation is <2 mm for this span.
		var span_s: float = minf(age,.035 if slot.kind=="shell" else .012)
		var previous_age: float = age-span_s
		var previous: Vector3 = slot.position+(slot.velocity as Vector3)*previous_age+Vector3.DOWN*float(slot.gravity)*.5*previous_age*previous_age
		var direction: Vector3 = point-previous
		if direction.length_squared() > .001:
			mesh.basis = Basis.looking_at(direction.normalized(),Vector3.RIGHT if absf(direction.normalized().y)>.99 else Vector3.UP)
		var width: float = _observer_width(point,size,2.2 if slot.kind=="shell" else 1.3,6.0 if slot.kind=="shell" else 1.5)
		mesh.scale = Vector3(width,width,maxf(.01,direction.length()))
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
	elif slot.kind in EVENT_SMOKE:
		# Initial gas expansion decelerates. Wind remains world-aligned as the
		# observer moves, with less drag near the contact/flash.
		var muzzle: bool = slot.kind=="muzzle_smoke"
		var spread: float = 1.-exp(-age*(3.3 if muzzle else 4.7))
		var wind: Vector2 = HARBOR_WIND*(2.7 if slot.kind!="self_destruct" else 1.5)
		var drift_s: float = age-.35*(1.-exp(-age/.35))
		var velocity: Vector3 = slot.velocity
		mesh.position = slot.position+Vector3(velocity.x,0,velocity.z)*spread*.62
		mesh.position += Vector3(wind.x*drift_s, velocity.y*(spread*.52+age*.43), wind.y*drift_s)
		var growth: float = .34+spread*(1.0 if muzzle else 1.33)+phase*(.65 if muzzle else .85)
		mesh.scale = (Vector3(1.45,.76,1.45) if slot.kind=="impact_dust" else Vector3.ONE)*size*growth
		fade = smoothstep(0.,.065,age)*(1.-smoothstep(.21,1.,phase))*(1.-phase*.23)
		if muzzle:
			var material: ShaderMaterial = slot.material
			material.set_shader_parameter("trail_stretch",lerpf(1.7,1.,smoothstep(0.,1.6,age)))
	elif slot.kind in DIRECTIONAL_FLASH:
		mesh.scale = Vector3.ONE*size*(.75+phase*.63)
		fade = 1.-smoothstep(.18,1.,phase)
		if slot.kind == "muzzle_flash":
			(slot.material as ShaderMaterial).set_shader_parameter("trail_stretch",1.55)
	elif slot.kind=="blast_sparks":
		mesh.scale = Vector3.ONE*size*(.32+phase*.75)
		fade = 1.-smoothstep(.15,1.,phase)
	elif slot.kind in ["smoke","dust","mist"]:
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

## Finite view-only compensation. Does not change collision caliber or position.
func _observer_width(point: Vector3, physical_width: float, pixels: float, maximum_m: float) -> float:
	var viewport: Viewport = get_viewport()
	if viewport == null: return physical_width
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null: return physical_width
	var height: float = maxf(1,viewport.get_visible_rect().size.y)
	var depth: float = -(camera.global_transform.affine_inverse()*to_global(point)).z
	if depth <= camera.near: return physical_width
	var metres_per_pixel: float = camera.size/height if camera.projection==Camera3D.PROJECTION_ORTHOGONAL else 2.*depth*tan(deg_to_rad(camera.fov)*.5)/height
	return clampf(metres_per_pixel*pixels,physical_width,maximum_m)

func advance(delta_s: float) -> void:
	_prepare()
	var dt: float = maxf(0,delta_s)
	elapsed_s += dt
	_update_slots(dt)
	smoke_timer_s -= dt
	_update_peak()

func _update_slots(dt: float) -> void:
	for slot: Dictionary in slots:
		if not slot.active: continue
		slot.age = maxf(0,elapsed_s-float(slot.born_s))
		if not effects_enabled or float(slot.age)>=float(slot.life):
			_hide_slot(slot)
			continue
		if dt>0 or slot.kind in ["tracer", "shell"]: _draw_slot(slot)

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
			_hide_slot(slot)
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
	apply_presentation_units(snapshot.get("units", {}).duplicate(true))

## Borrows an already detached frame. The producer replaces it instead of editing it.
func apply_presentation_units(frame_units: Dictionary) -> void:
	unit_views = frame_units
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
	if not sound_enabled or elapsed_s-emission_time_s > .25: return
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
			_hide_slot(slot)

func clear(new_generation: int = -1) -> void:
	generation = new_generation
	last_sequence = 0
	dropped_visuals = 0
	preempted_visuals = 0
	requested_by_kind.clear()
	rejected_by_kind.clear()
	evicted_by_kind.clear()
	peak_visible = 0
	shown_events = 0
	elapsed_s = 0.
	emission_time_s = 0.
	smoke_timer_s = 0.
	last_persistent_time_s = -INF
	unit_views = {}
	departed_units.clear()
	sea_contacts.clear()
	emitter_history.clear()
	active_by_group.fill(0)
	for slot: Dictionary in slots:
		slot.active = false
		(slot.mesh as MeshInstance3D).visible = false
	for player: AudioStreamPlayer3D in sounds: player.stop()
	for player: AudioStreamPlayer3D in engine_sources: player.stop()

func statistics() -> Dictionary:
	var active: int = 0
	var actual_visible: int = 0
	var active_by_kind: Dictionary = {}
	var observer: Dictionary = {}
	var viewport: Viewport = get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	for slot: Dictionary in slots:
		if slot.active:
			active += 1
			active_by_kind[slot.kind] = int(active_by_kind.get(slot.kind,0))+1
			if camera != null and slot.kind in ["shell", "tracer"]:
				var point: Vector3 = (slot.mesh as MeshInstance3D).global_position
				var row: Dictionary = observer.get(slot.kind,{"active":0,"in_frustum":0,"min_distance_m":INF,"max_distance_m":0.0})
				row.active += 1
				if camera.is_position_in_frustum(point): row.in_frustum += 1
				row.min_distance_m = minf(float(row.min_distance_m),camera.global_position.distance_to(point))
				row.max_distance_m = maxf(float(row.max_distance_m),camera.global_position.distance_to(point))
				observer[slot.kind] = row
		if (slot.mesh as MeshInstance3D).visible: actual_visible+=1
	return {"allocated":slots.size(),"active":active,"active_by_kind":active_by_kind,"observer":observer,
		"requested_by_kind":requested_by_kind.duplicate(),"rejected_by_kind":rejected_by_kind.duplicate(),"evicted_by_kind":evicted_by_kind.duplicate(),
		"render_instances":slots.size(),"visible_instances":actual_visible,"materials":slots.size(),"peak_visible":peak_visible,"dropped":dropped_visuals,"preempted":preempted_visuals,"last_sequence":last_sequence,"shown_events":shown_events,"sound_sources":sounds.size(),"engine_sources":engine_sources.size()}
