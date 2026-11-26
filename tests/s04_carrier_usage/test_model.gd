extends "res://tests/fixtures/combat_test.gd"

var evidence: Dictionary = {}
const GEOMETRY: Script = preload("res://scripts/aircraft_geometry/f6f5_carrier_geometry.gd")

func local_min_y(mesh: MeshInstance3D, reference: Node3D) -> float:
	var to_reference: Transform3D = reference.global_transform.affine_inverse()*mesh.global_transform
	var result: float = INF
	for vertex: Vector3 in mesh.mesh.get_faces(): result = minf(result,(to_reference*vertex).y)
	return result

func point_on_mesh(point: Vector3, mesh: MeshInstance3D, reference: Node3D) -> bool:
	var pose: Transform3D = reference.global_transform.affine_inverse()*mesh.global_transform
	var faces: PackedVector3Array = mesh.mesh.get_faces()
	for i: int in range(0,faces.size(),3):
		var a: Vector3 = pose*faces[i]
		var ab: Vector3 = pose*faces[i+1]-a
		var ac: Vector3 = pose*faces[i+2]-a
		var normal: Vector3 = ab.cross(ac)
		if normal.length_squared() < .0000000001: continue
		normal = normal.normalized()
		if absf((point-a).dot(normal)) > .0001: continue
		var v: Vector3 = point-a
		var denom: float = ab.dot(ab)*ac.dot(ac)-ab.dot(ac)*ab.dot(ac)
		if absf(denom) < .0000000001: continue
		var u: float = (ac.dot(ac)*v.dot(ab)-ab.dot(ac)*v.dot(ac))/denom
		var w: float = (ab.dot(ab)*v.dot(ac)-ab.dot(ac)*v.dot(ab))/denom
		if u >= -.0001 and w >= -.0001 and u+w <= 1.0001: return true
	return false

func check_muzzles(view: AircraftAdapter) -> void:
	var definition: UnitDefinition = FIX.catalog().unit("us_f6f5_1944")
	for mount: MountSocket in definition.mounts:
		var point: Vector3 = mount.local_muzzle_transform(0,0.0,0.0).origin
		expect(view.muzzle_transform_local(str(mount.id),0).origin.distance_to(point) < .0001,"Accepted six gun positions are unchanged")

func run_test() -> void:
	var packed: PackedScene = load("res://scenes/units/aircraft/f6f5_flight.tscn")
	var first: AircraftAdapter = packed.instantiate() as AircraftAdapter
	var second: AircraftAdapter = packed.instantiate() as AircraftAdapter
	root.add_child(first); root.add_child(second)
	expect(first.model_root.position == Vector3(0,-2.30,0),"Accepted flight origin remains exactly -2.30m")
	check_muzzles(first)
	var clean: Dictionary = first.carrier_usage_local()
	evidence.clean = clean
	evidence["cpu_geometry"] = GEOMETRY.definition()
	expect((clean.hook_tip_m as Vector3).distance_to(GEOMETRY.configuration(false,false).hook_tip_flight_m) < .0001,"CPU stowed hook data matches actual model marker without renderer dependency")
	expect(not clean.gear_down and not clean.hook_down and clean.flap_angle_rad == 0,"No carrier_ops keeps ordinary air combat clean")
	expect(not clean.hook_available,"Stowed hook cannot catch a wire")
	for contact: Dictionary in clean.wheel_contacts.values(): expect(not contact.available,"Hidden wheels are not active support features")
	var requested: Dictionary = {"position_m":[7,11,-5],"rotation_rad":[.05,.4,-.1],"module_data":{"aircraft_motion":{"aileron_rad":.1,"elevator_rad":-.08},"carrier_ops":{"gear_down":true,"hook_down":true,"flaps_down":true}}}
	var before: Dictionary = requested.duplicate(true)
	first.apply_state(requested)
	expect(requested == before,"Presentation never mutates the actual input snapshot")
	var deployed: Dictionary = first.carrier_usage_local()
	evidence.free = deployed
	var expected: Dictionary = {"main_left":Vector3(-1.93,-1.43,-1.27),"main_right":Vector3(1.93,-1.43,-1.27),"tail":Vector3(0,-.45,4.52)}
	for id: String in expected:
		var contact: Dictionary = deployed.wheel_contacts[id]
		expect((contact.position_m as Vector3).distance_to(expected[id]) < .0001 and contact.available,"Revised tyre body-axis bottom matches actual candidate: "+id)
		var gear: Node3D = first.model_root.get("carrier_gear")[id]
		var tyre: MeshInstance3D = gear.get_node("Tail tyre" if id == "tail" else "Tyre") as MeshInstance3D
		expect(absf(local_min_y(tyre,first)-(contact.position_m as Vector3).y) < .0001,"Contact lies on the real batched tyre bottom: "+id)
		var host: Node3D = first.model_root.damage_parts[contact.host_part_id]
		expect(host.is_ancestor_of(gear),"Gear assembly follows its actual detachable host: "+id)
	var parked: Transform3D = GEOMETRY.parked_transform_flight()
	evidence["parked_free_hook_height_m"] = (parked*(deployed.hook_tip_m as Vector3)).y
	expect(deployed.hook_available and (parked*(deployed.hook_tip_m as Vector3)).y < -.10,"Free hook hangs below the revised three-tyre support plane in landing attitude")
	var hook: Node3D = first.model_root.get("arresting_hook")
	var on_shoe: bool = false
	for mesh: Node in hook.find_children("*","MeshInstance3D",true,false): on_shoe = on_shoe or point_on_mesh(deployed.hook_tip_m,mesh as MeshInstance3D,first)
	expect(on_shoe,"Hook contact Marker lies on a real visible batched hook-shoe triangle")
	for angle: float in [0.0,deg_to_rad(12),deg_to_rad(25),GEOMETRY.HOOK_DEFLECTION_LIMIT_RAD]:
		first.model_root.call("set_hook_deflection",angle)
		expect((first.carrier_usage_local().hook_tip_m as Vector3).distance_to(GEOMETRY.configuration(true,true,angle).hook_tip_flight_m) < .0001,"CPU contact-travel data matches actual model tip at "+str(angle))
	first.model_root.call("set_hook_deflection",0.0)
	expect((deployed.hook_tip_m as Vector3).z > 5.0 and absf((deployed.hook_tip_m as Vector3).z-4.4) > .4,"Actual hook tip replaces the unrelated prototype 4.4m offset")
	var flap_count: int = 0
	for surface: Node3D in first.model_root.animated_surfaces:
		if "flap" in str(surface.name).to_lower():
			flap_count += 1
			expect(absf(surface.basis.get_rotation_quaternion().get_angle()-deg_to_rad(35)) < .0001,"Four flap panels rotate 35 degrees about their own swept hinge through batching")
	expect(flap_count == 4,"Existing four flap sections retained")
	for cover: Node3D in first.model_root.get("closed_gear_covers"): expect(not cover.visible,"Lowered gear does not retain a closed bay-cover surface")
	expect(not second.carrier_usage_local().gear_down and not second.carrier_usage_local().hook_down,"Shared mesh cache has independent per-instance usage state")
	# This is a static contact constraint test, not an OPS landing claim. Solve
	# only the offered pivot travel in the revised circles-derived parked pose.
	var lo: float = 0.0; var hi: float = GEOMETRY.HOOK_DEFLECTION_LIMIT_RAD
	for i: int in 30:
		var angle: float = (lo+hi)*.5
		first.model_root.call("set_hook_deflection",angle)
		if (parked*(first.carrier_usage_local().hook_tip_m as Vector3)).y < .02: lo = angle
		else: hi = angle
	first.model_root.call("set_hook_deflection",hi)
	var constrained: Dictionary = first.carrier_usage_local()
	evidence.constrained = constrained
	expect(absf((parked*(constrained.hook_tip_m as Vector3)).y-.02) < .0001 and constrained.hook_deflection_rad > 0,"Contact travel lifts the shoe above the revised support plane without a visual aircraft offset")
	expect(first.position == Vector3(7,11,-5) and first.rotation.is_equal_approx(Vector3(.05,.4,-.1)),"A hook contact state does not reposition or rotate the aircraft")
	expect(not bool(first.model_root.call("set_hook_deflection",NAN)),"Non-finite hook input rejected")
	expect(not bool(first.model_root.call("set_flap_angle",INF)),"Non-finite flap input rejected")
	first.model_root.call("set_hook_deflection",99.0)
	expect(absf(float(first.carrier_usage_local().hook_deflection_rad)-GEOMETRY.HOOK_DEFLECTION_LIMIT_RAD) < .0001,"Finite hook contact travel is bounded")
	# Real existing ammunition detaches an extended wing; no renderer creates
	# a damage outcome and no gear remains on the empty fuselage installation.
	var arena: Dictionary = AircraftDamageFixture.arena("us_f6f5_1944")
	AircraftDamageFixture.shoot(arena,"wing_left",6)
	(arena.world as SimulationWorld).step_ticks(8)
	var target: UnitState = (arena.world as SimulationWorld).get_unit("target")
	var state: Dictionary = target.snapshot()
	state.module_data["carrier_ops"] = {"gear_down":true,"hook_down":true,"flaps_down":true}
	first.apply_state(state)
	expect(not first.carrier_usage_local().wheel_contacts.main_left.available and first.carrier_usage_local().wheel_contacts.main_right.available,"Real wing loss disables only its own wheel support")
	var wing_piece: Node3D = first.get_node("Debris_wing_left")
	expect(wing_piece.find_children("Main gear left","Node3D",true,false).size() == 1,"Detached wing carries its lowered strut and tyre exactly once")
	var tail_arena: Dictionary = AircraftDamageFixture.arena("us_f6f5_1944")
	AircraftDamageFixture.shoot(tail_arena,"structure",1,"us_406mm_mk8_ap")
	(tail_arena.world as SimulationWorld).step_ticks(8)
	state = (tail_arena.world as SimulationWorld).get_unit("target").snapshot()
	state.module_data["carrier_ops"] = {"gear_down":true,"hook_down":true,"flaps_down":true}
	first.apply_state(state)
	expect(not first.carrier_usage_local().wheel_contacts.tail.available and not first.carrier_usage_local().hook_available,"Real tail breakup disables both tailwheel and hook")
	expect(first.get_node("Debris_tail").find_children("Arresting hook pivot","Node3D",true,false).size() == 1,"Tail fragment owns the hook root and shoe with no floating duplicate")
	first.apply_state({"module_data":{}})
	expect(first.damage_statistics().fragment_nodes == 0 and not first.carrier_usage_local().gear_down and not first.carrier_usage_local().hook_down,"Reset/no-ops snapshot restores clean flight and removes fragments")
	check_muzzles(first)
	var zero_packed: PackedScene = load("res://scenes/units/aircraft/a6m5a_flight.tscn")
	var zero: AircraftAdapter = zero_packed.instantiate() as AircraftAdapter
	root.add_child(zero); zero.apply_state(requested)
	expect(zero.carrier_usage_local().is_empty() and not zero.model_root.landing_gear.visible,"A6M usage remains unchanged in the F6F-only candidate")
	first.free();second.free();zero.free()
	expect(AircraftAdapter.live_fragment_nodes == 0,"Candidate visual nodes clean up their global debris budget")
	evidence["checks"] = checks; evidence["failures"] = failures
	var output: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-carrier-usage/model.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(AircraftDamageFixture.json_data(evidence),"\t"));output.close()
	finish("S04 F6F carrier usage candidate")
