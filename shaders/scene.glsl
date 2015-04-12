//!program raymarch fragment
#version 330

//!include sdf_libs.glsl

vec2 sdf(vec3 p)
{
	float c=pMod2(p.x,8);
	float g=pMod1(p.y,8);
	

	float box1=sdBox2(p.xz,vec2(1,abs(c*c)*0.15+0.15));
	float box2=sdBox2(p.yz,vec2(1,abs(g*g)*0.15+0.15));

	return vec2(min(box1,box2),abs(c+5*g+8));
}

//!include raymarch.glsl