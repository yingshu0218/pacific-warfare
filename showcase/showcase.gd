extends Node3D

const FIXED_STEP: float = 1.0 / 60.0
const MAX_STEPS_PER_FRAME: int = 32
const MAX_PROJECTILES: int = 512
const MAX_EFFECTS: int = 96
const SHIP_GEOMETRY_SCRIPT: Script = preload("res://scripts/ship_geometry.gd")
const AIRFIELD_SCRIPT: Script = preload("res://island_airfield/scripts/woleai_environment.gd")
const A6M5_SCENE: PackedScene = preload("res://aircraft/scenes/a6m5_52ko.tscn")
const F6F_SCENE: PackedScene = preload("res://aircraft/scenes/f6f5.tscn")
const TYPE96_MOUNT: PackedScene = preload("res://scenes/mounts/type96_ship_twin_mount.tscn")
const TYPE96_WEAPON: PackedScene = preload("res://scenes/weapons/type96_twin_25mm.tscn")
const TYPE96_SINGLE_GUN: PackedScene = preload("res://scenes/weapons/type96_25mm_single.tscn")
const TYPE92_MOUNT: PackedScene = preload("res://scenes/mounts/japanese_92_model_f_tripod.tscn")
const TYPE92_WEAPON: PackedScene = preload("res://scenes/weapons/navy_vickers_77mm.tscn")
const JAPANESE: String = "JP"
const UNITED_STATES: String = "US"
const UI_FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

var sim_time: float = 0.0
var accumulator: float = 0.0
var playback_rate: float = 1.0
var paused: bool = false
var reset_count: int = 0
var camera: Camera3D
var hud: CanvasLayer
var hud_label: Label
var performance_label: Label
var airfield: Node3D
var yamato: Node3D
var practice_targets: Array[Dictionary] = []
var aircraft_units: Array[Dictionary] = []
var ship_guns: Array[Dictionary] = []
var ship_weapons: Array[Dictionary] = []
var air_defences: Array[Dictionary] = []
var active_projectiles: Array[Dictionary] = []
var projectile_nodes: Array[MeshInstance3D] = []
var active_effects: Array[Dictionary] = []
var effect_nodes: Array[Node3D] = []
var shot_materials: Dictionary = {}
var effect_materials: Dictionary = {}
var camera_mode: String = "overview"
var camera_target: Vector3 = Vector3(310.0, 155.0, -390.0)
var camera_distance: float = 3000.0
var camera_yaw: float = -0.78
var camera_pitch: float = 0.55
var mouse_orbiting: bool = false
var mouse_panning: bool = false
var hud_visible: bool = true
var performance_visible: bool = false
var verification_mode: bool = false
var verification_duration: float = 120.0
var reset_audit_remaining: int = 0
var reset_audit_counts: Array[Dictionary] = []
var capture_view: String = ""
var capture_started: bool = false
var main_reload: float = 0.0
var secondary_reload: float = 0.0
var flak_reload: float = 0.5
var events: Array[Dictionary] = []
var statistics: Dictionary = {
	"shots": {"main": 0, "secondary": 0, "type89": 0, "type96": 0, "type92": 0, "a6m5": 0, "f6f5": 0},
	"hits": {"main": 0, "secondary": 0, "type89_airburst": 0, "type96": 0, "type92": 0, "a6m5": 0, "f6f5": 0},
	"ground_hits": 0,
	"ground_damage": 0.0,
	"air_damage_events": 0,
	"friendly_fire": 0,
	"projectile_cap_drops": 0,
	"effect_cap_drops": 0,
	"peak_projectiles": 0,
	"peak_effects": 0,
	"max_flight_distance_m": 0.0
}

var _ground_target_mesh: BoxMesh
var _effect_sphere: SphereMesh
var _projectile_meshes: Dictionary = {}
var weapon_profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_profiles.json"))


func _ready() -> void:
	name = "Pacific Combat and Flight Showcase · 1944 equipment integration"
	_configure_runtime_materials()
	_build_airfield()
	_build_neutral_range()
	_build_yamato()
	_build_air_defences()
	_spawn_fighters()
	_build_stage()
	_parse_arguments()
	_update_camera(0.0, true)
	_update_hud()
	print("SHOWCASE_READY engine=%s renderer=Compatibility aircraft=%d ship_guns=%d ground_targets=%d" % [str(Engine.get_version_info().string), aircraft_units.size(), ship_guns.size(), practice_targets.size()])


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_hud()
	if performance_visible and performance_label != null:
		performance_label.text = "FPS %d   Draw %d   Objects %d   Sim %.1fs" % [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), sim_time]


func _physics_process(delta: float) -> void:
	if paused:
		return
	accumulator += delta * playback_rate
	var step_count: int = 0
	while accumulator >= FIXED_STEP and step_count < MAX_STEPS_PER_FRAME:
		accumulator -= FIXED_STEP
		_simulate_step(FIXED_STEP)
		step_count += 1
	if step_count >= MAX_STEPS_PER_FRAME:
		accumulator = minf(accumulator, FIXED_STEP * MAX_STEPS_PER_FRAME)
	if verification_mode and sim_time >= verification_duration:
		_finish_verification()


func _simulate_step(dt: float) -> void:
	sim_time += dt
	_update_aircraft(dt)
	_update_ship_batteries(dt)
	_update_air_defences(dt)
	_update_projectiles(dt)
	_update_effects(dt)
	_update_capture_trigger()
	if verification_mode and reset_audit_remaining > 0 and sim_time >= 2.0:
		_reset_showcase()
		reset_audit_remaining -= 1
		reset_audit_counts.append(_showcase_object_counts())


func _configure_runtime_materials() -> void:
	_ground_target_mesh = BoxMesh.new()
	_ground_target_mesh.size = Vector3(9.0, 4.0, 0.45)
	_effect_sphere = SphereMesh.new()
	_effect_sphere.radius = 1.0
	_effect_sphere.height = 2.0
	_effect_sphere.radial_segments = 10
	_effect_sphere.rings = 6
	shot_materials = {
		"main": _emissive_material(Color("ffd89c"), 4.0),
		"secondary": _emissive_material(Color("ffd59b"), 3.5),
		"type89": _emissive_material(Color("ffcc7d"), 3.2),
		"type96": _emissive_material(Color("f8e7a0"), 4.5),
		"type92": _emissive_material(Color("fff1bd"), 5.0),
		"a6m5": _emissive_material(Color("e1ce8c"), 3.8),
		"f6f5": _emissive_material(Color("ffd491"), 3.8)
	}
	_projectile_meshes = {
		"main": _tracer_mesh(1.5, 0.16),
		"secondary": _tracer_mesh(1.0, 0.08),
		"type89": _tracer_mesh(1.0, 0.07),
		"type96": _tracer_mesh(0.62, 0.037),
		"type92": _tracer_mesh(0.48, 0.023),
		"a6m5": _tracer_mesh(0.72, 0.032),
		"f6f5": _tracer_mesh(0.56, 0.03)
	}
	effect_materials = {
		"explosion": _effect_material(Color("ffbc69"), 2.3, 0.92),
		"airburst": _effect_material(Color("ffe6ad"), 2.8, 0.82),
		"smoke": _effect_material(Color("45413b"), 0.0, 0.52),
		"splash": _effect_material(Color("9bd1d2"), 0.3, 0.5),
		"spark": _effect_material(Color("ffd59b"), 2.5, 0.88)
	}


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = energy
	result.no_depth_test = false
	return result


func _effect_material(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = Color(color.r, color.g, color.b, alpha)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = energy
	return result


func _tracer_mesh(length: float, radius: float) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 6
	return mesh


func _build_airfield() -> void:
	airfield = Node3D.new()
	airfield.name = "Woleai Atoll Airfield · reuse existing environment asset"
	airfield.set_script(AIRFIELD_SCRIPT)
	add_child(airfield)


func _build_neutral_range() -> void:
	var target_positions: Array[Vector3] = [
		Vector3(-16.0, 5.6, -740.0),
		Vector3(0.0, 5.6, -740.0),
		Vector3(16.0, 5.6, -740.0)
	]
	for index: int in range(target_positions.size()):
		var root: Node3D = Node3D.new()
		root.name = "Neutral inert target %02d · no personnel" % (index + 1)
		root.position = target_positions[index]
		root.set_meta("neutral_range_target", true)
		root.set_meta("owner", "neutral")
		root.set_meta("target_id", "range_target_%02d" % (index + 1))
		root.set_meta("damage", 0.0)
		root.set_meta("health", 1800.0)
		root.set_meta("radius_m", 7.0)
		var silhouette: MeshInstance3D = MeshInstance3D.new()
		silhouette.name = "Inert practice silhouette · full-size target board"
		silhouette.mesh = _ground_target_mesh
		silhouette.position.y = 0.2
		var target_material: StandardMaterial3D = StandardMaterial3D.new()
		target_material.albedo_color = Color("bb6c31")
		target_material.roughness = 0.88
		silhouette.material_override = target_material
		root.add_child(silhouette)
		var horizontal_bar: MeshInstance3D = MeshInstance3D.new()
		horizontal_bar.name = "Neutral range marker"
		var bar_mesh: BoxMesh = BoxMesh.new()
		bar_mesh.size = Vector3(13.0, 0.18, 0.25)
		horizontal_bar.mesh = bar_mesh
		horizontal_bar.position = Vector3(0.0, 2.05, -0.28)
		horizontal_bar.material_override = _emissive_material(Color("f2cf75"), 0.55)
		root.add_child(horizontal_bar)
		var label: Label3D = Label3D.new()
		label.name = "Neutral target identifier"
		label.text = "中立试验靶 %02d · 无人员" % (index + 1)
		label.font = UI_FONT
		label.font_size = 44
		label.pixel_size = 0.027
		label.outline_size = 9
		label.modulate = Color("f4dfae")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, 8.0, 0.0)
		root.add_child(label)
		airfield.add_child(root)
		practice_targets.append({"node": root, "id": str(root.get_meta("target_id")), "health": 1800.0, "radius": 7.0, "alive": true})
	var sign_root: Node3D = Node3D.new()
	sign_root.name = "Range separation and neutrality marker"
	sign_root.position = Vector3(0.0, 4.0, -710.0)
	var sign: MeshInstance3D = MeshInstance3D.new()
	sign.name = "Unoccupied range boundary sign"
	var sign_mesh: BoxMesh = BoxMesh.new()
	sign_mesh.size = Vector3(18.0, 4.0, 0.24)
	sign.mesh = sign_mesh
	var sign_material: StandardMaterial3D = StandardMaterial3D.new()
	sign_material.albedo_color = Color("c2a05c")
	sign_material.roughness = 0.85
	sign.material_override = sign_material
	sign_root.add_child(sign)
	var sign_label: Label3D = Label3D.new()
	sign_label.text = "NEUTRAL RANGE  /  NO PERSONNEL  /  EQUIPMENT TEST ONLY"
	sign_label.font = UI_FONT
	sign_label.font_size = 34
	sign_label.pixel_size = 0.025
	sign_label.outline_size = 8
	sign_label.position.y = 2.7
	sign_label.modulate = Color("f4dfae")
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_root.add_child(sign_label)
	airfield.add_child(sign_root)


func _build_yamato() -> void:
	var builder: Node3D = SHIP_GEOMETRY_SCRIPT.new() as Node3D
	add_child(builder)
	yamato = builder.call("build_ship") as Node3D
	var raw_weapons: Array = builder.get("weapons") as Array
	for entry: Variant in raw_weapons:
		ship_weapons.append(entry as Dictionary)
	yamato.reparent(self, false)
	builder.queue_free()
	yamato.name = "Yamato · existing April 1944 post-refit assembly"
	yamato.position = Vector3(1120.0, 0.0, 0.0)
	for entry: Dictionary in ship_weapons:
		var mount_node: WeaponMount = entry.pivot as WeaponMount
		mount_node.set_process(false)
		mount_node.moving = false
		mount_node.automatic_demo = false
	var main_mount: WeaponMount = _ship_weapon("main_01")
	var secondary_mount: WeaponMount = _ship_weapon("secondary_01")
	var heavy_mount: WeaponMount = _ship_weapon("heavy_aa_01")
	if main_mount != null:
		ship_guns.append(_make_ship_gun("Yamato main_01 · 46 cm Type 94", "main_01", "main", main_mount, 760.0, 14.0, 18.0, "main"))
	if secondary_mount != null:
		ship_guns.append(_make_ship_gun("Yamato secondary_01 · 15.5 cm triple", "secondary_01", "secondary", secondary_mount, 925.0, 5.0, 13.0, "secondary"))
	if heavy_mount != null:
		air_defences.append(_make_ship_flak("Yamato heavy_aa_01 · 12.7 cm Type 89", heavy_mount))
	for gun: Dictionary in ship_guns:
		_log_event("ship_mount_ready", {"weapon": gun.id, "world_mount": _vector_array((gun.mount as WeaponMount).global_position), "barrel_count": gun.barrel_count, "barrel_length_m": gun.barrel_length_m, "target_policy": "neutral_range_only"})


func _ship_weapon(identifier: String) -> WeaponMount:
	if yamato == null:
		return null
	var found: Node = yamato.find_child(identifier, true, false)
	if found is WeaponMount:
		return found as WeaponMount
	return null


func _make_ship_gun(label: String, identifier: String, role: String, mount_node: WeaponMount, muzzle_speed: float, rate_rpm: float, reload_seconds: float, projectile_kind: String) -> Dictionary:
	var profile_name: String = str(mount_node.get_meta("profile", role))
	var profile: Dictionary = weapon_profiles.get(profile_name, {})
	var count: int = int(mount_node.get_meta("barrels", 3))
	var spacing: float = float(profile.get("gun_spacing", 0.0))
	var length: float = float(profile.get("forward_barrel_length", 0.0))
	var axis_offset: Vector3 = mount_node.elevation_axis.position
	var muzzle_markers: Array[Node3D] = []
	for barrel: int in range(count):
		var marker: Node3D = Node3D.new()
		marker.name = "MuzzleTrace_%02d" % (barrel + 1)
		marker.position = Vector3((float(barrel) - float(count - 1) * 0.5) * spacing, 0.0, -length)
		mount_node.elevation_axis.add_child(marker)
		muzzle_markers.append(marker)
	return {
		"id": label,
		"identifier": identifier,
		"role": role,
		"mount": mount_node,
		"barrel_count": count,
		"barrel_spacing_m": spacing,
		"barrel_length_m": length,
		"axis_offset": axis_offset,
		"muzzle_markers": muzzle_markers,
		"muzzle_speed": muzzle_speed,
		"rate_rpm": rate_rpm,
		"reload_seconds": reload_seconds,
		"projectile_kind": projectile_kind,
		"cooldown": 0.2 if role == "main" else 0.5,
		"next_target_index": 0
	}


func _make_ship_flak(label: String, mount_node: WeaponMount) -> Dictionary:
	var profile: Dictionary = weapon_profiles.get("heavy_aa", {})
	var count: int = int(mount_node.get_meta("barrels", 2))
	var spacing: float = float(profile.get("gun_spacing", 0.76))
	var length: float = float(profile.get("forward_barrel_length", 3.8))
	var muzzle_markers: Array[Node3D] = []
	for barrel: int in range(count):
		var marker: Node3D = Node3D.new()
		marker.name = "MuzzleTrace_%02d" % (barrel + 1)
		marker.position = Vector3((float(barrel) - float(count - 1) * 0.5) * spacing, 0.0, -length)
		mount_node.elevation_axis.add_child(marker)
		muzzle_markers.append(marker)
	return {
		"id": label,
		"kind": "type89",
		"role": "type89",
		"mount": mount_node,
		"muzzle_markers": muzzle_markers,
		"barrel_count": count,
		"barrel_length_m": length,
		"muzzle_speed": 720.0,
		"train_speed": mount_node.train_speed,
		"elevation_speed": mount_node.elevation_speed,
		"train_limits": mount_node.train_limits,
		"elevation_limits": mount_node.elevation_limits,
		"cooldown": 0.0,
		"reload_seconds": 8.6,
		"ready_rounds": 2,
		"flight_fuse": 0.0,
		"target": null
	}


func _build_air_defences() -> void:
	var type96_positions: Array[Dictionary] = [
		{"id": "Type96_NW", "name": "Type 96 twin 25 mm AA position · northwest", "yaw": -0.8},
		{"id": "Type96_SE", "name": "Type 96 twin 25 mm AA position · southeast", "yaw": 2.4}
	]
	for spec: Dictionary in type96_positions:
		var emplacement: Node3D = airfield.find_child(str(spec.name), true, false) as Node3D
		if emplacement == null:
			continue
		_hide_airfield_static_weapon(emplacement, "Twin Type 96 barrels")
		_hide_airfield_parts(emplacement, ["Fixed pedestal base", "Pedestal column", "Traversing gear race", "Rotating gun platform", "Turntable frame", "Gunner foot platform left", "Gunner foot platform right", "Elevation yoke cheek", "Elevation trunnion bearing", "Layer seat column", "Layer bucket seat", "Layer seat back", "Elevation yoke crossbar", "Elevation handwheel", "Traverse handwheel", "Magazine rack frame", "Spare 15-round magazine", "Magazine identification band"])
		var foundation: Node3D = TYPE96_MOUNT.instantiate() as Node3D
		foundation.name = "Reusable Type96 twin mount · fixed host foundation"
		foundation.position.y = 0.5
		emplacement.add_child(foundation)
		var socket: Node3D = foundation.get_node("WeaponSocket") as Node3D
		var battery: Dictionary = _assemble_active_battery(str(spec.id), "type96", emplacement, foundation, socket, TYPE96_WEAPON, 0.36, 4.0, 30.0, 18.0, 2200.0, 900.0, 15, 3.8, float(spec.yaw), Vector2(-10.0, 85.0), 80.0)
		air_defences.append(battery)
	var type92_positions: Array[Dictionary] = [
		{"id": "Type92_W", "name": "Type 92 heavy machine-gun pit · west", "yaw": -1.2},
		{"id": "Type92_E", "name": "Type 92 heavy machine-gun pit · east", "yaw": 2.1},
		{"id": "Type92_S", "name": "Type 92 heavy machine-gun pit · southern shore", "yaw": 0.5}
	]
	for spec: Dictionary in type92_positions:
		var emplacement: Node3D = airfield.find_child(str(spec.name), true, false) as Node3D
		if emplacement == null:
			continue
		_hide_airfield_static_weapon(emplacement, "Type 92 tripod-mounted HMG")
		var tripod: Node3D = TYPE92_MOUNT.instantiate() as Node3D
		tripod.name = "Reusable Type92 Model F tripod · fixed host mount"
		emplacement.add_child(tripod)
		var socket: Node3D = tripod.get_node("WeaponSocket") as Node3D
		var battery: Dictionary = _assemble_active_battery(str(spec.id), "type92", emplacement, tripod, socket, TYPE92_WEAPON, 0.16, 3.5, 42.0, 25.0, 900.0, 744.0, 30, 3.0, float(spec.yaw), Vector2(-25.0, 85.0), 0.762)
		air_defences.append(battery)
	for battery: Dictionary in air_defences:
		var station_position: Vector3 = (battery.mount as WeaponMount).global_position if str(battery.kind) == "type89" else (battery.station as Node3D).global_position
		_log_event("aa_mount_ready", {"weapon": battery.id, "class": battery.kind, "world_mount": _vector_array(station_position), "muzzle_interface": "weapon_scene_root_local_minus_z", "target_policy": "US_aircraft_only"})


func _assemble_active_battery(identifier: String, kind: String, station: Node3D, fixed_mount: Node3D, socket: Node3D, weapon_scene: PackedScene, shot_interval: float, reload_seconds: float, train_speed: float, elevation_speed: float, max_range: float, muzzle_speed: float, magazine_capacity: int, reload_duration: float, base_yaw: float, elevation_limits: Vector2, mount_y: float) -> Dictionary:
	var traversal: Node3D = Node3D.new()
	traversal.name = identifier + " · train pivot"
	traversal.position = Vector3.ZERO
	station.add_child(traversal)
	fixed_mount.remove_child(socket)
	socket.name = identifier + " · ElevationPivot / weapon seat"
	socket.rotation = Vector3.ZERO
	traversal.add_child(socket)
	var weapon_root: Node3D
	var muzzle_markers: Array[Node3D] = []
	if kind == "type96":
		weapon_root = Node3D.new()
		weapon_root.name = identifier + " · twin reusable Type96 guns"
		socket.add_child(weapon_root)
		for index: int in range(2):
			var gun: Node3D = TYPE96_SINGLE_GUN.instantiate() as Node3D
			gun.name = "GunLeft" if index == 0 else "GunRight"
			gun.position.x = -0.19 if index == 0 else 0.19
			weapon_root.add_child(gun)
			var marker: Node3D = Node3D.new()
			marker.name = gun.name + " · MuzzleTrace"
			marker.position = Vector3(0.0, 0.0, -1.501775)
			gun.add_child(marker)
			muzzle_markers.append(marker)
	else:
		weapon_root = weapon_scene.instantiate() as Node3D
		weapon_root.name = identifier + " · reusable weapon asset"
		socket.add_child(weapon_root)
		var vickers_muzzle: Node3D = Node3D.new()
		vickers_muzzle.name = "Vickers · MuzzleTrace"
		vickers_muzzle.position = Vector3(0.0, 0.0, -0.72136)
		weapon_root.add_child(vickers_muzzle)
		muzzle_markers.append(vickers_muzzle)
	return {
		"id": identifier,
		"kind": kind,
		"role": kind,
		"station": station,
		"fixed_mount": fixed_mount,
		"traversal": traversal,
		"elevation": socket,
		"weapon_root": weapon_root,
		"muzzle_markers": muzzle_markers,
		"shot_interval": shot_interval,
		"reload_seconds": reload_seconds,
		"train_speed": train_speed,
		"elevation_speed": elevation_speed,
		"max_range": max_range,
		"muzzle_speed": muzzle_speed,
		"magazine_capacity": magazine_capacity,
		"ammo": magazine_capacity,
		"reload_duration": reload_duration,
		"reload_timer": 0.0,
		"base_yaw": base_yaw,
		"elevation_limits": elevation_limits,
		"mount_y": mount_y,
		"cooldown": shot_interval * 0.7,
		"target": null,
		"train_error": 180.0,
		"elevation_error": 90.0
	}


func _hide_airfield_static_weapon(emplacement: Node3D, child_name: String) -> void:
	var static_weapon: Node = emplacement.find_child(child_name, true, false)
	if static_weapon != null:
		static_weapon.visible = false


func _hide_airfield_parts(emplacement: Node3D, child_names: Array[String]) -> void:
	for part_name: String in child_names:
		var part: Node = emplacement.find_child(part_name, true, false)
		if part != null:
			part.visible = false


func _spawn_fighters() -> void:
	var initial: Array[Dictionary] = [
		{"id": "A6M5a_01", "side": JAPANESE, "scene": A6M5_SCENE, "position": Vector3(-660.0, 360.0, -1080.0), "heading": -1.47, "speed": 136.0, "turn_rate": 38.0, "climb_rate": 20.0, "altitude_offset": 18.0, "gun": "a6m5", "muzzle_names": ["20 mm muzzle"], "gun_speed": 790.0, "gun_interval": 0.16, "health": 100.0, "ammo": 250},
		{"id": "A6M5a_02", "side": JAPANESE, "scene": A6M5_SCENE, "position": Vector3(-850.0, 485.0, -1370.0), "heading": -1.40, "speed": 142.0, "turn_rate": 36.0, "climb_rate": 19.0, "altitude_offset": 24.0, "gun": "a6m5", "muzzle_names": ["20 mm muzzle"], "gun_speed": 790.0, "gun_interval": 0.16, "health": 100.0, "ammo": 250},
		{"id": "F6F5_01", "side": UNITED_STATES, "scene": F6F_SCENE, "position": Vector3(930.0, 405.0, -1080.0), "heading": 1.54, "speed": 155.0, "turn_rate": 25.0, "climb_rate": 16.0, "altitude_offset": -12.0, "gun": "f6f5", "muzzle_names": ["Browning muzzle*"], "gun_speed": 870.0, "gun_interval": 0.15, "health": 120.0, "ammo": 2400},
		{"id": "F6F5_02", "side": UNITED_STATES, "scene": F6F_SCENE, "position": Vector3(1130.0, 520.0, -1370.0), "heading": 1.50, "speed": 158.0, "turn_rate": 24.0, "climb_rate": 15.0, "altitude_offset": -18.0, "gun": "f6f5", "muzzle_names": ["Browning muzzle*"], "gun_speed": 870.0, "gun_interval": 0.15, "health": 120.0, "ammo": 2400}
	]
	for spec: Dictionary in initial:
		var plane: Node3D = (spec.scene as PackedScene).instantiate() as Node3D
		plane.name = str(spec.id)
		plane.position = spec.position
		plane.rotation.y = float(spec.heading)
		plane.set_meta("side", spec.side)
		plane.set_meta("service_year", "1944" if spec.gun == "a6m5" else "1944–1945")
		add_child(plane)
		var muzzle_markers: Array[Node3D] = []
		for muzzle_name: String in spec.muzzle_names:
			for node: Node in plane.find_children(muzzle_name, "MeshInstance3D", true, false):
				if node is Node3D:
					var marker: Node3D = Node3D.new()
					marker.name = "Operational muzzle · " + str(muzzle_markers.size() + 1)
					plane.add_child(marker)
					marker.position = plane.to_local((node as Node3D).global_position)
					muzzle_markers.append(marker)
		var unit: Dictionary = {
			"id": str(spec.id),
			"side": str(spec.side),
			"node": plane,
			"velocity": Vector3(-float(spec.speed) * sin(float(spec.heading)), 0.0, -float(spec.speed) * cos(float(spec.heading))),
			"speed": float(spec.speed),
			"base_speed": float(spec.speed),
			"turn_rate": deg_to_rad(float(spec.turn_rate)),
			"climb_rate": float(spec.climb_rate),
			"altitude_offset": float(spec.altitude_offset),
			"gun": str(spec.gun),
			"muzzles": muzzle_markers,
			"gun_speed": float(spec.gun_speed),
			"gun_interval": float(spec.gun_interval),
			"gun_timer": 0.3 + float(aircraft_units.size()) * 0.12,
			"ammo": int(spec.ammo),
			"health": float(spec.health),
			"max_health": float(spec.health),
			"alive": true,
			"crashed": false,
		"disengaging": false,
			"target": null,
			"flight_seconds": 0.0,
			"distance_m": 0.0,
			"peak_altitude_m": float(spec.position.y),
			"total_turn_rad": 0.0,
			"total_damage": 0.0,
			"bank": 0.0,
			"burst_timer": 0.0,
			"rest_timer": 1.2 + float(aircraft_units.size()) * 0.6
		}
		aircraft_units.append(unit)
	for unit: Dictionary in aircraft_units:
		unit.target = _nearest_enemy_for(unit)
		_log_event("aircraft_spawn", {"aircraft": unit.id, "side": unit.side, "position": _vector_array((unit.node as Node3D).global_position), "target": unit.target.id if unit.target is Dictionary else "none", "service_year": str((unit.node as Node3D).get_meta("service_year"))})


func _nearest_enemy_for(unit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	var source: Node3D = unit.node as Node3D
	for candidate: Dictionary in aircraft_units:
		if candidate == unit or not bool(candidate.get("alive", false)) or str(candidate.get("side", "")) == str(unit.get("side", "")):
			continue
		var candidate_node: Node3D = candidate.node as Node3D
		var distance: float = source.global_position.distance_to(candidate_node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _build_stage() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "Pacific late afternoon atmosphere"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aabfc1")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("9db1aa")
	environment.fog_density = 0.000018
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("3c6179")
	sky_material.sky_horizon_color = Color("d1cbb8")
	sky_material.ground_horizon_color = Color("8d9d8d")
	sky_material.ground_bottom_color = Color("3b514d")
	sky.sky_material = sky_material
	environment.sky = sky
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Tropical Pacific sun"
	sun.rotation_degrees = Vector3(-34.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)
	camera = Camera3D.new()
	camera.name = "Free, follow and combat-view camera"
	camera.fov = 52.0
	camera.near = 0.12
	camera.far = 12000.0
	camera.current = true
	add_child(camera)
	_build_hud()


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "Tactical and historical-context HUD"
	add_child(hud)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(root)
	hud_label = Label.new()
	hud_label.name = "Tactical situation and controls"
	hud_label.position = Vector2(24.0, 20.0)
	hud_label.custom_minimum_size = Vector2(730.0, 265.0)
	hud_label.add_theme_font_override("font", UI_FONT)
	hud_label.add_theme_font_size_override("font_size", 17)
	hud_label.add_theme_color_override("font_color", Color("f0eadb"))
	hud_label.add_theme_color_override("font_shadow_color", Color(0.04, 0.06, 0.06, 0.9))
	hud_label.add_theme_constant_override("shadow_offset_x", 1)
	hud_label.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(hud_label)
	var footer: Label = Label.new()
	footer.name = "Controls and scope note"
	footer.text = "1 总览   2 舰炮   3 靶区   4 空战跟随   5 防空近景    Space 暂停   T 倍速   R 重置   H 隐藏 HUD    鼠标左键环绕 / 右键平移 / 滚轮缩放"
	footer.position = Vector2(24.0, 846.0)
	footer.custom_minimum_size = Vector2(1510.0, 40.0)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_override("font", UI_FONT)
	footer.add_theme_font_size_override("font_size", 15)
	footer.add_theme_color_override("font_color", Color("e5dfcf"))
	hud.add_child(footer)
	performance_label = Label.new()
	performance_label.name = "Runtime performance"
	performance_label.position = Vector2(24.0, 215.0)
	performance_label.add_theme_font_override("font", UI_FONT)
	performance_label.add_theme_font_size_override("font_size", 15)
	performance_label.add_theme_color_override("font_color", Color("f0eadb"))
	performance_label.visible = false
	hud.add_child(performance_label)


func _update_camera(_delta: float, snap: bool = false) -> void:
	if camera == null:
		return
	var target: Vector3 = camera_target
	match camera_mode:
		"ship":
			target = yamato.global_position + Vector3(0.0, 13.0, -18.0)
		"impact":
			target = _active_target_position() + Vector3(0.0, 12.0, 0.0)
		"air":
			target = _air_fight_center()
		"aa":
			target = _active_aa_camera_target()
		"overview":
			target = Vector3(310.0, 155.0, -390.0)
		_: 
			target = camera_target
	if camera_mode == "air" and aircraft_units.size() > 0:
		var pair_distance: float = _air_pair_distance()
		camera_distance = clampf(pair_distance * 0.72, 240.0, 760.0)
	if snap:
		camera_target = target
	else:
		camera_target = camera_target.lerp(target, 0.14)
	camera.position = camera_target + Vector3(sin(camera_yaw) * cos(camera_pitch), sin(camera_pitch), cos(camera_yaw) * cos(camera_pitch)) * camera_distance
	camera.look_at(camera_target)


func _air_fight_center() -> Vector3:
	for unit: Dictionary in aircraft_units:
		if not bool(unit.get("alive", false)) or bool(unit.get("crashed", false)):
			continue
		var target: Dictionary = unit.get("target", {}) as Dictionary
		if not target.is_empty() and bool(target.get("alive", false)) and not bool(target.get("crashed", false)):
			return ((unit.node as Node3D).global_position + (target.node as Node3D).global_position) * 0.5
		return (unit.node as Node3D).global_position
	return Vector3(0.0, 250.0, -1000.0)


func _air_pair_distance() -> float:
	for unit: Dictionary in aircraft_units:
		if not bool(unit.get("alive", false)) or bool(unit.get("crashed", false)):
			continue
		var target: Dictionary = unit.get("target", {}) as Dictionary
		if not target.is_empty() and bool(target.get("alive", false)) and not bool(target.get("crashed", false)):
			return (unit.node as Node3D).global_position.distance_to((target.node as Node3D).global_position)
	return 420.0


func _active_target_position() -> Vector3:
	for target: Dictionary in practice_targets:
		if bool(target.get("alive", false)):
			return (target.node as Node3D).global_position
	return Vector3(0.0, 5.0, -740.0)


func _active_aa_camera_target() -> Vector3:
	for battery: Dictionary in air_defences:
		if str(battery.kind) == "type96":
			return (battery.station as Node3D).global_position + Vector3(0.0, 6.0, 0.0)
	return Vector3(0.0, 10.0, -690.0)


func _update_hud() -> void:
	if hud_label == null:
		return
	var living_planes: int = 0
	var damaged_planes: int = 0
	for unit: Dictionary in aircraft_units:
		if bool(unit.alive):
			living_planes += 1
			if float(unit.health) < float(unit.max_health):
				damaged_planes += 1
	var shots: Dictionary = statistics.shots
	var hits: Dictionary = statistics.hits
	var target_text: String = "中立试验靶区（无人）"
	if camera_mode == "air" and aircraft_units.size() > 0:
		for unit: Dictionary in aircraft_units:
			if bool(unit.get("alive", false)) and unit.get("target") is Dictionary:
				target_text = str(unit.id) + " → " + str(unit.target.id)
				break
	var state_text: String = "暂停" if paused else "运行"
	hud_label.text = "沃莱艾海空装备联调演示  /  1944  /  非史实战役\n"
	hud_label.text += "阵营：大和号与机场防空、零战为日军；F6F 为美军。大和炮击目标仅为机场以北隔离的无人中立靶区。\n"
	hud_label.text += "视角：%s   仿真：%6.1f s   状态：%s   倍速：%.0f×   目标：%s\n" % [_camera_mode_label(), sim_time, state_text, playback_rate, target_text]
	hud_label.text += "空中：%d / 4 架可飞   受损：%d   航炮/机枪命中：%d   空中伤害事件：%d\n" % [living_planes, damaged_planes, int(hits.a6m5) + int(hits.f6f5), int(statistics.air_damage_events)]
	hud_label.text += "舰炮：主炮 %d 发 / %d 命中；副炮 %d 发 / %d 命中   靶区命中：%d\n" % [int(shots.main), int(hits.main), int(shots.secondary), int(hits.secondary), int(statistics.ground_hits)]
	hud_label.text += "对敌防空：12.7 cm 空炸 %d 发 / %d 有效；25 mm %d 发；7.7 mm %d 发   弹丸 %d / %d   特效 %d / %d" % [int(shots.type89), int(hits.type89_airburst), int(shots.type96), int(shots.type92), active_projectiles.size(), MAX_PROJECTILES, active_effects.size(), MAX_EFFECTS]


func _camera_mode_label() -> String:
	match camera_mode:
		"overview": return "全景总览"
		"ship": return "舰炮跟随"
		"impact": return "靶区弹着"
		"air": return "空战跟随"
		"aa": return "防空近景"
		_: return "自由镜头"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			mouse_orbiting = mouse.pressed
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			mouse_panning = mouse.pressed
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(14.0, camera_distance * 0.88)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(8000.0, camera_distance / 0.88)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if mouse_orbiting:
			camera_mode = "free"
			camera_yaw -= motion.relative.x * 0.0045
			camera_pitch = clampf(camera_pitch + motion.relative.y * 0.0038, -0.08, 1.45)
		elif mouse_panning:
			camera_mode = "free"
			camera_target -= camera.global_basis.x * motion.relative.x * camera_distance * 0.0012
			camera_target += camera.global_basis.y * motion.relative.y * camera_distance * 0.0012
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_1:
				_set_camera_mode("overview")
			KEY_2:
				_set_camera_mode("ship")
			KEY_3:
				_set_camera_mode("impact")
			KEY_4:
				_set_camera_mode("air")
			KEY_5:
				_set_camera_mode("aa")
			KEY_SPACE:
				paused = not paused
			KEY_T:
				_cycle_playback_rate()
			KEY_R:
				_reset_showcase()
			KEY_H:
				hud_visible = not hud_visible
				hud.visible = hud_visible
			KEY_F8:
				performance_visible = not performance_visible
				performance_label.visible = performance_visible
			KEY_ESCAPE:
				mouse_orbiting = false
				mouse_panning = false


func _set_camera_mode(mode: String) -> void:
	camera_mode = mode
	switch_camera_defaults(mode)
	_update_camera(0.0, true)


func switch_camera_defaults(mode: String) -> void:
	match mode:
		"overview":
			camera_distance = 3000.0
			camera_yaw = -0.78
			camera_pitch = 0.55
		"ship":
			camera_distance = 235.0
			camera_yaw = -0.88
			camera_pitch = 0.28
		"impact":
			camera_distance = 105.0
			camera_yaw = 0.45
			camera_pitch = 0.27
		"air":
			camera_distance = 420.0
			camera_yaw = -0.92
			camera_pitch = 0.27
		"aa":
			camera_distance = 18.0
			camera_yaw = 0.62
			camera_pitch = 0.26
		"free":
			pass


func _cycle_playback_rate() -> void:
	if is_equal_approx(playback_rate, 1.0):
		playback_rate = 2.0
	elif is_equal_approx(playback_rate, 2.0):
		playback_rate = 4.0
	else:
		playback_rate = 1.0


func _update_aircraft(dt: float) -> void:
	for unit: Dictionary in aircraft_units:
		var plane: Node3D = unit.node as Node3D
		if not bool(unit.alive):
			continue
		if bool(unit.crashed):
			var crash_velocity: Vector3 = unit.velocity as Vector3
			crash_velocity.y -= 9.8 * dt
			plane.global_position += crash_velocity * dt
			unit.velocity = crash_velocity
			unit.speed = crash_velocity.length()
			plane.rotate_object_local(Vector3.FORWARD, dt * 0.2)
			if int(unit.get("smoke_tick", 0)) <= 0:
				_spawn_effect(plane.global_position - crash_velocity.normalized() * 2.0, "smoke", 2.6)
				unit.smoke_tick = 8
			else:
				unit.smoke_tick = int(unit.smoke_tick) - 1
			if plane.global_position.y < 0.0:
				unit.alive = false
				plane.visible = false
				_spawn_effect(plane.global_position, "splash", 7.0)
				_log_event("aircraft_crash", {"aircraft": unit.id, "position": _vector_array(plane.global_position), "flight_seconds": unit.flight_seconds})
			continue
		unit.flight_seconds = float(unit.flight_seconds) + dt
		var target: Dictionary = unit.get("target", {}) as Dictionary
		if target.is_empty() or not bool(target.get("alive", false)):
			target = _nearest_enemy_for(unit)
			unit.target = target
		if target.is_empty():
			continue
		var target_node: Node3D = target.node as Node3D
		var friendly_loss: bool = false
		if str(unit.side) == UNITED_STATES:
			for candidate: Dictionary in aircraft_units:
				if candidate != unit and str(candidate.side) == UNITED_STATES and bool(candidate.crashed):
					friendly_loss = true
		unit.disengaging = friendly_loss
		var own_position: Vector3 = plane.global_position
		var target_position: Vector3 = target_node.global_position
		var relative: Vector3 = target_position - own_position
		var distance: float = relative.length()
		var own_speed: float = float(unit.base_speed)
		var target_velocity: Vector3 = target.velocity as Vector3
		var closing_speed: float = maxf(80.0, own_speed + target_velocity.dot(-relative.normalized()))
		var lead_time: float = clampf(distance / closing_speed, 0.0, 2.6)
		var lead_position: Vector3 = target_position + target_velocity * lead_time
		var altitude_phase: float = sin(sim_time * 0.085 + float(aircraft_units.find(unit)) * 2.7)
		var altitude_offset: float = float(unit.altitude_offset) + altitude_phase * 72.0
		var desired: Vector3 = lead_position + Vector3.UP * altitude_offset - own_position
		var preturn_gun_direction: Vector3 = _gun_aim_direction(own_position, unit.velocity as Vector3, float(unit.gun_speed), target_position, target_velocity)
		var ground_aa_center: Vector3 = _ground_aa_center()
		var ground_aa_distance: float = own_position.distance_to(ground_aa_center)
		var breaking_away_from_aa: bool = friendly_loss and ground_aa_distance < 2600.0
		if breaking_away_from_aa:
			var escape_direction: Vector3 = (own_position - ground_aa_center).normalized()
			desired += escape_direction * 1500.0 + Vector3.UP * 450.0
		elif distance < 850.0 and distance > 80.0:
			desired = preturn_gun_direction
		if desired.length_squared() < 1.0:
			desired = relative
		var desired_direction: Vector3 = desired.normalized()
		var current_forward: Vector3 = -plane.global_basis.z.normalized()
		var pre_turn_forward: Vector3 = current_forward
		var turn_axis: Vector3 = current_forward.cross(desired_direction)
		var turn_angle: float = current_forward.angle_to(desired_direction)
		var turn_sign: float = signf(turn_axis.y)
		if turn_axis.length_squared() > 0.000001:
			current_forward = current_forward.rotated(turn_axis.normalized(), minf(turn_angle, float(unit.turn_rate) * dt)).normalized()
		unit.total_turn_rad = float(unit.total_turn_rad) + pre_turn_forward.angle_to(current_forward)
		var wanted_speed: float = float(unit.base_speed) + clampf(-desired_direction.y * 14.0, -10.0, 14.0)
		if float(unit.health) < float(unit.max_health) * 0.65:
			wanted_speed *= 0.92
		var speed: float = move_toward(float(unit.speed), wanted_speed, 8.0 * dt)
		var forward_horizontal: Vector3 = Vector3(current_forward.x, 0.0, current_forward.z)
		if forward_horizontal.length_squared() < 0.01:
			forward_horizontal = Vector3.FORWARD
		var vertical_speed: float = clampf(current_forward.y * speed, -float(unit.climb_rate) * 0.7, float(unit.climb_rate))
		var horizontal_forward: Vector3 = forward_horizontal.normalized()
		var velocity: Vector3 = horizontal_forward * sqrt(maxf(0.0, speed * speed - vertical_speed * vertical_speed)) + Vector3.UP * vertical_speed
		plane.global_position += velocity * dt
		unit.velocity = velocity
		unit.speed = speed
		unit.bank = lerpf(float(unit.bank), clampf(turn_sign * 0.58, -0.62, 0.62), minf(1.0, dt * 2.6))
		var orientation: Basis = Basis.looking_at(current_forward, Vector3.UP)
		plane.global_basis = Basis(current_forward, float(unit.bank)) * orientation
		unit.distance_m = float(unit.distance_m) + velocity.length() * dt
		unit.peak_altitude_m = maxf(float(unit.peak_altitude_m), plane.global_position.y)
		var to_target: Vector3 = lead_position - plane.global_position
		var current_gun_range: float = plane.global_position.distance_to(target_node.global_position)
		var ballistic_aim_direction: Vector3 = _gun_aim_direction(plane.global_position, velocity, float(unit.gun_speed), target_node.global_position, target_velocity)
		var aim_error: float = current_forward.angle_to(ballistic_aim_direction)
		unit.gun_timer = maxf(0.0, float(unit.gun_timer) - dt)
		unit.burst_timer = maxf(0.0, float(unit.burst_timer) - dt)
		unit.rest_timer = maxf(0.0, float(unit.rest_timer) - dt)
		if unit.rest_timer <= 0.0:
			unit.burst_timer = 1.3
			unit.rest_timer = 3.4
		if not breaking_away_from_aa and current_gun_range < 850.0 and current_gun_range > 80.0 and aim_error < deg_to_rad(3.5) and float(unit.burst_timer) > 0.0 and float(unit.gun_timer) <= 0.0:
			_fire_aircraft_volley(unit, target, target_node.global_position + target_velocity * 0.5)
			unit.gun_timer = float(unit.gun_interval)
		if plane.global_position.y < 28.0 and sim_time > 4.0:
			var escape_position: Vector3 = Vector3(0.0, 300.0, -950.0)
			unit.altitude_offset = 160.0 if (escape_position - own_position).dot(Vector3.UP) > 0.0 else float(unit.altitude_offset)


func _ground_aa_center() -> Vector3:
	var center: Vector3 = Vector3.ZERO
	var count: int = 0
	for battery: Dictionary in air_defences:
		if str(battery.kind) == "type89":
			continue
		var station: Node3D = battery.station as Node3D
		center += station.global_position
		count += 1
	return center / float(count) if count > 0 else Vector3.ZERO


func _gun_aim_direction(own_position: Vector3, own_velocity: Vector3, gun_speed: float, target_position: Vector3, target_velocity: Vector3) -> Vector3:
	var relative_position: Vector3 = target_position - own_position
	var distance: float = relative_position.length()
	if distance < 0.01:
		return relative_position.normalized()
	var line_of_sight: Vector3 = relative_position / distance
	var relative_velocity: Vector3 = target_velocity - own_velocity
	var closing_speed: float = maxf(80.0, gun_speed - relative_velocity.dot(line_of_sight))
	var flight_time: float = clampf(distance / closing_speed, 0.01, 1.5)
	var required_forward: Vector3 = relative_position / flight_time + relative_velocity + Vector3.UP * (4.9 * flight_time)
	return required_forward.normalized()


func _fire_aircraft_volley(unit: Dictionary, target: Dictionary, lead_position: Vector3) -> void:
	if int(unit.ammo) < (6 if str(unit.gun) == "f6f5" else 2):
		return
	if not _is_enemy(str(unit.side), str(target.side)):
		_count("friendly_fire", "", 1)
		return
	var plane: Node3D = unit.node as Node3D
	var forward: Vector3 = -plane.global_basis.z.normalized()
	var muzzle_list: Array = unit.muzzles
	var fired: int = 0
	for muzzle_item: Variant in muzzle_list:
		var muzzle: Node3D = muzzle_item as Node3D
		if muzzle == null or not is_instance_valid(muzzle):
			continue
		var start: Vector3 = muzzle.global_position
		var target_node: Node3D = target.node as Node3D
		var vector_to_lead: Vector3 = lead_position - start
		var direction: Vector3 = forward
		var kind: String = str(unit.gun)
		var projectile_kind: String = "a6m5" if kind == "a6m5" else "f6f5"
		if _spawn_projectile(projectile_kind, str(unit.side), start, direction * float(unit.gun_speed) + (unit.velocity as Vector3), 1.1 if kind == "a6m5" else 1.25, 1.0, target_node, "air_direct", 0.0, str(unit.id), str(target.id)):
			fired += 1
	if fired > 0:
		unit.ammo = int(unit.ammo) - fired
		_count("shots", str(unit.gun), fired)
		_log_event("aircraft_volley", {"aircraft": unit.id, "target": target.id, "muzzles": fired, "range_m": (unit.node as Node3D).global_position.distance_to((target.node as Node3D).global_position), "predicted_intercept": _vector_array(lead_position), "muzzle_positions": _muzzle_positions(unit.muzzles), "aim_error_deg": rad_to_deg((-plane.global_basis.z).angle_to((lead_position - plane.global_position).normalized()))})


func _update_ship_batteries(dt: float) -> void:
	for gun: Dictionary in ship_guns:
		var target: Dictionary = _next_live_ground_target(gun)
		if target.is_empty():
			continue
		var mount_node: WeaponMount = gun.mount as WeaponMount
		var target_node: Node3D = target.node as Node3D
		var desired_position: Vector3 = target_node.global_position
		var axis_position: Vector3 = mount_node.elevation_axis.global_position
		var heading_delta: Vector3 = desired_position - mount_node.global_position
		var world_heading: float = atan2(-heading_delta.x, -heading_delta.z)
		var relative_heading: float = wrapf(world_heading - mount_node.base_heading, -PI, PI)
		var desired_train: float = clampf(rad_to_deg(relative_heading), mount_node.train_limits.x, mount_node.train_limits.y)
		var current_train: float = wrapf(mount_node.rotation.y - mount_node.base_heading, -PI, PI)
		var next_train: float = _move_angle(current_train, deg_to_rad(desired_train), deg_to_rad(mount_node.train_speed) * dt)
		mount_node.rotation.y = mount_node.base_heading + next_train
		var horizontal_range: float = Vector2(desired_position.x - axis_position.x, desired_position.z - axis_position.z).length()
		var elevation: float = _solve_ballistic_elevation(horizontal_range, desired_position.y - axis_position.y, float(gun.muzzle_speed))
		var desired_elevation: float = clampf(rad_to_deg(elevation), mount_node.elevation_limits.x, mount_node.elevation_limits.y)
		mount_node.elevation_axis.rotation.x = move_toward(mount_node.elevation_axis.rotation.x, deg_to_rad(desired_elevation), deg_to_rad(mount_node.elevation_speed) * dt)
		var heading_error: float = absf(wrapf(mount_node.rotation.y - (mount_node.base_heading + deg_to_rad(desired_train)), -PI, PI))
		var elevation_error: float = absf(mount_node.elevation_axis.rotation.x - deg_to_rad(desired_elevation))
		gun.cooldown = maxf(0.0, float(gun.cooldown) - dt)
		if float(gun.cooldown) <= 0.0 and heading_error < deg_to_rad(2.0) and elevation_error < deg_to_rad(1.5):
			if _fire_ship_volley(gun, target):
				gun.cooldown = float(gun.reload_seconds)
		if str(gun.role) == "main":
			main_reload = float(gun.cooldown)
		else:
			secondary_reload = float(gun.cooldown)


func _next_live_ground_target(gun: Dictionary) -> Dictionary:
	if practice_targets.is_empty():
		return {}
	var start_index: int = int(gun.get("next_target_index", 0)) % practice_targets.size()
	for offset: int in range(practice_targets.size()):
		var index: int = (start_index + offset) % practice_targets.size()
		var target: Dictionary = practice_targets[index]
		var node: Node3D = target.node as Node3D
		if bool(target.get("alive", false)) and bool(node.get_meta("neutral_range_target", false)):
			gun.next_target_index = index
			return target
	return {}


func _fire_ship_volley(gun: Dictionary, target: Dictionary) -> bool:
	var target_node: Node3D = target.node as Node3D
	if not bool(target_node.get_meta("neutral_range_target", false)) or str(target_node.get_meta("owner", "")) != "neutral":
		_count("friendly_fire", "", 1)
		return false
	var markers: Array = gun.muzzle_markers
	var mount_node: WeaponMount = gun.mount as WeaponMount
	var fired: int = 0
	var target_position: Vector3 = target_node.global_position
	for marker_item: Variant in markers:
		var marker: Node3D = marker_item as Node3D
		var direction: Vector3 = -mount_node.elevation_axis.global_basis.z.normalized()
		var muzzle: Vector3 = marker.global_position
		var distance: float = muzzle.distance_to(target_position)
		if distance > float(gun.muzzle_speed) * 24.0:
			continue
		if _spawn_projectile(str(gun.projectile_kind), JAPANESE, muzzle, direction * float(gun.muzzle_speed), 55.0, 2500.0 if gun.role == "main" else 380.0, target_node, "ground", 0.0, str(gun.id), str(target.id)):
			fired += 1
	if fired <= 0:
		return false
	_count("shots", str(gun.role), fired)
	_log_event("ship_volley", {"weapon": gun.id, "target": target.id, "muzzles": fired, "muzzle_positions": _muzzle_positions(markers), "train_deg": rad_to_deg(wrapf(mount_node.rotation.y - mount_node.base_heading, -PI, PI)), "elevation_deg": rad_to_deg(mount_node.elevation_axis.rotation.x), "range_m": mount_node.global_position.distance_to(target_position)})
	return true


func _update_air_defences(dt: float) -> void:
	for battery: Dictionary in air_defences:
		battery.cooldown = maxf(0.0, float(battery.cooldown) - dt)
		if str(battery.kind) == "type89":
			_update_ship_flak(battery, dt)
		else:
			battery.reload_timer = maxf(0.0, float(battery.reload_timer) - dt)
			_update_ground_battery(battery, dt)


func _update_ship_flak(battery: Dictionary, dt: float) -> void:
	var mount_node: WeaponMount = battery.mount as WeaponMount
	var target: Dictionary = _select_enemy_plane(mount_node.global_position, UNITED_STATES, 6400.0)
	if target.is_empty():
		return
	battery.target = target
	var target_node: Node3D = target.node as Node3D
	var distance: float = mount_node.global_position.distance_to(target_node.global_position)
	var flight_time: float = distance / float(battery.muzzle_speed)
	var predicted: Vector3 = target_node.global_position + (target.velocity as Vector3) * minf(flight_time, 6.0)
	var delta_position: Vector3 = predicted - mount_node.global_position
	var heading: float = atan2(-delta_position.x, -delta_position.z)
	var relative_heading: float = wrapf(heading - mount_node.base_heading, -PI, PI)
	var desired_train: float = clampf(rad_to_deg(relative_heading), mount_node.train_limits.x, mount_node.train_limits.y)
	var current_train: float = wrapf(mount_node.rotation.y - mount_node.base_heading, -PI, PI)
	mount_node.rotation.y = mount_node.base_heading + _move_angle(current_train, deg_to_rad(desired_train), deg_to_rad(float(battery.train_speed)) * dt)
	var horizontal_range: float = Vector2(delta_position.x, delta_position.z).length()
	var desired_elevation: float = _solve_ballistic_elevation(horizontal_range, delta_position.y, float(battery.muzzle_speed))
	var elevation_limits: Vector2 = battery.elevation_limits
	desired_elevation = clampf(desired_elevation, deg_to_rad(elevation_limits.x), deg_to_rad(elevation_limits.y))
	mount_node.elevation_axis.rotation.x = move_toward(mount_node.elevation_axis.rotation.x, desired_elevation, deg_to_rad(float(battery.elevation_speed)) * dt)
	var heading_error: float = absf(wrapf(mount_node.rotation.y - (mount_node.base_heading + deg_to_rad(desired_train)), -PI, PI))
	var elevation_error: float = absf(mount_node.elevation_axis.rotation.x - desired_elevation)
	var within_range: bool = distance <= 6400.0 and distance >= 120.0
	if within_range and battery.cooldown <= 0.0 and battery.ready_rounds > 0 and heading_error < deg_to_rad(6.0) and elevation_error < deg_to_rad(4.0):
		var fired: int = 0
		var actual_fuse: float = 0.0
		for marker_item: Variant in battery.muzzle_markers:
			var marker: Node3D = marker_item as Node3D
			var muzzle: Vector3 = marker.global_position
			var direction: Vector3 = -mount_node.elevation_axis.global_basis.z.normalized()
			actual_fuse = muzzle.distance_to(predicted) / float(battery.muzzle_speed)
			if _spawn_projectile("type89", JAPANESE, muzzle, direction * float(battery.muzzle_speed), minf(12.0, actual_fuse + 0.025), 62.0, target_node, "airburst", actual_fuse, str(battery.id), str(target.id)):
				fired += 1
		if fired > 0:
			battery.ready_rounds = int(battery.ready_rounds) - 1
			_count("shots", "type89", fired)
			battery.cooldown = 0.24
			battery.flight_fuse = actual_fuse
			_log_event("timed_flak_volley", {"weapon": battery.id, "target": target.id, "muzzles": fired, "fuse_s": actual_fuse, "range_m": distance, "muzzle_positions": _muzzle_positions(battery.muzzle_markers)})
	elif battery.ready_rounds <= 0 and battery.cooldown <= 0.0:
		battery.cooldown = float(battery.reload_seconds)
		battery.ready_rounds = 2


func _update_ground_battery(battery: Dictionary, dt: float) -> void:
	var station: Node3D = battery.station as Node3D
	var target: Dictionary = _select_enemy_plane(station.global_position, UNITED_STATES, float(battery.max_range))
	if target.is_empty():
		return
	battery.target = target
	var target_node: Node3D = target.node as Node3D
	var start_axis: Vector3 = battery.elevation.global_position
	var distance: float = start_axis.distance_to(target_node.global_position)
	if distance > float(battery.max_range):
		return
	var flight_time: float = distance / float(battery.muzzle_speed)
	var predicted: Vector3 = target_node.global_position + (target.velocity as Vector3) * minf(flight_time, 2.0)
	var to_target: Vector3 = predicted - station.global_position
	var desired_world_heading: float = atan2(-to_target.x, -to_target.z)
	var base_yaw: float = float(battery.base_yaw)
	var desired_local_heading: float = wrapf(desired_world_heading - base_yaw, -PI, PI)
	var traversal: Node3D = battery.traversal as Node3D
	var current_train: float = wrapf(traversal.rotation.y, -PI, PI)
	var target_train: float = rad_to_deg(desired_local_heading)
	var train_limit: float = 180.0 if str(battery.kind) == "type96" else 180.0
	target_train = clampf(target_train, -train_limit, train_limit)
	traversal.rotation.y = _move_angle(current_train, deg_to_rad(target_train), deg_to_rad(float(battery.train_speed)) * dt)
	var horizontal_range: float = Vector2(predicted.x - start_axis.x, predicted.z - start_axis.z).length()
	var elevation_angle: float = _solve_ballistic_elevation(horizontal_range, predicted.y - start_axis.y, float(battery.muzzle_speed))
	var elevation_limits: Vector2 = battery.elevation_limits
	elevation_angle = clampf(elevation_angle, deg_to_rad(elevation_limits.x), deg_to_rad(elevation_limits.y))
	var elevation: Node3D = battery.elevation as Node3D
	elevation.rotation.x = move_toward(elevation.rotation.x, elevation_angle, deg_to_rad(float(battery.elevation_speed)) * dt)
	var heading_error: float = absf(wrapf(traversal.rotation.y - deg_to_rad(target_train), -PI, PI))
	var elevation_error: float = absf(elevation.rotation.x - elevation_angle)
	battery.train_error = rad_to_deg(heading_error)
	battery.elevation_error = rad_to_deg(elevation_error)
	if battery.reload_timer > 0.0:
		return
	if battery.cooldown > 0.0 or battery.ammo <= 0 or heading_error > deg_to_rad(9.0) or elevation_error > deg_to_rad(6.0):
		return
	var fired: int = 0
	for marker_item: Variant in battery.muzzle_markers:
		var marker: Node3D = marker_item as Node3D
		var muzzle: Vector3 = marker.global_position
		var weapon_root: Node3D = battery.weapon_root as Node3D
		var direction: Vector3 = -weapon_root.global_basis.z.normalized()
		if _spawn_projectile(str(battery.kind), JAPANESE, muzzle, direction * float(battery.muzzle_speed), minf(4.5, float(battery.max_range) / float(battery.muzzle_speed) + 1.0), 16.0 if battery.kind == "type96" else 2.0, target_node, "air_direct", 0.0, str(battery.id), str(target.id)):
			fired += 1
	if fired > 0:
		battery.ammo = int(battery.ammo) - 1
		battery.cooldown = float(battery.shot_interval)
		_count("shots", str(battery.kind), fired)
		_log_event("ground_aa_volley", {"weapon": battery.id, "target": target.id, "muzzles": fired, "range_m": distance, "train_error_deg": battery.train_error, "elevation_error_deg": battery.elevation_error, "muzzle_positions": _muzzle_positions(battery.muzzle_markers)})
	if int(battery.ammo) <= 0:
		battery.reload_timer = float(battery.reload_duration)
		battery.ammo = int(battery.magazine_capacity)


func _select_enemy_plane(origin: Vector3, enemy_side: String, max_range: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for unit: Dictionary in aircraft_units:
		if not bool(unit.get("alive", false)) or bool(unit.get("crashed", false)) or str(unit.side) != enemy_side:
			continue
		var plane: Node3D = unit.node as Node3D
		var distance: float = origin.distance_to(plane.global_position)
		if distance <= max_range and distance < best_distance:
			best = unit
			best_distance = distance
	return best


func _spawn_projectile(kind: String, owner_side: String, position: Vector3, velocity: Vector3, lifetime: float, damage: float, target: Node3D, mode: String, fuse: float, weapon_id: String, target_id: String) -> bool:
	if active_projectiles.size() >= MAX_PROJECTILES:
		_count("projectile_cap_drops", "", 1)
		return false
	var projectile_node: MeshInstance3D = _acquire_projectile_node(kind)
	if projectile_node == null:
		_count("projectile_cap_drops", "", 1)
		return false
	projectile_node.visible = true
	projectile_node.global_position = position
	var direction: Vector3 = velocity.normalized()
	projectile_node.global_basis = Basis.looking_at(direction, Vector3.UP)
	active_projectiles.append({
		"kind": kind,
		"owner_side": owner_side,
		"position": position,
		"previous": position,
		"velocity": velocity,
		"age": 0.0,
		"lifetime": lifetime,
		"damage": damage,
		"target": target,
		"target_id": target_id,
		"mode": mode,
		"fuse": fuse,
		"weapon_id": weapon_id,
		"node": projectile_node
	})
	statistics.peak_projectiles = maxi(int(statistics.peak_projectiles), active_projectiles.size())
	statistics.max_flight_distance_m = maxf(float(statistics.max_flight_distance_m), position.distance_to(yamato.global_position))
	return true


func _acquire_projectile_node(kind: String) -> MeshInstance3D:
	for node: MeshInstance3D in projectile_nodes:
		if not node.visible:
			node.mesh = _projectile_meshes.get(kind) as Mesh
			node.material_override = shot_materials.get(kind) as Material
			return node
	if projectile_nodes.size() >= MAX_PROJECTILES:
		return null
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "ProjectilePool_%03d" % (projectile_nodes.size() + 1)
	node.mesh = _projectile_meshes.get(kind) as Mesh
	node.material_override = shot_materials.get(kind) as Material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	projectile_nodes.append(node)
	return node


func _update_projectiles(dt: float) -> void:
	for index: int in range(active_projectiles.size() - 1, -1, -1):
		var shot: Dictionary = active_projectiles[index]
		var previous: Vector3 = shot.position
		var velocity: Vector3 = shot.velocity
		velocity.y -= 9.8 * dt
		var next_position: Vector3 = previous + velocity * dt
		shot.previous = previous
		shot.position = next_position
		shot.velocity = velocity
		shot.age = float(shot.age) + dt
		var projectile_node: MeshInstance3D = shot.node as MeshInstance3D
		projectile_node.global_position = next_position
		var forward: Vector3 = velocity.normalized()
		projectile_node.global_basis = Basis.looking_at(forward, Vector3.UP)
		var mode: String = str(shot.mode)
		var remove: bool = false
		if mode == "ground":
			var ground_target: Dictionary = _target_by_id(str(shot.target_id))
			if not ground_target.is_empty() and _segment_hits_sphere(previous, next_position, (ground_target.node as Node3D).global_position, float(ground_target.radius)):
				_apply_ground_hit(shot, ground_target, next_position)
				remove = true
		elif mode == "air_direct":
			var target_unit: Dictionary = _unit_by_id(str(shot.target_id))
			if not target_unit.is_empty() and bool(target_unit.get("alive", false)) and not bool(target_unit.get("crashed", false)) and _is_enemy(str(shot.owner_side), str(target_unit.side)):
				if _segment_hits_sphere(previous, next_position, (target_unit.node as Node3D).global_position, 6.5):
					_apply_air_hit(shot, target_unit, next_position)
					remove = true
		elif mode == "airburst" and float(shot.age) >= float(shot.fuse):
			_apply_airburst(shot, next_position)
			remove = true
		if float(shot.age) >= float(shot.lifetime):
			remove = true
		if mode == "ground" and next_position.y < 3.4:
			if not remove:
				_spawn_effect(next_position, "splash", 2.7)
			remove = true
		if remove:
			_recycle_projectile(projectile_node)
			active_projectiles.remove_at(index)


func _target_by_id(identifier: String) -> Dictionary:
	for target: Dictionary in practice_targets:
		if str(target.id) == identifier:
			return target
	return {}


func _unit_by_id(identifier: String) -> Dictionary:
	for unit: Dictionary in aircraft_units:
		if str(unit.id) == identifier:
			return unit
	return {}


func _apply_ground_hit(shot: Dictionary, target: Dictionary, impact_position: Vector3) -> void:
	var root: Node3D = target.node as Node3D
	if not bool(root.get_meta("neutral_range_target", false)):
		_count("friendly_fire", "", 1)
		return
	var damage: float = float(shot.damage)
	target.health = maxf(0.0, float(target.health) - damage)
	root.set_meta("health", target.health)
	root.set_meta("damage", 1800.0 - float(target.health))
	statistics.ground_hits = int(statistics.ground_hits) + 1
	statistics.ground_damage = float(statistics.ground_damage) + damage
	_count("hits", str(shot.kind), 1)
	_spawn_effect(impact_position, "explosion", 1.9 if shot.kind == "secondary" else 3.4)
	_spawn_effect(impact_position + Vector3.UP * 2.0, "smoke", 5.0)
	_log_event("ground_impact", {"weapon": shot.weapon_id, "target": target.id, "muzzle_id": shot.weapon_id, "impact": _vector_array(impact_position), "damage": damage, "health_remaining": target.health})
	if float(target.health) <= 0.0:
		target.alive = false
		root.visible = false
		_spawn_effect(impact_position, "explosion", 5.0)
		_log_event("ground_target_disabled", {"target": target.id, "impact": _vector_array(impact_position)})


func _apply_air_hit(shot: Dictionary, target: Dictionary, impact_position: Vector3) -> void:
	if not _is_enemy(str(shot.owner_side), str(target.side)):
		_count("friendly_fire", "", 1)
		return
	var damage: float = float(shot.damage)
	_apply_plane_damage(target, damage, str(shot.weapon_id), str(shot.target_id), impact_position)
	_count("hits", str(shot.kind), 1)


func _apply_airburst(shot: Dictionary, burst_position: Vector3) -> void:
	_spawn_effect(burst_position, "airburst", 2.4)
	var radius: float = 26.0
	var damaged: Array[String] = []
	for unit: Dictionary in aircraft_units:
		if not bool(unit.get("alive", false)) or bool(unit.get("crashed", false)):
			continue
		if str(unit.side) != UNITED_STATES or not _is_enemy(str(shot.owner_side), str(unit.side)):
			continue
		var plane: Node3D = unit.node as Node3D
		var distance: float = burst_position.distance_to(plane.global_position)
		if distance <= radius:
			var damage: float = 54.0 * (1.0 - distance / radius) + 8.0
			_apply_plane_damage(unit, damage, str(shot.weapon_id), str(shot.target_id), burst_position)
			damaged.append(str(unit.id))
	if damaged.size() > 0:
		_count("hits", "type89_airburst", damaged.size())
		_log_event("timed_airburst_hit", {"weapon": shot.weapon_id, "target": shot.target_id, "burst": _vector_array(burst_position), "damaged_aircraft": damaged})
	else:
		_log_event("timed_airburst", {"weapon": shot.weapon_id, "target": shot.target_id, "burst": _vector_array(burst_position), "damaged_aircraft": []})


func _apply_plane_damage(unit: Dictionary, damage: float, weapon_id: String, target_id: String, impact_position: Vector3) -> void:
	if not bool(unit.get("alive", false)):
		return
	unit.health = maxf(0.0, float(unit.health) - damage)
	unit.total_damage = float(unit.total_damage) + damage
	statistics.air_damage_events = int(statistics.air_damage_events) + 1
	var plane: Node3D = unit.node as Node3D
	_spawn_effect(impact_position, "spark", 0.65)
	if float(unit.health) <= 70.0 and int(unit.get("smoke_tick", 0)) <= 0:
		_spawn_effect(plane.global_position - (unit.velocity as Vector3).normalized() * 3.0, "smoke", 4.8)
		unit.smoke_tick = 6
	else:
		unit.smoke_tick = maxi(0, int(unit.get("smoke_tick", 0)) - 1)
	_log_event("aircraft_damage", {"weapon": weapon_id, "target": unit.id, "projectile_target": target_id, "damage": damage, "health_remaining": unit.health, "position": _vector_array(impact_position)})
	if float(unit.health) <= 0.0:
		unit.crashed = true
		var velocity: Vector3 = unit.velocity as Vector3
		unit.velocity = velocity + Vector3(0.0, -12.0, 0.0)
		unit.target = {}
		_log_event("aircraft_shot_down", {"aircraft": unit.id, "weapon": weapon_id, "position": _vector_array(plane.global_position), "flight_seconds": unit.flight_seconds})


func _spawn_effect(position: Vector3, kind: String, size: float) -> void:
	if active_effects.size() >= MAX_EFFECTS:
		_count("effect_cap_drops", "", 1)
		return
	var effect: Node3D = _acquire_effect_node(kind)
	if effect == null:
		_count("effect_cap_drops", "", 1)
		return
	effect.position = position
	effect.scale = Vector3.ONE * 0.2
	effect.visible = true
	var mesh: MeshInstance3D = effect.get_node("EffectMesh") as MeshInstance3D
	mesh.material_override = effect_materials.get(kind) as Material
	mesh.scale = Vector3.ONE * size
	active_effects.append({"node": effect, "kind": kind, "age": 0.0, "duration": 0.42 if kind in ["explosion", "airburst", "spark", "splash"] else 3.2, "size": size})
	statistics.peak_effects = maxi(int(statistics.peak_effects), active_effects.size())


func _acquire_effect_node(_kind: String) -> Node3D:
	for node: Node3D in effect_nodes:
		if not node.visible:
			return node
	if effect_nodes.size() >= MAX_EFFECTS:
		return null
	var effect: Node3D = Node3D.new()
	effect.name = "EffectPool_%02d" % (effect_nodes.size() + 1)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "EffectMesh"
	mesh.mesh = _effect_sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.add_child(mesh)
	add_child(effect)
	effect_nodes.append(effect)
	return effect


func _update_effects(dt: float) -> void:
	for index: int in range(active_effects.size() - 1, -1, -1):
		var effect_data: Dictionary = active_effects[index]
		effect_data.age = float(effect_data.age) + dt
		var node: Node3D = effect_data.node as Node3D
		var progress: float = clampf(float(effect_data.age) / float(effect_data.duration), 0.0, 1.0)
		var size: float = float(effect_data.size)
		if str(effect_data.kind) == "smoke":
			node.scale = Vector3.ONE * lerpf(0.25, 1.7, progress)
		else:
			node.scale = Vector3.ONE * lerpf(0.35, 1.0, progress)
			node.position.y += dt * size * 0.16
		if float(effect_data.age) >= float(effect_data.duration):
			node.visible = false
			active_effects.remove_at(index)


func _recycle_projectile(node: MeshInstance3D) -> void:
	node.visible = false


func _solve_ballistic_elevation(horizontal_range: float, vertical_delta: float, muzzle_speed: float) -> float:
	var distance: float = maxf(1.0, horizontal_range)
	var speed_sq: float = muzzle_speed * muzzle_speed
	var discriminant: float = speed_sq * speed_sq - 9.8 * (9.8 * distance * distance + 2.0 * vertical_delta * speed_sq)
	if discriminant <= 0.0:
		return atan2(vertical_delta, distance)
	return atan((speed_sq - sqrt(discriminant)) / (9.8 * distance))


func _move_angle(current: float, target: float, max_delta: float) -> float:
	var difference: float = wrapf(target - current, -PI, PI)
	return current + clampf(difference, -max_delta, max_delta)


func _segment_hits_sphere(start: Vector3, finish: Vector3, center: Vector3, radius: float) -> bool:
	var segment: Vector3 = finish - start
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.000001:
		return start.distance_squared_to(center) <= radius * radius
	var t: float = clampf((center - start).dot(segment) / length_sq, 0.0, 1.0)
	var closest: Vector3 = start + segment * t
	return closest.distance_squared_to(center) <= radius * radius


func _is_enemy(owner_side: String, target_side: String) -> bool:
	return owner_side != target_side and owner_side in [JAPANESE, UNITED_STATES] and target_side in [JAPANESE, UNITED_STATES]


func _count(group: String, key: String, amount: int) -> void:
	if group in ["shots", "hits"]:
		var counts: Dictionary = statistics[group]
		counts[key] = int(counts.get(key, 0)) + amount
		statistics[group] = counts
	else:
		statistics[group] = int(statistics.get(group, 0)) + amount


func _muzzle_positions(markers: Array) -> Array:
	var result: Array = []
	for item: Variant in markers:
		var marker: Node3D = item as Node3D
		if marker != null and is_instance_valid(marker):
			result.append(_vector_array(marker.global_position))
	return result


func _vector_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _log_event(event_name: String, fields: Dictionary) -> void:
	var entry: Dictionary = {"t": snappedf(sim_time, 0.001), "event": event_name}
	for key: Variant in fields.keys():
		entry[str(key)] = fields[key]
	events.append(entry)
	while events.size() > 140:
		events.pop_front()


func _update_capture_trigger() -> void:
	if capture_view.is_empty() or capture_started:
		return
	var ready: bool = false
	match capture_view:
		"ship":
			ready = int(statistics.shots.main) > 0
		"impact":
			ready = int(statistics.ground_hits) > 0
		"air":
			ready = int(statistics.shots.a6m5) + int(statistics.shots.f6f5) > 0
		"aa":
			ready = int(statistics.shots.type96) > 0 or int(statistics.shots.type89) > 0
	if ready:
		capture_started = true
		_set_camera_mode({"ship": "ship", "impact": "impact", "air": "air", "aa": "aa"}.get(capture_view, "overview"))
		_save_capture.call_deferred(capture_view)


func _save_capture(view_name: String) -> void:
	await get_tree().create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	var output_dir: String = "res://showcase/evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var image: Image = get_viewport().get_texture().get_image()
	var output_path: String = output_dir.path_join("%s.png" % view_name)
	var error: Error = image.save_png(output_path)
	print("SHOWCASE_CAPTURE view=%s path=%s error=%s" % [view_name, output_path, error_string(error)])
	if not verification_mode:
		get_tree().quit(0 if error == OK else 1)


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--verify":
			verification_mode = true
		elif argument.begins_with("--duration="):
			verification_duration = maxf(1.0, float(argument.trim_prefix("--duration=")))
		elif argument.begins_with("--rate="):
			playback_rate = clampf(float(argument.trim_prefix("--rate=")), 1.0, 12.0)
		elif argument.begins_with("--capture="):
			capture_view = argument.trim_prefix("--capture=")
		elif argument == "--performance":
			performance_visible = true
			performance_label.visible = true
		elif argument == "--reset-audit":
			reset_audit_remaining = 3
	if verification_mode:
		paused = false
		print("SHOWCASE_VERIFY_BEGIN duration_sim_seconds=%.1f rate=%.1f" % [verification_duration, playback_rate])
	if capture_view in ["ship", "impact", "air", "aa"]:
		playback_rate = maxf(playback_rate, 2.0)
		capture_started = false
		_set_camera_mode({"ship": "ship", "impact": "impact", "air": "air", "aa": "aa"}.get(capture_view, "overview"))


func _finish_verification() -> void:
	verification_mode = false
	paused = true
	var shots: Dictionary = statistics.shots
	var hits: Dictionary = statistics.hits
	var acceptance: Dictionary = {
		"main_fired": int(shots.main) > 0,
		"main_ground_hit": int(hits.main) > 0,
		"secondary_fired": int(shots.secondary) > 0,
		"secondary_ground_hit": int(hits.secondary) > 0,
		"type89_fired": int(shots.type89) > 0,
		"type96_fired": int(shots.type96) > 0,
		"type96_air_hit": int(hits.type96) > 0,
		"type92_fired": int(shots.type92) > 0,
		"type92_air_hit": int(hits.type92) > 0,
		"a6m5_fired": int(shots.a6m5) > 0,
		"f6f5_fired": int(shots.f6f5) > 0,
		"aircraft_sustained_flight": _has_aircraft_flown_for_side(JAPANESE, verification_duration * 0.95) and _has_aircraft_flown_for_side(UNITED_STATES, verification_duration * 0.95),
		"aircraft_gun_hit": int(hits.a6m5) + int(hits.f6f5) > 0,
		"aircraft_shot_down": _has_shot_down_aircraft(),
		"no_friendly_fire": int(statistics.friendly_fire) == 0,
		"projectile_limit_respected": projectile_nodes.size() <= MAX_PROJECTILES,
		"effect_limit_respected": effect_nodes.size() <= MAX_EFFECTS,
		"repeated_reset_no_accumulation": reset_audit_remaining == 0 and _reset_audit_passed()
	}
	for unit: Dictionary in aircraft_units:
		acceptance[str(unit.id) + "_moved"] = float(unit.distance_m) > 1000.0 or (bool(unit.crashed) and float(unit.distance_m) > 500.0)
		acceptance[str(unit.id) + "_turned"] = float(unit.total_turn_rad) > deg_to_rad(30.0)
	var payload: Dictionary = {
		"run": "Pacific equipment integration showcase",
		"engine": str(Engine.get_version_info().string),
		"renderer": "gl_compatibility",
		"fixed_step_seconds": FIXED_STEP,
		"simulated_seconds": snappedf(sim_time, 0.01),
		"requested_seconds": verification_duration,
		"playback_rate": playback_rate,
		"statistics": statistics,
		"shots": shots,
		"hits": hits,
		"acceptance": acceptance,
		"aircraft": _aircraft_report(),
		"projectile_pool_nodes": projectile_nodes.size(),
		"projectile_pool_limit": MAX_PROJECTILES,
		"active_projectiles_at_end": active_projectiles.size(),
		"effect_pool_nodes": effect_nodes.size(),
		"effect_pool_limit": MAX_EFFECTS,
		"active_effects_at_end": active_effects.size(),
		"air_defence_mount_count": air_defences.size(),
		"ship_position_m": _vector_array(yamato.global_position),
		"practice_target_positions_m": _target_report(),
		"events_tail": events,
		"reset_count": reset_count
	}
	var path: String = "res://docs/showcase/evidence/run-120s.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/showcase/evidence"))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()
	var all_passed: bool = true
	for key: Variant in acceptance.keys():
		if not bool(acceptance[key]):
			all_passed = false
	print("SHOWCASE_VERIFY_RESULT %s" % JSON.stringify({"passed": all_passed, "payload": payload}))
	get_tree().quit(0 if all_passed else 2)


func _aircraft_report() -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for unit: Dictionary in aircraft_units:
		var plane: Node3D = unit.node as Node3D
		report.append({"id": unit.id, "side": unit.side, "position": _vector_array(plane.global_position), "health": unit.health, "distance_flown_m": snappedf(float(unit.distance_m), 0.1), "peak_altitude_m": snappedf(float(unit.peak_altitude_m), 0.1), "turn_degrees": snappedf(rad_to_deg(float(unit.total_turn_rad)), 0.1), "flight_seconds": snappedf(float(unit.flight_seconds), 1.0), "alive": unit.alive, "crashed": unit.crashed, "damage_taken": unit.total_damage})
	return report


func _has_aircraft_flown_for_side(side: String, minimum_flight_seconds: float) -> bool:
	for unit: Dictionary in aircraft_units:
		if str(unit.side) == side and float(unit.flight_seconds) >= minimum_flight_seconds:
			return true
	return false


func _has_shot_down_aircraft() -> bool:
	for unit: Dictionary in aircraft_units:
		if bool(unit.crashed) and float(unit.total_damage) > 0.0:
			return true
	return false


func _target_report() -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for target: Dictionary in practice_targets:
		var node: Node3D = target.node as Node3D
		report.append({"id": target.id, "position": _vector_array(node.global_position), "health": target.health, "alive": target.alive, "neutral": node.get_meta("owner", "") == "neutral"})
	return report


func _reset_showcase() -> void:
	reset_count += 1
	var preserved_playback_rate: float = playback_rate
	sim_time = 0.0
	accumulator = 0.0
	paused = false
	playback_rate = preserved_playback_rate if verification_mode else 1.0
	for shot: Dictionary in active_projectiles:
		(shot.node as MeshInstance3D).visible = false
	active_projectiles.clear()
	for effect: Dictionary in active_effects:
		(effect.node as Node3D).visible = false
	active_effects.clear()
	events.clear()
	statistics = {
		"shots": {"main": 0, "secondary": 0, "type89": 0, "type96": 0, "type92": 0, "a6m5": 0, "f6f5": 0},
		"hits": {"main": 0, "secondary": 0, "type89_airburst": 0, "type96": 0, "type92": 0, "a6m5": 0, "f6f5": 0},
		"ground_hits": 0,
		"ground_damage": 0.0,
		"air_damage_events": 0,
		"friendly_fire": 0,
		"projectile_cap_drops": 0,
		"effect_cap_drops": 0,
		"peak_projectiles": 0,
		"peak_effects": 0,
		"max_flight_distance_m": 0.0
	}
	for target: Dictionary in practice_targets:
		target.health = 1800.0
		target.alive = true
		(target.node as Node3D).visible = true
		(target.node as Node3D).set_meta("health", 1800.0)
		(target.node as Node3D).set_meta("damage", 0.0)
	for unit: Dictionary in aircraft_units:
		var plane: Node3D = unit.node as Node3D
		plane.free()
	aircraft_units.clear()
	for mount: Dictionary in ship_weapons:
		var node: WeaponMount = mount.pivot as WeaponMount
		node.rotation.y = node.base_heading
		node.elevation_axis.rotation.x = 0.0
	for gun: Dictionary in ship_guns:
		gun.cooldown = 0.0
	for battery: Dictionary in air_defences:
		var traversal: Node3D = battery.get("traversal", null) as Node3D
		if traversal != null:
			traversal.rotation.y = 0.0
		var elevation: Node3D = battery.get("elevation", null) as Node3D
		if elevation != null:
			elevation.rotation.x = 0.0
		battery.cooldown = float(battery.get("shot_interval", 1.0)) * 0.7
		battery.reload_timer = 0.0
		battery.ammo = int(battery.get("magazine_capacity", 2))
		battery.ready_rounds = 2 if str(battery.get("kind", "")) == "type89" else int(battery.get("ready_rounds", 0))
		battery.target = null
	main_reload = 0.0
	secondary_reload = 0.0
	_spawn_fighters()
	_set_camera_mode("overview")
	_log_event("reset", {"reset_count": reset_count, "projectile_pool_nodes": projectile_nodes.size(), "effect_pool_nodes": effect_nodes.size()})


func _showcase_object_counts() -> Dictionary:
	return {"aircraft": aircraft_units.size(), "projectiles_allocated": projectile_nodes.size(), "effects_allocated": effect_nodes.size()}


func _reset_audit_passed() -> bool:
	if reset_audit_counts.size() < 3:
		return reset_count == 0
	var first: Dictionary = reset_audit_counts[0]
	for entry: Dictionary in reset_audit_counts:
		if int(entry.aircraft) != 4 or int(entry.projectiles_allocated) > MAX_PROJECTILES or int(entry.effects_allocated) > MAX_EFFECTS:
			return false
		if int(entry.projectiles_allocated) > int(first.projectiles_allocated) + 8 or int(entry.effects_allocated) > int(first.effects_allocated) + 8:
			return false
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
			mouse_orbiting = false
		elif mouse.button_index == MOUSE_BUTTON_RIGHT and not mouse.pressed:
			mouse_panning = false
