extends Node3D

## Explicit controlled projectile review, separate from normal/default AI combat.
class ScheduledProbe extends SimulationModule:
	var launcher: SimulationModule
	var case_name: String
	var fired: bool = false
	func _init(a: Dictionary, selected_case: String) -> void:
		module_id = "dm01_controlled_projectile_probe"
		priority = 390
		launcher = a.launcher
		case_name = selected_case
	func reset(_world: RefCounted) -> void: fired = false
	func fixed_update(world_ref: RefCounted, _dt: float) -> void:
		var world: SimulationWorld = world_ref as SimulationWorld
		if fired or world.tick < 60: return
		fired = true
		AircraftDamageFixture.shoot({"world":world,"launcher":launcher},"structure" if case_name == "breakup" else case_name,1 if case_name == "breakup" else (14 if case_name == "engine" else 6),"us_406mm_mk8_ap" if case_name == "breakup" else "jp_20mm_type99_2_shell")

var definition_id: String = "us_f6f5_1944"
var case_name: String = "wing_left"
var include_fx: bool = false
var world: SimulationWorld
var arena: Dictionary
var model: AircraftAdapter
var camera: Camera3D
var environment_view: CloudSeaEnvironment
var effects: CombatEffects
var label: Label
var event_log: Array[Dictionary] = []
var maximum_fragments: int = 0
var peak_effect_meshes: int = 0
var peak_effect_kinds: Dictionary = {}

func _ready() -> void:
	environment_view = CloudSeaEnvironment.new()
	add_child(environment_view)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 44
	camera.far = 70000
	add_child(camera)
	var altitude: float = 380.0 if case_name == "engine" else 150.0
	arena = AircraftDamageFixture.arena(definition_id,altitude)
	world = arena.world
	var receipt: Dictionary = world.register_module(ScheduledProbe.new(arena,case_name))
	if not AircraftDamageFixture.FIX.require_accepted(receipt,"register controlled projectile probe"): return
	var scene: PackedScene = load(world.unit_definition(definition_id).model_scene)
	model = scene.instantiate() as AircraftAdapter
	add_child(model)
	if include_fx:
		effects = CombatEffects.new()
		effects.effect_capacity = 384
		effects.sound_enabled = false
		add_child(effects)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(18,16)
	label.add_theme_font_size_override("font_size",17)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	layer.add_child(label)
	present([],0)

func advance_steps(count: int) -> void:
	var events: Array[BattleEvent] = []
	var before: float = world.time_s()
	for i: int in count:
		world.step_ticks(1)
		events.append_array(world.drain_events())
	present(events,world.time_s()-before)

func advance_wall(delta_s: float) -> void:
	var before: float = world.time_s()
	world.advance(delta_s)
	present(world.drain_events(),world.time_s()-before)

func present(events: Array[BattleEvent], simulation_delta_s: float) -> void:
	var target: UnitState = world.get_unit("target")
	model.apply_state(target.snapshot())
	if effects != null:
		effects.advance(simulation_delta_s)
		effects.consume(events,world.generation)
		effects.apply_snapshot(world.snapshot())
		peak_effect_meshes = maxi(peak_effect_meshes,int(effects.statistics().get("visible_instances",0)))
		var kinds: Dictionary = visible_effect_kinds()
		for kind: String in kinds: peak_effect_kinds[kind] = maxi(int(peak_effect_kinds.get(kind,0)),int(kinds[kind]))
	for event: BattleEvent in events:
		if event.kind in ["fired","hit","damaged","aircraft_part_detached","aircraft_breakup","unit_surface_contact","unit_impact","damage_phase","disabled"]: event_log.append(event.snapshot())
	var damage: Dictionary = target.module_data.damage
	maximum_fragments = maxi(maximum_fragments,model.damage_statistics().fragment_nodes)
	var focus: Vector3 = target.position_m
	if damage.phase in ["wreck","removed"]: focus.y = 1.0
	var side: float = 1.0 if case_name == "wing_right" else -1.0
	var offset: Vector3 = Vector3(side*19,10,-24) if case_name != "breakup" else Vector3(-28,16,-38)
	if damage.phase in ["wreck","removed"]:
		var widen: float = 1.0 if damage.phase == "removed" else smoothstep(0,1,clampf(float(damage.phase_time_s)/1.2,0,1))
		offset = offset.lerp(Vector3(-68,34,-90),widen)
	camera.position = focus+offset
	camera.look_at(focus,Vector3.UP)
	environment_view.advance(world.time_s())
	environment_view.update_observer(camera.position)
	label.text = "DM01 CONTROLLED PROJECTILE REVIEW | %s | %s\n%.2f s | %s | engine %.0f%% | L %.0f%% R %.0f%% tail %.0f%%\n%.1f m/s | %.1f m | debris %d / 3 | %s" % [definition_id,case_name,world.time_s(),damage.phase,100*float(damage.parts.engine),100*float(damage.parts.wing_left),100*float(damage.parts.wing_right),100*float(damage.parts.tail),target.velocity_mps.length(),target.position_m.y,model.damage_statistics().fragment_nodes,"FX01" if include_fx else "model assembly only"]

func visible_effect_kinds() -> Dictionary:
	var result: Dictionary = {}
	if effects == null: return result
	for slot: Dictionary in effects.slots:
		if slot.active and (slot.mesh as MeshInstance3D).visible and float(slot.get("opacity",0)) > .01:
			result[slot.kind] = int(result.get(slot.kind,0))+1
	return result

func snapshot() -> Dictionary:
	var target: UnitState = world.get_unit("target")
	var event_counts: Dictionary = {}
	for event: Dictionary in event_log: event_counts[event.kind] = int(event_counts.get(event.kind,0))+1
	return {"definition_id":definition_id,"case":case_name,"controlled":true,"tick":world.tick,"time_s":world.time_s(),"target":target.snapshot(),"model":model.damage_statistics(),"maximum_fragments":maximum_fragments,"effects":{} if effects == null else effects.statistics(),"environment":environment_view.snapshot(),"event_counts":event_counts,"visible_effect_kinds":visible_effect_kinds(),"peak_visible_effect_kinds":peak_effect_kinds.duplicate(),"peak_effect_meshes":peak_effect_meshes,"event_count":event_log.size(),"impact_count":event_log.filter(func(e: Dictionary)->bool:return e.kind == "unit_impact").size(),"surface_contact_count":event_log.filter(func(e: Dictionary)->bool:return e.kind == "unit_surface_contact").size(),"breakup_count":event_log.filter(func(e: Dictionary)->bool:return e.kind == "aircraft_breakup").size()}
