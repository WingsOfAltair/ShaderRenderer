#version 330 core

in vec2 vUV;
out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// ---------------- HASH ----------------
float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}

// ---------------- NOISE ----------------
float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

// ---------------- FBM ----------------
float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;

    for(int i = 0; i < 5; i++)
    {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }

    return v;
}

// ---------------- WORLD MAP ----------------
float worldMap(vec2 uv)
{
    float n = fbm(uv * 3.0);
    return smoothstep(0.45, 0.5, n);
}

// ---------------- RADAR SWEEP (LINEAR, NOT CIRCULAR) ----------------
float radarSweep(vec2 uv, float t)
{
    float sweepX = fract(t * 0.2); // moves left → right

    float dist = abs(uv.x - sweepX);

    float beam = smoothstep(0.05, 0.0, dist);

    return beam;
}

// ---------------- GRID ----------------
float grid(vec2 uv)
{
    vec2 g = abs(fract(uv * 20.0) - 0.5);
    float line = min(g.x, g.y);

    return smoothstep(0.02, 0.0, line) * 0.2;
}

// ---------------- BLIPS ----------------
float radarBlips(vec2 uv, float t)
{
    float b = 0.0;

    for(int i = 0; i < 8; i++)
    {
        float fi = float(i);

        vec2 pos = vec2(
            fract(sin(fi * 12.9898) * 43758.5453),
            fract(cos(fi * 78.233) * 12345.6789)
        );

        float d = distance(uv, pos);

        float pulse = smoothstep(0.02, 0.0, d);
        pulse *= 0.5 + 0.5 * sin(t * 4.0 + fi * 3.0);

        b += pulse;
    }

    return b;
}

// ---------------- MAIN ----------------
void main()
{
    vec2 uv = vUV;
    float t = uTime;

    // ---- FIX aspect ratio ONLY (no circular distortion) ----
    float aspect = uResolution.x / uResolution.y;
    uv.x = (uv.x - 0.5) * aspect + 0.5;

    // ---- WORLD ----
    float land = worldMap(uv);

    vec3 ocean = vec3(0.02, 0.08, 0.12);
    vec3 landColor = vec3(0.05, 0.25, 0.15);

    vec3 color = mix(ocean, landColor, land);

    // ---- RADAR EFFECTS ----
    float sweep = radarSweep(uv, t);
    float gridLines = grid(uv);
    float blips = radarBlips(uv, t);

    vec3 radarColor = vec3(0.0, 1.0, 0.3);

    color += radarColor * sweep * 1.5;
    color += radarColor * gridLines;
    color += radarColor * blips * 2.0;

    FragColor = vec4(color, 1.0);
}