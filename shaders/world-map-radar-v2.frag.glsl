#version 330 core

in vec2 vUV;
out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// --- Hash ---
float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123);
}

// --- Noise ---
float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1,0));
    float c = hash(i + vec2(0,1));
    float d = hash(i + vec2(1,1));

    vec2 u = f*f*(3.0-2.0*f);

    return mix(a,b,u.x) +
           (c-a)*u.y*(1.0-u.x) +
           (d-b)*u.x*u.y;
}

// --- Fractal noise for continents ---
float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;

    for(int i=0;i<5;i++)
    {
        v += noise(p) * a;
        p *= 2.0;
        a *= 0.5;
    }

    return v;
}

// --- World map (procedural continents) ---
float worldMap(vec2 uv)
{
    // FIX: proper aspect ratio correction
    float aspect = uResolution.x / uResolution.y;
    vec2 p = uv;
    p.x *= aspect;

    // stretch horizontally to look like Earth map
    p.x *= 1.6;

    float n = fbm(p * 3.0);

    return smoothstep(0.45, 0.55, n);
}

// --- Radar sweep lines (multiple) ---
float radarSweep(vec2 uv, float t)
{
    vec2 center = vec2(0.5);
    vec2 p = uv - center;

    float dist = length(p);
    if (dist == 0.0) return 0.0;

    vec2 dir = normalize(p);

    float sweep = 0.0;

    // number of beams
    const int beams = 3;

    for (int i = 0; i < beams; i++)
    {
        float angle = t * 0.8 + float(i) * 2.094395; // 120° spacing

        vec2 beamDir = vec2(cos(angle), sin(angle));

        // dot = 1 → aligned, 0 → perpendicular
        float d = dot(dir, beamDir);

        // narrow beam
        float beam = smoothstep(0.995, 1.0, d);

        // fade with distance
        beam *= exp(-dist * 2.0);

        sweep += beam;
    }

    return sweep;
}

// --- Grid overlay ---
float grid(vec2 uv)
{
    vec2 g = abs(fract(uv * 20.0) - 0.5);
    float line = min(g.x, g.y);
    return smoothstep(0.02, 0.0, line) * 0.15;
}

void main()
{
    vec2 uv = vUV;

    float t = uTime;

    // --- world ---
    float land = worldMap(uv);

    // --- radar ---
    float radar = radarSweep(uv, t);

    // --- grid ---
    float g = grid(uv);

    // --- colors ---
    vec3 ocean = vec3(0.02, 0.05, 0.08);
    vec3 landColor = vec3(0.05, 0.25, 0.1);

    vec3 base = mix(ocean, landColor, land);

    // radar glow
    vec3 radarColor = vec3(0.0, 1.0, 0.4) * radar * 1.5;

    // subtle noise flicker
    float flicker = noise(uv * 50.0 + t * 2.0) * 0.05;

    vec3 color = base + radarColor + g + flicker;

    FragColor = vec4(color, 1.0);
}