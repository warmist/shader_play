//!program blu fragment
#version 330

out vec3 color;
uniform float eng_time;
uniform vec3 eng_mouse;
uniform vec2 eng_resolution;
varying vec3 pos;

uniform usampler2D eng_last_frame;
varying flat ivec2 real_pos;
float sdf(vec2 p)
{
	float d=abs(sin(p.x*(abs(cos(eng_time*0.5))*25)+eng_time*5)-p.y);
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
uvec4 isample(ivec2 p)
{
	//vec3 deps=vec3(1/eng_resolution*1.01,0);
	return texelFetchOffset(eng_last_frame,p,1,ivec2(0,1))+texelFetchOffset(eng_last_frame,p,1,ivec2(1,1))+
	       texelFetchOffset(eng_last_frame,p,1,ivec2(1,0))+texelFetchOffset(eng_last_frame,p,1,ivec2(1,-1))+
	       texelFetchOffset(eng_last_frame,p,1,ivec2(0,-1))+texelFetchOffset(eng_last_frame,p,1,ivec2(-1,-1))+
	       texelFetchOffset(eng_last_frame,p,1,-ivec2(-1,0))+texelFetchOffset(eng_last_frame,p,1,ivec2(-1,1));
}
void main(){
	//ivec2 real_pos=ivec2((pos.xy/2+vec2(0.5,0.5))*eng_resolution);
	uvec4 p=texelFetch(eng_last_frame,real_pos,1);
	//vec2 tex_pos=(pos.xy+vec2(1,1))/2;
	//vec4 c_last=texture2D(eng_last_frame,tex_pos);
	uvec4 c_last2=(isample(real_pos)+p)/9;
	float aspect=eng_resolution.x/eng_resolution.y;
	vec2 mouse=eng_mouse.xy;
	mouse.x*=aspect;
	vec2 delta=pos.xy-mouse;
	float d=length(delta);
	d=clamp(sdf(pos.xy),0,1);
	vec3 out_col=vec3(c_last2.xyz)/vec3(255);
    color = clamp(out_col,0,1);//vec3(d,d-c_last2.x,0);//c_last.xyz*0.1+vec3(-0.01,0.01,0);
}