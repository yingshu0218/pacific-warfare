shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float trail = UV.y;
	float width = mix(0.18, 0.5, trail);
	float sides = 1.0 - smoothstep(width * 0.55, width, abs(UV.x - 0.5));
	float fade = sin(trail * 3.14159265) * (1.0 - trail * 0.65);
	ALBEDO = vec3(0.65, 0.85, 0.88);
	ALPHA = max(0.0, 0.25 * sides * fade);
}
