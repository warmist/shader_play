//!program raymarch fragment
#version 330
uniform vec3 offset; //!clamp
uniform float angle; //!clamp
uniform float eng_time;
//!include hg_sdf.glsl
//!include sdf_libs.glsl
vec2 sdf(vec3 p)
{

	float box0=fOctahedron(p,3);
	//pR(p.xy,PI/4.0);
	pR(p.xz,PI/4.0);
	//float g=pMod1(p.y,8);
	//float u=pMod1(p.z,8);
	//float c=1;
	float g=1;
	float u=1;
	//
	//vec3 off=vec3(r,-r,r)*offset*6;
	//float g=pMod1(p.z,8);
	//pR(p.xy,eng_time+g*0.175);
	
	
	float c=pModPolar(p.xy,4);
	float r=(cos(c*1377)+sin(g*7451.0154)+cos(g*331575))/3;
	pR(p.yz,eng_time*.2);
	float box1=fTorus(p+offset,0.2,1);
	box1=fOpUnionRound(box0,box1,angle);
	float box2=0;
	if(c==0)
		box2=fIcosahedron(p+offset+vec3(0,1,0),0.5);
	else
		box2=fDodecahedron(p+offset+vec3(0,1,0),0.5);

	return opUnion(vec2(box1,3),vec2(box2,abs(c+g*15+u*777)+8)); 
}
vec3 sdf_mat(vec3 pos,float mat)
{
	if(mat>5)
		return vec3(sin(pos.x*15)*0.5+0.5,1,0);
	else
		return vec3(sin(pos.y*0.25)*0.5+0.5,1,1);
}
//!include raymarch_mat.glsl