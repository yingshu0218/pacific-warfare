extends SceneTree

var game: AllUnitsShowcase
var output: String = "res://docs/showcase/evidence/S14/gallery-isolation"

func _initialize() -> void: call_deferred("run")
func shot(label: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false,0)
	root.get_texture().get_image().save_png(output.path_join(label+".png"))

func run() -> void:
	if "--fixed" in OS.get_cmdline_user_args(): output = "res://docs/showcase/evidence/S14/gallery-final"
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	game = (load("res://showcase/all_units.tscn") as PackedScene).instantiate() as AllUnitsShowcase
	root.add_child(game)
	game.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for index: int in [2,4]:
		game.inspect_weapon(index)
		await shot("weapon_%d_plate_on"%index)
		var parent: Node3D = game.gallery.get_node(NodePath(game.gallery.entries[index].id)) as Node3D
		var plate: MeshInstance3D
		for node: Node in parent.get_children():
			if node is MeshInstance3D and is_equal_approx((node as MeshInstance3D).position.y,-.06): plate = node
		if plate == null: push_error("S14 diagnostic plate not found"); quit(1); return
		plate.visible = false
		await shot("weapon_%d_plate_off"%index)
		plate.visible = true
	game.queue_free()
	await process_frame
	quit()
