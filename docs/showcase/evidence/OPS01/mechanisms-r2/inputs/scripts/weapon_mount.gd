class_name WeaponMount
extends Node3D

var elevation_axis: Node3D = Node3D.new()
var train_limits: Vector2 = Vector2(-150, 150)
var elevation_limits: Vector2 = Vector2(-5, 45)
var train_speed: float = 2.0
var elevation_speed: float = 5.0
var phase: float = 0.0
var base_heading: float = 0.0
var time: float = 0.0
var moving: bool = true
var automatic_demo: bool = true
var pose_guard: Callable
var obstructed: bool = false
var commanded_angles: Vector2 = Vector2.ZERO

func _init() -> void:
	elevation_axis.name = "ElevationPivot"
	add_child(elevation_axis)

func _process(delta: float) -> void:
	if not moving: return
	time += delta
	var train_target: float = lerpf(train_limits.x, train_limits.y, (sin(time * 0.13 + phase)+1.0)*0.5)
	var elevation_target: float = lerpf(elevation_limits.x, elevation_limits.y, (sin(time * 0.21 + phase)+1.0)*0.5)
	if not automatic_demo:
		train_target = commanded_angles.x
		elevation_target = commanded_angles.y
	apply_pose(move_toward(rotation.y, base_heading + deg_to_rad(train_target), deg_to_rad(train_speed)*delta),move_toward(elevation_axis.rotation.x, deg_to_rad(elevation_target), deg_to_rad(elevation_speed)*delta))

func aim_at_angles(train_degrees: float, elevation_degrees: float) -> void:
	if not is_finite(train_degrees) or not is_finite(elevation_degrees): return
	commanded_angles = Vector2(clampf(train_degrees,train_limits.x,train_limits.y),clampf(elevation_degrees,elevation_limits.x,elevation_limits.y))
	automatic_demo = false
	moving = true

func resume_demo() -> void:
	automatic_demo = true
	moving = true

func manual_move(horizontal: float, vertical: float, delta: float) -> void:
	var train: float = rad_to_deg(rotation.y-base_heading)+horizontal*train_speed*delta
	var heading: float = base_heading+deg_to_rad(clampf(train,train_limits.x,train_limits.y))
	var elevation: float = rad_to_deg(elevation_axis.rotation.x)+vertical*elevation_speed*delta
	apply_pose(heading,deg_to_rad(clampf(elevation,elevation_limits.x,elevation_limits.y)))

func apply_pose(heading: float, elevation: float) -> void:
	var steps: int = maxi(1,int(ceil(maxf(absf(heading-rotation.y),absf(elevation-elevation_axis.rotation.x))/deg_to_rad(0.5))))
	var initial: Vector2 = Vector2(rotation.y,elevation_axis.rotation.x)
	obstructed = false
	for step: int in range(1,steps+1):
		var candidate: Vector2 = initial.lerp(Vector2(heading,elevation),float(step)/steps)
		if pose_guard.is_valid() and not pose_guard.call(candidate.x,candidate.y):
			obstructed = true
			# A blocked train must not prevent a safe elevation change (and vice versa).
			if not is_equal_approx(candidate.y,elevation_axis.rotation.x) and pose_guard.call(rotation.y,candidate.y):
				elevation_axis.rotation.x = candidate.y
			elif not is_equal_approx(candidate.x,rotation.y) and pose_guard.call(candidate.x,elevation_axis.rotation.x):
				rotation.y = candidate.x
			return
		rotation.y = candidate.x
		elevation_axis.rotation.x = candidate.y

func set_geometry_visible(value: bool) -> void:
	for part: Node in find_children("*","MeshInstance3D",true,false):
		(part as MeshInstance3D).visible = value
