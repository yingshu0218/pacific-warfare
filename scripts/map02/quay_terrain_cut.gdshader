shader_type spatial;
render_mode cull_disabled;

// Use the same chart triangles, normal interpolation and vertex colors as the
// existing terrain. Only fragments immediately below/in a quay are removed;
// uphill terrain above the quay stays visible.
uniform vec4 footprint[16];
uniform float deck_limit[16];
uniform vec4 regional[2];
uniform int deck_count = 0;
uniform float highest_cut = 0.0;
varying vec3 world_p;
void vertex() {
	world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
bool inside_rect(vec4 r) {
	return world_p.x >= r.x && world_p.x <= r.z && world_p.z >= r.y && world_p.z <= r.w;
}
void fragment() {
	if (world_p.y <= highest_cut && (inside_rect(regional[0]) || inside_rect(regional[1]))) {
	for (int i = 0; i < 16; i++) {
		if (i >= deck_count) { break; }
		vec4 r = footprint[i];
		if (inside_rect(r) && world_p.y <= deck_limit[i]) {
			discard;
		}
	}
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.93;
	SPECULAR = 0.5;
}
