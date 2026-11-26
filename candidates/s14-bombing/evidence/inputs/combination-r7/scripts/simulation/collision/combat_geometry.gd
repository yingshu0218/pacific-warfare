class_name CombatGeometry
extends RefCounted

## Slab sweep returns first fraction, including starts inside. No rendering physics.
static func segment_box(a: Vector3, b: Vector3, center: Vector3, half_size: Vector3) -> float:
	var p: Vector3 = a - center
	var d: Vector3 = b - a
	var near_t: float = 0.0
	var far_t: float = 1.0
	for axis: int in range(3):
		if absf(d[axis]) < 0.00000001:
			if absf(p[axis]) > half_size[axis]:
				return INF
		else:
			var t1: float = (-half_size[axis] - p[axis]) / d[axis]
			var t2: float = (half_size[axis] - p[axis]) / d[axis]
			near_t = maxf(near_t, minf(t1, t2))
			far_t = minf(far_t, maxf(t1, t2))
			if near_t > far_t:
				return INF
	return near_t

static func contains(point: Vector3, boxes: Array) -> bool:
	for box: Dictionary in boxes:
		var offset: Vector3 = point - SimData.vec3(box.center_m)
		var half_size: Vector3 = SimData.vec3(box.half_extents_m)
		if absf(offset.x) <= half_size.x and absf(offset.y) <= half_size.y and absf(offset.z) <= half_size.z:
			return true
	return false

static func masked(a: Vector3, b: Vector3, boxes: Array, excluded_part: String = "") -> bool:
	for box: Dictionary in boxes:
		if not excluded_part.is_empty() and box.get("part", "") == excluded_part:
			continue
		var t: float = segment_box(a, b, SimData.vec3(box.center_m), SimData.vec3(box.half_extents_m))
		if t < 0.99999:
			return true
	return false

## Exact relative translation; rotating OBB paths subdivide with conservative sag pad.
static func moving_boxes(a: Vector3, b: Vector3, start: Transform3D, finish: Transform3D, boxes: Array, radius: float = 0.0) -> Dictionary:
	var angle: float = start.basis.get_rotation_quaternion().angle_to(finish.basis.get_rotation_quaternion())
	var steps: int = maxi(1, int(ceil(angle / deg_to_rad(3.0))))
	var best: Dictionary = {"fraction": INF}
	for index: int in range(steps):
		var t0: float = float(index) / steps
		var t1: float = float(index + 1) / steps
		var local_a: Vector3 = start.interpolate_with(finish, t0).affine_inverse() * a.lerp(b, t0)
		var local_b: Vector3 = start.interpolate_with(finish, t1).affine_inverse() * a.lerp(b, t1)
		var pad: float = radius + maxf(local_a.length(), local_b.length()) * (1.0 - cos(angle / steps * 0.5))
		for box: Dictionary in boxes:
			var t: float = segment_box(local_a, local_b, SimData.vec3(box.center_m), SimData.vec3(box.half_extents_m) + Vector3.ONE * pad)
			var fraction: float = lerpf(t0, t1, t)
			if t <= 1.0 and fraction < float(best.fraction):
				best = {"fraction": fraction, "part_id": box.part, "armor_mm": float(box.get("armor_mm", 0.0)), "local_position_m": local_a.lerp(local_b, t)}
	return best

static func normal_for_box(point: Vector3, box: Dictionary) -> Vector3:
	var offset: Vector3 = point - SimData.vec3(box.center_m)
	var size: Vector3 = SimData.vec3(box.half_extents_m)
	var ratio: Vector3 = Vector3(absf(offset.x) / size.x, absf(offset.y) / size.y, absf(offset.z) / size.z)
	if ratio.y >= ratio.x and ratio.y >= ratio.z:
		return Vector3(0, signf(offset.y), 0)
	if ratio.x >= ratio.z:
		return Vector3(signf(offset.x), 0, 0)
	return Vector3(0, 0, signf(offset.z))
