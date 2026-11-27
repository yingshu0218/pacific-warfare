extends SceneTree
## Standalone smoke check; optional argument after "--" is GLB export directory.
const BASE := "res://scenes/ships/us_carrier_1942_visual/"
var errors := 0

func _initialize() -> void:
	call_deferred("_test")

func require(ok: bool, msg: String) -> void:
	if not ok:
		errors += 1
		push_error(msg)

func _test() -> void:
	for spec: Array in [["saratoga",270.6624,32.3088,7.3533,2,38.34],["hornet",246.8118,25.3238,8.4,3,34.7472]]:
		var viewer := (load(BASE+spec[0]+"_viewer.tscn") as PackedScene).instantiate()
		root.add_child(viewer)
		var model := viewer.get_node("Model")
		var hull := model.get_node("CurvedWaterlineHull/Hull plating") as MeshInstance3D
		var keel := model.get_node("CurvedWaterlineHull/Keel and underwater hull") as MeshInstance3D
		var flight := model.get_node("FlightDeckAndCenterlineElevators/Continuous thin timber flight deck outline") as MeshInstance3D
		if hull == null or keel == null or flight == null:
			require(false,spec[0]+" missing geometry root or surface")
			viewer.free()
			continue
		require(absf(hull.get_aabb().size.z-spec[1])<.005,spec[0]+" length")
		require(absf(hull.get_aabb().size.x-spec[2])<.005,spec[0]+" hull beam")
		require(absf(keel.get_aabb().position.y+spec[3])<.005,spec[0]+" draft")
		require(absf(flight.get_aabb().size.x-spec[5])<.005,spec[0]+" flight deck beam")
		var lift_count := 0
		for node in model.get_node("FlightDeckAndCenterlineElevators").get_children():
			if "centerline lift flush timber panel" in String(node.name):
				lift_count += 1
		require(lift_count == spec[4],spec[0]+" centerline lift count")
		var mesh_count := 0
		var world_box := AABB()
		var box_found := false
		for node in model.find_children("*","MeshInstance3D",true,false):
			var item := node as MeshInstance3D
			var box: AABB = item.global_transform*item.get_aabb()
			require(box.size.is_finite() and box.position.is_finite(),spec[0]+" finite "+String(item.name))
			world_box = world_box.merge(box) if box_found else box
			box_found = true
			mesh_count += 1
		require(mesh_count > 380,spec[0]+" geometry layers")
		for keycode in range(KEY_1,KEY_4+1):
			var input := InputEventKey.new()
			input.keycode = keycode
			input.pressed = true
			viewer._unhandled_key_input(input)
			var camera := root.get_camera_3d()
			require(camera != null and camera.current,spec[0]+" camera")
			var water := viewer.get("_water") as MeshInstance3D
			require(water.visible == (keycode != KEY_4),spec[0]+" water toggle")
			var rect := root.get_visible_rect().grow(1)
			for i in range(8):
				require(rect.has_point(camera.unproject_position(world_box.get_endpoint(i))),spec[0]+" viewer model bounds mode "+str(keycode-KEY_1+1))
		if not OS.get_cmdline_user_args().is_empty():
			var state := GLTFState.new()
			var doc := GLTFDocument.new()
			require(doc.append_from_scene(model,state) == OK,spec[0]+" GLTF bake")
			require(doc.write_to_filesystem(state,OS.get_cmdline_user_args()[0].path_join(spec[0]+".glb")) == OK,spec[0]+" GLB writing")
		print("%s: %d meshes; hull %.4f × %.4f m; %d fixed centerline panels; 4 viewer cameras" % [spec[0],mesh_count,hull.get_aabb().size.z,hull.get_aabb().size.x,lift_count])
		viewer.free()
	quit(0 if errors == 0 else 1)
