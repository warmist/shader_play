//!program blu fragment
#version 330

out vec4 color;
uniform float eng_time;
uniform vec3 eng_mouse;
uniform vec2 eng_resolution;
varying vec3 pos;
uniform int do_clear; //!min 0 !max 1
uniform sampler2D eng_last_frame;
uniform float noise_inf; //!clamp
uniform int do_ticks; //!min 0 !max 1
in vec2 real_pos;
uniform float cell_scale; //!min 1 !max 20
uniform float decay_rate;
float sdf(vec2 p)
{
	float d=abs(sin(p.x*(abs(cos(eng_time*0.25))*25)+eng_time*5)-p.y);
	return d;
}
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
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
#define OCTAVES 6
float fbm (in vec2 st) {
    // Initial values
    float value = 0.0;
    float amplitud = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitud * noise(st);
        st *= 2.;
        amplitud *= .5;
    }
    return value;
}
vec4 lap_sample(ivec2 p)
{
	//vec3 deps=vec3(1/eng_resolution*1.01,0);
	return (4*(texelFetchOffset(eng_last_frame,p,0,ivec2(0,1))+
texelFetchOffset(eng_last_frame,p,0,ivec2(1,0))+
texelFetchOffset(eng_last_frame,p,0,ivec2(0,-1))+
texelFetchOffset(eng_last_frame,p,0,ivec2(-1,0)))+
	   (texelFetchOffset(eng_last_frame,p,0,ivec2(1,1))+
       	texelFetchOffset(eng_last_frame,p,0,ivec2(1,-1))+
       	texelFetchOffset(eng_last_frame,p,0,ivec2(-1,-1))+
       	texelFetchOffset(eng_last_frame,p,0,ivec2(-1,1))))/20;
}
vec4 fsample(ivec2 p)
{
	//vec3 deps=vec3(1/eng_resolution*1.01,0);
	return (texelFetchOffset(eng_last_frame,p,0,ivec2(0,0))+
		   texelFetchOffset(eng_last_frame,p,0,ivec2(0,1))+texelFetchOffset(eng_last_frame,p,0,ivec2(1,1))+
	       texelFetchOffset(eng_last_frame,p,0,ivec2(1,0))+texelFetchOffset(eng_last_frame,p,0,ivec2(1,-1))+
	       texelFetchOffset(eng_last_frame,p,0,ivec2(0,-1))+texelFetchOffset(eng_last_frame,p,0,ivec2(-1,-1))+
	       texelFetchOffset(eng_last_frame,p,0,ivec2(-1,0))+texelFetchOffset(eng_last_frame,p,0,ivec2(-1,1)))/9.0;
}
vec4 msample(ivec2 p)
{
	//vec3 deps=vec3(1/eng_resolution*1.01,0);
	return max(
			max(
				max(texelFetchOffset(eng_last_frame,p,0,ivec2(0,1)),texelFetchOffset(eng_last_frame,p,0,ivec2(1,1))),
	       		max(texelFetchOffset(eng_last_frame,p,0,ivec2(1,0)),texelFetchOffset(eng_last_frame,p,0,ivec2(1,-1)))
	       		),
	        max(
	        	max(texelFetchOffset(eng_last_frame,p,0,ivec2(0,-1)),texelFetchOffset(eng_last_frame,p,0,ivec2(-1,-1))),
	       		max(texelFetchOffset(eng_last_frame,p,0,ivec2(-1,0)),texelFetchOffset(eng_last_frame,p,0,ivec2(-1,1)))
	       		)
	        );
}
vec4 isample(ivec2 p)
{
	//vec3 deps=vec3(1/eng_resolution*1.01,0);
	return texelFetchOffset(eng_last_frame,p,0,ivec2(0,1))+texelFetchOffset(eng_last_frame,p,0,ivec2(1,1))+
	       texelFetchOffset(eng_last_frame,p,0,ivec2(1,0))+texelFetchOffset(eng_last_frame,p,0,ivec2(1,-1))+
	       texelFetchOffset(eng_last_frame,p,0,ivec2(0,-1))+texelFetchOffset(eng_last_frame,p,0,ivec2(-1,-1))+
	       texelFetchOffset(eng_last_frame,p,0,-ivec2(-1,0))+texelFetchOffset(eng_last_frame,p,0,ivec2(-1,1));
}
float col_to_val(vec4 s)
{
	float v=length(s.xyz);
	return clamp(((v)*pow(10,decay_rate)),0,1);
}
float get(int x,int y)
{
	vec4 s=texelFetch(eng_last_frame,ivec2(real_pos)+ivec2(x,y),0);
	
	return col_to_val(s);
}
vec3 rand_color(vec2 pos)
{
	return hsv2rgb(vec3(noise(pos),1,1));
}
void main(){
	float aspect=eng_resolution.x/eng_resolution.y;
	vec2 npos=pos.xy;
	npos.x*=aspect;

	vec2 mouse=eng_mouse.xy;

	vec2 delta=real_pos-(mouse/2+vec2(0.5,0.5))*eng_resolution.xy;
	float d=clamp(1-step(1,length(delta)/cell_scale),0,1)*step(0.001,eng_mouse.z);
	vec4 around=lap_sample(ivec2(real_pos));
	if(do_ticks==1)
	{
		//vec4 current = texelFetch(eng_last_frame,ivec2(real_pos),0);
		/*vec3 col_hsv=rgb2hsv(around.xyz*9);
		col_hsv.x+=0.001;
		col_hsv.x=mod(col_hsv.x,1);
		col_hsv.y=0.75;
		col_hsv.z=0.75;
		around.xyz=hsv2rgb(col_hsv);*/
        color = vec4(mod(around.xyz+vec3(0.001,0.001,0.001),1) , 1.0);
    }
    else
    {
    	vec4 current = texelFetch(eng_last_frame,ivec2(real_pos),0);
        color = vec4(current.xyz , 1.0);
    }

    color=max(color,vec4(d*rand_color(pos.xy*10+vec2(eng_time*0.05,eng_time*0.75)),1));
    color=min(vec4(float(do_clear)),color);
}
void main_cellular(){

	//ivec2 real_pos=ivec2((pos.xy/2+vec2(0.5,0.5))*eng_resolution);
	
	//vec2 tex_pos=(pos.xy+vec2(1,1))/2;
	//vec4 c_last=texture2D(eng_last_frame,tex_pos);
	/*vec4 c_last2=uvec4(0,0,0,0);//(isample(real_pos)+p)/9;
	
	
	
	
	vec3 out_col=vec3(p.xyz)/vec3(255);*/
	float aspect=eng_resolution.x/eng_resolution.y;
	vec2 npos=pos.xy;
	npos.x*=aspect;
	float d_center=length(npos);
	vec2 mouse=eng_mouse.xy;
	//mouse.x*=aspect;
	//mouse=clamp(mouse,-1,1);
	vec2 delta=real_pos-(mouse/2+vec2(0.5,0.5))*eng_resolution.xy;

	float d=clamp(1-step(1,length(delta)),0,1)*step(0.001,eng_mouse.z);

	delta=(vec2(eng_resolution.x-real_pos.x,eng_resolution.y-real_pos.y))-(mouse/2+vec2(0.5,0.5))*eng_resolution.xy;

	d=max(d,clamp(1-step(1,length(delta)),0,1)*step(0.001,eng_mouse.z));

	vec4 p=texelFetch(eng_last_frame,ivec2(real_pos),0);
	float self_value=col_to_val(p);
	float sum = get(-1, -1) +
              get(-1,  0) +
              get(-1,  1) +
              get( 0, -1) +
              get( 0,  1) +
              get( 1, -1) +
              get( 1,  0) +
              get( 1,  1);
	//vec4 p=isample(ivec2(real_pos))/4;
	vec4 color_t=texture(eng_last_frame,pos.xy/2+vec2(0.5,0.5));
	//conway game of life new: 3, survive 2
	//float dist_scaled=d_center*cell_scale; //ring shaped
	float dist_scaled=fbm(npos.xy/2)*cell_scale;
	float dist_scaled2=fbm(npos.xy/2+vec2(11,eng_time/40))*cell_scale;
	float min_value=clamp(dist_scaled,0,2);

	//float max_value=clamp(0.5*dist_scaled*dist_scaled-3.5*dist_scaled+8,0,8);
	float max_value=clamp(exp(-dist_scaled2/4+log(8)),0,8);

	float dist_scaled3=fbm(npos.xy+vec2(123,858+eng_time/55))*cell_scale;
	float dist_scaled4=fbm(npos.xy+vec2(444+eng_time/55,234))*cell_scale;
	float new_life_min=9-clamp(dist_scaled3,1,8);
	float new_life_max=clamp(dist_scaled4,dist_scaled3,8);
	if(do_ticks==1)
	{
		if (sum>new_life_min && sum<=new_life_max && self_value<0.9) { //new
			vec3 cn=clamp(rgb2hsv(isample(ivec2(real_pos)).xyz*sum),0,1);
			cn.x+=noise(pos.xy)*(noise_inf/2)-noise_inf/2;
			cn.y+=noise(pos.xy)*(noise_inf/2)-noise_inf/2;
			//cn.z+=noise(pos.xy)*(noise_inf/2)-noise_inf/2;
	        color = vec4(hsv2rgb(cn), 1.0);
	    }else if (
	    		/*( (d_center> 0.9) && (sum>=0 && sum<=8))||
	    		( (d_center<= 0.9) && (d_center> 0.5) && (sum>=1 && sum<=5))||
	    		( d_center<= 0.5   && (sum>=2 && sum<=3))*/
	    		(sum>=min_value && sum<max_value)
	    		)
	    { //survive
	        vec4 current = texelFetch(eng_last_frame,ivec2(real_pos),0);
	        color = vec4(current.xyz*(1-pow(0.1,decay_rate)), 1.0);
	    }
	    else {//die
	        color = vec4(0.0, 0.0, 0.0, 0.0);
	    }
    }
    else
    {
    	vec4 current = texelFetch(eng_last_frame,ivec2(real_pos),0);
        color = vec4(current.xyz , 1.0);
    }
    color=max(color,vec4(d*rand_color(pos.xy*10+vec2(eng_time*0.05,eng_time*0.75)),1));
    color=min(vec4(float(do_clear)),color);
    //color = vec4(max(d,p.x),0,0,1);//c_last.xyz*0.1+vec3(-0.01,0.01,0);
}