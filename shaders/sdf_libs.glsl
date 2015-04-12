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

float udRoundBox( vec3 p, vec3 b, float r )
{
  return length(max(abs(p)-b,0.0))-r;
}
float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y; 
}