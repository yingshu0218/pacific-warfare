extends "res://tests/fixtures/combat_test.gd"

var records: Array[Dictionary] = []

func lower_mesh_y(point: Vector3, vertices: PackedVector3Array, indices: PackedInt32Array) -> float:
	var result: float = INF
	for i: int in range(0,indices.size(),3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i+1]]
		var c: Vector3 = vertices[indices[i+2]]
		var denominator: float = (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(denominator) < .0000001: continue
		var wa: float = ((b.z-c.z)*(point.x-c.x)+(c.x-b.x)*(point.z-c.z))/denominator
		var wb: float = ((c.z-a.z)*(point.x-c.x)+(a.x-c.x)*(point.z-c.z))/denominator
		var wc: float = 1-wa-wb
		if minf(wa,minf(wb,wc)) >= -.00001: result = minf(result,wa*a.y+wb*b.y+wc*c.y)
	return result

func check_closed_gear_covers(definition_id: String) -> void:
	var builder: PacificAircraftBuilder = (AircraftAdapter.HELLCAT if definition_id == "us_f6f5_1944" else AircraftAdapter.ZERO).new() as PacificAircraftBuilder
	builder.flight_simplified = true
	root.add_child(builder)
	for part_id: String in ["wing_left","wing_right"]:
		var wing: Node3D = builder.damage_parts[part_id]
		var covers: Array[Node] = wing.find_children("Main gear bay cover *","MeshInstance3D",true,false)
		expect(covers.size() == 1,"Each retracted gear cover belongs to its detachable wing, never fuselage")
		if covers.is_empty(): continue
		var skin: MeshInstance3D = wing.get_child(0) as MeshInstance3D
		var arrays: Array = skin.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for index: int in vertices.size(): vertices[index] = skin.global_transform*vertices[index]
		var cover: MeshInstance3D = covers[0] as MeshInstance3D
		var cover_vertices: PackedVector3Array = cover.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var closest: float = INF
		var farthest: float = 0
		for index: int in range(0,cover_vertices.size(),8):
			var point: Vector3 = cover.global_transform*cover_vertices[index]
			var underside: float = lower_mesh_y(point,vertices,arrays[Mesh.ARRAY_INDEX])
			var gap: float = underside-point.y
			closest = minf(closest,gap)
			farthest = maxf(farthest,gap)
		expect(closest >= .0005 and farthest < .014,"Closed cover is flush below actual wing triangles (0.5–14mm), not hanging below airfoil: "+str([closest,farthest]))
	builder.free()

func run_test() -> void:
	var config: CombatConfig = FIX.config()
	for definition_id: String in ["us_f6f5_1944","jp_a6m5a_1944"]:
		check_closed_gear_covers(definition_id)
		var definition: UnitDefinition = FIX.catalog().unit(definition_id)
		var scene: PackedScene = load(definition.model_scene)
		var first: AircraftAdapter = scene.instantiate() as AircraftAdapter
		var second: AircraftAdapter = scene.instantiate() as AircraftAdapter
		root.add_child(first)
		root.add_child(second)
		var healthy_mesh_count: int = first.find_children("*","MeshInstance3D",true,false).size()
		expect(first.model_root.damage_parts.size() == 3 and healthy_mesh_count < 90,definition_id+" batches survive within exactly three detachable groups")
		for part_id: String in first.model_root.damage_parts:
			var group: Node3D = first.model_root.damage_parts[part_id]
			var anchor: Vector3 = (first.global_transform.affine_inverse()*group.global_transform).origin
			expect(anchor.distance_to(SimData.vec3(config.unit_profile(definition_id).aircraft_damage.anchors_m[part_id])) < .00001,"Visual pivot matches authoritative simulation installation anchor")
		var side_gun_count: int = 3 if definition_id == "us_f6f5_1944" else 1
		for part_id: String in ["wing_left","wing_right"]:
			var wing: Node3D = first.model_root.damage_parts[part_id]
			var markers: Array[Node] = wing.find_children("*","Marker3D",true,false)
			expect(markers.size() == side_gun_count,"Every same-side gun/muzzle belongs to the detachable wing")
			var ailerons: int = 0
			for surface: Node3D in first.model_root.animated_surfaces:
				if wing.is_ancestor_of(surface) and "aileron" in str(surface.name).to_lower(): ailerons += 1
			expect(ailerons == 1,"Aileron belongs to its own wing group")
		# A real hit drives model visibility; this is not a manually-authored damage pose.
		var a: Dictionary = AircraftDamageFixture.arena(definition_id)
		AircraftDamageFixture.shoot(a,"wing_left",6)
		var world: SimulationWorld = a.world
		for i: int in 8: world.step_ticks(1)
		var target: UnitState = world.get_unit("target")
		first.apply_state(target.snapshot())
		expect(not (first.model_root.damage_parts.wing_left as Node3D).visible and (second.model_root.damage_parts.wing_left as Node3D).visible,"Damaged instance hides only its own wing, untouched instance retains geometry")
		expect(first.damage_statistics().fragment_nodes == 1 and second.damage_statistics().fragment_nodes == 0,"Exactly one private fragment node; shared mesh has no shared damage state")
		var piece: Dictionary = target.module_data.damage.aircraft.fragments[0]
		var fragment: Node3D = first.get_node("Debris_wing_left")
		expect(fragment.global_position.distance_to(piece.position_m) < .001 and fragment.global_basis.is_equal_approx(Basis.from_euler(piece.rotation_rad)),"Detached model consumes exact world pose from simulation")
		var original_meshes: Array[Node] = (first.model_root.damage_parts.wing_left as Node3D).find_children("*","MeshInstance3D",true,false)
		var detached_meshes: Array[Node] = fragment.find_children("*","MeshInstance3D",true,false)
		var same_resources: bool = original_meshes.size() == detached_meshes.size()
		for index: int in original_meshes.size():
			same_resources = same_resources and (original_meshes[index] as MeshInstance3D).mesh == (detached_meshes[index] as MeshInstance3D).mesh and (original_meshes[index] as MeshInstance3D).material_override == (detached_meshes[index] as MeshInstance3D).material_override
		expect(same_resources,"Detached markings/guns/skin keep original batched meshes and materials")
		var pose: Transform3D = fragment.global_transform
		for i: int in 20: first.apply_state(target.snapshot())
		expect(first.damage_statistics().fragment_nodes == 1 and fragment.global_transform == pose,"Repeated snapshot consumption does not duplicate or advance debris")
		expect(not first.apply_weapon_state("wing_port_01",{}) and first.muzzle_transform_local("wing_port_01",0) == Transform3D.IDENTITY,"Detached side no longer exposes an enabled muzzle")
		world.reset()
		first.apply_state(world.get_unit("target").snapshot())
		expect(first.damage_statistics().fragment_nodes == 0 and (first.model_root.damage_parts.wing_left as Node3D).visible and first.apply_weapon_state("wing_port_01",{}),"Reset removes fragment nodes and restores full wing and muzzle")
		records.append({"definition_id":definition_id,"healthy_mesh_nodes":healthy_mesh_count,"cap":3,"fragment_mesh_nodes":detached_meshes.size(),"instance_isolation":true})
		first.free()
		second.free()
	# Multiple real-damage views exercise actual allocated nodes, not a counter stub.
	var stress_arena: Dictionary = AircraftDamageFixture.arena("us_f6f5_1944")
	AircraftDamageFixture.shoot(stress_arena,"structure",1,"us_406mm_mk8_ap")
	stress_arena.world.step_ticks(8)
	var damaged_state: Dictionary = stress_arena.world.get_unit("target").snapshot()
	var stress_views: Array[AircraftAdapter] = []
	for i: int in 20:
		var packed: PackedScene = load("res://scenes/units/aircraft/f6f5_flight.tscn")
		var view: AircraftAdapter = packed.instantiate() as AircraftAdapter
		root.add_child(view)
		view.apply_state(damaged_state)
		stress_views.append(view)
	var actual_fragments: int = 0
	var suppressed: int = 0
	for view: AircraftAdapter in stress_views:
		actual_fragments += view.find_children("Debris_*","Node3D",false,false).size()
		suppressed += int(view.damage_statistics().suppressed_fragments)
	expect(actual_fragments == AircraftAdapter.GLOBAL_FRAGMENT_CAP and suppressed == 12 and AircraftAdapter.live_fragment_nodes == actual_fragments,"Actual scene debris nodes stop at global48; excess views do not allocate or alter damage")
	expect(stress_arena.world.get_unit("target").snapshot() == damaged_state,"Render budget and discarded visual fragments never mutate simulation")
	for view: AircraftAdapter in stress_views: view.free()
	expect(AircraftAdapter.live_fragment_nodes == 0,"Freeing every damaged model returns the shared presentation budget to zero")

	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/DM01/models.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"models":records},"\t"))
	finish("DM01 model assembly")
