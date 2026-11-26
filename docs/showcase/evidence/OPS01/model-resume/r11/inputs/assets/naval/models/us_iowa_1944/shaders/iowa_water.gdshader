shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.055, 0.105, 0.135);
uniform vec3 light_color : source_color = vec3(0.16, 0.24, 0.27);

void vertex() {
	float wave_a = sin(VERTEX.x * 0.035 + TIME * 0.55) * 0.07;
	float wave_b = sin(VERTEX.z * 0.052 - TIME * 0.34) * 0.045;
	VERTEX.y += wave_a + wave_b;
}

void fragment() {
	float band = sin(UV.x * 140.0 + UV.y * 65.0 + TIME * 0.7) * 0.5 + 0.5;
	float sheen = smoothstep(0.80, 1.0, band) * 0.12;
	ALBEDO = mix(deep_color, light_color, 0.12 + sheen);
	ROUGHNESS = 0.24;
}

