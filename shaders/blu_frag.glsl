//!program blu fragment
#version 330

out vec3 color;
uniform float eng_time;
uniform vec3 eng_mouse;
varying vec3 pos;
void main(){
	vec2 delta=pos.xy-eng_mouse.xy;
	float d=dot(delta,delta);
	d=clamp(d,0,1);
    color = vec3(sin(eng_time*1)*0.5+0.5,d/(eng_mouse.z+1),0);
}