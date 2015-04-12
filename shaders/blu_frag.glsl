//!program blu fragment
#version 330

out vec3 color;
uniform float eng_time;
uniform vec3 eng_mouse;
uniform vec2 eng_resolution;
varying vec3 pos;

void main(){
	float aspect=eng_resolution.x/eng_resolution.y;
	vec2 mouse=eng_mouse.xy;
	mouse.x*=aspect;
	vec2 delta=pos.xy-mouse;
	float d=length(delta);
	d=clamp(d,0,1);
    color = vec3(sin(eng_time*1)*0.5+0.5,d,0);
}