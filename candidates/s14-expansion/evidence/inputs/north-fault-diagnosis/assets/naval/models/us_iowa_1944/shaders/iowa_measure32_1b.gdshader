shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D camouflage_mask : filter_nearest, repeat_disable;
uniform vec4 navy_blue : source_color = vec4(0.25, 0.32, 0.36, 1.0);
uniform vec4 light_gray : source_color = vec4(0.68, 0.71, 0.71, 1.0);
uniform vec4 deck_blue : source_color = vec4(0.20, 0.26, 0.31, 1.0);
uniform vec4 anti_fouling_red : source_color = vec4(0.30, 0.20, 0.18, 1.0);
uniform vec3 tint = vec3(1.0);
uniform bool paint_underwater = false;
uniform bool paint_decks = true;
uniform mat4 world_to_ship = mat4(1.0);
uniform bool use_pattern_transform = false;
uniform mat4 pattern_transform = mat4(1.0);
uniform vec3 pattern_center = vec3(0.0);
uniform vec2 mount_pattern_zoom = vec2(1.0);

varying vec3 ship_position;
varying vec3 ship_normal;

void vertex() {
	ship_position = (world_to_ship * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (use_pattern_transform) {
		ship_position = (pattern_transform * vec4(VERTEX, 1.0)).xyz;
	}
	ship_normal = normalize(mat3(world_to_ship) * MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 pattern_uv = vec2(
		clamp((ship_position.z + 135.2) / 270.4, 0.0, 1.0),
		clamp((44.4 - ship_position.y) / 55.7, 0.0, 1.0)
	);
	if (use_pattern_transform) {
		vec2 center_uv = vec2(
			clamp((pattern_center.z + 135.2) / 270.4, 0.0, 1.0),
			clamp((44.4 - pattern_center.y) / 55.7, 0.0, 1.0)
		);
		pattern_uv = clamp(center_uv + (pattern_uv - center_uv) * mount_pattern_zoom, vec2(0.0), vec2(1.0));
	}
	float navy_mask = texture(camouflage_mask, pattern_uv).r;
	vec3 paint_color = mix(navy_blue.rgb, light_gray.rgb, navy_mask);
	if (paint_decks && ship_normal.y > 0.82) {
		paint_color = deck_blue.rgb;
	}
	if (paint_underwater && ship_position.y < -0.55) {
		paint_color = anti_fouling_red.rgb;
	}
	ALBEDO = paint_color * tint;
	ROUGHNESS = 0.84;
	METALLIC = 0.0;
}
