shader_type spatial;
render_mode unshaded, shadows_disabled, cull_front, depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler3D cloud_detail : repeat_enable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float cloud_bottom = 1050.0;
uniform float cloud_top = 2600.0;
uniform float cloud_extent = 45000.0;
uniform float cloud_reach_m = 22000.0;
uniform float footprint_scale = 1.0;
uniform float density_gain = 1.0;
uniform float scene_time = 0.0;
uniform vec2 wind_mps = vec2(6.3, 4.0);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.97, 0.90);
uniform vec3 cloud_shade : source_color = vec3(0.50, 0.62, 0.72);
uniform vec3 sea_haze : source_color = vec3(0.67, 0.77, 0.80);
varying vec3 volume_point;
const vec2 GRID_M = vec2(4800.0,4200.0);

void vertex() {
	volume_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 random2(vec2 cell) {
	return fract(sin(vec2(dot(cell,vec2(127.1,311.7)),dot(cell,vec2(269.5,183.3)))) * 43758.5453);
}

float distance_to_puff(vec3 p, vec3 center, vec3 radius_m) {
	return 1.0 - length((p-center)/radius_m);
}

float smooth_union(float a, float b) {
	float x = clamp(0.5 + (a-b)*2.0,0.0,1.0);
	return mix(b,a,x)+0.20*x*(1.0-x);
}

float cloud_shape(vec3 p, vec2 position, vec2 cell, vec2 random, mat2 spin, out vec3 shade_ref) {
	vec2 q = position - cell*GRID_M - GRID_M*0.5 - (random-0.5)*vec2(1020.0,890.0);
	q = spin * q;
	float high = mix(0.58,1.10,random.y);
	float wide = mix(0.62,1.01,random.x);
	float by = cloud_bottom + (cloud_top-cloud_bottom) * (0.15 + 0.15*random.y);
	vec3 c = vec3(q.x, (p.y-by) * 1550.0/(cloud_top-cloud_bottom), q.y);
	shade_ref = c;
	if (abs(q.x)>2020.0 || abs(q.y)>1540.0 || random.x<.10) { return -1.0; }
	float a = distance_to_puff(c, vec3(-200.0,-50.0,40.0), vec3(mix(890.0,1370.0,random.y)*wide,400.0*high,720.0*wide));
	float b = distance_to_puff(c, vec3(-680.0,130.0+220.0*random.x,-160.0+150.0*random.y), vec3(860.0*wide,mix(390.0,615.0,random.x)*high,715.0*wide));
	float d = distance_to_puff(c, vec3(130.0+210.0*random.y,250.0+160.0*random.y,170.0), vec3(900.0*wide,mix(475.0,650.0,random.y)*high,820.0*wide));
	float e = distance_to_puff(c, vec3(860.0+170.0*random.x,128.0,-140.0), vec3(mix(610.0,840.0,random.x)*wide,490.0*high,670.0*wide));
	float f = random.y>0.23 ? distance_to_puff(c, vec3(-530.0+200.0*random.x,100.0,650.0), vec3(880.0*wide,405.0*high,640.0*wide)) : -1.0;
	return smooth_union(smooth_union(smooth_union(a,b),smooth_union(d,e)),f);
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 ray = normalize(volume_point - eye);
	// Slab plus horizontal extents; identical on either side of the cloud layer.
	vec3 lo = vec3(-cloud_extent, cloud_bottom, -cloud_extent);
	vec3 hi = vec3(cloud_extent, cloud_top, cloud_extent);
	vec3 safe_ray = mix(ray, vec3(0.00001), lessThan(abs(ray), vec3(0.00001)));
	vec3 ta = (lo - eye) / safe_ray;
	vec3 tb = (hi - eye) / safe_ray;
	vec3 tlo = min(ta, tb);
	vec3 thi = max(ta, tb);
	float enter_m = max(0.0, max(max(tlo.x, tlo.y), tlo.z));
	float exit_m = min(cloud_reach_m, min(min(thi.x, thi.y), thi.z));
	if (exit_m <= enter_m) { discard; }
	float raw_depth = texture(scene_depth, SCREEN_UV).r;
	// Compatibility has [-1,1] depth NDC; Forward+/Mobile use [0,1].
	if (raw_depth > 0.000001) {
		float depth_z = CLIP_SPACE_FAR < -0.5 ? raw_depth * 2.0 - 1.0 : raw_depth;
		vec4 local = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_z, 1.0);
		local.xyz /= max(0.000001, local.w);
		vec3 scene_point = (INV_VIEW_MATRIX * vec4(local.xyz, 1.0)).xyz;
		exit_m = min(exit_m, max(0.0, dot(scene_point - eye, ray) - 1.0));
	}
	if (exit_m <= enter_m) { discard; }
	float segment = exit_m - enter_m;
	float stride = max(23.0,segment / 48.0);
	// Tiny static per-pixel offset breaks long-ray sampling bands without animating.
	float jitter = fract(sin(dot(FRAGCOORD.xy,vec2(127.1,311.7)))*43758.5453);
	float cursor = enter_m + mix(0.13,0.87,jitter) * stride;
	float opacity = 0.0;
	vec3 composite = vec3(0.0);
	vec2 shift = wind_mps * scene_time;
	vec2 prev_cell = vec2(1e8);
	vec2 cell_random = vec2(0.0);
	mat2 cell_spin = mat2(vec2(1.0,0.0),vec2(0.0,1.0));
	for (int i = 0; i < 48; i++) {
		if (cursor >= exit_m || opacity > 0.985) { break; }
		vec3 p = eye + ray * cursor;
		vec3 weather_p = p - vec3(shift.x,0.0,shift.y);
		vec2 place = weather_p.xz/footprint_scale + vec2(1750.0,2450.0);
		vec2 cell = floor(place/GRID_M);
		if (any(notEqual(cell,prev_cell))) {
			prev_cell = cell;
			cell_random = random2(cell);
			float angle = (cell_random.x-.5)*1.45;
			float c = cos(angle);
			float s = sin(angle);
			cell_spin = mat2(vec2(c,s),vec2(-s,c));
		}
		vec3 shape_ref;
		float shell = cloud_shape(p,place,cell,cell_random,cell_spin,shape_ref);
		if (shell > -0.28) {
			float macro = textureLod(cloud_detail, weather_p*vec3(.00063,.00079,.00063),0.0).r;
			float fluff = textureLod(cloud_detail, weather_p*vec3(.00182,.0022,.00182)+vec3(.41,.62,.37),0.0).r;
			float n = macro*0.74 + fluff*0.26;
			float density = smoothstep(-0.19,0.26,shell+(n-.53)*0.63);
			density *= smoothstep(cloud_bottom,cloud_bottom+190.0,p.y);
			density *= 1.0-smoothstep(cloud_top-155.0,cloud_top,p.y);
			float fade = 1.0-smoothstep(cloud_reach_m*0.47,cloud_reach_m,cursor);
			float a = (1.0 - exp(-density * min(stride,exit_m-cursor+stride*0.5) * 0.0048 * density_gain))*fade;
			float h = clamp((p.y-cloud_bottom)/(cloud_top-cloud_bottom),0.0,1.0);
			float sunlight = clamp(0.45+0.75*h+0.26*(n-0.52)+dot(shape_ref.xz,vec2(.00004,.00004))-0.13*density,0.0,1.0);
			vec3 shade = mix(cloud_shade,cloud_light,sunlight);
			shade = mix(shade,sea_haze,smoothstep(cloud_reach_m*.28,cloud_reach_m,cursor)*0.55);
			composite += (1.0-opacity)*a*shade;
			opacity += (1.0-opacity)*a;
		}
		cursor += stride;
	}

	if (opacity < 0.005) { discard; }
	ALBEDO = composite / opacity;
	ALPHA = opacity;
}
