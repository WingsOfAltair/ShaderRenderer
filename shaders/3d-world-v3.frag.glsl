#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// =====================================================
// NOISE
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
// LIGHTNING EVENT
// =====================================================
float lightning(float t)
{
    float n = noise(vec3(floor(t * 2.0), 0.0, 0.0));
    return step(0.97, n) * exp(-fract(t * 2.0) * 10.0);
}

// =====================================================
// TERRAIN HEIGHT
// =====================================================
float terrain(vec2 xz)
{
    return
        noise(vec3(xz * 0.15, 0.0)) * 3.0 +
        noise(vec3(xz * 0.5, 10.0)) * 0.7;
}

// =====================================================
// BIOME COLOR (WATER / SAND / GRASS)
// =====================================================
vec3 biome(float h)
{
    vec3 water = vec3(0.02, 0.1, 0.25);
    vec3 sand  = vec3(0.76, 0.7, 0.5);
    vec3 grass = vec3(0.1, 0.5, 0.15);

    float w = smoothstep(-1.0, 0.5, h);
    float s = smoothstep(0.3, 1.5, h);
    float g = smoothstep(1.2, 3.0, h);

    return water * (1.0 - w)
         + sand  * (w - s)
         + grass * s;
}

// =====================================================
// RAIN (WORLD-SPACE STREAKS)
// =====================================================
float rain(vec2 uv, float t)
{
    // stretch for streak effect
    uv.x += sin(t * 0.5) * 0.2;

    vec2 grid = uv * 80.0;

    float id = floor(grid.x);
    float rnd = fract(sin(id * 43758.5453));

    float speed = mix(0.8, 2.5, rnd);

    grid.y += t * speed;

    float drop = step(0.98, noise(vec3(grid, t)));

    // make it streak-like instead of dots
    float streak = smoothstep(0.0, 1.0, fract(grid.y));

    return drop * streak;
}

// =====================================================
// CAMERA
// =====================================================
vec3 sky(vec3 rd)
{
    float t = rd.y * 0.5 + 0.5;
    return mix(
        vec3(0.02, 0.03, 0.06),
        vec3(0.15, 0.2, 0.3),
        t
    );
}

// =====================================================
// RAYMARCH
// =====================================================
float map(vec3 p)
{
    return p.y - terrain(p.xz);
}

vec3 normal(vec3 p)
{
    float e = 0.001;
    return normalize(vec3(
        map(p + vec3(e,0,0)) - map(p - vec3(e,0,0)),
        map(p + vec3(0,e,0)) - map(p - vec3(0,e,0)),
        map(p + vec3(0,0,e)) - map(p - vec3(0,0,e))
    ));
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.4;

    // CAMERA
    vec3 ro = vec3(0.0, 3.0, uTime * 2.0);
    vec3 rd = normalize(vec3(p.x, p.y, -1.5));

    // LIGHTNING
    float flash = lightning(uTime);
    vec3 lightningCol = vec3(0.9, 0.95, 1.0);

    // RAYMARCH
    float d = 0.0;
    vec3 pos;

    int i;
    for (i = 0; i < 64; i++)
    {
        pos = ro + rd * d;
        float h = map(pos);
        if (h < 0.001) break;
        d += h * 0.6;
    }

    vec3 col;

    if (i < 64)
    {
        vec3 n = normal(pos);
        float h = terrain(pos.xz);

        col = biome(h);

        float diff = max(dot(n, normalize(vec3(0.3,1.0,0.2))), 0.0);
        col *= 0.3 + diff;

        // water boost
        float water = smoothstep(-1.0, 0.3, -h);
        col += vec3(0.2,0.4,0.8) * water;

        // lightning reflection
        col += lightningCol * flash * (1.0 - diff) * 2.0;
    }
    else
    {
        col = sky(rd);
        col += lightningCol * flash * 2.5;
    }

    // =====================================================
    // � RAIN OVERLAY (NO FOG)
    // =====================================================
    float r = rain(uv, uTime);

    col = mix(col, vec3(0.7, 0.8, 1.0), r * 0.6);

    // =====================================================
    // ⚡ GLOBAL LIGHTNING EXPOSURE
    // =====================================================
    col *= 1.0 + flash * 3.0;

    FragColor = vec4(col, 1.0);
}