extends Node3D
class_name AirfieldSortieController

signal telemetry_updated(phase: String, speed_mps: float, altitude_m: float, elapsed_seconds: float)
signal sortie_completed

const A6M5_SCENE: PackedScene = preload("res://aircraft/scenes/a6m5_52ko.tscn")
const AIRFIELD_ELEVATION_M: float = 3.72
const TAKEOFF_SPEED_MPS: float = 51.0
const CRUISE_SPEED_MPS: float = 118.0
const APPROACH_SPEED_MPS: float = 54.0
const TAXI_SPEED_MPS: float = 5.2
const PLAYBACK_RATES: Array[float] = [1.0, 2.0, 3.0]

var playback_rate: float = 3.0
var paused: bool = false
var phase: String = "停机准备"
var speed_mps: float = 0.0
var elapsed_seconds: float = 0.0
var aircraft: Node3D
var _propeller: Node3D
var _wheel_nodes: Array[MeshInstance3D] = []
var _path: Path3D
var _follower: PathFollow3D
var _curve: Curve3D
var _phase_offsets: Array[float] = []
var _waypoints: Array[Vector3] = []
var _start_delay: float = 3.0
var _complete: bool = false
var _last_heading: float = 0.0
var _has_heading: bool = false


func _ready() -> void:
	_build_route()
	_create_aircraft()


func _physics_process(delta: float) -> void:
	if paused or _complete:
		return
	var simulated_delta: float = delta * playback_rate
	if _start_delay > 0.0:
		_start_delay = maxf(0.0, _start_delay - simulated_delta)
		elapsed_seconds += simulated_delta
		telemetry_updated.emit(phase, 0.0, AIRFIELD_ELEVATION_M, elapsed_seconds)
		return

	elapsed_seconds += simulated_delta
	var progress: float = _follower.progress
	var phase_name: String = _phase_for_progress(progress)
	var target_speed: float = _target_speed_for_phase(phase_name, progress)
	var acceleration: float = 8.0 if phase_name == "起飞滑跑" else 14.0
	if phase_name == "着陆滑跑":
		acceleration = 3.3
	if phase_name == "滑回机坪":
		acceleration = 6.0
	speed_mps = move_toward(speed_mps, target_speed, acceleration * simulated_delta)
	var next_progress: float = minf(_curve.get_baked_length(), progress + speed_mps * simulated_delta)
	_follower.progress = next_progress
	phase = _phase_for_progress(next_progress)
	_update_aircraft_attitude(simulated_delta)
	_spin_propeller(simulated_delta)
	_spin_wheels(simulated_delta)
	telemetry_updated.emit(phase, speed_mps, maxf(0.0, aircraft.global_position.y), elapsed_seconds)
	if next_progress >= _curve.get_baked_length() - 0.25:
		_complete = true
		phase = "返场停机"
		speed_mps = 0.0
		if _propeller != null:
			_propeller.rotation.z = 0.0
		telemetry_updated.emit(phase, speed_mps, AIRFIELD_ELEVATION_M, elapsed_seconds)
		sortie_completed.emit()


func toggle_pause() -> void:
	paused = not paused


func cycle_playback_rate() -> float:
	var current_index: int = PLAYBACK_RATES.find(playback_rate)
	playback_rate = PLAYBACK_RATES[(current_index + 1) % PLAYBACK_RATES.size()]
	return playback_rate


func restart() -> void:
	_follower.progress = 0.0
	_start_delay = 3.0
	_complete = false
	paused = false
	speed_mps = 0.0
	elapsed_seconds = 0.0
	phase = "停机准备"
	_has_heading = false
	if _propeller != null:
		_propeller.rotation.z = 0.0
	telemetry_updated.emit(phase, speed_mps, AIRFIELD_ELEVATION_M, elapsed_seconds)


func seek_to_airborne_capture() -> void:
	_follower.progress = _phase_offsets[8]
	_start_delay = 0.0
	_complete = false
	paused = false
	speed_mps = CRUISE_SPEED_MPS
	phase = _phase_for_progress(_follower.progress)
	_has_heading = false


func seek_to_takeoff_capture() -> void:
	_follower.progress = _phase_offsets[5]
	_start_delay = 0.0
	_complete = false
	paused = false
	speed_mps = 38.0
	phase = _phase_for_progress(_follower.progress)
	_has_heading = false


func _create_aircraft() -> void:
	_path = Path3D.new()
	_path.name = "A6M5a sortie route · real scale"
	_path.curve = _curve
	add_child(_path)
	_follower = PathFollow3D.new()
	_follower.name = "Aircraft route progress"
	_follower.rotation_mode = PathFollow3D.ROTATION_NONE
	_follower.loop = false
	_path.add_child(_follower)
	aircraft = A6M5_SCENE.instantiate() as Node3D
	aircraft.name = "Mitsubishi A6M5a Model 52 Ko · 1944"
	_follower.add_child(aircraft)
	_propeller = aircraft.get("propeller") as Node3D
	var wheels: Array[Node] = aircraft.find_children("Tyre", "MeshInstance3D", true, false)
	for wheel_node in wheels:
		var wheel := wheel_node as MeshInstance3D
		if wheel != null:
			_wheel_nodes.append(wheel)
	_follower.progress = 0.0
	_update_aircraft_attitude(0.0)


func _build_route() -> void:
	_waypoints = [
		Vector3(260.0, AIRFIELD_ELEVATION_M, 180.0),
		Vector3(-130.0, AIRFIELD_ELEVATION_M, 180.0),
		Vector3(-130.0, AIRFIELD_ELEVATION_M, 380.0),
		Vector3(-70.0, AIRFIELD_ELEVATION_M, 430.0),
		Vector3(0.0, AIRFIELD_ELEVATION_M, 420.0),
		Vector3(0.0, AIRFIELD_ELEVATION_M, 120.0),
		Vector3(0.0, 36.0, -550.0),
		Vector3(-180.0, 220.0, -1700.0),
		Vector3(750.0, 350.0, -2950.0),
		Vector3(1800.0, 320.0, -850.0),
		Vector3(1400.0, 270.0, 1200.0),
		Vector3(0.0, 148.0, 2800.0),
		Vector3(0.0, 90.0, 1700.0),
		Vector3(0.0, 43.0, 800.0),
		Vector3(0.0, 7.2, 470.0),
		Vector3(0.0, AIRFIELD_ELEVATION_M, 400.0),
		Vector3(0.0, AIRFIELD_ELEVATION_M, -460.0),
		Vector3(95.0, AIRFIELD_ELEVATION_M, -505.0),
		Vector3(120.0, AIRFIELD_ELEVATION_M, -390.0),
		Vector3(120.0, AIRFIELD_ELEVATION_M, 150.0),
		Vector3(215.0, AIRFIELD_ELEVATION_M, 180.0),
		Vector3(260.0, AIRFIELD_ELEVATION_M, 180.0)
	]
	_curve = Curve3D.new()
	_curve.bake_interval = 5.0
	_curve.up_vector_enabled = false
	for index in range(_waypoints.size()):
		var point: Vector3 = _waypoints[index]
		var tangent := Vector3.ZERO
		if index == 0:
			tangent = _waypoints[1] - point
		elif index == _waypoints.size() - 1:
			tangent = point - _waypoints[index - 1]
		else:
			tangent = (_waypoints[index + 1] - _waypoints[index - 1]) * 0.5
		var handle_length: float = minf(80.0, tangent.length() * 0.24)
		var handle: Vector3 = tangent.normalized() * handle_length
		_curve.add_point(point, -handle, handle)
	_phase_offsets = _find_waypoint_offsets()


func _find_waypoint_offsets() -> Array[float]:
	var offsets: Array[float] = []
	var curve_length: float = _curve.get_baked_length()
	var samples: int = ceili(curve_length / 4.0)
	for point in _waypoints:
		var nearest_offset: float = 0.0
		var nearest_distance: float = INF
		for sample_index in range(samples + 1):
			var offset: float = minf(curve_length, float(sample_index) * 4.0)
			var distance: float = _curve.sample_baked(offset).distance_squared_to(point)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_offset = offset
		offsets.append(nearest_offset)
	return offsets


func _phase_for_progress(progress: float) -> String:
	if progress < _phase_offsets[4]:
		return "滑行出场"
	if progress < _phase_offsets[6]:
		return "起飞滑跑"
	if progress < _phase_offsets[11]:
		return "空中航线"
	if progress < _phase_offsets[14]:
		return "着陆进近"
	if progress < _phase_offsets[17]:
		return "着陆滑跑"
	return "滑回机坪"


func _target_speed_for_phase(phase_name: String, progress: float) -> float:
	match phase_name:
		"滑行出场", "滑回机坪":
			return TAXI_SPEED_MPS
		"起飞滑跑":
			return TAKEOFF_SPEED_MPS
		"空中航线":
			return CRUISE_SPEED_MPS
		"着陆进近":
			return APPROACH_SPEED_MPS
		"着陆滑跑":
			var landing_start: float = _phase_offsets[14]
			var landing_end: float = _phase_offsets[17]
			var t: float = clampf((progress - landing_start) / maxf(1.0, landing_end - landing_start), 0.0, 1.0)
			return lerpf(APPROACH_SPEED_MPS, 6.0, t)
	return 0.0


func _update_aircraft_attitude(simulated_delta: float) -> void:
	if aircraft == null or _follower == null or _curve == null:
		return
	var tangent: Vector3 = _curve.sample_baked(_follower.progress, true)
	if tangent.length_squared() < 0.0001:
		return
	var forward: Vector3 = tangent.normalized()
	var heading: float = atan2(forward.x, -forward.z)
	var bank: float = 0.0
	if _has_heading and simulated_delta > 0.0001 and speed_mps > 18.0:
		var turn_rate: float = wrapf(heading - _last_heading, -PI, PI) / simulated_delta
		bank = clampf(-turn_rate * 0.6, -0.24, 0.24)
	_last_heading = heading
	_has_heading = true
	var aircraft_position: Vector3 = _follower.global_position
	aircraft.look_at(aircraft_position + forward, Vector3.UP)
	aircraft.rotate_object_local(Vector3(0.0, 0.0, 1.0), bank)


func _spin_propeller(simulated_delta: float) -> void:
	if _propeller == null:
		return
	var spin_rate: float = 26.0 if speed_mps > 12.0 else 10.0
	_propeller.rotation.z = wrapf(_propeller.rotation.z + spin_rate * simulated_delta, -TAU, TAU)


func _spin_wheels(simulated_delta: float) -> void:
	if _wheel_nodes.is_empty() or speed_mps < 0.1:
		return
	var wheel_rotation: float = speed_mps * simulated_delta / 0.31
	for wheel in _wheel_nodes:
		wheel.rotation.x = wrapf(wheel.rotation.x + wheel_rotation, -TAU, TAU)

