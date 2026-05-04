#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// =====================================================
// � NOISE
// =====================================================
float hash(vec3 p)
{
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z);
}

float noise(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);

    float n000 = hash(i + vec3(0,0,0));
    float n100 = hash(i + vec3(1,0,0));
    float n010 = hash(i + vec3(0,1,0));
    float n110 = hash(i + vec3(1,1,0));
    float n001 = hash(i + vec3(0,0,1));
    float n101 = hash(i + vec3(1,0,1));
    float n011 = hash(i + vec3(0,1,1));
    float n111 = hash(i + vec3(1,1,1));

    vec3 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(mix(n000,n100,u.x), mix(n010,n110,u.x), u.y),
        mix(mix(n001,n101,u.x), mix(n011,n111,u.x), u.y),
        u.z
    );
}

// =====================================================
// ⚡ LIGHTNING EVENT
// =====================================================
float lightning(float t)
{
    float n = noise(vec3(floor(t * 2.0), 0.0, 0.0));
    float flash = step(0.97, n);
    return flash * exp(-fract(t * 2.0) * 10.0);
}

// =====================================================
// � TERRAIN HEIGHT (ICE WORLD)
// =====================================================
float terrain(vec2 xz)
{
    float h =
        noise(vec3(xz * 0.2, 0.0)) * 2.0 +
        noise(vec3(xz * 0.5, 10.0)) * 0.5;

    return h;
}

// =====================================================
// � SKY COLOR
// =====================================================
vec3 sky(vec3 rd)
{
    float t = rd.y * 0.5 + 0.5;

    vec3 top = vec3(0.02, 0.03, 0.06);
    vec3 mid = vec3(0.08, 0.12, 0.18);
    vec3 horizon = vec3(0.2, 0.25, 0.3);

    vec3 c = mix(top, mid, t);
    c = mix(c, horizon, smoothstep(0.0, 0.4, t));

    return c;
}

// =====================================================
// � RAYMARCH
// =====================================================
float map(vec3 p)
{
    float ground = p.y - terrain(p.xz);
    return ground;
}

vec3 calcNormal(vec3 p)
{
    float e = 0.001;
    return normalize(vec3(
        map(p + vec3(e,0,0)) - map(p - vec3(e,0,0)),
        map(p + vec3(0,e,0)) - map(p - vec3(0,e,0)),
        map(p + vec3(0,0,e)) - map(p - vec3(0,0,e))
    ));
}

// =====================================================
// � FOG
// =====================================================
vec3 fog(vec3 col, float dist)
{
    vec3 fogColor = vec3(0.6, 0.7, 0.8);
    float f = exp(-dist * 0.15);
    return mix(fogColor, col, f);
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.4;

    // =====================================================
    // � CAMERA
    // =====================================================
    vec3 ro = vec3(0.0, 2.0, uTime * 2.0);
    vec3 rd = normalize(vec3(p.x, p.y, -1.5));

    // =====================================================
    // ⚡ LIGHTNING GLOBAL EVENT
    // =====================================================
    float flash = lightning(uTime);
    vec3 lightCol = vec3(0.9, 0.95, 1.0);

    // =====================================================
    // � RAYMARCH LOOP
    // =====================================================
    float d = 0.0;
    vec3 pos;

    int steps;
    for (steps = 0; steps < 64; steps++)
    {
        pos = ro + rd * d;
        float h = map(pos);

        if (h < 0.001) break;

        d += h * 0.6;
    }

    vec3 col;

    if (steps < 64)
    {
        // hit ground
        vec3 n = calcNormal(pos);

        float ice = noise(vec3(pos.xz * 2.0, 0.0));

        vec3 base = vec3(0.2, 0.5, 0.9) * ice;
        vec3 dark = vec3(0.02, 0.04, 0.08);

        float diff = max(dot(n, normalize(vec3(0.3,1.0,0.2))), 0.0);

        col = mix(dark, base, diff);

        // lightning reveals cracks
        col += lightCol * flash * (1.0 - diff) * 2.0;
    }
    else
    {
        // sky
        col = sky(rd);

        // lightning sky flash
        col += lightCol * flash * 2.5;
    }

    // =====================================================
    // � FOG
    // =====================================================
    col = fog(col, d);

    // lightning exposure spike
    col *= 1.0 + flash * 3.0;

    FragColor = vec4(col, 1.0);
}