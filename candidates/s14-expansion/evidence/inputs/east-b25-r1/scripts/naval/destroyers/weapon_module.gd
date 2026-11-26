extends Node3D
## Reusable S03 mounts: fixed hardware, train housing and separate gun elevations.
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
@export_enum("us_5in38_mk30", "jp_127mm_type_c", "us_11in_quad", "us_oerlikon_single", "jp_type96_twin") var mount_kind: String = "us_5in38_mk30"
var train_axis: Node3D
var elevation_axes: Array[Node3D] = []
var muzzle_markers: Array[Marker3D] = []
var barrel_meshes: Array[MeshInstance3D] = []
var elevation_pivot_m: Vector3
var muzzle_offsets_m: Array[Vector3] = []
var seat_radius_m: float

func _ready() -> void:
	var p: Dictionary = G.palette(mount_kind.begins_with("us_"))
	train_axis = Node3D.new()
	train_axis.name = "TrainPivot"
	add_child(train_axis)
	match mount_kind:
		"us_5in38_mk30": _mk30(p)
		"jp_127mm_type_c": _type_c(p)
		"us_11in_quad": _aa(p, 4, 0.36, 1.20, 2.55, 0.058)
		"us_oerlikon_single": _aa(p, 1, 0.0, 1.05, 1.20, 0.034)
		"jp_type96_twin": _aa(p, 2, 0.36, 1.12, 1.85, 0.042)
	set_meta("interface_id", mount_kind)

func _mk30(p: Dictionary) -> void:
	seat_radius_m = 1.52
	G.cylinder(self, "FixedRollerPath", seat_radius_m, 0.14, Vector3(0, 0.07, 0), p.steel)
	var outline: Array[Vector2] = G.polygon([[-1.48,-1.75],[1.48,-1.75],[1.68,-1.30],[1.68,1.25],[1.30,1.65],[-1.30,1.65],[-1.68,1.25],[-1.68,-1.30]])
	var lower: MeshInstance3D = G.prism(train_axis, "GunHouseLower", outline, 0.14, 1.52, p.gray)
	var roof: MeshInstance3D = G.prism(train_axis, "SlopingGunHouseRoof", outline, 1.52, 2.42, p.gray, 0.82, Vector2(0, 0.18))
	var slot: AABB = AABB(Vector3(-0.45,0.78,-2.0),Vector3(0.90,2.0,1.95))
	G.open_gun_slot(lower,slot)
	G.open_gun_slot(roof,slot)
	G.box(train_axis,"DarkGunWell",Vector3(0.88,1.8,0.02),Vector3(0,1.52,0.18),p.dark)
	elevation_pivot_m = Vector3(0, 1.32, -0.38)
	_guns(p, [0.0], 3.82, 0.102, 0.15)

func _type_c(p: Dictionary) -> void:
	seat_radius_m = 1.88
	G.cylinder(self, "FixedRollerPath", seat_radius_m, 0.18, Vector3(0, 0.09, 0), p.steel)
	var outline: Array[Vector2] = G.polygon([[-1.85,-2.55],[1.85,-2.55],[2.16,-1.70],[2.16,1.95],[1.75,2.35],[-1.75,2.35],[-2.16,1.95],[-2.16,-1.70]])
	var lower: MeshInstance3D = G.prism(train_axis, "TypeCGunHouse", outline, 0.18, 1.95, p.gray)
	var roof: MeshInstance3D = G.prism(train_axis, "TypeCSlopingRoof", outline, 1.95, 2.55, p.gray, 0.92, Vector2(0, 0.17))
	for x: float in [-0.70, 0.70]:
		var slot: AABB = AABB(Vector3(x-0.38,0.95,-2.75),Vector3(0.76,2.1,2.70))
		G.open_gun_slot(lower,slot)
		G.open_gun_slot(roof,slot)
	# Reuse the already-cut outer surfaces for a dark inside face. Backface culling
	# must not let oblique views through a gun slot see out through the far wall.
	var lining: StandardMaterial3D = G.material(Color("131719"))
	lining.cull_mode = BaseMaterial3D.CULL_FRONT
	lining.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	G.mesh_node(train_axis,"DarkGunHouseWallLiner",lower.mesh,lining)
	G.mesh_node(train_axis,"DarkGunHouseRoofLiner",roof.mesh,lining)
	# Minimal opaque inner floor: openings reveal a dark compartment, not the deck.
	# Kept inside the exterior walls and below the entire -7…55 degree gun sweep.
	var inner_floor: Array[Vector2] = []
	for point: Vector2 in outline:
		inner_floor.append(point * 0.94)
	G.prism(train_axis,"DarkGunHouseFloor",inner_floor,0.30,0.34,p.dark)
	elevation_pivot_m = Vector3(0, 1.44, -0.32)
	_guns(p, [-0.70, 0.70], 5.06, 0.098, 0.16)

func _aa(p: Dictionary, count: int, spacing: float, height: float, length: float, radius: float) -> void:
	seat_radius_m = 0.34 if count == 1 else (0.78 if count == 2 else 1.05)
	var pedestal_height: float = 0.78 if count < 4 else 0.52
	G.cylinder(self, "FixedPedestalFoot", seat_radius_m, 0.14, Vector3(0, 0.07, 0), p.steel)
	G.cylinder(self, "FixedPedestal", seat_radius_m * 0.36, pedestal_height, Vector3(0, pedestal_height * 0.5 + 0.14, 0), p.gray)
	G.box(train_axis, "TrainYoke", Vector3(seat_radius_m * 1.8, 0.34, 0.70), Vector3(0, height - 0.22, 0), p.gray)
	if count == 1:
		var shield: Array[Vector2] = G.polygon([[-0.53,-0.10],[0.53,-0.10],[0.53,0.10],[-0.53,0.10]])
		G.prism(train_axis, "SplinterShield", shield, 0.82, 1.65, p.gray).position.z = -0.36
	else:
		for side: float in [-1.0, 1.0]:
			G.rod(train_axis, "YokeCheek", Vector3(side * seat_radius_m, 0.45, 0), Vector3(side * seat_radius_m, height + 0.10, 0), 0.075, p.steel)
			G.box(train_axis, "OperatorSeat", Vector3(0.46, 0.12, 0.40), Vector3(side * seat_radius_m * 1.2, 0.66, 0.65), p.steel)
	elevation_pivot_m = Vector3(0, height, 0)
	var offsets: Array[float] = []
	for index: int in range(count):
		offsets.append((float(index) - float(count - 1) * 0.5) * spacing)
	_guns(p, offsets, length, radius, radius * 1.65)
	for axis: Node3D in elevation_axes:
		if count == 1:
			var drum: MeshInstance3D = G.cylinder(axis, "DrumMagazine", 0.23, 0.15, Vector3(0, 0.22, 0.21), p.dark, 14)
			drum.rotation.z = PI * 0.5
		elif count == 2:
			G.box(axis, "BoxMagazine", Vector3(0.16, 0.40, 0.36), Vector3(0, 0.25, 0.15), p.dark)
		else:
			G.box(axis, "FeedBox", Vector3(0.30, 0.30, 0.42), Vector3(0, 0.12, 0.24), p.dark)

func _guns(p: Dictionary, offsets: Array[float], length: float, radius: float, breech_radius: float) -> void:
	for index: int in range(offsets.size()):
		var axis: Node3D = Node3D.new()
		axis.name = "ElevationPivot_%02d" % index
		axis.position = elevation_pivot_m + Vector3(offsets[index], 0, 0)
		train_axis.add_child(axis)
		elevation_axes.append(axis)
		G.box(axis, "Breech", Vector3(breech_radius * 2.0, breech_radius * 2.0, 0.65), Vector3(0, 0, 0.10), p.steel)
		G.rod(axis, "BarrelJacket", Vector3(0, 0, 0.02), Vector3(0, 0, -length * 0.53), radius * 1.35, p.steel, 12)
		# End face is at exactly the muzzle marker, not at the cylinder centre.
		var barrel: MeshInstance3D = G.rod(axis, "Barrel", Vector3(0, 0, -length * 0.35), Vector3(0, 0, -length), radius, p.steel, 12)
		barrel_meshes.append(barrel)
		G.rod(axis, "Bore", Vector3(0, 0, -length - 0.001), Vector3(0, 0, -length - 0.005), radius * 0.64, p.dark, 12)
		var marker: Marker3D = Marker3D.new()
		marker.name = "Muzzle_%02d" % index
		marker.position = Vector3(0, 0, -length)
		axis.add_child(marker)
		muzzle_markers.append(marker)
		muzzle_offsets_m.append(Vector3(offsets[index], 0, -length))
