extends SceneTree

var game: FirstPlayableGame
var directory: String = "/Users/infinity/Desktop/Dev/game-pacific/.local/repairs/20261112_morning/rx02/native_after"
var samples: Array[Dictionary] = []
var last_sample_s: float = -1.0
var captures: Dictionary = {}
var wall_start: int = Time.get_ticks_msec()
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): directory = arg.trim_prefix("--out=")
	call_deferred("start")
func start() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	game = load("res://showcase/carrier_harbor.tscn").instantiate() as FirstPlayableGame
	root.add_child(game)
	game.set_process_input(false);game.set_process_unhandled_input(false)
	root.size = Vector2i(1280,720)
func _process(_delta: float) -> bool:
	if game == null or not game.running:
		if Time.get_ticks_msec()-wall_start>15000: quit(1)
		return false
	var now: float = game.session.world.time_s()
	if now-last_sample_s>=1.0:
		last_sample_s=now
		var projectiles: Array[Dictionary] = []
		for slot: Dictionary in game.effects.slots:
			if not slot.active or str(slot.projectile_id).is_empty(): continue
			var mesh: MeshInstance3D=slot.mesh
			var distance: float=game.camera.global_position.distance_to(mesh.global_position)
			var depth: float=-(game.camera.global_transform.affine_inverse()*mesh.global_position).z
			var metres_per_pixel: float=2.*maxf(.001,depth)*tan(deg_to_rad(game.camera.fov)*.5)/root.size.y
			projectiles.append({"id":slot.projectile_id,"kind":slot.kind,"distance_m":distance,"width_px":mesh.scale.x/metres_per_pixel,"in_frustum":game.camera.is_position_in_frustum(mesh.global_position)})
		samples.append({"time_s":now,"paused":game.session.world.paused,"ended":game.session.ended_reason,"speed":game.session.world.time_scale,"shot_label":game.camera.shot_label,"followed_id":game.camera.followed_id,"camera_m":SimData.array3(game.camera.position),"fov":game.camera.fov,"effects":game.effects.statistics(),"projectiles":projectiles})
	for mark: float in [12.,27.,34.]:
		if now>=mark and not captures.has(mark):
			captures[mark]=true
			capture.call_deferred(int(mark))
	if now>=36.0 or Time.get_ticks_msec()-wall_start>65000:
		var file: FileAccess=FileAccess.open(directory.path_join("observer.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"scope":"Current ordinary harbor default event camera; real simulation; input disabled only during unattended native recording; 1280x720; not a performance run","simulation_s":now,"wall_s":(Time.get_ticks_msec()-wall_start)*.001,"samples":samples},"\t"));file.close()
		print("RX02 native readonly samples ",samples.size()," at ",now,"s")
		quit(0 if now>=35. else 1)
	return false

func capture(mark: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("harbor_%02d.png"%mark))
