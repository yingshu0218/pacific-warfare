class_name SimData
extends RefCounted

## Coordinates: metres, +X starboard/right, +Y up, -Z forward; angles radians.
static func vec3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 and finite_number(value[0]) and finite_number(value[1]) and finite_number(value[2])

static func pure_data(value: Variant) -> bool:
	if value is Object or value is Callable or value is Signal:
		return false
	if value is float:
		return is_finite(value)
	if value is Vector3:
		return value.is_finite()
	if value is Array:
		for item: Variant in value:
			if not pure_data(item):
				return false
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not pure_data(value[key]):
				return false
	return true

static func valid_id(value: Variant) -> bool:
	if not value is String or value.is_empty():
		return false
	for character: String in value:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:-":
			return false
	return true
