class_name CarrierWreckSettling
extends RefCounted

## Overdamped gravity settling, only after existing DM has declared a wreck.
## Exact surviving mesh support and a declared coarse mass distribution decide
## tipping. No new breakage, propeller hiding, animation pose or rigid-body scene.
const CONTACT_TOLERANCE_M: float = 0.008
const STABILITY_TOLERANCE_M: float = 0.015
const MAX_RATE_RADPS: float = 0.35

static func mass_center(unit: UnitState, geometry: CarrierAirframeGeometry, parameters: Dictionary) -> Vector3:
	var estimate: Dictionary = parameters.wreck_mass_estimate
	var total: float = 0.0
	var weighted: Vector3 = Vector3.ZERO
	for host: String in estimate.parts:
		if not geometry.present(host,unit.module_data.damage): continue
		var row: Dictionary = estimate.parts[host]
		var mass: float = float(estimate.dry_mass_kg)*float(row.fraction)
		total += mass; weighted += mass*SimData.vec3(row.center_flight_m)
	var fuel: float = maxf(0.0,float(unit.module_data.aircraft_motion.fuel_kg))
	total += fuel; weighted += fuel*SimData.vec3(estimate.fuel_center_flight_m)
	return weighted/maxf(total,0.001)

static func floor_contacts(origin: Vector3, basis: Basis, cloud: PackedVector3Array, deck: CarrierDeckGeometry) -> Dictionary:
	var height: float = float(deck.data.flight_deck.height_m)
	var target_y: float = -INF
	for point: Vector3 in cloud:
		var relative: Vector3 = basis*point
		if height-relative.y <= target_y: continue
		var surface: Dictionary = deck.surface(Vector2(origin.x+relative.x,origin.z+relative.z))
		if surface.supported and absf(float(surface.height_m)-height) < 0.02: target_y = height-relative.y
	if not is_finite(target_y): return {"available":false}
	var points: PackedVector2Array = []
	for point: Vector3 in cloud:
		var relative: Vector3 = basis*point
		if target_y+relative.y-height > CONTACT_TOLERANCE_M: continue
		var position: Vector2 = Vector2(origin.x+relative.x,origin.z+relative.z)
		var surface: Dictionary = deck.surface(position)
		if surface.supported and absf(float(surface.height_m)-height) < 0.02: points.append(position)
	var polygon: PackedVector2Array = Geometry2D.convex_hull(points) if points.size() >= 3 else points
	return {"available":not points.is_empty(),"target_y":target_y,"points":points,"polygon":polygon,"height_m":height}

static func stability(origin: Vector3, basis: Basis, center: Vector3, gravity: Vector3, floor: Dictionary) -> Dictionary:
	var com: Vector3 = origin+basis*center
	var projection: Vector3 = com-gravity*((com.y-float(floor.height_m))/gravity.y)
	var point: Vector2 = Vector2(projection.x,projection.z)
	var polygon: PackedVector2Array = floor.polygon
	var nearest: Vector2 = polygon[0]
	var inside: bool = false
	var span: float = 0.0
	for i: int in polygon.size():
		var a: Vector2 = polygon[i]; var b: Vector2 = polygon[(i+1)%polygon.size()]
		var candidate: Vector2 = Geometry2D.get_closest_point_to_segment(point,a,b)
		if point.distance_squared_to(candidate) < point.distance_squared_to(nearest): nearest = candidate
		if (a.y > point.y) != (b.y > point.y) and point.x < float(a.x)+(float(b.x)-float(a.x))*(float(point.y)-float(a.y))/(float(b.y)-float(a.y)): inside = not inside
		for other: Vector2 in polygon: span = maxf(span,a.distance_to(other))
	var distance: float = 0.0 if inside else point.distance_to(nearest)
	return {"center_of_mass_local_m":com,"gravity_projection_xz_m":point,"pivot_m":Vector3(nearest.x,float(floor.height_m),nearest.y),"projection_error_m":distance,"support_span_m":span,"stable":distance <= STABILITY_TOLERANCE_M and span > 0.15,"support_polygon_xz_m":polygon,"contact_count":floor.points.size()}

static func step(unit: UnitState, ship: UnitState, support: Dictionary, operations: CarrierOperations, dt: float) -> void:
	var origin: Vector3 = support.local_m
	var basis: Basis = Basis.from_euler(support.local_rotation_rad)
	var state: Dictionary = operations.roster[unit.id]
	var phase: float = float(unit.module_data.aircraft_motion.propeller_phase_rad)
	var center: Vector3 = mass_center(unit,operations.airframe,operations.parameters)
	var cloud: PackedVector3Array = operations.airframe.resting_cloud(basis,state,unit.module_data.damage,phase)
	var floor: Dictionary = floor_contacts(origin,basis,cloud,operations.deck)
	if not floor.available: support["settling_stable"] = false; return
	var vertical: float = float(support.get("settle_velocity_mps",0.0))
	if origin.y > float(floor.target_y)+0.000001:
		vertical -= AircraftDamageMotion.G*dt
		origin.y = maxf(float(floor.target_y),origin.y+vertical*dt)
	if origin.y <= float(floor.target_y)+0.000001:
		origin.y = float(floor.target_y); vertical = 0.0
		var gravity: Vector3 = ship.world_transform().basis.inverse()*(Vector3.DOWN*AircraftDamageMotion.G)
		var contact: Dictionary = stability(origin,basis,center,gravity,floor)
		if not contact.stable:
			var pivot: Vector3 = contact.pivot_m
			var torque: Vector3 = ((origin+basis*center)-pivot).cross(gravity)
			# Declared radius of gyration and damping approximate a heavy damaged
			# airframe. Rotation follows decreasing gravitational potential.
			var rate: Vector3 = Vector3(torque.x,0,torque.z)/float(operations.parameters.wreck_mass_estimate.overdamped_inertia_m2ps)
			rate = rate.limit_length(MAX_RATE_RADPS)
			var angle: float = rate.length()*dt
			if angle > 0.00000001:
				var energy: float = -(origin+basis*center).dot(gravity)
				for attempt: int in 10:
					var rotation: Basis = Basis(rate.normalized(),angle)
					var next_basis: Basis = (rotation*basis).orthonormalized()
					var next_origin: Vector3 = pivot+rotation*(origin-pivot)
					var next_cloud: PackedVector3Array = operations.airframe.resting_cloud(next_basis,state,unit.module_data.damage,phase)
					var next_floor: Dictionary = floor_contacts(next_origin,next_basis,next_cloud,operations.deck)
					if next_floor.available:
						next_origin.y = float(next_floor.target_y)
						if -(next_origin+next_basis*center).dot(gravity) <= energy+0.000001:
							origin = next_origin; basis = next_basis; floor = next_floor; break
					angle *= 0.5
		var final_contact: Dictionary = stability(origin,basis,center,gravity,floor)
		final_contact["minimum_mesh_clearance_m"] = origin.y-float(floor.target_y)
		support["settling_diagnostics"] = final_contact
		support["settling_stable"] = final_contact.stable
	else: support["settling_stable"] = false
	support["settle_velocity_mps"] = vertical
	support.local_m = origin
	support.local_rotation_rad = basis.get_euler()
