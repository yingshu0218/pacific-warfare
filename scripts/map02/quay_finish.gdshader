shader_type spatial;
varying vec3 world_p;
void vertex() {
	world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float tone = 1.0;
	if (UV.x > 0.5) {
		vec2 slabs = world_p.xz / vec2(16.0, 13.0);
		vec2 x = fract(slabs);
		vec2 edge = min(x, 1.0 - x);
		vec2 aa = fwidth(slabs);
		vec2 seam = 1.0 - smoothstep(vec2(0.002), vec2(0.009) + aa * 0.8, edge);
		float fade_dist = 1.0 - smoothstep(0.11, 0.42, max(aa.x, aa.y));
		vec2 cell = floor(slabs);
		float patina = sin(cell.x * 9.53 + sin(cell.y * 4.13)) * 0.022;
		tone = 1.0 + patina * fade_dist - max(seam.x, seam.y) * 0.13 * fade_dist;
	}
	ALBEDO = COLOR.rgb * tone;
	ROUGHNESS = 0.94;
}
