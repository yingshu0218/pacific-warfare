shader_type spatial;
// Inspection-only water occlusion. Orthographic rays can originate below the
// sea plane; keep the full source hull and clip only its submerged fragments.
uniform vec4 surface_color : source_color = vec4(0.384, 0.412, 0.416, 1.0);
uniform float sea_height_m = -0.02;
varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (world_y < sea_height_m) { discard; }
	ALBEDO = surface_color.rgb;
	ROUGHNESS = 0.88;
}
