shader_type spatial;
render_mode cull_disabled;
uniform float simulation_time = 0.0;
varying vec3 world_p;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),f.x),f.y);
}
void vertex(){world_p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	// Metre-scale, directionally related ripples. Domain warping breaks long
	// parallel stripes; every frequency fades before it becomes sub-pixel.
	vec2 p=world_p.xz;vec2 d=normalize(vec2(.84,.54));vec2 e=normalize(vec2(.95,.30));
	float warp=noise2(p*.035)*4.0;
	float q=dot(p,d)*1.2+warp-simulation_time*1.1;
	float r=dot(p,e)*2.7+noise2(p*.08)*3.0-simulation_time*1.5;
	float s=dot(p,d)*.45+noise2(p*.012)*5.0-simulation_time*.55;
	float fq=1.0-smoothstep(.7,2.8,fwidth(q));
	float fr=1.0-smoothstep(.7,2.8,fwidth(r));
	float fs=1.0-smoothstep(.7,2.8,fwidth(s));
	vec2 grad=d*(.028*sin(q)*fq+.012*sin(s)*fs)+e*.014*sin(r)*fr;
	vec3 n=normalize(vec3(-grad.x,1.0,-grad.y));
	NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
	float horizon=pow(1.0-max(0.0,dot(NORMAL,VIEW)),5.0);
	ALBEDO=mix(vec3(.032,.125,.171),vec3(.15,.28,.33),horizon*.65);
	vec2 cell=p*.18+vec2(.06,-.02)*simulation_time;
	float grain=(noise2(cell)-.5)*(1.0-smoothstep(.4,1.5,length(fwidth(cell))));
	ALBEDO+=vec3(.008,.015,.019)*grain;
	ROUGHNESS=.56;METALLIC=.04;SPECULAR=.30;
}
