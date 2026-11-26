shader_type sky;

// The same clock and wind as the sea. No TIME or screen-space cloud positions.
uniform float simulation_time = 0.0;
uniform vec3 observer_position = vec3(0.0);
uniform vec2 wind_direction = vec2(0.84, 0.54);
uniform vec3 sun_direction = vec3(0.5792, 0.5736, 0.5792);
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform bool clouds_enabled = true;
uniform vec3 zenith_color : source_color = vec3(0.32, 0.56, 0.72);
uniform vec3 horizon_color : source_color = vec3(0.67, 0.77, 0.80);

void sky() {
	vec3 ray = normalize(EYEDIR);
	float elevation = max(ray.y, 0.0);
	vec3 sky_color = mix(horizon_color, zenith_color, pow(smoothstep(0.0, 0.85, elevation), 0.55));
	float toward_sun = max(dot(ray, sun_direction), 0.0);
	sky_color += vec3(0.14, 0.105, 0.06) * pow(toward_sun, 12.0);
	sky_color += vec3(0.8, 0.72, 0.53) * smoothstep(0.99968, 0.99991, toward_sun);
	if (clouds_enabled && !AT_CUBEMAP_PASS && ray.y > -0.015) {
		// Shallow curved shell avoids the straight plane/horizon intersection.
		// Only appearance uses curvature: collision and sea level stay unchanged.
		float radius = 180000.0;
		// Distant appearance dome: gently limited vertical parallax prevents a
		// close flat cloud-sheet intersection when the observer climbs high.
		float height = 6200.0;
		vec3 origin = vec3(observer_position.x, 2000.0 * (1.0 - exp(-max(observer_position.y, 0.0) / 5000.0)) + radius, observer_position.z);
		float b = dot(origin, ray);
		float c = dot(observer_position.xz, observer_position.xz) +
			2.0 * radius * (origin.y - radius - height) + (origin.y - radius) * (origin.y - radius) - height * height;
		float distance_m = max(0.0, -b + sqrt(max(0.0, b * b - c)));
		vec2 cloud_p = (observer_position.xz + ray.xz * distance_m - wind_direction * simulation_time * 12.0) / 32000.0;
		float broad = texture(cloud_noise, cloud_p).r;
		float detail = texture(cloud_noise, cloud_p * 3.17 + vec2(0.31, 0.71)).r;
		float density = smoothstep(0.55, 0.73, broad * 0.91 + detail * 0.09);
		float sunward = texture(cloud_noise, cloud_p + normalize(sun_direction.xz) * 0.012).r;
		float lit_edge = clamp((broad - sunward) * 3.0, -0.18, 0.22);
		vec3 cloud_color = mix(vec3(0.54, 0.64, 0.70), vec3(1.0, 0.98, 0.91), 0.48 + broad * 0.42 + lit_edge);
		float air_fade = smoothstep(-0.005, 0.16, ray.y) * exp(-distance_m * 0.000010);
		sky_color = mix(sky_color, cloud_color, density * air_fade * 0.96);
		// A second, much weaker wispy layer remains part of the same world dome.
		float thin = smoothstep(0.62, 0.83, texture(cloud_noise, cloud_p * vec2(0.8, 1.5) + vec2(0.28, 0.5)).r);
		sky_color = mix(sky_color, vec3(0.83, 0.88, 0.90), thin * smoothstep(0.45, 0.65, detail) * air_fade * smoothstep(0.12, 0.4, ray.y) * 0.055);
	}
	// Below the mathematical horizon the background matches far-water haze.
	COLOR = mix(horizon_color, sky_color, smoothstep(-0.025, 0.025, ray.y));
}
