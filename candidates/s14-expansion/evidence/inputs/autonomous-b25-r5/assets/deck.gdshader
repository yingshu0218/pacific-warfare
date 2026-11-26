shader_type spatial;
render_mode cull_disabled;
varying vec2 deck_position;
void vertex(){deck_position=VERTEX.xz;}
float hash(float p){return fract(sin(p*127.1)*43758.5453);}
void fragment(){
 float board=floor(deck_position.x/0.24);
 vec2 grid=vec2(deck_position.x/0.24,(deck_position.y+hash(board)*3.8)/3.8);
 vec2 edge=min(fract(grid),1.0-fract(grid));
 vec2 aa=max(fwidth(grid),vec2(0.0001));
 float longitudinal=1.0-smoothstep(0.008,0.008+aa.x,edge.x);
 float end_seam=1.0-smoothstep(0.0015,0.0015+aa.y,edge.y);
 float variation=hash(board+floor(grid.y)*17.3);
 vec3 timber=mix(vec3(0.46,0.39,0.28),vec3(0.50,0.43,0.31),variation);
 float seam=clamp(longitudinal+end_seam,0.0,1.0);
 ALBEDO=mix(timber,timber*0.63,seam*0.32);
 ROUGHNESS=0.87;
 SPECULAR=0.22;
}
