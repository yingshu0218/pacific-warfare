shader_type spatial;
render_mode cull_disabled;
varying vec3 land_xyz;
varying vec3 land_normal;
float hash21(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float cloud(vec2 xy){
	vec2 p=floor(xy), f=fract(xy);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(p),hash21(p+vec2(1,0)),f.x),mix(hash21(p+vec2(0,1)),hash21(p+1.0),f.x),f.y);
}
void vertex() {
	land_xyz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	land_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	vec2 q=land_xyz.xz;
	float terrain_noise=cloud(q*.008)*.55+cloud(q*.023)*.29+cloud(q*.086)*.16;
	float grain=cloud(q*.67)*.12;
	float slope=1.0-abs(normalize(land_normal).y);
	float stone=smoothstep(.10,.39,slope+.18*terrain_noise);
	float heights=smoothstep(95.0,215.0,land_xyz.y);
	vec3 green=mix(vec3(.105,.224,.128),vec3(.313,.366,.214),terrain_noise);
	vec3 shale=mix(vec3(.285,.321,.275),vec3(.529,.519,.437),terrain_noise);
	vec3 sand=mix(vec3(.526,.48,.337),vec3(.775,.695,.482),terrain_noise);
	vec3 forest=mix(green,shale,stone*.91+heights*.07);
	float beach=1.0-smoothstep(2.0+terrain_noise*5.0,9.0+terrain_noise*8.5,land_xyz.y);
	vec3 color=mix(forest,sand,beach*(1.0-stone*.74));
	ALBEDO=color*(.91+grain);
	ROUGHNESS=.96;
	SPECULAR=.06;
}
