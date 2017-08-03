//!program main fragment
#version 330

out vec4 color;
uniform float val; //!clamp
uniform float val2; //!clamp
uniform float time_off;
varying vec3 pos;
uniform float eng_time;
uniform vec3 eng_mouse;
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main(){
	float r=length(pos);
	float r2=length(pos.xy-eng_mouse.xy)*val2*100*eng_mouse.z;
	float v1=sin(r*5+0.5+eng_time)+sin(r*20+0.5+eng_time*50*val)+2;
	float v2=sin(r*5+0.5+(eng_time+time_off+r2))+sin(r*20+0.5+(eng_time+time_off+r2)*50*val)+2;
    color = vec4(hsv2rgb(vec3(v1/2,v2/2,v2/2)),v2/2);
}