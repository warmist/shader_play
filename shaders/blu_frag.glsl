//!program blu fragment
#version 330

out vec3 color;
uniform float eng_time;

void main(){
    color = vec3(sin(eng_time)*0.5+0.5,0,1);
}