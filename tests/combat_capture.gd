extends Node3D

const FIX: Script=preload("res://tests/fixtures/combat_fixture.gd")
var camera: Camera3D
var output_dir: String="res://docs/showcase/evidence/S05"
var effects: CombatEffects
var models: Dictionary={}
var stage: Node3D
var audit: Array[Dictionary]=[]

func _ready() -> void:
	get_viewport().size=Vector2i(1440,900)
	var environment: Environment=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("a9c9df")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("b7c9d8")
	environment.ambient_light_energy=.7
	var world_environment: WorldEnvironment=WorldEnvironment.new()
	world_environment.environment=environment
	add_child(world_environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-45,0)
	sun.light_energy=1.1
	sun.shadow_enabled=true
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.current=true
	camera.far=12000
	add_child(camera)
	call_deferred("capture_all")

func make_stage() -> void:
	if stage!=null: stage.free()
	stage=Node3D.new()
	add_child(stage)
	models.clear()
	var water: MeshInstance3D=MeshInstance3D.new()
	var plane: PlaneMesh=PlaneMesh.new()
	plane.size=Vector2(14000,14000)
	water.mesh=plane
	var material: StandardMaterial3D=StandardMaterial3D.new()
	material.albedo_color=Color("28516a")
	material.roughness=.6
	water.material_override=material
	stage.add_child(water)
	effects=CombatEffects.new()
	effects.sound_enabled=false
	effects.effect_capacity=256
	stage.add_child(effects)

func add_models(world: SimulationWorld) -> void:
	for id: String in world.unit_ids():
		var unit: UnitState=world.get_unit(id)
		var path: String=world.unit_definition(unit.definition_id).model_scene
		var model: Node3D=(load(path) as PackedScene).instantiate() as Node3D
		stage.add_child(model)
		models[id]=model
	apply(world)

func apply(world: SimulationWorld) -> void:
	var snapshot: Dictionary=world.snapshot()
	for id: String in models:
		var model: Node3D=models[id]
		if model.has_method("apply_state"):model.call("apply_state",snapshot.units[id])
		else:
			model.position=snapshot.units[id].position_m
			model.rotation=snapshot.units[id].rotation_rad
	effects.apply_snapshot(snapshot)

func save_view(name_value: String, world: SimulationWorld, events: Array[BattleEvent], from: Vector3, to: Vector3, size: float) -> void:
	apply(world)
	camera.position=from
	camera.size=size
	camera.look_at(to)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String=ProjectSettings.globalize_path(output_dir.path_join(name_value+".png"))
	if get_viewport().get_texture().get_image().save_png(path)!=OK:
		push_error("S05 capture save failed")
		get_tree().quit(1)
	var counts: Dictionary={}
	var sample: Array=[]
	for event: BattleEvent in events:
		counts[event.kind]=int(counts.get(event.kind,0))+1
		if event.kind in ["airburst","surface_impact","damaged"] or (event.kind=="fired" and sample.size()<10):sample.append(event.snapshot())
	audit.append({"view":name_value,"tick":world.tick,"events":counts,"samples":sample,"effects":effects.statistics(),"active_projectiles":world.snapshot().modules.combat_projectiles.rounds.size()})

func capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	make_stage()
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","jp",Vector3.ZERO,"jp_yamato_1944_04"),FIX.spawn("enemy","us",Vector3(4000,0,0),"us_iowa_bb61_1944_12_28")])
	var world: SimulationWorld=a.world
	world.get_unit("shooter").module_data.combat_intent={"fire":true}
	FIX.target(world,"shooter","enemy")
	for socket: MountSocket in (a.frame.definitions.shooter as UnitDefinition).mounts:
		if socket.role=="main":world.get_unit("shooter").weapons[socket.id].train_rad=wrapf(-PI*.5-socket.base_yaw_rad,-PI,PI)
	add_models(world)
	var accumulated: Array[BattleEvent]=[]
	for index: int in range(300):
		world.step_ticks(1)
		var events: Array[BattleEvent]=world.drain_events()
		effects.advance(1./60.)
		effects.consume(events,world.generation)
		accumulated.append_array(events)
		var main_fired: bool=false
		for event: BattleEvent in events:
			if event.kind=="fired" and "/main_" in event.weapon_id:main_fired=true
		if main_fired:break
	await save_view("gunnery",world,accumulated,Vector3(190,95,-190),Vector3(0,11,-22),160)
	make_stage()
	var c: CombatConfig=FIX.config()
	c.data.unit_profiles.us_f6f5_1944.structure=1000000.
	c.data.unit_profiles.us_f6f5_1944.part_durability=1000000.
	a=FIX.arena([FIX.spawn("shooter","us",Vector3.ZERO,"us_iowa_bb61_1944_12_28"),FIX.spawn("air_a","jp",Vector3(180,85,-90)),FIX.spawn("air_b","jp",Vector3(230,90,70))],c)
	world=a.world
	world.get_unit("shooter").module_data.combat_intent={"allow_aa":true}
	add_models(world)
	accumulated.clear()
	for index: int in range(1500):
		world.step_ticks(1)
		var events: Array[BattleEvent]=world.drain_events()
		effects.advance(1./60.)
		effects.consume(events,world.generation)
		accumulated.append_array(events)
		var burst: bool=false
		for event: BattleEvent in events:
			if event.kind=="airburst":burst=true
		if burst and index>120:break
	for index: int in range(8):
		world.step_ticks(1)
		var events: Array[BattleEvent]=world.drain_events()
		effects.advance(1./60.)
		effects.consume(events,world.generation)
		accumulated.append_array(events)
	await save_view("air_defence",world,accumulated,Vector3(440,220,380),Vector3(90,40,0),245)
	var burst_point: Vector3=Vector3(180,85,-90)
	for event: BattleEvent in accumulated:
		if event.kind=="airburst":burst_point=event.position_m
	await save_view("airburst_close",world,accumulated,burst_point+Vector3(80,35,90),burst_point,60)
	make_stage()
	c=FIX.config()
	c.data.environment.solids=[{"id":"island","surface":"ground","center_m":[40,-1,0],"half_extents_m":[25,3,25]}]
	a=FIX.arena([FIX.spawn("shooter","us",Vector3(800,200,0))],c)
	world=a.world
	var ground: MeshInstance3D=MeshInstance3D.new()
	var ground_mesh: BoxMesh=BoxMesh.new()
	ground_mesh.size=Vector3(50,6,50)
	ground.mesh=ground_mesh
	ground.position=Vector3(40,-1,0)
	var earth: StandardMaterial3D=StandardMaterial3D.new()
	earth.albedo_color=Color("77704d")
	ground.material_override=earth
	stage.add_child(ground)
	(a.launcher as FIX.Launcher).pending=[{"ammo":"jp_460mm_ap","position":Vector3(-35,100,0),"direction":Vector3.DOWN,"gravity":0.},{"ammo":"jp_460mm_ap","position":Vector3(40,102,0),"direction":Vector3.DOWN,"gravity":0.}]
	accumulated.clear()
	for index: int in range(26):
		world.step_ticks(1)
		var events: Array[BattleEvent]=world.drain_events()
		effects.advance(1./60.)
		effects.consume(events,world.generation)
		accumulated.append_array(events)
	await save_view("sea_and_ground",world,accumulated,Vector3(100,75,120),Vector3(0,10,0),105)
	var file: FileAccess=FileAccess.open(output_dir.path_join("capture_audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Controlled S05 mechanism/effects capture, no final AI/UI/browser claim","views":audit},"\t"))
	file.close()
	print("S05 native captures saved: ",audit.size())
	get_tree().quit(0)
