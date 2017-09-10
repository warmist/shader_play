//!program raymarch fragment
#version 330
uniform float offset; //!clamp
uniform float offset2; //!clamp
uniform float offset3; //!clamp
uniform float offset4; //!clamp
uniform float eng_time;
//!include sdf_libs.glsl

#define ROOT_GUESS t*2
#define EPS 0.1
float approx_root(float t)
{
	float x=0.5*(ROOT_GUESS+t/ROOT_GUESS);
	x=0.5*(x+t/x);
	return 0.5*(x+t/x);
}
float approx_root2(float t)
{
	return sqrt(t+EPS);
}
float approx_abs(float t)
{
	return approx_root(t*t);
}
float approx_max(float a,float b)
{
	return (a+b+approx_abs(a-b))*0.5;
}
float approx_min(float a,float b)
{
	return -approx_max(-a,-b);
}
float approx_floor(float x)
{
	return (floor(x+EPS)+floor(x-EPS))/2;
}
float approx_mod(float a,float b)
{
	return a-b*approx_floor(a/b);
}
float pAMod1(inout float p,float size)
{
	float halfsize=size*0.5;
	float c= approx_floor((p+halfsize)/size);
	p=approx_mod(p+halfsize,size)-halfsize;
	return c;
}
#define M_PI 3.14159265358979323846
float spHarmonics_old(vec3 p,vec4 m1,ivec4 m2)
{
	float r=length(p);
	float theta=acos(p.z/r);
	float phi=atan(p.y,p.x);

	float r_out=0;
	vec4 s=vec4(sin(m1[0]*phi),cos(m1[1]*phi),sin(m1[2]*theta),cos(m1[3]*theta));
	
	ivec4 mod_v=(m2 % 2)*2-ivec4(1); 
	
	if(m2[0]==0)
		mod_v[0]=1;
	if(m2[1]==0)
		mod_v[1]=1;
	if(m2[2]==0)
		mod_v[2]=1;
	if(m2[3]==0)
		mod_v[3]=1;

	//vec4 mod_v=vec4(1)-mod(m2,ivec4(2))*2;
	vec4 sgn_s=sign(s)*mod_v;
	
	
	s=pow(abs(s),m2);
	
	r_out=dot(s,sgn_s);

	return r-r_out;
}
float spHarmonics_polar(vec3 p,vec4 m1,ivec4 m2)
{
	
	float theta=p.y;
	float phi=p.z;

	float r_out=0;
	vec4 s=vec4(sin(m1[0]*phi),cos(m1[1]*phi),sin(m1[2]*theta),cos(m1[3]*theta));
	vec4 sgn_s=sign(s);

	s=pow(abs(s),m2);

	for(int k=0;k<4;k++)
	{
	
		if(m2[k]%2==0)
			sgn_s[k]*=-1;
		if(m2[k]==0)
			sgn_s[k]=1;
	}

	r_out=dot(s,sgn_s);	

	return r_out;
}
float spHarmonics_internal(vec3 p,vec4 m1,ivec4 m2,float r)
{
	
	float theta=acos(p.z/r);
	float phi=atan(p.y,p.x);

	float r_out=0;
	vec4 s=vec4(sin(m1[0]*phi),cos(m1[1]*phi),sin(m1[2]*theta),cos(m1[3]*theta));
	vec4 sgn_s=sign(s);

	s=pow(abs(s),m2);

	for(int k=0;k<4;k++)
	{
	
		if(m2[k]%2==0)
			sgn_s[k]*=-1;
		if(m2[k]==0)
			sgn_s[k]=1;
	}

	r_out=dot(s,sgn_s);	

	return r_out;
}
float spHarmonics(vec3 p,vec4 m1,ivec4 m2)
{
	float r=length(p);
	return r-spHarmonics_internal(p,m1,m2,r);
}

vec2 sdf_old(vec3 p)
{
	//float c=pMod1(p.x,8);
	//float g=pMod1(p.z,8);
	//float u=pMod1(p.z,8);
	//p.x=approx_abs(p.x)-2.5;
	p.y=abs(p.y)-0.25*cos(eng_time)-0.5;
	p.x=abs(p.x)-0.5;
	p.z=abs(p.z)-0.5;
	//p.y=abs(p.y)-0.5;
	pMod1(p.x,8);
	pMod1(p.z,8);	
	
	pMod1(p.y,8);

	float c=1;
	float g=1;
	//float u=1;
	float r=(cos(c*1377)+sin(g*7451.0154)+cos(g*331575))/3;
	vec3 off=vec3(r,-r,r)*offset*6;
	float box1=sdTorus(p,vec2(1,0.2));
	
	float box3=sdSphere(p+vec3(0,-r*0.5+sin(eng_time*1)/2,0),r*0.5+0.5+offset);
	float tx=cos(eng_time)*p.x-sin(eng_time)*p.z;

	p.z=sin(eng_time)*p.x+cos(eng_time)*p.z;
	p.x=tx;
	float box2=udRoundBox(p+vec3(0,1,0),vec3(0.7,0.7,0.7),0.1);
	return vec2(approx_min(approx_min(box2,box1),box3),abs(c*15+3)); 
}
float normalize_sph(vec3 p,vec4 m1,ivec4 m2)
{
	float r=length(p);
	#define MAX_K 10
	#define MAX_J 10
	float sum=0;
	for(int k=0;k<MAX_K;k++)
	for(int j=0;j<MAX_J;j++)
	{
		vec3 pol=vec3(r,(M_PI*k)/MAX_K,(M_PI*k*2)/MAX_K);
		float h=spHarmonics_polar(pol,m1,m2);
		sum+=h*h;
	}
	return sqrt(sum);
}
void rotate_z(inout vec2 p,float angle)
{
	float cos_t=cos(angle);
	float sin_t=sin(angle);
	p=vec2(p.x*cos_t-p.y*sin_t,p.x*sin_t+p.y*cos_t);
}
vec2 sdf( in vec3 p )
{
   float d = sdBox(p,vec3(2.0));
   vec2 res = vec2( d, 1.0 );

   float s = 1.0;
   for( int m=0; m<4; m++ )
   {
      vec3 a = mod( p*s, 2.0 )-1.0;
      s *= 3.0;
      vec3 r = abs(1.0 - 3.0*abs(a));

      float da = max(r.x,r.y);
      float db = max(r.y,r.z);
      float dc = max(r.z,r.x);
      float c = (min(da,min(db,dc))-1.0)/s;

      if( c>d )
      {
          d = c;
          res = vec2( d,(1.0+float(m))/4.0);
       }
      p+=vec3(1,-1,-1)*offset4;
     rotate_z(p.xy,offset2);
     rotate_z(p.yz,offset3);
   }

   return res;
}
vec2 sdf2(vec3 p)
{
	vec4 harmonics=vec4(10*offset,10*offset2,10*offset3,10*offset4);
	ivec4 powers=ivec4(10*offset3,1,1,1);
	//float val=spHarmonics(p,harmonics,powers);
	//float h=spHarmonics_internal(p,harmonics,powers,length(p));
	//float l=normalize_sph(p,harmonics,powers);
	//float val=sdSphere(p,1);
	
	return vec2(sdSphere(p,1),4);

}
//#define OLD_RAYTRACE
//!include raymarch.glsl