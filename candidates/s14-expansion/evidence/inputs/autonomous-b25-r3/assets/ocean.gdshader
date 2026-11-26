shader_type spatial;
render_mode cull_disabled;
varying vec3 world;

float hash(vec2 p) {
 return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453);
}
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float ripple(vec2 p, float t) {
 float n=noise(p*0.095+vec2(t*0.035,-t*0.02));
 return 0.12*sin(dot(p,vec2(0.21,0.13))+t*1.1+n*4.0)
 +0.075*sin(dot(p,vec2(-0.16,0.27))-t*0.85+n*3.0)
 +0.035*sin(dot(p,vec2(0.63,-0.31))+t*1.7);
}
void vertex(){
 world=VERTEX;
 VERTEX.y=0.35*sin(dot(VERTEX.xz,vec2(0.015,0.007))+TIME*0.65)
 +0.22*sin(dot(VERTEX.xz,vec2(-0.009,0.022))+TIME*0.9);
}
void fragment(){
 vec2 p=world.xz;
 float h=ripple(p,TIME);
 float dx=(ripple(p+vec2(0.4,0),TIME)-h)/0.4;
 float dz=(ripple(p+vec2(0,0.4),TIME)-h)/0.4;
 float fade=1.0/(1.0+length(VERTEX)*0.0015);
 vec3 world_normal=normalize(vec3(-dx*fade,1.0,-dz*fade));
 NORMAL=normalize((VIEW_MATRIX*vec4(world_normal,0.0)).xyz);
 float patch=noise(p*0.018+TIME*0.006);
 ALBEDO=mix(vec3(0.025,0.095,0.125),vec3(0.065,0.17,0.19),patch);
 METALLIC=0.1;
 ROUGHNESS=0.22+0.08*patch;
 SPECULAR=0.6;
}
