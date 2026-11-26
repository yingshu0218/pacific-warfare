extends "res://scripts/ship_geometry.gd"

var mount_detail: StandardMaterial3D = material(Color("3c454b"))


func _ready() -> void:
	name = "Japanese92ModelF_TripodMount"
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/naval_mount_profiles.json"))
	var profile: Dictionary = profiles.get("japanese_92_model_f_tripod", {})
	var max_height: float = float(profile.get("height_max_m", 0.762))
	var footprint_radius: float = float(profile.get("tripod_footprint_radius_estimate_m", 0.48))
	var head_y: float = max_height - 0.182
	var head: Vector3 = Vector3(0.0, head_y, 0.0)
	# Display the tripod at its documented maximum height; the foot geometry remains an estimate.
	for index: int in range(3):
		var angle: float = PI * 0.5 + TAU * float(index) / 3.0
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var foot: Vector3 = Vector3(direction.x * footprint_radius, 0.06, direction.z * footprint_radius)
		var leg_top: Vector3 = head + direction * 0.14
		box(foot, Vector3(0.24, 0.12, 0.2), mount_detail)
		rod(leg_top, foot + Vector3.UP * 0.08, 0.075, steel)
		var brace_point: Vector3 = Vector3(direction.x * footprint_radius * 0.64, 0.35, direction.z * footprint_radius * 0.64)
		rod(leg_top, brace_point, 0.036, mount_detail)
	cylinder(head, 0.2, 0.15, mount_detail)
	cylinder(head + Vector3(0.0, 0.1, 0.0), 0.15, 0.08, steel)
	# Separate upper post and sleeve keep the clamp at the recorded maximum height.
	var sleeve_y: float = max_height - 0.04
	cylinder(Vector3(0.0, (head_y + sleeve_y) * 0.5, 0.0), 0.068, sleeve_y - head_y, steel)
	cylinder(Vector3(0.0, sleeve_y, 0.0), 0.09, 0.08, mount_detail)
	# A compact U-yoke and transverse pintle make the free-swinging gun-to-tripod joint legible.
	for side: int in [-1, 1]:
		var arm: Vector3 = Vector3(float(side) * 0.15, max_height - 0.022, 0.0)
		rod(head + Vector3(float(side) * 0.1, 0.05, 0.0), arm, 0.045, steel)
		box(arm + Vector3(0.0, 0.015, 0.0), Vector3(0.065, 0.12, 0.15), mount_detail)
		var pivot: MeshInstance3D = cylinder(arm, 0.065, 0.12, steel)
		pivot.rotation.z = PI / 2.0
	var pintle: MeshInstance3D = cylinder(Vector3(0.0, max_height, 0.0), 0.04, 0.32, mount_detail)
	pintle.rotation.z = PI / 2.0
	var weapon_socket: Node3D = Node3D.new()
	weapon_socket.name = "WeaponSocket"
	weapon_socket.position = Vector3(0.0, max_height, 0.0)
	add_child(weapon_socket)
