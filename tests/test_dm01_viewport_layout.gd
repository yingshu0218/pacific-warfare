extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var parent: Node3D = Node3D.new()
	root.add_child(parent)
	var old: SubViewportContainer = SubViewportContainer.new()
	old.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	old.size = Vector2(1280,720)
	old.stretch = true
	parent.add_child(old)
	var inner: SubViewport = SubViewport.new()
	inner.size = Vector2i(1280,720)
	old.add_child(inner)
	await process_frame
	await process_frame
	var bad: Dictionary = {"container_rect":[old.get_global_rect().position.x,old.get_global_rect().position.y,old.size.x,old.size.y],"subviewport_size":[inner.size.x,inner.size.y]}
	var camera: Camera3D = Camera3D.new()
	parent.add_child(camera)
	camera.position = Vector3(0,0,10)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var projected: Vector2 = camera.unproject_position(Vector3.ZERO)
	var current: Dictionary = {"path":"single_main_viewport","actual_viewport_size":[camera.get_viewport().get_visible_rect().size.x,camera.get_viewport().get_visible_rect().size.y],"projected_focus":[projected.x,projected.y]}
	var passed: bool = old.size == Vector2(2560,1440) and inner.size == Vector2i(2560,1440) and projected.distance_to(Vector2(640,360)) < .01
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/DM01/viewport-layout.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"reproduced_old_layout":bad,"current_root_layout":current},"\t"))
	if not passed: push_error("Unexpected viewport layout: "+str([bad,current]))
	print("DM01 viewport layout ","PASS" if passed else "FAIL")
	quit(0 if passed else 1)
