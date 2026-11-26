class_name AircraftFlightMath
extends RefCounted

## No Euler integration: transport an orthogonal flight/lift frame in world space.
static func frame(forward: Vector3, up_hint: Vector3) -> Basis:
	var f: Vector3 = forward.normalized()
	if f.length_squared() < 0.5:
		f = Vector3.FORWARD
	var up: Vector3 = up_hint - f * up_hint.dot(f)
	if up.length_squared() < 0.000001:
		up = Vector3.RIGHT - f * f.x
	up = up.normalized()
	var right: Vector3 = f.cross(up).normalized()
	return Basis(right, right.cross(f).normalized(), -f)

static func level_up(forward: Vector3, fallback: Vector3) -> Vector3:
	var up: Vector3 = Vector3.UP - forward * forward.y
	return up.normalized() if up.length_squared() > 0.008 else frame(forward, fallback).y

static func pitch(direction: Vector3) -> float:
	return atan2(direction.y, Vector2(direction.x, direction.z).length())

static func heading(direction: Vector3, fallback: float = 0.0) -> float:
	return atan2(-direction.x, -direction.z) if Vector2(direction.x,direction.z).length_squared() > 0.00001 else fallback

static func direction(heading_rad: float, pitch_rad: float) -> Vector3:
	return Vector3(-sin(heading_rad)*cos(pitch_rad),sin(pitch_rad),-cos(heading_rad)*cos(pitch_rad))

static func elevated(direction_hint: Vector3, elevation_rad: float, fallback: Vector3 = Vector3.FORWARD) -> Vector3:
	var flat: Vector3 = Vector3(direction_hint.x,0,direction_hint.z)
	if flat.length_squared() < 0.00001:
		flat = Vector3(fallback.x,0,fallback.z)
	if flat.length_squared() < 0.00001:
		flat = Vector3.FORWARD
	return flat.normalized()*cos(elevation_rad)+Vector3.UP*sin(elevation_rad)

static func signed_roll(from: Vector3, to: Vector3, forward: Vector3) -> float:
	return atan2(forward.dot(from.cross(to)),clampf(from.dot(to),-1.0,1.0))
