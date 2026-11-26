extends Node3D
## Pure AV02 model: metres, +Y up, -Z forward. Origin stays at the airframe datum.
## No _process, timers, physics, firing, release, damage rolls or production registry.
const G: Script = preload("res://aircraft/d4y2/geometry.gd")
const LENGTH_M: float = 10.22
const SPAN_M: float = 11.50
const REPORTED_HEIGHT_M: float = 3.740
const PROPELLER_RADIUS_M: float = 1.60
const MAIN_WHEEL_CENTER_M: Vector3 = Vector3(2.18, -1.28, -1.80)
const MAIN_WHEEL_RADIUS_M: float = 0.32
const TAIL_WHEEL_CENTER_M: Vector3 = Vector3(0.0, -0.34, 4.20)
const TAIL_WHEEL_RADIUS_M: float = 0.12
# [z, center_y, half_width, upper_radius, lower_radius]; photographic reconstruction.
const BODY: Array = [
	[-4.72, 0.0, 0.32, 0.32, 0.36], [-4.45, 0.0, 0.40, 0.43, 0.52],
	[-4.0, 0.0, 0.46, 0.49, 0.60], [-3.3, 0.0, 0.49, 0.54, 0.63],
	[-2.2, 0.0, 0.53, 0.57, 0.65], [-1.5, 0.0, 0.55, 0.58, 0.68],
	[-0.9, 0.0, 0.55, 0.56, 0.67], [0.3, 0.0, 0.52, 0.53, 0.65],
	[1.45, 0.0, 0.46, 0.46, 0.58], [2.1, 0.0, 0.39, 0.36, 0.49],
	[2.8, 0.015, 0.30, 0.27, 0.37], [3.5, 0.025, 0.22, 0.22, 0.28],
	[4.3, 0.035, 0.14, 0.17, 0.20], [4.9, 0.045, 0.08, 0.10, 0.12],
	[5.11, 0.04, 0.015, 0.035, 0.035]]
# [span, leading_edge_z, chord, base_y, thickness_ratio]
const WING: Array = [
	[0.0, -2.10, 2.95, -0.27, 0.14], [0.65, -2.08, 2.90, -0.23, 0.14],
	[2.40, -1.95, 2.40, -0.12, 0.12], [3.45, -1.81, 2.10, -0.055, 0.11],
	[4.60, -1.65, 1.72, 0.016, 0.10], [5.25, -1.36, 1.28, 0.056, 0.09],
	[5.55, -1.10, 0.82, 0.075, 0.08], [5.70, -0.91, 0.43, 0.084, 0.08],
	[5.75, -0.73, 0.035, 0.087, 0.08]]
const TAIL: Array = [
	[0.0, 3.55, 1.55, 0.12, 0.10], [0.60, 3.59, 1.49, 0.12, 0.10],
	[1.35, 3.76, 1.21, 0.13, 0.09], [1.95, 4.00, 0.78, 0.14, 0.08],
	[2.20, 4.22, 0.35, 0.15, 0.08], [2.25, 4.39, 0.035, 0.15, 0.08]]
const CANOPY: Array = [
	[-2.15, 0.52, 0.24, 0.04, 0.0], [-1.80, 0.52, 0.39, 0.64, 0.0],
	[-1.24, 0.52, 0.43, 0.70, 0.0], [-0.50, 0.51, 0.43, 0.69, 0.0],
	[0.20, 0.48, 0.40, 0.62, 0.0], [0.83, 0.44, 0.35, 0.44, 0.0],
	[1.40, 0.40, 0.20, 0.17, 0.0], [1.72, 0.36, 0.04, 0.025, 0.0]]

var materials: Dictionary = {}
var damage_modules: Dictionary = {}
var markers: Dictionary = {}
var surfaces: Dictionary = {}
var gear_axes: Array[Node3D] = []
var closed_gear_doors: Array[Node3D] = []
var bay_doors: Array[Node3D] = []
var propeller: Node3D
var hook_axis: Node3D
var crutch_axis: Node3D
var bomb_visual: Node3D
var rear_train: Node3D
var rear_elevation: Node3D
var rear_cover: Node3D
var state: Dictionary = {"gear": 1.0, "hook": 0.0, "flap": 0.0, "brake": 0.0, "bay": 0.0,
	"crutch": 0.0, "bomb_visible": true, "rear_gun": false, "propeller_rad": 0.0}

func _ready() -> void:
	_make_materials()
	for id: String in ["center", "engine", "left_wing", "right_wing", "tail"]:
		damage_modules[id] = G.group(self, id.to_pascal_case())
		damage_modules[id].set_meta("damage_part_id", id)
	_build_body()
	_build_wings()
	_build_tail()
	_build_canopy()
	_build_powerplant()
	_build_gear()
	_build_bay()
	_build_rear_gun()
	_build_hook()
	mark(damage_modules.center, "FLIGHT_DATUM", Vector3.ZERO, "presentation reference; NOT measured CG")
	mark(damage_modules.engine, "DAMAGE_ENGINE_CUT", Vector3(0.0, 0.0, -2.2), "precut module boundary")
	mark(damage_modules.tail, "DAMAGE_TAIL_CUT", Vector3(0.0, 0.015, 2.8), "precut module boundary")
	apply_visual_state({})
	set_meta("configuration", "D4Y2 Model12 1944-10; hypothetical with Shokaku1941")

func _make_materials() -> void:
	var colors: Dictionary = {"top": "30483f", "bottom": "b6b9ad", "glass": "607d87", "frame": "263c35",
		"steel": "60696b", "dark": "222a29", "rubber": "202224", "red": "a3322b", "white": "dbd8c8",
		"yellow": "c9a13e", "prop": "443b33", "bomb": "525c47"}
	for id: String in colors:
		materials[id] = G.material(Color(colors[id]), 0.25 if id == "steel" else 0.0)
	materials.skin = G.material(Color.WHITE)
	materials.skin.vertex_color_use_as_albedo = true

func mark(parent: Node3D, id: String, at: Vector3, source_status: String, forward: Vector3 = Vector3.FORWARD) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	marker.name = id
	marker.position = at
	if not forward.is_equal_approx(Vector3.FORWARD):
		marker.basis = Basis.looking_at(forward, Vector3.UP)
	marker.set_meta("source_status", source_status)
	marker.set_meta("host_id", str(parent.name))
	parent.add_child(marker)
	markers[id] = marker
	return marker

func _build_body() -> void:
	for row: Array in [["engine", -4.72, -2.2], ["center", -2.2, 2.8], ["tail", 2.8, 5.11]]:
		G.part(damage_modules[row[0]], "ContinuousSkin", G.shell(BODY, row[1], row[2], Color("30483f"), Color("b6b9ad"), row[0] == "center"), materials.skin)
	# Fuselage insignia omitted in V1: keep the approved clean skin, not a failing decal.
	# Chin fairing is an external radiator shell, not a radial cowl or engine interior.
	var chin: Array = [[-4.55, -0.40, 0.30, 0.08, 0.20], [-4.30, -0.43, 0.32, 0.10, 0.32],
		[-3.80, -0.44, 0.32, 0.10, 0.35], [-3.25, -0.44, 0.28, 0.10, 0.29], [-2.95, -0.44, 0.18, 0.08, 0.14]]
	G.part(damage_modules.engine, "ChinRadiatorFairing", G.shell(chin, -4.55, -2.95, Color("b6b9ad"), Color("b6b9ad")), materials.skin)
	var mouth: SurfaceTool = SurfaceTool.new(); mouth.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(32):
		var a: float = TAU * float(i) / 32.0; var b: float = TAU * float(i + 1) / 32.0
		G.triangle(mouth, Vector3(0.0, -0.45, -4.563), Vector3(cos(a) * 0.245, -0.45 + sin(a) * 0.105, -4.563),
			Vector3(cos(b) * 0.245, -0.45 + sin(b) * 0.105, -4.563), Vector3.FORWARD)
	G.part(damage_modules.engine, "RadiatorMouthShadow", G.finish(mouth), materials.dark)
	for side: float in [-1.0, 1.0]:
		for i: int in range(6):
			var z: float = -3.96 + float(i) * 0.18
			G.rod(damage_modules.engine, "Exhaust_%s_%d" % [side, i], Vector3(side * 0.43, -0.12, z), Vector3(side * 0.51, -0.17, z + 0.07), 0.044, materials.prop)
		var gun: Node3D = G.group(damage_modules.engine, "Type97_" + ("Port" if side < 0.0 else "Starboard"))
		G.rod(gun, "BarrelRecess", Vector3(side * 0.20, 0.47, -3.30), Vector3(side * 0.20, 0.47, -3.94), 0.025, materials.dark)
		mark(gun, "MUZZLE_TYPE97_" + ("PORT" if side < 0.0 else "STARBOARD"), Vector3(side * 0.20, 0.47, -3.94), "2 fixed Type97 7.7mm; station photo-estimated, bore -Z")

func _build_wings() -> void:
	for side: float in [-1.0, 1.0]:
		var id: String = "left_wing" if side < 0.0 else "right_wing"
		var root: Node3D = damage_modules[id]
		G.part(root, "FixedWing", G.wing(WING, side, 0.50, 5.75, 0.0, 0.75, Vector3.ZERO, Color("30483f"), Color("b6b9ad"), true), materials.skin)
		G.part(root, "RootTrailingFillet", G.wing(WING, side, 0.50, 0.65, 0.75, 1.0, Vector3.ZERO, Color("30483f"), Color("b6b9ad")), materials.skin)
		G.part(root, "TipTrailingCap", G.wing(WING, side, 5.55, 5.75, 0.75, 1.0, Vector3.ZERO, Color("30483f"), Color("b6b9ad")), materials.skin)
		_surface(root, "flap_" + id, WING, side, 0.65, 3.45, 0.75)
		_surface(root, "aileron_" + id, WING, side, 3.45, 5.55, 0.75)
		for i: int in range(3):
			var x: float = 0.85 + float(i) * 0.84
			var start: Vector3 = G.wing_point(WING, x, 0.62, false)
			start.x *= side
			start.y -= 0.012
			var axis: Node3D = G.group(root, "DiveBrake%d" % (i + 1), start)
			G.box(axis, "SolidNarrowPlate", Vector3(0.76, 0.018, 0.135), Vector3(side * 0.38, 0.0, 0.0675), materials.bottom)
			surfaces["brake_%s_%d" % [id, i]] = axis
			mark(axis, "HINGE_BRAKE_%s_%d" % [id.to_upper(), i], Vector3.ZERO, "R05 and 3 panels/wing text; reconstructed span and simplified chord")
		mark(root, "DAMAGE_" + id.to_upper() + "_CUT", Vector3(side * 0.50, -0.24, -0.8), "precut wing root boundary")
		# Generic release fittings retained, no unverified wing stores are displayed.
		var store: Vector3 = G.wing_point(WING, 2.85, 0.40, false)
		store.x *= side
		mark(root, "STORE_WING_" + id.to_upper(), store, "optional underwing station; payload/type not validated; not registered")
		_wing_roundel(root, side, 4.45, -0.82, 0.54)

func _surface(parent: Node3D, id: String, profile: Array, side: float, x0: float, x1: float, fraction: float) -> void:
	var at: Vector3 = G.wing_point(profile, x0, fraction, true)
	at.x *= side
	var pivot: Node3D = G.group(parent, id.to_pascal_case(), at)
	G.part(pivot, "MovableSkin", G.wing(profile, side, x0, x1, fraction, 1.0, at, Color("30483f"), Color("b6b9ad")), materials.skin)
	surfaces[id] = pivot
	mark(pivot, "HINGE_" + id.to_upper(), Vector3.ZERO, "simplified control hinge, local +X; photo-estimated")

func _build_tail() -> void:
	var root: Node3D = damage_modules.tail
	for side: float in [-1.0, 1.0]:
		G.part(root, "FixedTailplane" + str(side), G.wing(TAIL, side, 0.0, 2.25, 0.0, 0.65, Vector3.ZERO, Color("30483f"), Color("b6b9ad")), materials.skin)
		_surface(root, "elevator_" + ("left" if side < 0.0 else "right"), TAIL, side, 0.15, 2.25, 0.65)
	var fin: PackedVector2Array = PackedVector2Array([Vector2(0.10, 3.24), Vector2(0.50, 3.54), Vector2(1.38, 3.77),
		Vector2(1.64, 3.95), Vector2(1.73, 4.17), Vector2(1.72, 4.33), Vector2(1.61, 4.43), Vector2(0.05, 4.43)])
	G.plate(root, "VerticalFin", fin, 0.13, materials.top)
	var at: Vector3 = Vector3(0.0, 0.12, 4.43)
	var rudder: Node3D = G.group(root, "Rudder", at)
	G.plate(rudder, "RoundedRudder", PackedVector2Array([Vector2(0.05, 4.43), Vector2(1.61, 4.43), Vector2(1.56, 4.62),
		Vector2(1.30, 4.82), Vector2(0.91, 5.00), Vector2(0.37, 5.09), Vector2(0.05, 5.11)]), 0.11, materials.top, at)
	surfaces.rudder = rudder
	mark(rudder, "HINGE_RUDDER", Vector3.ZERO, "local +Y; fin/rudder photos reconstructed")

func _build_canopy() -> void:
	var root: Node3D = G.group(damage_modules.center, "Canopy")
	# Upper half of an elliptic loft. Each ring attaches to the continuous fuselage sill.
	var front: Array = CANOPY.slice(0, 5)
	var rear: Array = CANOPY.slice(4)
	G.part(root, "FixedAndSlidingGlazing", _canopy_mesh(front), materials.glass)
	rear_cover = G.part(root, "RearRotatingCoverSimplified", _canopy_mesh(rear), materials.glass)
	for z: float in [-2.15, -1.8, -1.24, -0.5, 0.2, 0.83, 1.4, 1.72]:
		for i: int in range(10):
			var a: Vector3 = G.shell_point(CANOPY, z, -PI * 0.5 + PI * float(i) / 10.0)
			var b: Vector3 = G.shell_point(CANOPY, z, -PI * 0.5 + PI * float(i + 1) / 10.0)
			G.rod(root, "CanopyFrame_%s_%d" % [z, i], a, b, 0.014, materials.frame)
	for side: float in [-1.0, 1.0]:
		for i: int in range(CANOPY.size() - 1):
			G.rod(root, "Sill_%s_%d" % [side, i], G.shell_point(CANOPY, CANOPY[i][0], side * PI * 0.5),
				G.shell_point(CANOPY, CANOPY[i + 1][0], side * PI * 0.5), 0.018, materials.frame)
			G.rod(root, "SideFrame_%s_%d" % [side, i], G.shell_point(CANOPY, CANOPY[i][0], side * PI * 0.29),
				G.shell_point(CANOPY, CANOPY[i + 1][0], side * PI * 0.29), 0.013, materials.frame)
	G.rod(root, "RadioMast", Vector3(0.0, 1.18, -0.46), Vector3(0.0, 1.68, -0.50), 0.024, materials.frame, 0.015)
	G.rod(root, "OpticalBombsight", Vector3(0.0, 0.95, -2.40), Vector3(0.0, 1.02, -1.91), 0.043, materials.dark)

func _canopy_mesh(profile: Array) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in range(profile.size() - 1):
		for i: int in range(16):
			var a: float = -PI * 0.5 + PI * float(i) / 16.0
			var b: float = -PI * 0.5 + PI * float(i + 1) / 16.0
			G.quad(st, G.shell_point(profile, profile[j][0], a), G.shell_point(profile, profile[j + 1][0], a),
				G.shell_point(profile, profile[j + 1][0], b), G.shell_point(profile, profile[j][0], b), Vector3(sin((a + b) * 0.5), cos((a + b) * 0.5), 0.0))
	return G.finish(st)

func _build_powerplant() -> void:
	propeller = G.group(damage_modules.engine, "Propeller", Vector3(0.0, 0.0, -4.72))
	var spinner: Array = [[-0.39, 0.0, 0.003, 0.003, 0.003], [-0.25, 0.0, 0.19, 0.19, 0.19],
		[-0.08, 0.0, 0.30, 0.30, 0.30], [0.0, 0.0, 0.32, 0.32, 0.32]]
	G.part(propeller, "Spinner", G.shell(spinner, -0.39, 0.0, Color("30483f"), Color("30483f")), materials.skin)
	for i: int in range(3):
		var blade: Node3D = G.group(propeller, "Blade%d" % (i + 1))
		blade.rotation.z = float(i) * TAU / 3.0
		var shape: PackedVector2Array = PackedVector2Array([Vector2(0.23, -0.06), Vector2(0.55, -0.14), Vector2(1.20, -0.14),
			Vector2(1.54, -0.075), Vector2(1.60, -0.025), Vector2(1.56, 0.03), Vector2(0.90, 0.095), Vector2(0.23, 0.045)])
		# G.plate is a YZ plane; rotate around Y to put width along X and depth along Z.
		var mesh: MeshInstance3D = G.plate(blade, "BladeSkin", shape, 0.025, materials.prop)
		mesh.rotation.y = PI * 0.5
		mark(blade, "PROP_TIP_%d" % i, Vector3(0.0, 1.60, 0.0), "photo-estimated radius; 3-blade assembly")
	mark(damage_modules.engine, "ENGINE_SMOKE", Vector3(0.0, 0.37, -2.45), "simulation-driven emission suggestion, no automatic smoke")

func _build_gear() -> void:
	for side: float in [-1.0, 1.0]:
		var wing: Node3D = damage_modules.left_wing if side < 0.0 else damage_modules.right_wing
		var root_at: Vector3 = Vector3(side * 2.0, -0.20, -1.50)
		var center: Vector3 = MAIN_WHEEL_CENTER_M * Vector3(side, 1.0, 1.0)
		var gear: Node3D = G.group(wing, "MainGear", root_at)
		gear.set_meta("retract_side", side)
		G.rod(gear, "SimpleOleo", Vector3.ZERO, center - root_at + Vector3(0.0, 0.13, 0.0), 0.052, materials.steel)
		G.rod(gear, "DragBrace", Vector3(-side * 0.40, 0.04, 0.25), (center - root_at) * 0.55, 0.026, materials.dark)
		G.rod(gear, "Axle", center - root_at, center - root_at + Vector3(side * 0.14, 0.0, 0.0), 0.05, materials.steel)
		_wheel(gear, "MainTyre", center - root_at, MAIN_WHEEL_RADIUS_M, 0.19)
		G.box(gear, "SimpleAttachedDoor", Vector3(0.025, 0.86, 0.29), (center - root_at) * 0.55 + Vector3(side * 0.12, 0.0, 0.0), materials.bottom)
		mark(gear, "WHEEL_" + ("PORT" if side < 0.0 else "STARBOARD"), center - root_at, "M03/M05/R04: wheel station/radius photo-estimated; center of actual cylinder")
		mark(gear, "GEAR_PIVOT_" + ("PORT" if side < 0.0 else "STARBOARD"), Vector3.ZERO, "simple inward rotation, no well linkage")
		gear_axes.append(gear)
		var door: MeshInstance3D = G.box(wing, "ClosedGearDoor", Vector3(1.20, 0.018, 0.50), Vector3(side * 1.50, -0.33, -1.32), materials.bottom)
		closed_gear_doors.append(door)
	var root_at: Vector3 = Vector3(0.0, -0.13, 4.0)
	var tail: Node3D = G.group(damage_modules.tail, "TailGear", root_at)
	G.rod(tail, "ShortTailStrut", Vector3.ZERO, TAIL_WHEEL_CENTER_M - root_at, 0.033, materials.steel)
	_wheel(tail, "TailTyre", TAIL_WHEEL_CENTER_M - root_at, TAIL_WHEEL_RADIUS_M, 0.085)
	mark(tail, "WHEEL_TAIL", TAIL_WHEEL_CENTER_M - root_at, "short tailwheel, not extended to force level parking")
	gear_axes.append(tail)

func _wheel(parent: Node3D, id: String, at: Vector3, radius: float, width: float) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = width; mesh.radial_segments = 64
	var tyre: MeshInstance3D = G.part(parent, id, mesh, materials.rubber, at)
	tyre.rotation.z = PI * 0.5
	tyre.set_meta("wheel_radius_m", radius)
	G.rod(parent, id + "Hub", at - Vector3(width * 0.52, 0.0, 0.0), at + Vector3(width * 0.52, 0.0, 0.0), radius * 0.52, materials.steel)

func _build_bay() -> void:
	var root: Node3D = G.group(damage_modules.center, "BombBay")
	G.box(root, "InternalShadow", Vector3(0.55, 0.035, 2.24), Vector3(0.0, -0.23, 0.275), materials.dark)
	for side: float in [-1.0, 1.0]:
		var at: Vector3 = G.shell_point(BODY, 0.3, PI + side * 5.0 * TAU / 48.0)
		at.z = 0.0
		var door: Node3D = G.group(root, "Door" + str(side), at)
		var st: SurfaceTool = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j: int in range(24):
			for k: int in range(5):
				var z0: float = lerpf(-0.90, 1.45, float(j) / 24.0); var z1: float = lerpf(-0.90, 1.45, float(j + 1) / 24.0)
				var a: float = PI + side * float(k) * TAU / 48.0; var b: float = PI + side * float(k + 1) * TAU / 48.0
				G.quad(st, G.shell_point(BODY, z0, a) - at, G.shell_point(BODY, z1, a) - at,
					G.shell_point(BODY, z1, b) - at, G.shell_point(BODY, z0, b) - at, Vector3.DOWN)
		var mat: StandardMaterial3D = materials.bottom.duplicate() as StandardMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		G.part(door, "CurvedDoorSkin", G.finish(st), mat)
		bay_doors.append(door)
		mark(door, "BAY_HINGE_" + ("LEFT" if side < 0.0 else "RIGHT"), Vector3.ZERO, "curved door matches real shell cut; simplified longitudinal hinge")
	crutch_axis = G.group(root, "SwingCrutch", Vector3(0.0, -0.30, -0.72))
	for side: float in [-1.0, 1.0]:
		G.rod(crutch_axis, "CarrierArm" + str(side), Vector3(side * 0.16, 0.0, 0.0), Vector3(side * 0.12, -0.12, 0.95), 0.026, materials.steel)
	G.rod(crutch_axis, "ActualLoadBar", Vector3(-0.15, -0.12, 0.95), Vector3(0.15, -0.12, 0.95), 0.035, materials.steel)
	var at: Vector3 = Vector3(0.0, -0.27, 0.95)
	mark(crutch_axis, "STORE_INTERNAL", at, "one250kg visual; actual suspension lug is +0.15m above store centre")
	mark(crutch_axis, "BOMB_RELEASE", at, "moving reference follows crutch; actual release is BOMB01 responsibility")
	bomb_visual = G.group(crutch_axis, "Single250kgDisplayBomb", at)
	var profile: Array = [[-0.86, 0.0, 0.008, 0.008, 0.008], [-0.65, 0.0, 0.12, 0.12, 0.12],
		[-0.45, 0.0, 0.155, 0.155, 0.155], [0.35, 0.0, 0.155, 0.155, 0.155], [0.61, 0.0, 0.07, 0.07, 0.07], [0.84, 0.0, 0.06, 0.06, 0.06]]
	G.part(bomb_visual, "SimplifiedCase", G.shell(profile, -0.86, 0.84, Color("525c47"), Color("525c47")), materials.skin)
	G.box(bomb_visual, "TailFinVertical", Vector3(0.015, 0.36, 0.30), Vector3(0.0, 0.0, 0.69), materials.bomb)
	G.box(bomb_visual, "TailFinHorizontal", Vector3(0.36, 0.015, 0.30), Vector3(0.0, 0.0, 0.69), materials.bomb)
	G.rod(bomb_visual, "SuspensionLug", Vector3(0.0, 0.14, 0.0), Vector3(0.0, 0.18, 0.0), 0.035, materials.steel)

func _build_rear_gun() -> void:
	var root: Node3D = G.group(damage_modules.center, "RearGunInstallation")
	# A compact ring supported from the rear cockpit sides, not a floating gun.
	for side: float in [-1.0, 1.0]:
		G.rod(root, "RingSupport" + str(side), Vector3(side * 0.31, 0.36, 0.37), Vector3(side * 0.31, 0.68, 0.37), 0.026, materials.frame)
	G.rod(root, "RingCrossmember", Vector3(-0.31, 0.68, 0.37), Vector3(0.31, 0.68, 0.37), 0.026, materials.frame)
	rear_train = G.group(root, "TrainAxis", Vector3(0.0, 0.71, 0.37))
	rear_elevation = G.group(rear_train, "ElevationAxis")
	G.box(rear_elevation, "Type1_MG15_Receiver", Vector3(0.08, 0.09, 0.31), Vector3(0.0, 0.02, 0.05), materials.dark)
	G.rod(rear_elevation, "SingleBarrel", Vector3(0.0, 0.03, 0.15), Vector3(0.0, 0.03, 0.86), 0.023, materials.dark)
	for side: float in [-1.0, 1.0]:
		G.rod(rear_elevation, "SaddleDrum" + str(side), Vector3(side * 0.09, 0.11, -0.035), Vector3(side * 0.09, 0.11, 0.07), 0.085, materials.dark)
	G.rod(rear_elevation, "PistolGrip", Vector3(0.0, -0.02, -0.035), Vector3(0.0, -0.15, -0.08), 0.025, materials.prop)
	mark(rear_elevation, "MUZZLE_TYPE1_REAR", Vector3(0.0, 0.03, 0.86), "single7.92mm Type1, photo-estimated mount; local +Z bore", Vector3.BACK)
	mark(rear_train, "REAR_TRAIN_AXIS", Vector3.ZERO, "presentation range only; true firing/self-occlusion is BOMB01")

func _build_hook() -> void:
	hook_axis = G.group(damage_modules.center, "HookAxis", Vector3(0.0, -0.27, 2.25))
	G.rod(hook_axis, "SimpleHookShank", Vector3.ZERO, Vector3(0.0, 0.05, 0.92), 0.022, materials.steel)
	G.rod(hook_axis, "HookToe", Vector3(0.0, 0.05, 0.92), Vector3(0.0, 0.0, 0.88), 0.030, materials.steel)
	mark(hook_axis, "HOOK_TIP", Vector3(0.0, 0.0, 0.88), "0.92m approximate hook; endpoint follows actual local +X axis")
	mark(hook_axis, "HOOK_PIVOT", Vector3.ZERO, "recess simplified; support attaches inside aft cockpit")

func _wing_roundel(parent: Node3D, side: float, x: float, z: float, radius: float) -> void:
	for upper: bool in [true, false]:
		var st: SurfaceTool = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring: int in range(8):
			for i: int in range(48):
				var a: float = float(i) * TAU / 48.0; var b: float = float(i + 1) * TAU / 48.0
				var points: Array[Vector3] = []
				for p: Vector2 in [Vector2(cos(a), sin(a)) * radius * float(ring) / 8.0, Vector2(cos(b), sin(b)) * radius * float(ring) / 8.0,
					Vector2(cos(b), sin(b)) * radius * float(ring + 1) / 8.0, Vector2(cos(a), sin(a)) * radius * float(ring + 1) / 8.0]:
					p += Vector2(x, z)
					var s: Array = G.sample(WING, p.x)
					var at: Vector3 = G.wing_point(WING, p.x, (p.y - float(s[1])) / float(s[2]), upper)
					at.x *= side; at.y += 0.012 if upper else -0.012; points.append(at)
				G.quad(st, points[0], points[1], points[2], points[3], Vector3.UP if upper else Vector3.DOWN)
		G.part(parent, "Hinomaru" + str(upper), G.finish(st), materials.red)

func apply_visual_state(input: Dictionary) -> void:
	# Inputs are snapshots; caller owns time, transition rate, ammunition and health.
	for key: String in ["gear", "hook", "flap", "brake", "bay", "crutch"]:
		if input.has(key) and (input[key] is float or input[key] is int) and is_finite(float(input[key])):
			state[key] = clampf(float(input[key]), 0.0, 1.0)
	for key: String in ["bomb_visible", "rear_gun"]:
		if input.has(key) and input[key] is bool:
			state[key] = input[key]
	if input.has("propeller_rad") and is_finite(float(input.propeller_rad)):
		state.propeller_rad = fmod(float(input.propeller_rad), TAU)
	propeller.rotation.z = state.propeller_rad
	for i: int in range(gear_axes.size()):
		var axis: Node3D = gear_axes[i]
		axis.visible = float(state.gear) > 0.005
		if i < 2:
			axis.rotation.z = -float(axis.get_meta("retract_side")) * (1.0 - float(state.gear)) * PI * 0.5
		else:
			axis.rotation.x = -(1.0 - float(state.gear)) * PI * 0.5
	for door: Node3D in closed_gear_doors:
		door.visible = float(state.gear) < 0.005
	for id: String in surfaces:
		var axis: Node3D = surfaces[id]
		if id.begins_with("flap"):
			axis.rotation.x = deg_to_rad(40.0) * float(state.flap)
			# Modest aft travel stands in for Fowler rails, not an invented hinge-only flap.
			if not axis.has_meta("base_z"):
				axis.set_meta("base_z", axis.position.z)
			axis.position.z = float(axis.get_meta("base_z")) + 0.12 * float(state.flap)
		elif id.begins_with("brake"):
			axis.rotation.x = deg_to_rad(70.0) * (float(state.brake) if float(state.flap) <= 0.001 else 0.0)
		elif input.has(id + "_rad") and is_finite(float(input[id + "_rad"])):
			if id == "rudder": axis.rotation.y = clampf(float(input[id + "_rad"]), -0.35, 0.35)
			else: axis.rotation.x = clampf(float(input[id + "_rad"]), -0.35, 0.35)
	hook_axis.visible = float(state.hook) > 0.001
	hook_axis.rotation.x = deg_to_rad(24.0) * float(state.hook)
	for i: int in range(bay_doors.size()):
		bay_doors[i].rotation.z = (1.0 if i == 0 else -1.0) * deg_to_rad(95.0) * float(state.bay)
	crutch_axis.rotation.x = deg_to_rad(34.0) * minf(float(state.crutch), float(state.bay))
	bomb_visual.visible = bool(state.bomb_visible) and float(state.bay) > 0.15
	rear_cover.visible = not bool(state.rear_gun)
	rear_train.visible = bool(state.rear_gun)
	var yaw: float = float(input.get("rear_yaw_rad", 0.0))
	var elevation: float = float(input.get("rear_elevation_rad", deg_to_rad(35.0)))
	if is_finite(yaw): rear_train.rotation.y = clampf(yaw, -0.70, 0.70)
	if is_finite(elevation): rear_elevation.rotation.x = -clampf(elevation, deg_to_rad(20.0), deg_to_rad(70.0))

func apply_damage_state(attached: Dictionary) -> void:
	for id: String in damage_modules:
		if attached.has(id) and attached[id] is bool:
			damage_modules[id].visible = attached[id]

func get_parked_transform() -> Transform3D:
	# Tangency of parallel wheel discs: (tail-main).rotated(X,theta).y = r_tail-r_main.
	# Not a transform of the local bottom vertex; circular tyre tangency stays vertical.
	var delta: Vector3 = TAIL_WHEEL_CENTER_M - MAIN_WHEEL_CENTER_M
	var pitch: float = atan2(delta.y, delta.z) - asin((TAIL_WHEEL_RADIUS_M - MAIN_WHEEL_RADIUS_M) / Vector2(delta.y, delta.z).length())
	var axes: Basis = Basis(Vector3.RIGHT, pitch)
	var height: float = MAIN_WHEEL_RADIUS_M - (axes * MAIN_WHEEL_CENTER_M).y
	return Transform3D(axes, Vector3(0.0, height, 0.0))

func set_flight_configuration() -> void:
	apply_visual_state({"gear": 0.0, "hook": 0.0, "flap": 0.0, "brake": 0.0, "bay": 0.0, "crutch": 0.0, "rear_gun": false})

func set_landing_gear_deployed(deployed: bool) -> void:
	apply_visual_state({"gear": 1.0 if deployed else 0.0})

func set_arrestor_hook_deployed(deployed: bool) -> void:
	apply_visual_state({"hook": 1.0 if deployed else 0.0})
