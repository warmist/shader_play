//!program raymarch fragment
#version 330
uniform float offset; //!clamp
//!include sdf_libs.glsl
vec2 sdf(vec3 p)
{
	//float c=pMod1(p.x,8);
	//float g=pMod1(p.y,8);
	//float u=pMod1(p.z,8);
	float c=1;
	float g=1;
	float u=1;
	float r=(cos(c*1377)+sin(g*7451.0154)+cos(g*331575))/3;
	vec3 off=vec3(r,-r,r)*offset*6;
	float box1=sdTorus(p+off,vec2(1,0.2));
	float box2=udRoundBox(p+vec3(0,1,0)+off,vec3(0.1,0.1,0.1),0.1);

	return opUnion(vec2(box1,3),vec2(box2,abs(c+g*15+u*777)+8)); 
}

//!include raymarch.glsl