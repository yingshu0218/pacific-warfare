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

func surface(point: Vector2) -> Dictionary:
	for row: Dictionary in data.elevators:
		if absf(point.x-float(row.center_xz_m[0])) <= float(row.size_xz_m[0])*0.5 and absf(point.y-float(row.center_xz_m[1])) <= float(row.size_xz_m[1])*0.5:
			return {"supported":true, "height_m":elevators[row.id], "id":row.id}
	if Geometry2D.is_point_in_polygon(point, polygon(data.flight_deck.boundary_xz_m)):
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
				if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon(obstacle.polygon_xz_m)): return "deck_obstacle:"+str(obstacle.id)
	return ""

static func velocity_at(ship: UnitState, local: Vector3, angular_velocity: Vector3) -> Vector3:
	return ship.velocity_mps + angular_velocity.cross(ship.world_transform().basis*local)

static func contact_points(gear_down: bool) -> Array[Vector3]:
	# Existing generated F6F geometry, flight origin = raw origin - (0,2.30,0).
	# Wheel tyre bottoms: _add_main_gear_pair / _add_tailwheel. Gear-up first
	# feature conservatively uses the rotating prop disc, not imaginary wheels.
	if gear_down: return [Vector3(-1.93,-2.30,-0.09),Vector3(1.93,-2.30,-0.09),Vector3(0,-2.30,4.52)]
	return [Vector3(0,-1.775,-4.68),Vector3(-1.995,0.22,-4.68),Vector3(1.995,0.22,-4.68)]
