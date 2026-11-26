shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Original analytic masks. One material per reusable mesh slot; no TIME/random state.
uniform int effect_mode = 0; // Legacy modes 0–5; muzzle 6, flak 7, impact smoke 8, flare 9, sparks 10
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
float lobed_radius(vec2 p, float profile) {
	// Rounded, overlapping eddies with different silhouettes for each profile.
	if (profile == 6.0) {
		float jet = length((p-vec2(0.18,-0.13))*vec2(1.15,1.0));
		float shoulder = length((p+vec2(0.36,0.02))*vec2(1.42,1.65));
		return min(jet,shoulder);
	}
	if (profile == 7.0) {
		float left = length((p+vec2(0.32,0.1))*1.5);
		float right = length((p-vec2(0.27,0.05))*1.35);
		float crown = length((p-vec2(0.03,0.37))*1.8);
		return min(crown,min(left,right));
	}
	float stem = length((p+vec2(0.05,0.23))*vec2(1.7,1.07));
	float head = length((p-vec2(0.05,0.23))*vec2(1.06,1.48));
	return min(stem,head);
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
	float grain = 0.0;
	if (effect_mode <= 8 && effect_mode != 3 && effect_mode != 5) {
		vec2 evolution = effect_mode >= 6 ? vec2(0.28,-0.33) : vec2(0.09,-0.12);
		grain = cloud(UV*5.0 + vec2(seed*29.0,seed*17.0) + phase*evolution);
	}
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
	} else if (effect_mode == 5) {
		mask = pow(max(0.0,1.0-radius),1.5);
	} else if (effect_mode <= 8) {
		float profile = float(effect_mode);
		p.y = -p.y;
		// Dark cores with soft, broken outer lobes. Later air entrainment
		// erodes the edge as the CPU grows and fades the world-space volume.
		float contour = lobed_radius(p,profile)+(grain-.47)*0.40+phase*0.14;
		float edge = mix(0.88,0.71,phase);
		mask = (1.0-smoothstep(0.24,edge,contour))*mix(0.54,1.0,grain);
		float lit = smoothstep(-0.6,0.55,p.y-p.x*0.37+(grain-.5)*1.4);
		color *= mix(.42,1.46,lit);
		if (effect_mode == 6) {
			color = mix(color,color*vec3(0.92,1.03,1.13),smoothstep(0.06,0.5,phase));
		}
	} else if (effect_mode == 9) {
		float flame = length(p*vec2(.85,1.4));
		float core = 1.0-smoothstep(0.10,0.48,flame);
		float halo = 1.0-smoothstep(0.15,0.87,flame);
		color = mix(tint.rgb,vec3(1.0,0.96,0.74),core);
		EMISSION = color*core*.65;
		mask = max(core,halo*.74);
	} else {
		// Five short streaks share one billboard and fan outward from contact.
		float angle = atan(p.y,p.x)+seed*6.2832;
		float spoke = fract(angle*0.7958+0.5)-0.5;
		float lane = floor(angle*0.7958+0.5);
		float end = 0.36+0.56*hash21(vec2(lane,seed));
		float front = end*mix(.32,1.0,phase);
		mask = (1.0-smoothstep(.009,.055,abs(spoke)*radius))
			* smoothstep(front-.18,front-.07,radius)*(1.0-smoothstep(front-.03,front,radius));
		color = mix(tint.rgb,vec3(1.0,.92,.65),smoothstep(front-.12,front,radius));
	}
	if (effect_mode == 0 || effect_mode == 4 || (effect_mode >= 6 && effect_mode <= 8)) {
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
