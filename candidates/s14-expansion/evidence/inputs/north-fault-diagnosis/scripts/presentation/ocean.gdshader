shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float simulation_time = 0.0;
uniform vec2 wind_direction = vec2(0.84, 0.54);
uniform vec3 sun_direction = vec3(0.5792, 0.5736, 0.5792);
uniform vec3 observer_position = vec3(0.0);
uniform sampler2D wave_noise : repeat_enable, filter_linear_mipmap;
uniform vec3 deep_color : source_color = vec3(0.09, 0.255, 0.32);
uniform vec3 horizon_color : source_color = vec3(0.67, 0.77, 0.80);
varying vec3 world_p;

vec2 wave_slope(vec2 uv, float distance_fade) {
	// Mipmaps average signed height gradients towards zero. Screen derivatives
	// remove the last subpixel band smoothly, even during camera rotation.
	float footprint = length(fwidth(uv)) * 512.0;
	return (texture(wave_noise, uv).rg * 2.0 - 1.0) * (1.0 - smoothstep(6.0, 26.0, footprint)) * distance_fade;
}

void vertex() {
	// Exactly the simulation's y=0 plane: wakes and splashes cannot float above a crest.
	world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_p.xz;
	vec2 d = normalize(wind_direction);
	vec2 e = vec2(-d.y, d.x);
	float distance_m = length(world_p - observer_position);
	vec2 uv = vec2(dot(p, d) * 0.013, dot(p, e) * 0.009);
	vec2 broad = wave_slope(uv * 0.23 - vec2(simulation_time * .003, 0.0), 1.0 - smoothstep(2000.0, 14000.0, distance_m));
	vec2 medium = wave_slope(uv + vec2(-simulation_time * .012, .37), 1.0 - smoothstep(260.0, 2800.0, distance_m));
	vec2 fine = wave_slope(uv * 3.13 + vec2(-simulation_time * .022, simulation_time * .003), 1.0 - smoothstep(50.0, 650.0, distance_m));
	vec2 local_slope = broad * .12 + medium * .055 + fine * .018;
	vec2 slope = d * local_slope.x + e * local_slope.y * .8;
	slope *= 1.0 - smoothstep(4000.0, 18000.0, distance_m);
	vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	vec3 view_direction = normalize(observer_position - world_p);
	float fresnel = pow(1.0 - max(dot(normal, view_direction), 0.0), 4.0);
	float broad_tone = broad.x * 0.035;
	vec3 color = deep_color * (0.94 + broad_tone + dot(normal, sun_direction) * 0.14);
	color = mix(color, horizon_color * 0.69, fresnel * 0.40);
	vec3 halfway = normalize(view_direction + sun_direction);
	// A wide, dim sun glint instead of sharp plastic pinpoints.
	float sun_glint = pow(max(dot(normal, halfway), 0.0), 110.0);
	color += vec3(0.20, 0.18, 0.13) * sun_glint * (1.0 - smoothstep(3000.0, 12000.0, distance_m));
	// Native Environment distance fog affects water, islands and units equally.
	// No angle-based whitening: a low viewing angle must not fog nearby water.
	ALBEDO = color;
}
