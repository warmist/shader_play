//!program blackbody fragment
#version 330
//#define hp highp

//!include sdf_libs.glsl

#ifndef hp
#define hp
#endif

#define USE_SUN
#define MAX_ITER 4

out vec4 color;
uniform float temp; //!clamp
uniform float power; //!clamp
uniform float light_angle; //!angle !min -180 !max 180

varying vec3 pos;
uniform float eng_time;
uniform vec3 eng_mouse;
uniform vec2 eng_resolution;

uniform mat4 eng_projection;
uniform mat4 eng_modelview;
uniform mat4 eng_projection_inv;
uniform mat4 eng_modelview_inv;
uniform vec3 light_dir; //!norm
uniform float sqr_alpha; //!clamp
uniform float fbm_freq;
uniform float fbm_influence; //!clamp
uniform float gamma;


hp float xFit_1931( hp float wave )
{
	hp float t1 = (wave-442.0f)*((wave<442.0f)?0.0624f:0.0374f);
	hp float t2 = (wave-599.8f)*((wave<599.8f)?0.0264f:0.0323f);
	hp float t3 = (wave-501.1f)*((wave<501.1f)?0.0490f:0.0382f);
	return 0.362f*exp(-0.5f*t1*t1) + 1.056f*exp(-0.5f*t2*t2)
	- 0.065f*exp(-0.5f*t3*t3);
}
hp float yFit_1931( hp float wave )
{
	hp float t1 = (wave-568.8f)*((wave<568.8f)?0.0213f:0.0247f);
	hp float t2 = (wave-530.9f)*((wave<530.9f)?0.0613f:0.0322f);
	return 0.821f*exp(-0.5f*t1*t1) + 0.286f*exp(-0.5f*t2*t2);
}
hp float zFit_1931( hp float wave )
{
	hp float t1 = (wave-437.0f)*((wave<437.0f)?0.0845f:0.0278f);
	hp float t2 = (wave-459.0f)*((wave<459.0f)?0.0385f:0.0725f);
	return 1.217f*exp(-0.5f*t1*t1) + 0.681f*exp(-0.5f*t2*t2);
}
hp vec3 fit_1931(hp float w)
{
	return vec3(xFit_1931(w),yFit_1931(w),zFit_1931(w));
}
hp float black_body_spectrum(hp float l,hp float temperature )
{
	/*float h=6.626070040e-34; //Planck constant
	float c=299792458; //Speed of light
	float k=1.38064852e-23; //Boltzmann constant
	*/
	hp float const_1=5.955215e-17;//h*c*c
	hp float const_2=0.0143878;//(h*c)/k
	hp float top=(2*const_1);
	hp float bottom=(exp((const_2)/(temperature*l))-1)*l*l*l*l*l;
	return top/bottom;
	//return (2*h*freq*freq*freq)/(c*c)*(1/(math.exp((h*freq)/(k*temperature))-1))
}
//how much the interference happens 
//if v is int then it's 1 and if v-0.5 is int then it's 0
float interfere(float v ) 
{
	return abs((v-floor(v-0.5)-1)*2);
}
float interference_spectrum(float l,float t,float film_size,float angle)
{
	float n=1.4;// index of refraction for soapy water
	//10 nanometers to 1000 nm
	//float angle=light_angle*3.1459;
	float m=(2*n*(film_size)*cos(angle));
	float i=m/l;

	return black_body_spectrum(l,
#ifndef USE_SUN
	t
#else
	5800
#endif
	)*interfere(i);//sun ~5800
}
//from https://gist.github.com/mattatz/44f081cac87e2f7c8980
hp vec3 xyz2rgb(hp  vec3 c ) {
	const hp mat3 mat = mat3(
        3.2406, -1.5372, -0.4986,
        -0.9689, 1.8758, 0.0415,
        0.0557, -0.2040, 1.0570
	);
    vec3 v =c*mat;// mul(c , mat);
    vec3 r;
    r.x = ( v.r > 0.0031308 ) ? (( 1.055 * pow( v.r, ( 1.0 / 2.4 ))) - 0.055 ) : 12.92 * v.r;
    r.y = ( v.g > 0.0031308 ) ? (( 1.055 * pow( v.g, ( 1.0 / 2.4 ))) - 0.055 ) : 12.92 * v.g;
    r.z = ( v.b > 0.0031308 ) ? (( 1.055 * pow( v.b, ( 1.0 / 2.4 ))) - 0.055 ) : 12.92 * v.b;
    return r;
}
hp vec3 get_bb_xyz(hp float t)
{
	vec3 lab=vec3(0,0,0);
	for(hp float l=380;l<=780;l+=5)
	{
		lab+=fit_1931(l)*black_body_spectrum(l*1e-9,t);
	}
	return lab;
}
hp vec3 get_bb_xyz_film(hp float t,float film_size,float angle)
{
	vec3 lab=vec3(0,0,0);
	for(hp float l=380;l<=780;l+=5)
	{
		lab+=fit_1931(l)*interference_spectrum(l*1e-9,t,film_size,angle);
	}
	return lab;
}
float random (in vec2 st) { 
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))
                 * 43758.5453123);
}
float hash__(vec2 p)  // replace this by something better
{
    p  = 50.0*fract( p*0.3183099 + vec2(0.71,0.113));
    return -1.0+2.0*fract( p.x*p.y*(p.x+p.y) );
}
float voronoi(vec2 p)
{
	p.x*=eng_resolution.x/eng_resolution.y;
	vec2 point[6];
	point[0] = vec2(-0.83,0.75);
    point[1] = vec2(0.60,0.07);
    point[2] = vec2(0.28,-0.64);
    point[3] = vec2(0.31,0.26);
    point[4] = vec2(-0.31,0.26);
    point[5] = eng_mouse.xy;
    float m_dist = 1.;  // minimun distance
    vec2 m_point;        // minimum position

    // Iterate through the points positions
    for (int i = 0; i < 6; i++) {
        float dist = distance(p, point[i]);
        if ( dist < m_dist ) {
            // Keep the closer distance
            m_dist = dist;
        }
    }

    return m_dist;
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
float phash( float n )
{
    return fract(sin(n)*43758.5453);
}

float pnoise( vec3 x )
{
    // The noise function returns a value in the range -1.0f -> 1.0f

    vec3 p = floor(x);
    vec3 f = fract(x);

    f       = f*f*(3.0-2.0*f);
    float n = p.x + p.y*57.0 + 113.0*p.z;

    return mix(     mix( mix( phash(n), phash(n+1.), f.x ), mix( phash(n+57.), phash(n+58.),f.x ), f.y ),
                    mix( mix( phash(n+113.0), phash(n+114.),f.x), mix( phash(n+170.), phash(n+171.),f.x ), f.y ),
                    f.z);
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
float noise2xx(in vec2 st)
{
	return noise(st)*0.5+0.5*noise(st*2);
}
vec2 map__xx(vec3 p)
{
	return vec2(sdSphere(p-vec3(0,0,-200),1),2);
}
vec2 map(vec3 p)
{
	float max_dist=0.5;
	float p_id=sqr_alpha*10+1;
	float a= -sqr_alpha/(max_dist*max_dist);
	float d=clamp(distance(vec2(0,0),p.xy),0,1);
	float v=atan(p.y,p.x)*3.7;
	float drop_shape=(1-pow(d,p_id));
	float fbm_i=(1-drop_shape)*fbm_influence;
	float fbm_mod=((1-fbm_i)+pnoise(vec3(v,0,0)*fbm_freq)*fbm_i);
	float s=clamp(drop_shape*fbm_mod,0,1)*1e-6;
	return vec2(s,2);
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
void main(){
	vec3 npos=pos;
	npos.x*=eng_resolution.x/eng_resolution.y;

	hp float kelvins=temp*50000+500;
	hp float pow_v=pow(10,power*30);
	float len=1;
	vec3 N=calcNormal(npos,len);//vec3(0,0,1);
	//hp vec3 xyz=get_bb_xyz(kelvins);
	float f=map(npos).x;
	//float f=fbm(npos.xy)*5e-7+1e-7;//(abs(pos.x)*1000)*10e-9+10e-9;
	//float f=noise(vec2(noise(pos.xy*5*eng_mouse.xy),noise(pos.xy*13))*eng_mouse.xy)*10e-7;
	float d=dot(N,light_dir);
	vec3 xyz=get_bb_xyz_film(kelvins,f,light_angle);//acos(d));
	//xyz/=xyz.y;
	//if(pos.y<0)
		xyz/=pow_v;
	//else
	//	xyz/=xyz.y;
	//float diffuse=clamp(d,0,1); //diffuse does not work well because real water has internal reflection(s)
    color = vec4(xyz2rgb(xyz),1);
	color.rgb=pow(color.rgb,vec3(gamma));
}

void main_raytrace(){
	vec4 ray_eye=eng_projection_inv*vec4(pos.xy,-1,1);
	ray_eye=vec4(ray_eye.xy,-1,0);
	vec3 ray_world=(eng_modelview_inv*ray_eye).xyz;
	ray_world=normalize(ray_world);

	vec4 pos_eye=eng_projection_inv*vec4(0,0,0,1);
	pos_eye=vec4(pos_eye.xyz,1);
	pos_eye=eng_modelview_inv*pos_eye;



	int count=0;
	vec2 hit=raytrace_simple(pos_eye.xyz,ray_world,count);

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

		float diffuse=clamp(dot(norm,light_dir),0,0.5);
		vec3 ambient=vec3(0.5,0.5,0.5)*col;
		color=vec4(col*diffuse+ambient,1);
	}
	else
	{
		color=vec4(0,0,0,1);
	}
}
vec3 sphere1(vec3 spos)
{
	//map to sphere
	float r=1;
	//r=sqrt(x*x+y*y+z*z); <- fixed
	float theta=acos(spos.z/r);
	float phi=atan(spos.y,spos.x);
	//vec3 pst=vec3(1-2*spos.x,1-2*spos.y,1);
	//float k=sqrt(3+4*(pst.x*pst.x-pst.x+pst.y*pst.y-pst.y));
	//color=vec4(theta/3.14,(phi/3.14+1)/2,0,1);

	hp float kelvins=temp*50000+500;
	hp float pow_v=pow(10,power*30);

	float f=fbm(vec2(theta,phi))*10e-7;//(abs(pos.x)*1000)*10e-9+10e-9;
	//float f=noise(vec2(noise(pos.xy*5*eng_mouse.xy),noise(pos.xy*13))*eng_mouse.xy)*10e-7;
	float angle=acos(dot(spos,light_dir));
	vec3 xyz=get_bb_xyz_film(kelvins,f,angle);
	xyz/=pow_v;
	return xyz;
}
void main_bubble()
{
	vec3 npos=pos;
	npos.x*=eng_resolution.x/eng_resolution.y;
	if(dot(npos,npos)<1)
	{
		vec3 spos=vec3(npos.x,sqrt(1-npos.x*npos.x-npos.y*npos.y),npos.y);
		float diffuse=clamp(dot(spos,light_dir),0,1);
		vec3 lcol=sphere1(spos)*diffuse;
		
		spos=vec3(npos.x,-sqrt(1-npos.x*npos.x-npos.y*npos.y),npos.y);
		diffuse=clamp(dot(spos,-light_dir),0,1);
		lcol+=sphere1(spos)*diffuse;
		vec3 col=xyz2rgb(lcol);
		vec3 cg=pow(col,vec3(1.0/gamma));
	    color = vec4(cg,1);
	}
	else
	{
		color=vec4(0,0,0,1);
	}
}