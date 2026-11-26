shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
varying float hull_y;
void vertex() { hull_y = VERTEX.y; }
void fragment() {
	vec3 paint = vec3(0.35,0.38,0.41);
	if (hull_y < -0.55) { paint = vec3(0.32,0.12,0.11); }
	else if (hull_y < 0.20) { paint = vec3(0.14,0.17,0.19); }
	ALBEDO = paint;
	ROUGHNESS = 0.85;
}
