
//inspired by: https://www.shadertoy.com/view/Xds3zN and amboss by mercury demogroup
// also from http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
// amboss: https://www.youtube.com/watch?v=s8nFqwOho-s


#define MAX_ITER 640
//#define OLD_RAYTRACE


out vec3 color;

varying vec3 pos;

uniform mat4 eng_projection;
uniform mat4 eng_modelview;
uniform mat4 eng_projection_inv;
uniform mat4 eng_modelview_inv;

//custom uniforms 
uniform float plane_pos; //!clamp
uniform vec3 light_dir; //!norm

vec2 map(vec3 p)
{
	return opUnion(sdf(p),vec2(sdPlane(p-vec3(0,(plane_pos-0.5)*500,0)),-1.0));
}

vec3 calcNormal( in vec3 pos ,inout float len)
{
	vec3 eps = vec3( 0.001, 0.0, 0.0 );
	vec3 nor = vec3(
	    map(pos+eps.xyy).x - map(pos-eps.xyy).x,
	    map(pos+eps.yxy).x - map(pos-eps.yxy).x,
	    map(pos+eps.yyx).x - map(pos-eps.yyx).x );
	len=length(nor)/eps.x;
	return normalize(nor);
}
//from Keinert et al. Enchanced sphere tracing
vec2 raytrace(vec3 o,vec3 d,inout int count)
{
	float t_min=0.01;
	float t_max=200;
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
	#ifdef OLD_RAYTRACE
	vec2 hit=raytrace_simple(pos_eye.xyz,ray_world,count);
	#else
	vec2 hit=raytrace(pos_eye.xyz,ray_world,count);
	#endif
	//color=vec3(float(count)/float(MAX_ITER),0,0);
	//return;
	float mat=hit.y;
	if(mat>0)
	{
		vec3 hit_pos=pos_eye.xyz+hit.x*ray_world;
		float dist=length(hit_pos-pos_eye.xyz)+1;

		float n_len;
		vec3 norm=calcNormal(hit_pos,n_len);
		//float M_N=dist/100;//0.15;
		//float v_n=clamp(log(abs(n_len)),0,1+M_N);
		//float v_o=clamp(log((v_n-1)/M_N),0,1);

		//v_n=clamp(v_n,0,1);
		//vec3 col=vec3(v_o,v_n,v_n);
		vec3 col=vec3(clamp(sin(mat*15.2+77.2)*0.5+0.5,0,1),clamp(sin(mat+666)*0.5+0.5,0,1),clamp(sin(mat*1337.0152+12.0)*0.5+0.5,0,1));
		//mat=clamp(mat,0,1);
		//vec3 col=vec3(mat,0,0);

		float diffuse=clamp(dot(norm,light_dir),0,1);
		vec3 ambient=vec3(0.5,0.5,0.5)*col;
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