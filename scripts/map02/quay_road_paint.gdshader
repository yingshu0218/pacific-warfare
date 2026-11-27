shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Flush paint should not receive its own cascaded shadow.
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.93;
}
