//!program symmetry fragment
#version 330

out vec4 color;
varying vec3 pos;
uniform float eng_time;
uniform vec3 eng_mouse;
uniform vec2 eng_resolution;

uniform float ensmallen; //!min 1 !max 10
uniform float mirror_world; //!min -1 !max 1
uniform float step_angle; //!angle
#define M_PI 3.14159265359

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float random (in vec2 st) { 
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))
                 * 43758.5453123);
}
float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    // Smooth Interpolation

    // Cubic Hermine Curve.  Same as SmoothStep()
    //vec2 u = f*f*(3.0-2.0*f);
    vec2 u = smoothstep(0.,1.,f);

    // Mix 4 coorners porcentages
    return mix(a, b, u.x) + 
            (c - a)* u.y * (1.0 - u.x) + 
            (d - b) * u.x * u.y;
}
float sh_circle(in vec2 st,in float rad,in float fw)
{
	return 1-smoothstep(rad-fw*0.75,rad+fw*0.75,dot(st,st)*4);
}
float sh_ring(in vec2 st,in float rad1,in float rad2,in float fw)
{
	return sh_circle(st,rad1,fw)-sh_circle(st,rad2,fw);
}
float sh_polyhedron(in vec2 st,in float num,in float size,in float rot,in float fw)
{
	float a=atan(st.x,st.y)+rot;
	float b=6.28319/num;
	return 1-(smoothstep(size-fw,size+fw, cos(floor(0.5+a/b)*b-a)*length(st.xy)));
}
float sh_rectangle(in vec2 st,in vec2 size,in float fw)
{
	float v=length(max(abs(st)-size,0));
 	return 1-smoothstep(0,+fw,v);
}
float sh_letter_f(in vec2 st,in float fw)
{
	float ret=0;
	float w=0.05;
	float s2=0.9;
	float s=0.25;
	//ret=sh_rectangle(st,vec2(0.5,.25),fw);
	ret=max(ret,sh_rectangle(st-vec2(0,0.5),vec2(s,w),fw));
	ret=max(ret,sh_rectangle(st-vec2(s*s2-s,0.2),vec2(s*s2,w),fw));
	ret=max(ret,sh_rectangle(st-vec2(-s,w),vec2(w,0.5),fw));
	return ret;
}
float sh_polar_thing(in vec2 st,in float fw)
{
	vec2 s=st;//mod(st,(noise(vec2(eng_time,0))+0.4)*mirror_world);
	float a=atan(s.y,s.x);
	float r=length(st)*2;

	float f=(a+M_PI-cos(a*2)*2*sin(a*2));
	float va=1;
	float vv=.5;

	float v=0.025;//fwidth(f);

	return 1-smoothstep(f-v,f+v,r);
}
void t_rot(inout vec2 st,float angle)
{
	float c=cos(angle);
	float s=sin(angle);
	mat2 m=mat2(c,-s,s,c);
	st*=m;
}
void t_ref(inout vec2 st,float angle)
{
	float c=cos(2*angle);
	float s=sin(2*angle);
	mat2 m=mat2(c,s,s,-c);
	st*=m;
}
//TODO: wallpaper groups
float thing(vec2 p,float fw)
{
	return sh_polar_thing(p,fw)-sh_polar_thing(p*1.1,fw);
}
float pMod1(inout float p,float size)
{
	float halfsize=size*0.5;
	float c= floor((p+halfsize)/size);
	p=mod(p+halfsize,size)-halfsize;
	return c;
}
vec2 pMod2(inout vec2 p,float size)
{
	vec2 halfsize=vec2(size*0.5);
	vec2 c= floor((p+halfsize)/size);
	p=mod(p+halfsize,size)-halfsize;
	return c;
}
vec3 pMod3(inout vec3 p,float size)
{
	vec3 halfsize=vec3(size*0.5);
	vec3 c= floor((p+halfsize)/size);
	p=mod(p+halfsize,size)-halfsize;
	return c;
}
void Barycentric(vec2 p, vec2 a,vec2 b,vec2 c,out vec3 bc)
{
    vec2 v0 = b - a, v1 = c - a, v2 = p - a;
    float d00 = dot(v0, v0);
    float d01 = dot(v0, v1);
    float d11 = dot(v1, v1);
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);
    float denom = d00 * d11 - d01 * d01;
    bc.x = (d11 * d20 - d01 * d21) / denom;
    bc.y = (d00 * d21 - d01 * d20) / denom;
    bc.z = 1.0f - bc.x - bc.y;
}
vec3 to_barycentric(in vec2 p)
{
	float angle_offset=0;
	float a_d=M_PI*(2.0/3.0);
	vec2 p1=vec2(cos(angle_offset),sin(angle_offset));
	vec2 p2=vec2(cos(a_d+angle_offset),sin(a_d+angle_offset));
	vec2 p3=vec2(cos(-a_d+angle_offset),sin(-a_d+angle_offset));
	vec3 bc;
	Barycentric(p,p1,p2,p3,bc);
	return bc;
}
vec2 from_barycentric(in vec2 p)
{
	float angle_offset=step_angle;
	float a_d=M_PI*(2.0/3.0);
	vec2 p1=vec2(cos(angle_offset),sin(angle_offset));
	vec2 p2=vec2(cos(a_d+angle_offset),sin(a_d+angle_offset));
	vec2 p3=vec2(cos(-a_d+angle_offset),sin(-a_d+angle_offset));
	return p1*p.x+p2*p.y+p3*(1-p.x-p.y);
}
vec2 from_barycentric(in vec3 p)
{
	float angle_offset=step_angle;
	float a_d=M_PI*(2.0/3.0);
	vec2 p1=vec2(cos(angle_offset),sin(angle_offset));
	vec2 p2=vec2(cos(a_d+angle_offset),sin(a_d+angle_offset));
	vec2 p3=vec2(cos(-a_d+angle_offset),sin(-a_d+angle_offset));

	return p1*p.x+p2*p.y+p3*p.z;
}
float map(in vec2 p,in float fw)
{
	float ret=0;

	vec2 p2=p*ensmallen;
	vec3 bc=to_barycentric(p2);
	//t_rot(bc,M_PI/3);
	vec3 c=pMod3(bc,0.45);
	t_rot(bc.xy,(-M_PI/6)*c.x);
	t_rot(bc.yz,(-M_PI/6)*c.y);
	t_rot(bc.zx,(-M_PI/6)*c.z);
	//p2=from_barycentric(bc);
	//float c2=pMod1(p2.y,1);
	/*p2+=vec2(mirror_world);

	t_rot(p2,M_PI/3);
	p2-=vec2(mirror_world);
	vec2 c=pMod2(p2,1.5);

	

	
	t_rot(p2,M_PI/3);
	p2+=vec2(mirror_world);
	vec2 c2=pMod2(p2,1);
	p2-=vec2(mirror_world);


	t_rot(p2,M_PI/3);*/

	//p2+=vec2(mirror_world);
	ret=sh_polyhedron(bc.xy,5,0.2,0,fw)-sh_polyhedron(bc.xy,5,0.18,0,fw);
	//ret=abs(bc.z)*abs(bc.x)*abs(bc.y)*20;
	//ret=c2.y/10;
	return ret;
}
float map_shapes_swim(in vec2 p,in float fw)
{
	float ret=0;
	vec2 p2=p;
	float rsize=0.5;
	
	p2*=2;
	//p2.y*=sqrt(2);
	t_rot(p2,M_PI/4);
	//p2=mod(p2,1)-0.5;
	float c1=pMod1(p2.x,1);
	float c2=pMod1(p2.y,1);
	t_rot(p2,-M_PI/4);
	float n1=noise(vec2(eng_time/10,c1+c2-c1*c2*4));
	float v_rot=n1*10+1;
	v_rot=clamp(v_rot,1,10);
	t_rot(p2,(M_PI/v_rot)+(c1+c2/2));
	//p2+=vec2(mirror_world,0);
	
	p2+=vec2((n1-0.5)*0.36,0);
	/*
	p2.y=mod(p2.y*tan(step_angle),1)/tan(step_angle);*/
	//p2.x=mod(p2.x,0.5)-0.25;
	//float c=pMod1(p2.x,0.5);
	//p2.y/=sqrt(2);
	//t_ref(p2,(M_PI/2)*c);
	float num=3;
	if(abs(cos(c1+c2))<n1/2)
		num=4;
	else if(abs(cos(c1+c2))<n1)
		num=5;
	ret=sh_polyhedron(p2,num,ensmallen,0,fw)-sh_polyhedron(p2,num,ensmallen-0.1,0,fw);
	//ret=sh_letter_f(p2*ensmallen,fw);
	
	//ret=max(ret,sh_letter_f(p2*ensmallen-vec2(mirror_world,0),fw));
	//ret=max(ret,sh_letter_f(p2,fw));
	//ret=max(ret,sh_rectangle(p2,vec2(rsize,rsize),fw)-sh_rectangle(p2,vec2(rsize-0.01,rsize-0.01),fw));//domain
	
	
	
	/*for(int i=0;i<8;i++)
	{
		t_ref(p2,M_PI/8);
		ret=max(ret,thing(p2+vec2(ensmallen,0),fw));
		t_ref(p2,0);
		//t_rot(p,step_angle);
	}*/
	return ret;
}
void main(){
	float phi=1.618033988;
	float phi1=1/phi;
	
	vec3 npos=pos;
	npos.x*=eng_resolution.x/eng_resolution.y;
	float fw=fwidth(length(npos.xy));
	float outv=0;
	//infinite axis of reflection
	outv=map(npos.xy,fw);
	color = vec4(vec3(outv),1);
}