class_name CombatFireControl
extends RefCounted

## First positive low-trajectory root. Constant gravity, no drag; not range tables.
static func intercept(origin: Vector3, inherited_velocity: Vector3, target: Vector3, target_velocity: Vector3, speed: float, gravity: float, lifetime: float) -> Dictionary:
	var r: Vector3 = target - origin
	var v: Vector3 = target_velocity - inherited_velocity
	if r.length() < 0.01 or speed <= 0.0:
		return {}
	var acceleration: Vector3 = Vector3.DOWN * gravity
	var lo: float = 0.0
	var hi: float = minf(lifetime, maxf(0.01, r.length() / (speed + v.length())))
	while _equation(r, v, acceleration, speed, hi) > 0.0:
		lo = hi
		hi = minf(lifetime, hi * 1.18 + 0.005)
		if hi <= lo:
			return {}
	# Safeguarded Newton solves common low-angle roots quickly; bisection retains bounds.
	var flight: float = (lo+hi)*.5
	var converged: bool = false
	for iteration: int in range(12):
		var offset: Vector3 = r+v*flight-acceleration*(.5*flight*flight)
		var residual: float = offset.length_squared()-speed*speed*flight*flight
		if absf(residual)<maxf(.25,offset.length_squared()*0.000001):
			converged=true
			break
		if residual>0:lo=flight
		else:hi=flight
		var derivative: float = 2.*offset.dot(v-acceleration*flight)-2.*speed*speed*flight
		var next: float = flight-residual/derivative if absf(derivative)>.00001 else (lo+hi)*.5
		flight=next if next>lo and next<hi else (lo+hi)*.5
	if not converged:
		for iteration: int in range(24):
			var middle: float = (lo+hi)*.5
			if _equation(r,v,acceleration,speed,middle)>0:lo=middle
			else:hi=middle
		flight=(lo+hi)*.5
	var direction: Vector3 = (r + v * flight - acceleration * (0.5 * flight * flight)).normalized()
	return {"direction": direction, "time_s": flight, "point_m": target + target_velocity * flight}

static func _equation(r: Vector3, v: Vector3, acceleration: Vector3, speed: float, t: float) -> float:
	return (r + v * t - acceleration * (0.5 * t * t)).length_squared() - speed * speed * t * t

static func scatter(direction: Vector3, radians: float, rng: RandomNumberGenerator) -> Vector3:
	var tangent: Vector3 = direction.cross(Vector3.UP)
	if tangent.length_squared() < 0.0001:
		tangent = Vector3.RIGHT
	tangent = tangent.normalized()
	var second: Vector3 = tangent.cross(direction).normalized()
	# Uniform disk, independent per barrel; no forced collision or target attraction.
	var radius: float = sqrt(rng.randf()) * tan(radians)
	var theta: float = rng.randf_range(-PI, PI)
	return (direction + radius * (cos(theta) * tangent + sin(theta) * second)).normalized()
