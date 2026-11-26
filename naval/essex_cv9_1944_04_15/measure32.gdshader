shader_type spatial;
render_mode cull_back;
uniform mat4 ship_inverse = mat4(1.0);
varying vec3 ship_pos;
void vertex(){ship_pos=(ship_inverse*MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 light=vec3(0.51,0.55,0.58), dark=vec3(0.14,0.18,0.21);
 float z=ship_pos.z, y=ship_pos.y;
 // Major irregular areas only. Reconstructed from E01-E03; not colorimetric paint chips.
 bool p=ship_pos.x<0.0;
 bool black=p ? (z < -23.0-y*3.3 && z > -115.0+y*1.7 || z>72.0-y*1.4 || (z>1.0+y*2.3 && z<22.0+y)) : (z>67.0-y*1.5 || z < -58.0+y*2.2 || (z>22.0-y*2.8 && z<48.0-y*2.2));
 ALBEDO=y< -0.2 ? vec3(0.18,0.22,0.23) : (black ? dark:light);
 ROUGHNESS=0.9;
}
