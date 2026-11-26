extends SceneTree

const GEOMETRY: Script = preload("res://scripts/aircraft_geometry/f6f5_carrier_geometry.gd")
var output: String = "res://docs/showcase/evidence/S04-carrier-usage/native"
var view: SubViewport
var carrier: Node3D
var aircraft: AircraftAdapter
var camera: Camera3D
var label: Label
var samples: Dictionary
var records: Array[Dictionary] = []
var selected_view: String = ""

func _initialize() -> void: call_deferred("run")

func visible_bounds_local() -> Dictionary:
	var smallest: Vector3 = Vector3(INF,INF,INF)
	var largest: Vector3 = Vector3(-INF,-INF,-INF)
	var inverse: Transform3D = aircraft.global_transform.affine_inverse()
	for node: Node in aircraft.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
		var pose: Transform3D = inverse*mesh.global_transform
		for vertex: Vector3 in mesh.mesh.get_faces():
			var point: Vector3 = pose*vertex
			smallest = smallest.min(point);largest = largest.max(point)
	return {"min_m":smallest,"max_m":largest,"size_m":largest-smallest,"method":"Actual currently visible triangle vertices; propeller is at recorded phase, not its entire swept disc."}

func actual_deck_clearances() -> Dictionary:
	if not carrier.visible: return {}
	var deck_height: float = float((carrier.call("deck_definition") as Dictionary).flight_deck.height_m)
	var relative: Transform3D = carrier.global_transform.affine_inverse()*aircraft.global_transform
	var prop: Dictionary = GEOMETRY.definition().gear_up_contact_proxy
	var centre: Vector3 = relative*(prop.center_flight_m as Vector3)
	var normal: Vector3 = (relative.basis*Vector3.FORWARD).normalized()
	var prop_low: float = centre.y-float(prop.radius_m)*sqrt(maxf(0,1.0-pow(normal.y,2)))
	var flap_low: float = INF
	for surface: Node3D in aircraft.model_root.animated_surfaces:
		if "flap" not in str(surface.name).to_lower(): continue
		for node: Node in surface.find_children("*","MeshInstance3D",true,false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			var to_deck: Transform3D = carrier.global_transform.affine_inverse()*mesh.global_transform
			for vertex: Vector3 in mesh.mesh.get_faces(): flap_low = minf(flap_low,(to_deck*vertex).y)
	var tyre_gaps: Dictionary = {}
	for id: String in aircraft.model_root.get("carrier_tyres"):
		var tyre: MeshInstance3D = aircraft.model_root.get("carrier_tyres")[id] as MeshInstance3D
		var to_deck: Transform3D = carrier.global_transform.affine_inverse()*tyre.global_transform
		var bottom: float = INF
		for vertex: Vector3 in tyre.mesh.get_faces(): bottom = minf(bottom,(to_deck*vertex).y)
		tyre_gaps[id] = bottom-deck_height
	return {"propeller_full_disc_clearance_m":prop_low-deck_height,"flap_actual_triangle_clearance_m":flap_low-deck_height,"tyre_actual_mesh_clearance_m":tyre_gaps,"scope":"Static actual CV01 top; tyre visual facet error measured separately from continuous circular support."}

func show_sample(phase: String) -> Dictionary:
	var sample: Dictionary = samples.samples[phase]
	carrier.call("apply_state",sample.ship)
	aircraft.apply_state(sample.unit)
	return sample

func show_revised_fixture(approach: bool) -> Dictionary:
	var original: Dictionary = samples.samples["approach" if approach else "standby"]
	carrier.call("apply_state",original.ship)
	var state: Dictionary = original.unit.duplicate(true)
	var local: Vector3 = carrier.global_transform.affine_inverse()*SimData.vec3(state.position_m)
	var height: float = float((carrier.call("deck_definition") as Dictionary).flight_deck.height_m)
	if approach: local = Vector3(-3,height+3,105)
	else: local = Vector3(-3,height,75)
	var pose: Transform3D = carrier.global_transform*Transform3D(Basis.IDENTITY,local)*GEOMETRY.parked_transform_flight()
	state.position_m = pose.origin;state.rotation_rad = pose.basis.get_euler()
	state.module_data.carrier_ops = {"gear_down":true,"hook_down":approach,"flaps_down":approach,"hook_deflection_rad":0.0,"phase":"static_geometry_fixture"}
	aircraft.apply_state(state)
	return {"time_s":original.time_s,"frame":original.frame,"unit":state,"original_unit":original.unit,"scope":"Explicit revised geometry fixture; old OPS world Y / pitch=0 are obsolete. Flags retained from recorded operation; pose solved from revised tyre circles, not a new operations execution."}

func capture(name: String, sample: Dictionary, offset: Vector3, target_offset: Vector3, scale_m: float, scope: String) -> void:
	if not selected_view.is_empty() and name not in selected_view.split(","): return
	var target: Vector3 = aircraft.position+target_offset
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = scale_m
	camera.position = target+offset
	camera.look_at(target,Vector3.UP)
	var support_normal: Vector3 = aircraft.global_basis.inverse()*carrier.global_basis.y
	var usage: Dictionary = aircraft.carrier_usage_local(support_normal)
	label.text = "S04 F6F CARRIER USAGE CANDIDATE | %s\n%s\ngear %s / hook %s / flaps %.1fdeg / hook contact deflection %.2fdeg\nactual hook tip local: %.3f %.3f %.3fm | origin unchanged -2.30m\n%s" % [name,scope,usage.gear_down,usage.hook_down,rad_to_deg(float(usage.flap_angle_rad)),rad_to_deg(float(usage.hook_deflection_rad)),usage.hook_tip_m.x,usage.hook_tip_m.y,usage.hook_tip_m.z,"Pure model / actual snapshot or labelled static fixture; flight operations not accepted here"]
	await process_frame
	await process_frame
	RenderingServer.force_draw(false,0)
	var image: Image = view.get_texture().get_image()
	var error: Error = image.save_png(output.path_join(name+".png"))
	if error != OK: push_error("Candidate screenshot save failed");quit(1);return
	var contacts: Dictionary = {}
	for id: String in usage.wheel_contacts:
		var contact: Dictionary = usage.wheel_contacts[id]
		var local: Vector3 = carrier.global_transform.affine_inverse()*(aircraft.global_transform*(contact.position_m as Vector3))
		contacts[id] = {"point_deck_m":local,"surface":carrier.call("deck_surface_at",Vector2(local.x,local.z)),"available":contact.available}
	records.append({"name":name,"scope":scope,"source_time_s":sample.get("time_s",-1),"source_frame":sample.get("frame",-1),"unit_state":sample.get("unit",{}),"original_obsolete_OPS_state":sample.get("original_unit",{}),"usage":usage,"visible_bounds_aircraft_local":visible_bounds_local(),"deck_contacts":contacts,"actual_deck_clearances":actual_deck_clearances(),"aircraft_world_position_m":aircraft.position,"aircraft_rotation_rad":aircraft.rotation,"camera_position_m":camera.position,"camera_target_m":target,"camera_orthographic_size_m":scale_m,"camera_clip_m":[camera.near,camera.far],"damage_statistics":aircraft.damage_statistics()})
	print("S04 carrier native saved ",name)

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	AudioServer.set_bus_mute(0,true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.get_slice("=",1)
		if arg.begins_with("--only="): selected_view = arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	samples = JSON.parse_string(FileAccess.get_file_as_string("res://tests/s04_carrier_usage/ops_samples.json"))
	root.size = Vector2i(1280,800)
	view = SubViewport.new();view.size = Vector2i(1280,800);view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var stage: Node3D = Node3D.new();view.add_child(stage)
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR;environment.background_color = Color("bdc9d0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color = Color.WHITE;environment.ambient_light_energy = .85
	environment_node.environment = environment;stage.add_child(environment_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new();sun.rotation_degrees = Vector3(-48,-32,0);sun.light_energy = 1.2;sun.shadow_enabled = true;stage.add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new();fill.rotation_degrees = Vector3(25,140,0);fill.light_energy = .45;stage.add_child(fill)
	camera = Camera3D.new();camera.current = true;camera.near = .5;camera.far = 2000;stage.add_child(camera)
	label = Label.new();label.position = Vector2(15,12);label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_color",Color("172d3b"));view.add_child(label)
	var carrier_scene: PackedScene = load("res://naval/essex_cv9_1944_04_15/essex.tscn")
	carrier = carrier_scene.instantiate() as Node3D;stage.add_child(carrier)
	var aircraft_scene: PackedScene = load("res://scenes/units/aircraft/f6f5_flight.tscn")
	aircraft = aircraft_scene.instantiate() as AircraftAdapter;stage.add_child(aircraft)
	var sample: Dictionary = show_sample("mission")
	carrier.visible = false
	await capture("clean_quarter",sample,Vector3(18,9,-22),Vector3.ZERO,18,"Recorded OPS01 mission snapshot; no carrier_ops deployment")
	await capture("clean_underside",sample,Vector3(15,-11,18),Vector3.ZERO,18,"Recorded OPS01 clean flight; closed covers and DM groups retained")
	sample = show_revised_fixture(true)
	carrier.visible = false # Clear silhouette; ship structures must not occlude the usage review.
	await capture("approach_quarter",sample,Vector3(17,6,20),Vector3.ZERO,18,"REVISED APPROACH GEOMETRY FIXTURE; recorded usage flags, new tyre-derived attitude")
	await capture("approach_side",sample,Vector3(25,1,0),Vector3(0,-.5,0),14,"REVISED APPROACH GEOMETRY FIXTURE; old OPS parked/approach pose retired")
	sample = show_revised_fixture(false)
	carrier.visible = true
	await capture("parked_side",sample,Vector3(24,1.5,0),Vector3(0,-.6,0),14,"NEW THREE-TYRE STATIC FIXTURE on actual CV01; origin/attitude solved from circles")
	await capture("parked_rear",sample,Vector3(16,5,20),Vector3.ZERO,18,"NEW THREE-TYRE STATIC FIXTURE; short tailwheel, no fixed world-Y offset")
	await capture("parked_front",sample,Vector3(0,2,-24),Vector3(0,-.3,0),14,"NEW THREE-TYRE STATIC FIXTURE; both main tyres and simple struts")
	await capture("parked_front_quarter",sample,Vector3(-17,4,-22),Vector3.ZERO,16,"NEW THREE-TYRE STATIC FIXTURE; original body/wing installation, short gear")
	# Labelled mechanical assembly fixture: old OPS data has no contact-deflection
	# field. This solver only supplies a static pose; it is not landing logic.
	var fixture_state: Dictionary = sample.unit.duplicate(true)
	fixture_state.module_data.carrier_ops = {"gear_down":true,"hook_down":true,"flaps_down":true,"hook_deflection_rad":0.0}
	aircraft.apply_state(fixture_state)
	var low: float = 0.0;var high: float = GEOMETRY.HOOK_DEFLECTION_LIMIT_RAD
	for i: int in 30:
		var angle: float = (low+high)*.5
		aircraft.model_root.call("set_hook_deflection",angle)
		var at: Vector3 = carrier.global_transform.affine_inverse()*(aircraft.global_transform*(aircraft.carrier_usage_local().hook_tip_m as Vector3))
		var surface: Dictionary = carrier.call("deck_surface_at",Vector2(at.x,at.z))
		if not surface.supported: push_error("Hook fixture is outside real CV01 surface");quit(1);return
		if at.y < float(surface.height_m)+.02: low = angle
		else: high = angle
	fixture_state.module_data.carrier_ops.hook_deflection_rad = high
	aircraft.apply_state(fixture_state)
	var fixture_sample: Dictionary = {"time_s":sample.time_s,"unit":fixture_state}
	await capture("hook_contact_side",fixture_sample,Vector3(25,1.2,0),Vector3(0,-.65,0),14,"STATIC CONTACT FIXTURE: supplied deflection; OPS has not integrated this hook yet")
	var target: Vector3 = aircraft.global_transform*(aircraft.carrier_usage_local().hook_tip_m as Vector3)
	await capture("hook_contact_detail",fixture_sample,Vector3(5,1.4,3),target-aircraft.position+Vector3(0,.8,0),5,"STATIC CONTACT FIXTURE: real sole Marker, shank/root; no origin change")
	carrier.visible = false
	for part: String in ["wing_left","structure"]:
		var arena: Dictionary = AircraftDamageFixture.arena("us_f6f5_1944")
		AircraftDamageFixture.shoot(arena,part,6 if part == "wing_left" else 1,"jp_20mm_type99_2_shell" if part == "wing_left" else "us_406mm_mk8_ap")
		(arena.world as SimulationWorld).step_ticks(120 if part == "structure" else 45)
		var unit: UnitState = (arena.world as SimulationWorld).get_unit("target")
		var state: Dictionary = unit.snapshot()
		state.module_data["carrier_ops"] = {"gear_down":true,"hook_down":true,"flaps_down":true}
		aircraft.apply_state(state)
		await capture("damage_"+part,{"time_s":(arena.world as SimulationWorld).time_s(),"unit":state},Vector3(-22,9,25),Vector3(0,-1,0),24,"REAL EXISTING-AMMO DAMAGE with explicit lowered-usage fixture; wing/tail equipment follows host")
	var file: FileAccess = FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(AircraftDamageFixture.json_data({"scope":"Static native model usage/installation review. Revised gear retires old OPS parked/approach poses. New parked/approach/contact poses are explicit tyre-circle geometry fixtures, not new OPS execution. Clean mission pose remains the recorded snapshot.","resolution":[1280,800],"source":samples.source,"source_sha256":samples.source_sha256,"cpu_geometry":GEOMETRY.definition(),"views":records}),"\t"));file.close()
	aircraft.free();carrier.free()
	if AircraftAdapter.live_fragment_nodes != 0: push_error("Candidate capture leaked debris");quit(1);return
	print("S04 carrier native PASS views=",records.size())
	quit(0)
