class_name BombBallistics
extends RefCounted

## Unguided point mass. Constant effective Cd*A/m is an explicit approximation.
static func acceleration(position: Vector3, velocity: Vector3, gravity: float, drag_per_m: float) -> Vector3:
	return Vector3.DOWN*gravity - velocity*velocity.length()*drag_per_m*exp(-maxf(0.0,position.y)/8500.0)

## Prediction never sees an enemy UnitState, changes a round, or promises a hit.
static func predict(position: Vector3, velocity: Vector3, surface_y: float, ammo: AmmoDefinition, dt: float = 1.0/60.0) -> Dictionary:
	var point: Vector3 = position
	var speed: Vector3 = velocity
	var time: float = 0.0
	while time < ammo.max_lifetime_s:
		var a: Vector3 = acceleration(point,speed,ammo.gravity_mps2,ammo.drag_per_m)
		var next: Vector3 = point+speed*dt+a*(0.5*dt*dt)
		if next.y <= surface_y and point.y > surface_y:
			var fraction: float = (point.y-surface_y)/(point.y-next.y)
			return {"point":point.lerp(next,fraction),"time_s":time+dt*fraction}
		speed += a*dt
		point = next
		time += dt
	return {}
