#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

#define MAX_STEPS 80
#define MAX_DIST 50.0
#define SURF_DIST 0.001

// =====================================================
// HASH / NOISE
// =====================================================
float hash(vec3 p)
{
    p = fract(p * 0.3189 + vec3(0.1,0.2,0.3));
    p += dot(p, p.yzx + 19.19);
    return fract(p.x * p.y * p.z);
}

float noise(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);

    float n000 = hash(i);
    float n100 = hash(i+vec3(1,0,0));
    float n010 = hash(i+vec3(0,1,0));
    float n110 = hash(i+vec3(1,1,0));
    float n001 = hash(i+vec3(0,0,1));
    float n101 = hash(i+vec3(1,0,1));
    float n011 = hash(i+vec3(0,1,1));
    float n111 = hash(i+vec3(1,1,1));

    vec3 u = f*f*(3.0-2.0*f);

    return mix(mix(mix(n000,n100,u.x),mix(n010,n110,u.x),u.y),
               mix(mix(n001,n101,u.x),mix(n011,n111,u.x),u.y),
               u.z);
}

// =====================================================
// DISTANCE FUNCTIONS (SDF WORLD)
// =====================================================

// Earth sphere SDF
float sdEarth(vec3 p, vec3 c)
{
    return length(p - c) - 1.0;
}

// Moon sphere SDF
float sdMoon(vec3 p, vec3 c)
{
    return length(p - c) - 0.27;
}

// Sun (emissive volume field)
float sdSun(vec3 p, vec3 c)
{
    return length(p - c) - 0.5;
}

// Atmosphere shell
float sdAtmosphere(vec3 p, vec3 c)
{
    return length(p - c) - 1.15;
}

// =====================================================
// WORLD ORBITS (physically inspired Kepler-lite)
// =====================================================
vec3 orbit(vec3 center, float r, float t, float speed, float e)
{
    float M = t * speed;

    float E = M + e * sin(M);

    vec3 pos;
    pos.x = r * (cos(E) - e);
    pos.z = r * sqrt(1.0 - e*e) * sin(E);
    pos.y = 0.0;

    return center + pos;
}

// =====================================================
// SCENE MAP (SDF COMBINATION)
// =====================================================
float map(vec3 p, out int id)
{
    id = 0;

    float t = uTime * 0.2;

    vec3 sunPos = vec3(0.0);

    vec3 earthPos = orbit(sunPos, 2.0, t, 1.0, 0.02);

    vec3 moonPos = orbit(earthPos, 0.6, t*5.0, 1.0, 0.05);

    float dEarth = sdEarth(p, earthPos);
    float dMoon  = sdMoon(p, moonPos);
    float dSun   = sdSun(p, sunPos);

    float d = dEarth;
    id = 1;

    if(dMoon < d) { d = dMoon; id = 2; }
    if(dSun  < d) { d = dSun;  id = 3; }

    return d;
}

// =====================================================
// NORMAL FROM SDF (critical for realism)
// =====================================================
vec3 normal(vec3 p)
{
    float e = 0.001;

    int tmp;
    vec3 n;

    n.x = map(p + vec3(e,0,0), tmp) - map(p - vec3(e,0,0), tmp);
    n.y = map(p + vec3(0,e,0), tmp) - map(p - vec3(0,e,0), tmp);
    n.z = map(p + vec3(0,0,e), tmp) - map(p - vec3(0,0,e), tmp);

    return normalize(n);
}

// =====================================================
// RAYMARCH
// =====================================================
float raymarch(vec3 ro, vec3 rd, out int id)
{
    float dO = 0.0;

    for(int i=0;i<MAX_STEPS;i++)
    {
        vec3 p = ro + rd * dO;

        float dS = map(p, id);

        if(dS < SURF_DIST) return dO;
        if(dO > MAX_DIST) break;

        dO += dS;
    }

    id = 0;
    return dO;
}

// =====================================================
// LIGHTING
// =====================================================
vec3 lighting(vec3 p, vec3 n, vec3 rd, int id)
{
    vec3 sunPos = vec3(0.0);
    vec3 lightDir = normalize(sunPos - p);

    float diff = max(dot(n, lightDir), 0.0);

    float rim = pow(1.0 - abs(dot(n, -rd)), 3.0);

    vec3 col;

    if(id == 1) // Earth
    {
        float land = noise(p*3.0);
        vec3 ocean = vec3(0.02,0.05,0.2);
        vec3 landC = vec3(0.05,0.25,0.1);

        col = mix(ocean, landC, step(0.5, land));
        col *= (0.2 + diff);
    }
    else if(id == 2) // Moon
    {
        col = vec3(0.7) * (0.3 + diff);
    }
    else // Sun
    {
        col = vec3(1.0,0.9,0.6) * 5.0;
    }

    col += rim * vec3(0.2,0.5,1.0);

    return col;
}

// =====================================================
// STARFIELD VOLUME
// =====================================================
float stars(vec3 dir)
{
    vec3 p = dir * 50.0;
    return step(0.98, hash(floor(p)));
}

// =====================================================
// MAIN
// =====================================================
void main()
{
    vec2 uv = (gl_FragCoord.xy/uResolution.xy)*2.0-1.0;
    uv.x *= uResolution.x/uResolution.y;

    vec3 ro = vec3(0.0,0.0,5.0);
    vec3 rd = normalize(vec3(uv,-1.5));

    int id;

    float dist = raymarch(ro, rd, id);

    vec3 col = vec3(0.0);

    if(id > 0)
    {
        vec3 p = ro + rd * dist;
        vec3 n = normal(p);

        col = lighting(p, n, rd, id);
    }
    else
    {
        col += vec3(1.0) * stars(rd);
    }

    FragColor = vec4(col,1.0);
}