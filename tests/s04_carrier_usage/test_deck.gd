extends "res://tests/fixtures/combat_test.gd"

const GEOMETRY: Script = preload("res://scripts/aircraft_geometry/f6f5_carrier_geometry.gd")
var records: Array[Dictionary] = []

func run_test() -> void:
	var definition: Dictionary = GEOMETRY.definition()
	expect(definition.gear_up_contact_proxy.radius_m == 1.995,"CPU gear-up proxy retains the actual 3.99m swept propeller disc")
	expect(GEOMETRY.configuration(true,true,NAN).is_empty(),"CPU geometry rejects non-finite contact state")
	var carrier_scene: PackedScene = load("res://naval/essex_cv9_1944_04_15/essex.tscn")
	var carrier: Node3D = carrier_scene.instantiate() as Node3D
	root.add_child(carrier)
	carrier.call("apply_state",{"position_m":Vector3(81,1.5,-230),"rotation_rad":Vector3(.03,.4,-.02)})
	var packed: PackedScene = load("res://scenes/units/aircraft/f6f5_flight.tscn")
	var aircraft: AircraftAdapter = packed.instantiate() as AircraftAdapter
	root.add_child(aircraft)
	var parked: Transform3D = GEOMETRY.parked_transform_flight()
	var relative: Transform3D = Transform3D(Basis(Vector3.UP,.15),Vector3(-3,15.85,75))*parked
	var normal: Vector3 = relative.basis.inverse()*Vector3.UP
	expect(parked.basis.get_euler().x > deg_to_rad(8) and parked.basis.get_euler().x < deg_to_rad(12),"Three real tyre circles solve a nose-up parked pose; pitch=0 is withdrawn")
	var propeller_centre: Vector3 = parked*(definition.gear_up_contact_proxy.center_flight_m as Vector3)
	var disc_normal: Vector3 = parked.basis*Vector3.FORWARD
	var disc_low: float = propeller_centre.y-float(definition.gear_up_contact_proxy.radius_m)*sqrt(1.0-pow(disc_normal.dot(Vector3.UP),2))
	expect(disc_low > .15,"Entire rotating propeller disc clears the three-tyre support plane without shrinking the aircraft")
	var pose: Transform3D = carrier.global_transform*relative
	aircraft.apply_state({"position_m":pose.origin,"rotation_rad":pose.basis.get_euler(),"module_data":{"carrier_ops":{"gear_down":true,"hook_down":false,"flaps_down":false}}})
	for id: String in aircraft.carrier_usage_local(normal).wheel_contacts:
		var point: Vector3 = aircraft.carrier_usage_local(normal).wheel_contacts[id].position_m
		var deck_local: Vector3 = carrier.global_transform.affine_inverse()*(aircraft.global_transform*point)
		var hit: Dictionary = carrier.call("deck_surface_at",Vector2(deck_local.x,deck_local.z))
		expect(hit.supported and absf(deck_local.y-float(hit.height_m)) < .0001,"Actual tyre follows complete tilted carrier pose and CV01 top surface: "+id)
		var tyre: MeshInstance3D = aircraft.model_root.get("carrier_tyres")[id] as MeshInstance3D
		var to_deck: Transform3D = carrier.global_transform.affine_inverse()*tyre.global_transform
		var minimum: float = INF
		for vertex: Vector3 in tyre.mesh.get_faces(): minimum = minf(minimum,(to_deck*vertex).y)
		expect(minimum-float(hit.height_m) >= -.001 and minimum-float(hit.height_m) < .006,"Simplified 20-segment tyre mesh agrees with circular support within 6mm: "+id)
		records.append({"contact_id":id,"aircraft_local_m":point,"deck_local_m":deck_local,"surface":hit})
	var deck: Dictionary = carrier.call("deck_definition")
	var boundary: PackedVector2Array = PackedVector2Array()
	for row: Array in deck.flight_deck.boundary_xz_m: boundary.append(Vector2(float(row[0]),float(row[1])))
	for x: float in [-6.528,0.0,6.528]:
		for z: float in [-5.118,0.0,5.118]:
			var corner: Vector3 = relative*Vector3(x,0,z)
			expect(Geometry2D.is_point_in_polygon(Vector2(corner.x,corner.z),boundary),"Unscaled full wing/length footprint stays within the actual CV01 boundary")
	# Contact constraint is supplied by the fixture, never by the visual model.
	var current: Transform3D = aircraft.global_transform
	var flap_clearances: Dictionary = {}
	for angle_deg: float in [35.0,50.0]:
		aircraft.model_root.call("set_flap_angle",deg_to_rad(angle_deg))
		var values: Dictionary = {}
		for surface: Node3D in aircraft.model_root.animated_surfaces:
			if "flap" not in str(surface.name).to_lower(): continue
			var minimum: float = INF
			for node: Node in surface.find_children("*","MeshInstance3D",true,false):
				var mesh: MeshInstance3D = node as MeshInstance3D
				var to_deck: Transform3D = carrier.global_transform.affine_inverse()*mesh.global_transform
				for vertex: Vector3 in mesh.mesh.get_faces(): minimum = minf(minimum,(to_deck*vertex).y)
			var clearance: float = minimum-float(deck.flight_deck.height_m)
			values[str(surface.name)] = clearance
			expect(clearance > .02,"Actual "+str(angle_deg)+"-degree flap triangles clear the CV01 top in the tyre-supported pose: "+str(surface.name))
		flap_clearances[str(angle_deg)] = values
	aircraft.model_root.call("set_flaps_deployed",true)
	aircraft.model_root.call("set_arresting_hook_deployed",true)
	var low: float = 0.0
	var high: float = GEOMETRY.HOOK_DEFLECTION_LIMIT_RAD
	for i: int in 30:
		var middle: float = (low+high)*.5
		aircraft.model_root.call("set_hook_deflection",middle)
		var point: Vector3 = carrier.global_transform.affine_inverse()*(aircraft.global_transform*(aircraft.carrier_usage_local().hook_tip_m as Vector3))
		if point.y < float(deck.flight_deck.height_m)+.02: low = middle
		else: high = middle
	var constrained: Dictionary = aircraft.carrier_usage_local(normal)
	var hook_point: Vector3 = carrier.global_transform.affine_inverse()*(aircraft.global_transform*(constrained.hook_tip_m as Vector3))
	expect(absf(hook_point.y-float(deck.flight_deck.height_m)-.02) < .0001,"Existing aircraft origin stays fixed while supplied contact travel lifts the shoe to CV01 wire height")
	expect(aircraft.global_transform.is_equal_approx(current),"A presentation contact constraint never changes aircraft movement or placement")
	# A lowered elevator does not remain an imaginary surface at the old height.
	var elevator: Dictionary = deck.elevators[0]
	var at: Vector2 = Vector2(float(elevator.center_xz_m[0]),float(elevator.center_xz_m[1]))
	var moved: bool = carrier.call("apply_equipment_state",str(elevator.id),{"height_m":float(elevator.lower_height_m)})
	expect(moved,"Fixture uses the real CV01 equipment interface")
	var lowered: Dictionary = carrier.call("deck_surface_at",at)
	expect(lowered.supported and absf(float(lowered.height_m)-float(elevator.lower_height_m)) < .001 and absf(float(lowered.height_m)-float(deck.flight_deck.height_m)) > 7,"Current lowered elevator surface is distinct from flight-deck support")
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-carrier-usage/deck.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(AircraftDamageFixture.json_data({"scope":"Static actual CV01 installation and contact geometry; no claim of carrier operation execution.","checks":checks,"failures":failures,"contacts":records,"flap_clearances_m_by_degrees":flap_clearances,"hook_contact_flight":constrained,"hook_contact_deck_m":hook_point,"lowered_surface":lowered}),"\t"));file.close()
	aircraft.free();carrier.free()
	finish("S04 F6F CV01 installation candidate")
