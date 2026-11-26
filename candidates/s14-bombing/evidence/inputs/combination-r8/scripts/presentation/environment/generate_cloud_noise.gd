extends SceneTree

## Original deterministic texture; no photographs or downloaded assets.
func _initialize() -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 130707
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.006
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.45
	noise.fractal_lacunarity = 2.0
	var image: Image = noise.get_seamless_image(512, 512, false, false, 0.20)
	var result: Error = image.save_png("res://scripts/presentation/environment/cloud_noise.png")
	noise.seed = 130708
	noise.frequency = 0.028
	noise.fractal_octaves = 3
	var height: Image = noise.get_seamless_image(512, 512, false, false, 0.20)
	var slopes: Image = Image.create(512, 512, false, Image.FORMAT_RGB8)
	for y: int in 512:
		for x: int in 512:
			var dx: float = (height.get_pixel((x + 1) % 512, y).r - height.get_pixel((x + 511) % 512, y).r) * 8.0
			var dz: float = (height.get_pixel(x, (y + 1) % 512).r - height.get_pixel(x, (y + 511) % 512).r) * 8.0
			slopes.set_pixel(x, y, Color(clampf(dx, -1, 1) * .5 + .5, clampf(dz, -1, 1) * .5 + .5, height.get_pixel(x, y).r))
	if slopes.save_png("res://scripts/presentation/environment/wave_slopes.png") != OK: result = ERR_CANT_CREATE
	quit(0 if result == OK else 1)
