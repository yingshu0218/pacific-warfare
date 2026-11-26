shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float simulation_time = 0.0;
varying vec3 world_p;
void vertex(){ world_p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
	float foam=pow(COLOR.a,10.0)*(0.42+0.10*sin(world_p.x*.017+world_p.z*.013-simulation_time*.7));
	ALBEDO=mix(vec3(.12,.38,.40),vec3(.70,.80,.74),foam);
	ALPHA=COLOR.a*.42;
}
