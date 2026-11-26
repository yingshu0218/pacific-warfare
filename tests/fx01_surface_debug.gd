extends SceneTree
const DEMO: Script=preload("res://tests/fixtures/fx01_demo.gd")
var game: FirstPlayableGame
var demo: Node3D
var directory: String="res://docs/showcase/evidence/FX01/surface-debug"

func _initialize() -> void:call_deferred("run")
func shot(name_value: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false,0.)
	root.get_texture().get_image().save_png(directory.path_join(name_value+".png"))
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-1800,0))
	DisplayServer.window_set_size(Vector2i(1280,720));root.content_scale_size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	game=(load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game);game.set_process(false);game.effects.hide();game.hud.hide()
	demo=DEMO.new();root.add_child(demo);demo.configure(false);demo.start("water");demo.step_ticks(96)
	game.camera.mode="free";game.camera.followed_id="";game.camera.position=Vector3(-10,8,12);game.camera.look_at(Vector3(-18,5,0))
	game.environment_view.advance(demo.arena.world.time_s());game.environment_view.update_observer(game.camera.position)
	var data: Array=[]
	for slot: Dictionary in demo.effects.slots:
		var material: ShaderMaterial=slot.material
		data.append({"kind":slot.kind,"active":slot.active,"mode":material.get_shader_parameter("effect_mode"),"fade":material.get_shader_parameter("fade"),"position":SimData.array3((slot.mesh as MeshInstance3D).position),"scale":SimData.array3((slot.mesh as MeshInstance3D).scale),"seed":material.get_shader_parameter("seed"),"shader":material.shader.code})
	await shot("all")
	for slot: Dictionary in demo.effects.slots:(slot.mesh as MeshInstance3D).visible=slot.active and slot.kind=="mist"
	await shot("mist_only")
	game.environment_view.world_environment.environment.fog_enabled=false
	await shot("mist_no_fog")
	game.environment_view.water.hide()
	await shot("mist_without_water")
	game.environment_view.water.show()
	for slot: Dictionary in demo.effects.slots:(slot.mesh as MeshInstance3D).visible=slot.active and slot.kind=="water"
	await shot("water_only")
	for slot: Dictionary in demo.effects.slots:(slot.mesh as MeshInstance3D).visible=slot.active and slot.kind=="foam"
	await shot("foam_only")
	var file: FileAccess=FileAccess.open(directory.path_join("materials.json"),FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
	demo.free();game.free();quit(0)
