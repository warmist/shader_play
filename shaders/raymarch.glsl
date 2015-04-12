//!program raymarch fragment
//inspired by: https://www.shadertoy.com/view/Xds3zN and amboss by mercury demogroup
// also from http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
// amboss: https://www.youtube.com/watch?v=s8nFqwOho-s
#version 330

#define MAX_ITER 6400

out vec3 color;

varying vec3 pos;

uniform mat4 eng_projection;
uniform mat4 eng_modelview;
uniform mat4 eng_projection_inv;
uniform mat4 eng_modelview_inv;

//custom uniforms 
uniform float plane_pos;
uniform vec3 light_dir; //!norm
//hash from: https://www.shadertoy.com/view/XlfGWN
#define MOD2 vec2(.16632,.17369)

float hash12(vec2 p)
{
	p  = fract(p * MOD2);
    p += dot(p.xy, p.yx+19.19);
    return fract(p.x * p.y);
}
// polynomial smooth min (k = 0.1);
float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

float udBox( vec3 p, vec3 b )
{
  return length(max(abs(p)-b,0.0));
}
float sdBox( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) +
         length(max(d,0.0));
}
float sdBox2( vec2 p, vec2 b )
{
  vec2 d = abs(p) - b;
  return min(max(d.x,d.y),0.0) +
         length(max(d,0.0));
}
float sdPlane(vec3 p)
{
	return p.y;
}
float sdSphere(vec3 p,float s)
{
	return length(p)-s;
}
float sdCylinder(vec2 p,float s)
{
	return length(p)-s;
}
float sdSomething(vec3 p,float s)
{
	return dot(sin(p),cos(p));
}
float opCombineChampfer(float a,float b,float r)
{
	float m=min(a,b);
	if(a<r && b<r)
	{
		float d=(a+b-r);
		return min(m,d);
	}
	else
		return m;
}
float opCombine(float a,float b,float r)
{
	float m=min(a,b);
	if(a<r && b<r)
	{
		return min(m,r-sqrt((r-a)*(r-a)+(r-b)*(r-b)));
	}
	else
		return m;
}
float opDivide(float a,float b,float r)
{
	return -opCombine(-a,b,r);
}
float opDivideChampfer(float a,float b,float r)
{
	return -opCombineChampfer(-a,b,r);
}
float opSmoothUnionIntersect(float a,float b,float v)
{
	float mMax=max(a,b);
	float mMin=min(a,b);
	return mMax*v+mMin*(1-v);
}
float opUnionSimple(float a,float b)
{
	return min(a,b);
}
float pMod1(inout float p,float size)
{
	float halfsize=size*0.5;
	float c= floor((p+halfsize)/size);
	p=mod(p+halfsize,size)-halfsize;
	return c;
}
vec2 opUnion(vec2 a,vec2 b)
{
	return (a.x<b.x)?(a):(b);
}

void pMirror2(inout vec2 p,vec2 d)
{
	p=abs(p)-d;
	if(p.x>p.y)
		p.xy=p.yx;
}


vec2 sdf(vec3 p)
{
	float c=pMod1(p.x,8);
	float g=pMod1(p.y,8);
	

	float box1=sdBox2(p.xz,vec2(1,abs(c*c)*0.15+0.15));
	float box2=sdBox2(p.yz,vec2(1,abs(g*g)*0.15+0.15));

	return vec2(min(box1,box2),abs(c+5*g+8));
}

vec2 map(vec3 p)
{
	return opUnion(sdf(p),vec2(sdPlane(p-vec3(0,plane_pos,0)),-1.0));
}

vec3 calcNormal( in vec3 pos )
{
	vec3 eps = vec3( 0.001, 0.0, 0.0 );
	vec3 nor = vec3(
	    map(pos+eps.xyy).x - map(pos-eps.xyy).x,
	    map(pos+eps.yxy).x - map(pos-eps.yxy).x,
	    map(pos+eps.yyx).x - map(pos-eps.yyx).x );
	return normalize(nor);
}
//from Keinert et al. Enchanced sphere tracing
vec2 raytrace(vec3 o,vec3 d,inout int count)
{
	float t_min=0.01;
	float t_max=300;
	float pixel_radius=0.0001; //TODO: calculate real pixel radius @t=1
	bool force_hit=false;


	float omega=1.6;//relaxation const
	float t=t_min;
	float candidate_error=1.0/0.0;
	float candidate_t=t_min;
	float candidate_m=0;
	float previous_rad=0;
	float step_len=0;
	float function_sign=map(o).x<0?-1:1;
	for(int i=0;i<MAX_ITER;++i)
	{
		vec2 hit=map(d*t+o);
		float signed_radius=function_sign*hit.x;
		float radius=abs(signed_radius);

		bool sor_fail=omega>1 && (radius+previous_rad)<step_len;
		if(sor_fail)
		{
			step_len-=omega*step_len;
			omega=1;
		}
		else
		{
			step_len=signed_radius*omega;
		}
		previous_rad=radius;

		float error=radius/t;
		if(!sor_fail && error<candidate_error){
			candidate_t=t;
			candidate_m=hit.y;
			candidate_error=error;

		}
		if(!sor_fail && error<pixel_radius || t>t_max)
			break;
		t+=step_len;
		count=i;
	}
	if ((t>t_max || candidate_error>pixel_radius)&& !force_hit) return vec2(0,0);
	return vec2(candidate_t,candidate_m);
}
vec2 raytrace_simple(vec3 o,vec3 d,inout int count)
{
	float t_min=0.01;
	float tmax=300;
	float t=t_min;
	vec2 hit;
	for(int i=0;i<MAX_ITER;i++)
	{
		hit=map(o+t*d);
		if(abs(hit.x)<0.00002 || t>tmax)
		{
			break;
		}
		t+=hit.x;
		count=i;
	}
	if(t>tmax)
		return vec2(0,0);
	return vec2(t,hit.y);
}
void main(){
	//color=vec3(pos.x*0.5+0.5,pos.y*0.5+0.5,0);
	vec4 ray_eye=eng_projection_inv*vec4(pos.xy,-1,1);
	ray_eye=vec4(ray_eye.xy,-1,0);
	vec3 ray_world=(eng_modelview_inv*ray_eye).xyz;
	ray_world=normalize(ray_world);

	vec4 pos_eye=eng_projection_inv*vec4(0,0,0,1);
	pos_eye=vec4(pos_eye.xyz,1);
	pos_eye=eng_modelview_inv*pos_eye;



	int count=0;
	vec2 hit=raytrace(pos_eye.xyz,ray_world,count);
	//color=vec3(float(count)/float(MAX_ITER),0,0);
	//return;
	float mat=hit.y;
	if(mat>0)
	{
		vec3 hit_pos=pos_eye.xyz+hit.x*ray_world;
		vec3 norm=calcNormal(hit_pos);

		vec3 col=vec3(clamp(sin(mat*15.2+77.2)*0.5+0.5,0,1),clamp(sin(mat+666)*0.5+0.5,0,1),clamp(sin(mat*1337.0152+12.0)*0.5+0.5,0,1));

		float diffuse=clamp(dot(norm,light_dir),0,1);
		vec3 ambient=vec3(0.2,0.2,0.2)*col;
		color=col*diffuse+ambient;
	}
	else if (mat<0)
	{
		hit=sdf(pos_eye.xyz+hit.x*ray_world);

		float blue=(1-clamp(hit.x,0,1))*sin(hit.x*20)*0.5+0.5;
		float red=sin(hit.x*20)*0.5+0.5;

		color=vec3(red,red,blue);
	}
}