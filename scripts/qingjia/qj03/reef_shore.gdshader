shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float simulation_time = 0.0;
varying vec2 coords;
void vertex(){ coords=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment(){
	float t=clamp(COLOR.a,0.0,1.0);
	float ripples=sin(coords.x*.046+coords.y*.032+sin(coords.x*.019-coords.y*.016)*1.25-simulation_time*.75)*.5+.5;
	float foam=smoothstep(.88,1.0,t)*(.26+.43*ripples);
	vec3 teal=mix(vec3(.052,.265,.273),vec3(.117,.463,.452),smoothstep(.08,.92,t));
	ALBEDO=mix(teal,vec3(.73,.84,.75),foam);
	ALPHA=smoothstep(.0,.91,t)*(.83+.12*ripples);
}
