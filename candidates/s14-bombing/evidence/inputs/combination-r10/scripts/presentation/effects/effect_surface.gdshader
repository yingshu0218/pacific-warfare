shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Original analytic masks. One material per reusable mesh slot; no TIME/random state.
uniform int effect_mode = 0; // cloud, water, foam, tracer, fire, flash
uniform vec4 tint : source_color = vec4(1.0);
uniform float fade = 1.0;
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform vec3 trail_axis = vec3(0.0);
uniform float trail_stretch = 1.0;
uniform float water_fade_m = 0.0;
varying float world_height_m;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}
float noise2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float cloud(vec2 p) {
	return noise2(p)*0.6 + noise2(p*2.1)*0.28 + noise2(p*4.3)*0.12;
}
void vertex() {
	if (effect_mode == 0 || effect_mode >= 4) {
		vec2 axis = (VIEW_MATRIX * vec4(trail_axis,0.0)).xy;
		if (length(axis)>0.001) {
			axis=normalize(axis);
			VERTEX.xy=mat2(axis,vec2(-axis.y,axis.x))*vec2(VERTEX.x*trail_stretch,VERTEX.y);
		}
		// Camera-facing quad, retaining each pooled instance's world scale.
		MODELVIEW_MATRIX = mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0),
			vec4(0,length(MODEL_MATRIX[1].xyz),0,0),
			vec4(0,0,length(MODEL_MATRIX[2].xyz),0), MODELVIEW_MATRIX[3]);
	}
	world_height_m=(INV_VIEW_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0)).y;
}
void fragment() {
	vec2 p = UV*2.0-1.0;
	float radius = length(p);
	float grain = cloud(UV*5.0 + vec2(seed*29.0,seed*17.0) + vec2(phase*0.09,-phase*0.12));
	float mask;
	vec3 color = tint.rgb;
	if (effect_mode == 0) {
		float contour = radius + (grain-0.5)*0.42;
		mask = (1.0-smoothstep(0.45,1.0,contour)) * mix(0.55,1.0,grain);
		color *= mix(0.7,1.3,grain);
	} else if (effect_mode == 1) {
		mask = mix(0.38,0.9,grain) * (1.0-smoothstep(0.65,1.0,UV.y));
		color *= mix(0.8,1.1,grain);
	} else if (effect_mode == 2) {
		float ring = smoothstep(0.16,0.45,radius) * (1.0-smoothstep(0.72,1.0,radius));
		mask = ring * smoothstep(0.24,0.64,grain) * 0.75;
	} else if (effect_mode == 3) {
		float core = pow(max(0.0,1.0-abs(p.x)),1.5);
		mask = core * pow(max(0.0,1.0-UV.y),0.9);
		color = mix(tint.rgb,vec3(1.0,0.96,0.7),core*(1.0-UV.y));
	} else if (effect_mode == 4) {
		mask = (1.0-smoothstep(0.12,1.0,radius+(grain-0.5)*0.5));
		color = mix(tint.rgb,vec3(1.0,0.86,0.25),max(0.0,1.0-radius*2.0));
	} else {
		mask = pow(max(0.0,1.0-radius),1.5);
	}
	if (effect_mode == 0 || effect_mode == 4) {
		// Noise may expand the radial contour; UV edges must still be exactly clear.
		float edge=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
		mask *= smoothstep(0.0,0.12,edge);
	}
	// A large billboard can intersect the opaque y=0 sea inside its UV mask.
	// Fade before that depth boundary rather than exposing a hard waterline cut.
	if (water_fade_m>0.0) mask *= smoothstep(0.05,water_fade_m,world_height_m);
	ALBEDO = color;
	ALPHA = mask * tint.a * fade;
	if (ALPHA < 0.012) discard;
}
