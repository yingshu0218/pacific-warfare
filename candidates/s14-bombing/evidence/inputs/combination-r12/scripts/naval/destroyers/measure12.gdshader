shader_type spatial;
render_mode cull_disabled;
uniform mat4 ship_inverse = mat4(1.0);
varying vec3 ship_point;
void vertex() {
	ship_point = (ship_inverse * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Source-inspired broad Measure 12 Modified fields; not a measured paint stencil.
	float edge = 3.0 + 1.5 * sin(ship_point.z * 0.39 + ship_point.x * 0.32) + 0.65 * sin(ship_point.z * 0.89);
	vec3 navy_blue = vec3(0.155, 0.200, 0.255);
	vec3 ocean_gray = vec3(0.315, 0.370, 0.405);
	vec3 haze_gray = vec3(0.475, 0.520, 0.540);
	ALBEDO = mix(navy_blue, ocean_gray, smoothstep(edge - 0.07, edge + 0.07, ship_point.y));
	ALBEDO = mix(ALBEDO, haze_gray, smoothstep(8.5 + sin(ship_point.z * 0.60) * 1.1, 8.65 + sin(ship_point.z * 0.60) * 1.1, ship_point.y));
	ROUGHNESS = 0.9;
}
