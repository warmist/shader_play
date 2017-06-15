//!program blu fragment
#version 330

out vec4 color;
uniform float eng_time;
uniform vec3 eng_mouse;
uniform vec2 eng_resolution;
varying vec3 pos;

uniform sampler2D eng_last_frame;
in vec2 real_pos;
float sdf(vec2 p)
{
	float d=abs(sin(p.x*(abs(cos(eng_time*0.25))*25)+eng_time*5)-p.y);
	return d;
}

/*vec4 sample(vec2 p)
{
	//vec3 deps=vec3(1/eng_resolution*1.01,0);
	return textureOffset(eng_last_frame,p,ivec2(0,1))+textureOffset(eng_last_frame,p,ivec2(1,1))+
	       textureOffset(eng_last_frame,p,ivec2(1,0))+textureOffset(eng_last_frame,p,ivec2(1,-1))+
	       textureOffset(eng_last_frame,p,ivec2(0,-1))+textureOffset(eng_last_frame,p,ivec2(-1,-1))+
	       textureOffset(eng_last_frame,p,-ivec2(-1,0))+textureOffset(eng_last_frame,p,ivec2(-1,1));
}*/
vec4 isample(ivec2 p)
{
	//vec3 deps=vec3(1/eng_resolution*1.01,0);
	return texelFetchOffset(eng_last_frame,p,0,ivec2(0,1))+texelFetchOffset(eng_last_frame,p,0,ivec2(1,1))+
	       texelFetchOffset(eng_last_frame,p,0,ivec2(1,0))+texelFetchOffset(eng_last_frame,p,0,ivec2(1,-1))+
	       texelFetchOffset(eng_last_frame,p,0,ivec2(0,-1))+texelFetchOffset(eng_last_frame,p,0,ivec2(-1,-1))+
	       texelFetchOffset(eng_last_frame,p,0,-ivec2(-1,0))+texelFetchOffset(eng_last_frame,p,0,ivec2(-1,1));
}
int get(int x,int y)
{
	return int(texelFetch(eng_last_frame,ivec2(real_pos)+ivec2(x,y),0));
}
void main(){
	//ivec2 real_pos=ivec2((pos.xy/2+vec2(0.5,0.5))*eng_resolution);
	
	//vec2 tex_pos=(pos.xy+vec2(1,1))/2;
	//vec4 c_last=texture2D(eng_last_frame,tex_pos);
	/*vec4 c_last2=uvec4(0,0,0,0);//(isample(real_pos)+p)/9;
	
	
	
	
	vec3 out_col=vec3(p.xyz)/vec3(255);*/
	float aspect=eng_resolution.x/eng_resolution.y;
	vec2 mouse=eng_mouse.xy;
	//mouse.x*=aspect;
	//mouse=clamp(mouse,-1,1);
	vec2 delta=real_pos-(mouse/2+vec2(0.5,0.5))*eng_resolution.xy;

	float d=clamp(1-step(1,length(delta)),0,1)*step(0.001,eng_mouse.z);

	vec4 p=texelFetch(eng_last_frame,ivec2(real_pos),0);
	int sum = get(-1, -1) +
              get(-1,  0) +
              get(-1,  1) +
              get( 0, -1) +
              get( 0,  1) +
              get( 1, -1) +
              get( 1,  0) +
              get( 1,  1);
	//vec4 p=isample(ivec2(real_pos))/4;
	vec4 color_t=texture(eng_last_frame,pos.xy/2+vec2(0.5,0.5));
	if (sum == 3) {
        color = vec4(1.0, 1.0, 1.0, 1.0);
    } else if (sum == 2) {
        float current = float(get(0, 0));
        color = vec4(current, current, current, 1.0);
    } else {
        color = vec4(0.0, 0.0, 0.0, 1.0);
    }
    color=max(color,vec4(d));
    //color = vec4(max(d,p.x),0,0,1);//c_last.xyz*0.1+vec3(-0.01,0.01,0);
}