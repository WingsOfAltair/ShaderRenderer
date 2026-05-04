#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

// =====================================================
// HASH / NOISE
// =====================================================
float hash(vec2 p)
{
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0,0.0));
    float c = hash(i + vec2(0.0,1.0));
    float d = hash(i + vec2(1.0,1.0));

    vec2 u = f*f*(3.0-2.0*f);

    return mix(a,b,u.x) +
           (c-a)*u.y*(1.0-u.x) +
           (d-b)*u.x*u.y;
}

// =====================================================
// ROTATION
// =====================================================
mat2 rot(float a)
{
    float s = sin(a), c = cos(a);
    return mat2(c,-s,s,c);
}

// =====================================================
// SPHERE INTERSECTION
// =====================================================
float sphere(vec3 ro, vec3 rd, float r)
{
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r*r;
    float h = b*b - c;
    if(h < 0.0) return -1.0;
    return -b - sqrt(h);
}

// =====================================================
// EARTH TEXTURE (procedural continents)
// =====================================================
vec3 earth(vec3 p)
{
    float lat = asin(p.y);
    float lon = atan(p.z, p.x);

    vec2 uv = vec2(lon, lat);

    float land = noise(uv * 6.0 + uTime * 0.02);
    float detail = noise(uv * 20.0);

    float c = smoothstep(0.45, 0.65, land);

    vec3 ocean = vec3(0.02, 0.05, 0.2);
    vec3 landC = vec3(0.05, 0.25, 0.08);

    return mix(ocean, landC, c) + detail * 0.05;
}

// =====================================================
// ATMOSPHERE (Rayleigh-ish fake scattering)
// =====================================================
vec3 atmosphere(vec3 n, vec3 rd)
{
    float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 4.0);

    vec3 skyTop = vec3(0.3, 0.6, 1.2);
    vec3 skyHorizon = vec3(0.6, 0.7, 1.0);

    vec3 col = mix(skyHorizon, skyTop, fresnel);

    return col * fresnel;
}

// =====================================================
// CLOUDS
// =====================================================
float clouds(vec3 p)
{
    vec2 uv = vec2(atan(p.z,p.x), asin(p.y));
    uv.x += uTime * 0.01;

    return smoothstep(0.55,0.75, noise(uv*10.0));
}

// =====================================================
// CITY LIGHTS
// =====================================================
float lights(vec3 p, float night)
{
    vec2 uv = vec2(atan(p.z,p.x), asin(p.y));
    float n = noise(uv*50.0 + uTime*0.02);
    return smoothstep(0.7,0.95,n) * night;
}

// =====================================================
// STARFIELD
// =====================================================
float stars(vec2 uv, float scale)
{
    vec2 gv = fract(uv*scale)-0.5;
    vec2 id = floor(uv*scale);

    float h = hash(id);
    float d = length(gv);

    return smoothstep(0.02,0.0,d) * step(0.97,h);
}

// =====================================================
// GALAXY
// =====================================================
vec3 galaxy(vec2 uv, vec2 c, vec3 col)
{
    vec2 p = uv - c;

    float r = length(p);
    float a = atan(p.y,p.x);

    float spiral = sin(3.0*a + r*8.0 - uTime*0.1);
    float glow = exp(-r*2.5);
    float core = exp(-r*12.0);

    float g = glow*(0.6+0.4*spiral) + core;

    return col * g;
}

// =====================================================
// BLACK HOLE (background distortion)
// =====================================================
vec3 blackHole(vec2 uv, vec2 pos)
{
    vec2 p = uv - pos;
    float r = length(p);

    float bend = 0.2 / (r + 0.1);

    uv += normalize(p) * bend;

    float glow = exp(-r*6.0);

    return vec3(0.1,0.0,0.2) * glow;
}

// =====================================================
// MOON (simple second sphere orbiting Earth)
// =====================================================
float moon(vec3 ro, vec3 rd)
{
    vec3 mpos = vec3(1.8*cos(uTime*0.3), 0.3, 1.8*sin(uTime*0.3));

    float b = dot(ro-mpos, rd);
    float c = dot(ro-mpos, ro-mpos) - 0.27;
    float h = b*b - c;

    if(h < 0.0) return -1.0;
    return -b - sqrt(h);
}

// =====================================================
// MAIN
// =====================================================
void main()
{
    vec2 uv = (gl_FragCoord.xy/uResolution.xy)*2.0 - 1.0;
    uv.x *= uResolution.x/uResolution.y;

    vec3 ro = vec3(0.0,0.0,3.2);
    vec3 rd = normalize(vec3(uv,-1.5));

    float t = uTime*0.2;

    ro.xz *= rot(t);
    rd.xz *= rot(t*0.8);

    vec3 col = vec3(0.0);

    // ================= EARTH =================
    float hit = sphere(ro, rd, 1.0);

    if(hit > 0.0)
    {
        vec3 p = ro + rd*hit;
        vec3 n = normalize(p);

        vec3 e = earth(n);

        vec3 sunDir = normalize(vec3(1.0,0.3,0.2));

        float diff = max(dot(n,sunDir),0.0);
        float night = 1.0 - diff;

        float city = lights(n, night);
        float cl = clouds(n);

        vec3 earthCol = e*(0.25+diff);
        earthCol += vec3(1.0,0.8,0.5)*city;

        earthCol = mix(earthCol, vec3(1.0), cl*0.25);

        earthCol += atmosphere(n, rd);

        col = earthCol;
    }
    else
    {
        // ================= SPACE =================
        vec3 space = vec3(0.0);

        // stars
        space += stars(uv+uTime*0.01, 60.0);
        space += stars(uv+uTime*0.02, 140.0);
        space += stars(uv+uTime*0.03, 300.0);

        // galaxies
        space += galaxy(uv, vec2(-0.6,0.3), vec3(0.8,0.5,1.2));
        space += galaxy(uv, vec2(0.7,-0.4), vec3(1.2,0.6,0.3));

        // black hole lensing
        space += blackHole(uv, vec2(0.1,0.2));

        col = space;
    }

    // ================= MOON =================
    float m = moon(ro, rd);
    if(m > 0.0)
    {
        col = mix(col, vec3(0.6), 0.8);
    }

    // slight gamma
    col = pow(col, vec3(0.95));

    FragColor = vec4(col,1.0);
}