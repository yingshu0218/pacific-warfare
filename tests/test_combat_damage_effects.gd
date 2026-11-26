extends "res://tests/fixtures/combat_test.gd"

var evidence: Array[Dictionary]=[]

func run_test() -> void:
	for definition: String in ["jp_yamato_1944_04","us_fletcher_dd445_1942_07_18"]:
		_check_model_anchor(definition)
	var config: CombatConfig=FIX.config()
	for definition: String in ["jp_a6m5a_1944","us_f6f5_1944"]:
		var anchors: Dictionary=config.data.unit_profiles[definition].damage_effects
		var engine: Dictionary=config.data.unit_profiles[definition].boxes[0]
		for key: String in ["fire_anchor_m","smoke_anchor_m"]:
			var point: Vector3=SimData.vec3(anchors[key])
			var center: Vector3=SimData.vec3(engine.center_m)
			var half_size: Vector3=SimData.vec3(engine.half_extents_m)
			expect(absf(point.x-center.x)<=half_size.x and absf(point.z-center.z)<=half_size.z and absf(point.y-(center.y+half_size.y))<.3,definition+" "+key+" follows engine skin instead of hovering several metres above flight origin")
	var file: FileAccess=FileAccess.open("res://docs/showcase/evidence/S05/damage_effect_anchors.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	file.close()
	finish("damage effects on formal models")

func _check_model_anchor(definition: String) -> void:
	var arena: Dictionary=FIX.arena([FIX.spawn("ship","jp",Vector3(80,0,-60),definition)])
	var world: SimulationWorld=arena.world
	var unit: UnitState=world.get_unit("ship")
	unit.rotation_rad=Vector3(0,.7,0)
	unit.module_data.damage.fire=.12
	var before: Dictionary=world.snapshot()
	var model: Node3D=(load(world.unit_definition(definition).model_scene) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	model.call("apply_state",unit.snapshot())
	var effects: CombatEffects=CombatEffects.new()
	effects.sound_enabled=false
	root.add_child(effects)
	effects.consume([],world.generation)
	effects.apply_snapshot({"units":{"ship":unit.snapshot()}})
	effects.advance(.1)
	var record: Dictionary={"definition_id":definition,"fire_severity":.12,"anchors":{}}
	for kind: String in ["fire","smoke"]:
		var found: bool=false
		for slot: Dictionary in effects.slots:
			if not slot.active or slot.kind!=kind:continue
			found=true
			var point: Vector3=slot.position
			var key: String="fire_anchor_m" if kind=="fire" else "smoke_anchor_m"
			var expected_point: Vector3=unit.world_transform()*SimData.vec3(arena.config.data.unit_profiles[definition].damage_effects[key])
			expect(point.distance_to(expected_point)<.0001,definition+" "+kind+" emitter follows the formal model's translated/yawed local point")
			var deck_gap: float=_closest_surface(model,point,Vector3.DOWN*50.)
			var upward_hit: float=_closest_surface(model,point,Vector3.UP*40.)
			expect(is_finite(deck_gap) and deck_gap>.2 and deck_gap<3.,definition+" "+kind+" is just above actual deck, not buried under it or moved onto bridge roof")
			expect(not is_finite(upward_hit),definition+" "+kind+" actual mesh has clear upward view from emitter")
			record.anchors[kind]={"world_position_m":SimData.array3(point),"actual_mesh_gap_below_m":deck_gap,"clear_upward":not is_finite(upward_hit),"size_m":slot.size}
		expect(found,definition+" actual 12-percent fire generates "+kind)
	expect(world.snapshot()==before,definition+" showing damage does not alter structure/fire/inventory or simulation")
	unit.active=false
	unit.module_data["ship_motion"]={"exited":true}
	effects.apply_snapshot({"units":{"ship":unit.snapshot()}})
	effects.advance(4.)
	expect(effects.statistics().active==0,definition+" exposed anchor does not continue emitting after actual ship departure")
	evidence.append(record)
	effects.free()
	model.free()

func _closest_surface(model: Node3D, origin: Vector3, offset: Vector3) -> float:
	var nearest: float=INF
	for node: Node in model.find_children("*","MeshInstance3D",true,false):
		var part: MeshInstance3D=node as MeshInstance3D
		if part.mesh==null:continue
		var faces: PackedVector3Array=part.mesh.get_faces()
		var inverse: Transform3D=part.global_transform.affine_inverse()
		var a: Vector3=inverse*origin
		var b: Vector3=inverse*(origin+offset)
		for index: int in range(0,faces.size()-2,3):
			var hit: Variant=Geometry3D.segment_intersects_triangle(a,b,faces[index],faces[index+1],faces[index+2])
			if hit is Vector3:
				nearest=minf(nearest,origin.distance_to(part.global_transform*(hit as Vector3)))
	return nearest
