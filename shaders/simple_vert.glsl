//!program main vertex
#version 330

layout(location = 0) in vec3 vertexPosition_modelspace;

varying vec3 pos;
void main()
{
    gl_Position.xyz = vertexPosition_modelspace;
    gl_Position.w = 1.0;
    pos=vertexPosition_modelspace;
}