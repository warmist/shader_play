//!program cards fragment
#version 330

out vec4 color;
varying vec3 pos;
uniform float eng_time;
uniform vec3 eng_mouse;
uniform vec2 eng_resolution;
uniform int card; //!min 0 !max 14
uniform int anim; //!min 0 !max 3
#define M_PI 3.14159265359

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
//shapes
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
float df_polyhedron(in vec2 st,in float num,in float size,in float rot)
{
	float a=atan(st.x,st.y)+rot;
	float b=6.28319/num;
	return 1-(cos(floor(0.5+a/b)*b-a)*length(st.xy))*size;
}
//transforms
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
//operations
// The "Round" variant uses a quarter-circle to join the two objects smoothly:
float fOpUnionRound(float a, float b, float r) {
	vec2 u = max(vec2(r - a,r - b), vec2(0));
	return max(r, min (a, b)) - length(u);
}
//custom shapes
float dagger(in vec2 st,float fw)
{
	float v=sh_polyhedron(st*vec2(0.4,0.5)+vec2(0,0.122),3,0.1,0,fw/2);
	v=max(v,sh_polyhedron(st+vec2(0,-0.2),3,0.25,M_PI/3,fw));
	return v;
}
float sickle(in vec2 st, float fw)
{
	float v=sh_polyhedron(st*vec2(0.4,0.5),5,0.1,0,fw/2);
	v-=sh_circle(st-vec2(0,0.123),0.3,fw);
	return v;
}
float shield(in vec2 st,float r,float fw)
{
	float theta=atan(st.y,st.x);
	float d=length(st.xy)*(cos(theta)/2+1);
	
	vec2 np=vec2(cos(theta),sin(theta))*d;
	return sh_polyhedron(np,6,r,0,fw)-sh_polyhedron(np,6,r-0.05,0,fw);
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
float bit_noise( in vec2 p )
{
    vec2 i = floor( p );
    vec2 f = fract( p );
	
	vec2 u = f*f*(3.0-2.0*f);

    return mix( mix( random( i + vec2(0.0,0.0) ), 
                     random( i + vec2(1.0,0.0) ), u.x),
                mix( random( i + vec2(0.0,1.0) ), 
                     random( i + vec2(1.0,1.0) ), u.x), u.y);
}
float fbm(in vec2 uv)
{
	float f=0.0;
	uv *= 8.0;
    mat2 m = mat2( 1.6,  1.2, -1.2,  1.6 );
	f  = 0.5000*bit_noise( uv ); uv = m*uv;
	f += 0.2500*bit_noise( uv ); uv = m*uv;
	f += 0.1250*bit_noise( uv ); uv = m*uv;
	f += 0.0625*bit_noise( uv ); uv = m*uv;
	return f;
}
/*
//thing
vec2 st=npos.xy;
float theta=atan(st.y,st.x);
float d=(0.5/(length(st.xy)+0.25))*(3*cos(theta*4))*4;
float dd=pMod1(d,4);
vec2 np=vec2(cos(theta),sin(theta))*d;
outv=smoothstep(0.5-fw,0.5+fw,d);
*/
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
	float angle_offset=0;
	vec2 p1=vec2(cos(angle_offset),sin(angle_offset));
	vec2 p2=vec2(cos(M_PI/3+angle_offset),sin(M_PI/3+angle_offset));
	vec2 p3=vec2(cos(-M_PI/3+angle_offset),sin(-M_PI/3+angle_offset));

	return p1*p.x+p2*p.y+p3*(1-p.x-p.y);
}
vec2 from_barycentric(in vec3 p)
{
	float angle_offset=0;
	vec2 p1=vec2(cos(angle_offset),sin(angle_offset));
	vec2 p2=vec2(cos(M_PI/3+angle_offset),sin(M_PI/3+angle_offset));
	vec2 p3=vec2(cos(-M_PI/3+angle_offset),sin(-M_PI/3+angle_offset));

	return p1*p.x+p2*p.y+p3*p.z;
}
float grid(in vec2 p,float t)
{
	float s=0.05;
	float noise_level=0.25;
	/*
	vec2 pd=p/s;
	float d=length(mod(p,s)-vec2(s/2))-s/4;*/
	vec2 pp=pMod2(p,s);
	float d=length(p)-s/4;
	//p+=vec2(s/4);
	float dd=step(0.01,max(abs(p.x),abs(p.y)));
	float n=noise(pp/5);

	if(n>(1-t*noise_level))
		return 1-smoothstep(-0.001,0.001,d);
	else if (n>(1-t*noise_level)*0.5)
		return 1-dd;//smoothstep(-0.001,0.001,dd);
	else
		return 0;
}
float rod(float p,float fw,float d)
{
	return smoothstep(-fw/2,fw/2,p+d/2)-smoothstep(-fw/2,fw/2,p-d/2);
}
void main(){
	/*
	Ideas for having:
		* axis of reflection/rotation
		* items (clubs, shields, etc...)
		* counts (1,2,3,...)
		* themes (voronoi, perlin noise, pure noise, exact images, polar)
		* colors (bw, saturated, pastel, mono color)
		* celtic knots: http://www.calligraphy-skills.com/celtic-knotwork-design.html
	*/
	float phi=1.618033988;
	float phi1=1/phi;
	
	vec3 npos=pos;
	npos.x*=eng_resolution.x/eng_resolution.y;
	float fw=length(fwidth(npos));
	float outv=0;
	float slow_anim;
	
	if(anim==0) //off
		slow_anim=1;
	else if(anim==1) //default
		slow_anim=noise(vec2(eng_time/20));
	else if(anim==2) //debug
		slow_anim=noise(vec2(eng_time));
	else if(anim==3) //messed up
		slow_anim=noise(vec2(eng_time))*fbm(npos.xy);

	if(card==0)
	{

    	float st_val=0.9;
		outv=sh_ring(npos.xy,st_val,st_val*phi1,fw*2);
		for(int i=0;i<4;i++)
		{
			st_val*=pow(phi1,1+slow_anim);
			fw*=phi1;
			outv=max(outv,sh_ring(npos.xy,st_val,st_val*phi1,fw*2));
		}
	}
	else if(card==1)
	{
		float mask=sh_circle(npos.xy,1.25,fw);
		float chance=dot(npos.xy,npos.xy);
		//chance=exp(chance*p1)*p2-1;
		chance=smoothstep(0,1,chance*(1.3+slow_anim));
		float chance2=0.6-dot(npos.xy,npos.xy);
		chance2=smoothstep(0,1,chance2*(1+slow_anim));
		float r=random(npos.xy);
		float v=(r>(1-chance))?(1):(0);
		float v2=(r>(1-chance2))?(1):(0);
		outv=v*mask+v2*(1-mask);
	}
	else if(card==2)
	{
		outv=smoothstep(-fw,fw,npos.y);
		vec2 np=npos.xy+vec2(slow_anim*2,0);
		np.x=mod(np.x,0.3);
		outv=abs(outv-sh_polyhedron(np.xy,3,0.1,M_PI/2,fw));
	}
	else if(card==3)
	{
		float angle=slow_anim*M_PI-M_PI/4;
		vec2 p1=npos.xy*2+vec2(cos(angle),sin(angle));
		t_rot(p1,M_PI/6*slow_anim);
		outv=dagger(p1,fw)-dagger(p1*1.3-vec2(0,0.1),fw);
		vec2 p2=npos.xy*2+vec2(cos(angle+M_PI),sin(angle+M_PI));
		t_rot(p2,M_PI+M_PI/6*slow_anim);
		outv=max(outv,dagger(p2,fw)-dagger(p2*1.3-vec2(0,0.1),fw));
	}

	else if(card==4)
	{
		outv=sh_circle(npos.xy,1.6,fw*4);
		outv-=sh_polyhedron(npos.xy,3,0.45,M_PI*(1-slow_anim),fw);
		outv=max(outv,sh_polyhedron(npos.xy,3,0.38,M_PI*(1-slow_anim),fw));
	}
	else if(card==5)
	{

		vec2 np=npos.xy;
		//outv=sh_circle(np,.2,fw);
		for(int i=0;i<4;i++)
		{
			outv=max(outv,sickle(np*(slow_anim/5+0.8)-vec2(0.35,0.1),fw));
			outv=max(outv,sh_circle(np-vec2(0.3,0.2),0.05*slow_anim,fw));
			t_rot(np,M_PI/2);
			//np+=vec2(0.1,-0.5);
		}
	}
	else if(card==6)
	{
		outv=sh_polyhedron(npos.xy,3,0.45,0,fw);
		outv-=sh_circle(npos.xy,0.9*(slow_anim/2+0.5),fw);
		outv=max(outv,sh_circle(npos.xy,0.6*(slow_anim/2+0.5),fw));
	}
	else if(card==7)
	{
		//TODO anim
		vec2 p1=npos.xy*2;
		for(int i=0;i<3;i++)
		{
			t_rot(p1,(M_PI*2)/3);
			vec2 p2=p1;
			t_rot(p2,M_PI);
			outv=max(outv,dagger(p1+vec2(0,1),fw)-dagger(p2-vec2(0,0.7),fw));
		}
		outv=max(outv,sh_circle(npos.xy,3.3,fw*2)-sh_circle(npos.xy,3.1,fw*3));
	}
	else if(card==8)
	{
		float st_val=1;
		float angle=M_PI/16;
		float theta=atan(npos.y,npos.x);
		float d=length(npos.xy)/4;
		float mask=step(0.25,d);
		float i=pMod1(d,0.1*(slow_anim/2+0.5));
		st_val*=pow(0.025,1);
		vec2 np=vec2(cos(theta),sin(theta))*d;
		float v1=sh_polyhedron(np,4,st_val,angle*i,fw/4);
		float v2=sh_polyhedron(np,4,st_val*phi1,M_PI/4,fw/4);
		outv=max(outv,v1-v2-mask);
	}
	else if(card==9)
	{
		vec2 np=npos.xy;
		float ring=sh_circle(np,1.5,fw*2)-sh_circle(np,1,fw*2);
		t_rot(np,(M_PI/5)*2+M_PI/10);
		for(int i=0;i<5;i++)
		{
			t_rot(np,(M_PI/5)*2);
			float vv=shield(np*(2-slow_anim)-vec2(0.75,0),0.3,fw/2);
			float v2=shield(np*(2-slow_anim)-vec2(0.75,0),0.25,fw/2);
			ring-=v2;
			outv=max(outv,vv);
		}
		outv+=ring;
	}
	else if(card==10)
	{
		float dd=df_polyhedron(npos.xy,7,1.25,0);
		float dd2=df_polyhedron(npos.xy,7,1.,0);
		outv=smoothstep(0.5,0.5+fw*1.5,max(dd,1-dd2));
		float theta=atan(npos.y,npos.x);
		float d=length(npos.xy);

		outv*=(d<0.5)?(1):(smoothstep(0.5-fw*10,0.5+fw*10,cos(theta*21)));
		//outv*=(d<0.9)?(1):(0);
	}
	else if(card==11)
	{
		fw=0.01;
		vec2 np=npos.xy+vec2(0.25,0);
		float d=sh_circle(np,1,fw)-sh_circle(np,0.5,fw);
		vec2 np2=npos.xy-vec2(0.25,0);
		float d2=sh_circle(np2,1,fw)-sh_circle(np2,0.5,fw);
		float w=0.1;
		float mask1=sh_circle(np2,1+w*2,fw)-sh_circle(np2,0.5-w,fw);
		float mask2=sh_circle(np,1+w*2,fw)-sh_circle(np,0.5-w,fw);
		outv=max(d-((np2.y>0)?(mask1):0),d2-((np.y<0)?(mask2):0));
	}
	else if (card==12)
	{
		//NOT VERY GOOD :< does not match the others
		float dd=grid(npos.xy,slow_anim);
		//fw=fwidth(dd);
		outv=dd;//smoothstep(0.5-fw/2,0.5+fw/2,dd);
		//outv=fw*200;
	}
	else if (card==13)
	{
		float pipe_size=0.2;
		float d=length(npos);
		npos*=vec3((0.7-d)*4);
		float fw2=length(fwidth(npos));
		t_rot(npos.xy,slow_anim*M_PI*2);
		outv=rod(npos.x,fw2,pipe_size);
		outv-=rod(npos.y,fw2,pipe_size*1.5);
		outv=clamp(outv,0,1);
		outv+=rod(npos.y,fw2,pipe_size);
#if 0
		t_rot(npos.xy,M_PI/4);
		outv-=rod(npos.y,fw2,pipe_size*1.5);
		outv=clamp(outv,0,1);
		outv+=rod(npos.y,fw2,pipe_size);
		t_rot(npos.xy,M_PI/2);
		outv-=rod(npos.y,fw2,pipe_size*1.5);
		outv=clamp(outv,0,1);
		outv+=rod(npos.y,fw2,pipe_size);
#endif
	}
	else if (card==14)
	{
		float pipe_size=0.2;
		float d=length(npos);
		//npos*=vec3((0.7-d)*4);
		float r_anim=0.5+slow_anim/2;
		float r=smoothstep(0.3*r_anim,0.5*r_anim,d);
		r-=smoothstep(0.8*r_anim,2*r_anim*(1/d),d/0.5-0.25);
		clamp(r,0,1);
		#if 1
		t_rot(npos.xy,M_PI*r);
		float fw2=length(fwidth(npos));
		t_rot(npos.xy,slow_anim*M_PI*2);
		outv=rod(npos.x,fw2,pipe_size);
		outv-=rod(npos.y,fw2,pipe_size*1.5);
		outv=clamp(outv,0,1);
		outv+=rod(npos.y,fw2,pipe_size);

		t_rot(npos.xy,M_PI/4);
		outv-=rod(npos.y,fw2,pipe_size*1.5);
		outv=clamp(outv,0,1);
		outv+=rod(npos.y,fw2,pipe_size);
		t_rot(npos.xy,M_PI/2);
		outv-=rod(npos.y,fw2,pipe_size*1.5);
		outv=clamp(outv,0,1);
		outv+=rod(npos.y,fw2,pipe_size);
		#endif
		outv*=1-smoothstep(0.97,0.98,d);
	}
	color = vec4(vec3(outv),1);
}