class_name CarrierDeckGeometry
extends RefCounted

## The same CV01 polygons/elevator heights drive support and visual equipment.
const DECK_PATH: String = "res://naval/essex_cv9_1944_04_15/data/deck.json"
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
var elevators: Dictionary = {}

func _init() -> void:
	for row: Dictionary in data.elevators:
		elevators[row.id] = float(row.upper_height_m)

func polygon(rows: Array) -> PackedVector2Array:
	var result: PackedVector2Array = []
	for row: Array in rows: result.append(Vector2(float(row[0]), float(row[1])))
	return result

func contains(point: Vector2, rows: Array) -> bool:
	# Same CV01 vertices, double-precision horizontal crossings. Godot 4.7.2's
	# diagonal-ray predicate misclassifies (-3,-47.0342865) inside this polygon.
	# Do not dither the aircraft pose or enlarge the deck to evade that defect.
	var inside: bool = false
	for i: int in rows.size():
		var a: Array = rows[i]; var b: Array = rows[(i+1)%rows.size()]
		var ax: float = float(a[0]); var az: float = float(a[1])
		var bx: float = float(b[0]); var bz: float = float(b[1])
		var cross: float = (float(point.x)-ax)*(bz-az)-(float(point.y)-az)*(bx-ax)
		if absf(cross) < 0.00001 and float(point.x) >= minf(ax,bx)-0.000001 and float(point.x) <= maxf(ax,bx)+0.000001 and float(point.y) >= minf(az,bz)-0.000001 and float(point.y) <= maxf(az,bz)+0.000001: return true
		if (az > float(point.y)) != (bz > float(point.y)):
			var edge_x: float = ax+(bx-ax)*(float(point.y)-az)/(bz-az)
			if float(point.x) < edge_x: inside = not inside
	return inside

func surface(point: Vector2) -> Dictionary:
	for row: Dictionary in data.elevators:
		if absf(point.x-float(row.center_xz_m[0])) <= float(row.size_xz_m[0])*0.5 and absf(point.y-float(row.center_xz_m[1])) <= float(row.size_xz_m[1])*0.5:
			return {"supported":true, "height_m":elevators[row.id], "id":row.id}
	if contains(point,data.flight_deck.boundary_xz_m):
		return {"supported":true, "height_m":data.flight_deck.height_m, "id":"flight_deck"}
	return {"supported":false}

func footprint_reason(at: Vector3, yaw: float, span: float = 13.056, length: float = 10.236) -> String:
	# Conservative full unfolded envelope, including edge midpoints; no point-only
	# clearance and no scaling aircraft to fit an elevator.
	for x: float in [-span*0.5, 0.0, span*0.5]:
		for z: float in [-length*0.5, 0.0, length*0.5]:
			var p: Vector3 = at + Basis(Vector3.UP,yaw)*Vector3(x,0,z)
			var hit: Dictionary = surface(Vector2(p.x,p.z))
			if not hit.supported or absf(float(hit.height_m)-float(data.flight_deck.height_m)) > 0.02: return "unsupported_envelope"
			for obstacle: Dictionary in data.obstacles:
				if contains(Vector2(p.x,p.z),obstacle.polygon_xz_m): return "deck_obstacle:"+str(obstacle.id)
	return ""

static func velocity_at(ship: UnitState, local: Vector3, angular_velocity: Vector3) -> Vector3:
	return ship.velocity_mps + angular_velocity.cross(ship.world_transform().basis*local)
