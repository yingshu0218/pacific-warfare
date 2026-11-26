extends "res://scripts/ship_geometry.gd"

var mount_detail: StandardMaterial3D = material(Color("3c454b"))


func _ready() -> void:
	name = "Type96TwinShipMount"
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/naval_mount_profiles.json"))
	var profile: Dictionary = profiles.get("type96_twin_ship_mount", {})
	var equilibrator_length: float = float(profile.get("equilibrator_length_m", 0.4953))
	var equilibrator_radius: float = float(profile.get("equilibrator_outer_diameter_m", 0.065024)) * 0.5
	# Circular deck plate with hold-down fasteners and a rotating bearing.
	cylinder(Vector3(0.0, 0.08, 0.0), 0.92, 0.16, steel)
	for index: int in range(16):
		var angle: float = TAU * float(index) / 16.0
		cylinder(Vector3(cos(angle) * 0.78, 0.17, sin(angle) * 0.78), 0.045, 0.05, mount_detail)
	var bearing: TorusMesh = TorusMesh.new()
	bearing.inner_radius = 0.57
	bearing.outer_radius = 0.69
	bearing.rings = 12
	bearing.ring_segments = 32
	mesh_part(bearing, Vector3(0.0, 0.19, 0.0), mount_detail)
	var pedestal: CylinderMesh = CylinderMesh.new()
	pedestal.top_radius = 0.64
	pedestal.bottom_radius = 0.84
	pedestal.height = 0.78
	pedestal.radial_segments = 12
	mesh_part(pedestal, Vector3(0.0, 0.62, 0.0), steel)
	cylinder(Vector3(0.0, 1.0, 0.0), 0.69, 0.1, mount_detail)
	box(Vector3(0.0, 1.13, 0.0), Vector3(1.95, 0.18, 1.8), steel)
	# Round access/fastener details follow the perforated lower pedestal in the survey photographs.
	for face: int in [-1, 1]:
		for row: int in range(2):
			for column: int in range(3):
				var x: float = (float(column) - 1.0) * 0.34
				var y: float = 0.47 + float(row) * 0.27
				var detail: MeshInstance3D = cylinder(Vector3(x, y, float(face) * 0.72), 0.052, 0.018, mount_detail)
				detail.rotation.x = PI / 2.0
	# Open trunnion frames, operator gearboxes, handwheels and adjustable seats.
	for side: int in [-1, 1]:
		var frame_x: float = float(side) * 0.76
		var lower_frame: Vector3 = Vector3(frame_x, 1.27, 0.28)
		var trunnion: Vector3 = Vector3(frame_x, 2.03, -0.04)
		var rear_frame: Vector3 = Vector3(frame_x, 1.58, 0.72)
		rod(lower_frame, trunnion, 0.09, steel)
		rod(trunnion, rear_frame, 0.09, steel)
		rod(rear_frame, lower_frame, 0.08, steel)
		box(Vector3(frame_x, 1.74, 0.47), Vector3(0.24, 0.32, 0.28), mount_detail)
		rod(Vector3(float(side) * 0.76, 1.86, 0.55), Vector3(float(side) * 1.0, 1.86, 0.55), 0.07, steel)
		control_wheel(Vector3(float(side) * 1.11, 1.86, 0.55), 0.19)
		var seat: Vector3 = Vector3(float(side) * 0.69, 1.52, 0.83)
		box(seat, Vector3(0.45, 0.12, 0.38), mount_detail)
		box(seat + Vector3(0.0, 0.29, 0.17), Vector3(0.45, 0.44, 0.1), mount_detail)
		rod(seat + Vector3(0.0, -0.04, -0.08), seat + Vector3(0.0, -0.44, -0.08), 0.04, steel)
		box(Vector3(float(side) * 0.69, 1.22, -0.39), Vector3(0.48, 0.08, 0.34), steel)
		# One foot pedal per barrel, as described for the manual twin mount.
		box(Vector3(float(side) * 0.2, 1.245, -0.62), Vector3(0.16, 0.04, 0.2), mount_detail)
		rod(Vector3(float(side) * 0.2, 1.27, -0.58), Vector3(float(side) * 0.2, 1.33, -0.42), 0.018, steel)
	# Cradle, sighting gear and trunnions belong to the mount; the guns remain reusable assets.
	box(Vector3(0.0, 1.84, 0.08), Vector3(1.28, 0.1, 0.42), mount_detail)
	for side: int in [-1, 1]:
		box(Vector3(float(side) * 0.56, 2.03, 0.04), Vector3(0.12, 0.34, 0.56), steel)
		var trunnion_bearing: MeshInstance3D = cylinder(Vector3(float(side) * 0.7, 2.03, -0.04), 0.14, 0.2, mount_detail)
		trunnion_bearing.rotation.z = PI / 2.0
		rod(Vector3(float(side) * 0.7, 2.03, -0.04), Vector3(float(side) * 0.89, 2.03, -0.04), 0.085, steel)
		rod(Vector3(float(side) * 0.58, 2.18, 0.12), Vector3(float(side) * 0.72, 2.3, -0.42), 0.018, mount_detail)
		var sight: TorusMesh = TorusMesh.new()
		sight.inner_radius = 0.035
		sight.outer_radius = 0.045
		sight.rings = 10
		sight.ring_segments = 12
		var sight_part: MeshInstance3D = mesh_part(sight, Vector3(float(side) * 0.72, 2.3, -0.42), steel)
		sight_part.rotation.x = PI / 2.0
	var equilibrator_count: int = int(profile.get("recoil_equilibrator_count", 2))
	for index: int in range(equilibrator_count):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		# The survey calls these rear-mounted spring equilibrators and gives their tube envelope.
		var lower_anchor: Vector3 = Vector3(side * 0.52, 1.44, 0.69)
		var vertical_delta: float = 0.38
		var fore_aft_delta: float = sqrt(maxf(0.0, equilibrator_length * equilibrator_length - vertical_delta * vertical_delta))
		var upper_anchor: Vector3 = Vector3(side * 0.52, lower_anchor.y + vertical_delta, lower_anchor.z - fore_aft_delta)
		equilibrator_between(lower_anchor, upper_anchor, equilibrator_radius)
	var weapon_socket: Node3D = Node3D.new()
	weapon_socket.name = "WeaponSocket"
	weapon_socket.position = Vector3(0.0, 2.03, -0.04)
	add_child(weapon_socket)


func equilibrator_between(start: Vector3, end: Vector3, radius: float) -> void:
	var axis: Vector3 = (end - start).normalized()
	# Render a compact tubular spring equilibrator; the report gives its length and outside diameter,
	# but does not document exposed coil geometry.
	rod(start, end, radius, steel)
	for endpoint: Vector3 in [start, end]:
		rod(endpoint - axis * 0.018, endpoint + axis * 0.018, radius * 1.12, mount_detail)
	rod(start.lerp(end, 0.12), end.lerp(start, 0.12), radius * 0.28, mount_detail)
