extends "res://tests/fixtures/combat_test.gd"

const BEFORE: Script = preload("res://tests/s04_carrier_usage/baseline_f6f5.gd")
const AFTER: Script = preload("res://aircraft/models/f6f5.gd")

func fingerprint(mesh: MeshInstance3D) -> String:
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for surface: int in mesh.mesh.get_surface_count(): hash.update(var_to_bytes(mesh.mesh.surface_get_arrays(surface)))
	return hash.finish().hex_encode()

func named_mesh(model: Node3D, label: String) -> MeshInstance3D:
	for node: Node in model.find_children("*","MeshInstance3D",true,false):
		if str(node.name) == label: return node as MeshInstance3D
	return null

func run_test() -> void:
	var before: PacificAircraftBuilder = BEFORE.new() as PacificAircraftBuilder
	var after: PacificAircraftBuilder = AFTER.new() as PacificAircraftBuilder
	before.flight_simplified = true;after.flight_simplified = true
	root.add_child(before);root.add_child(after)
	var rows: Array[Dictionary] = []
	for label: String in ["Wide Grumman fuselage","Port folding wing","Starboard folding wing","Port horizontal stabilizer","Starboard horizontal stabilizer","Vertical stabilizer","R-2800 cowling","R-2800 cowling closed front"]:
		var old_mesh: MeshInstance3D = named_mesh(before,label)
		var new_mesh: MeshInstance3D = named_mesh(after,label)
		expect(old_mesh != null and new_mesh != null,"Same admitted core mesh exists: "+label)
		if old_mesh == null or new_mesh == null: continue
		var old_hash: String = fingerprint(old_mesh)
		var new_hash: String = fingerprint(new_mesh)
		expect(old_hash == new_hash and old_mesh.global_transform.is_equal_approx(new_mesh.global_transform),"Core vertex/index/normal/color data and installation are unchanged: "+label)
		rows.append({"mesh":label,"before_sha256":old_hash,"after_sha256":new_hash,"same_transform":old_mesh.global_transform.is_equal_approx(new_mesh.global_transform)})
	expect(before.spec.span_m == after.spec.span_m and before.spec.length_m == after.spec.length_m and before.spec.prop_y == after.spec.prop_y,"Nominal airframe dimensions and propeller installation preserved")
	var out: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-carrier-usage/airframe-preservation.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks,"failures":failures,"meshes":rows,"scope":"Saved admitted F6F script vs candidate, unbatched actual core mesh arrays and transforms; wheel and hook changes excluded intentionally."},"\t"));out.close()
	before.free();after.free();finish("S04 F6F core airframe preservation")
