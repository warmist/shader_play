//!program blu vertex
#version 330

layout(location = 0) in vec3 vertexPosition_modelspace;

uniform vec2 eng_resolution;

varying vec3 pos;
varying flat ivec2 real_pos;
void main()
{
    gl_Position.xyz = vertexPosition_modelspace;
    gl_Position.w = 1.0;
    pos=vertexPosition_modelspace;
    real_pos=ivec2(((vertexPosition_modelspace.xy+vec2(1,1))/2)*eng_resolution);
}