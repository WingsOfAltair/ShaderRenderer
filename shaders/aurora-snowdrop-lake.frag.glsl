#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// ---------------- SAFE NOISE ----------------
float hash(vec2 p)
{
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x)
         + (c - a) * u.y * (1.0 - u.x)
         + (d - b) * u.x * u.y;
}

// ---------------- AURORA FUNCTION ----------------
vec3 aurora(vec2 p, float t)
{
    float wave =
        sin(p.x * 2.0 + t) +
        sin(p.x * 3.0 - t * 0.7) +
        sin(p.y * 1.5 + t * 0.5);

    float n = noise(p * 2.0 + t);

    float intensity = smoothstep(-1.0, 2.0, wave + n * 2.0);

    vec3 color =
        vec3(0.1, 0.8, 0.6) * intensity +
        vec3(0.2, 0.4, 1.0) * intensity * 0.6 +
        vec3(0.6, 0.2, 1.0) * intensity * 0.3;

    return color;
}

// ---------------- SNOW FUNCTION ----------------
float snow(vec2 uv, float t)
{
    uv *= 40.0;

    float n = noise(uv + vec2(t * 0.2, t));

    // falling motion
    uv.y += t * 2.0;

    float s = step(0.98, n);

    return s;
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.3;

    // =====================================================
    // � 1. FROZEN LAKE BASE
    // =====================================================
    float baseIce =
        noise(p * 1.5) +
        noise(p * 3.0) * 0.5 +
        noise(p * 6.0) * 0.25;

    baseIce = smoothstep(0.3, 0.8, baseIce);

    // =====================================================
    // � 2. CRACK SYSTEM (fracture network)
    // =====================================================
    vec2 warp = vec2(
        noise(p * 2.0 + t),
        noise(p * 2.0 - t)
    );

    p += (warp - 0.5) * 0.6;

    float cracks =
        abs(sin(p.x * 5.0)) +
        abs(sin(p.y * 4.0)) +
        abs(sin((p.x + p.y) * 3.0));

    cracks += noise(p * 5.0 + t) * 2.0;

    float crackMask = smoothstep(1.0, 2.2, cracks);

    // =====================================================
    // � 3. AURORA SKY (background glow)
    // =====================================================
    vec2 sky = p;
    sky.y += 0.5;

    vec3 aur = aurora(sky, t);

    // =====================================================
    // � 4. ICE DEPTH LIGHTING
    // =====================================================
    float dist = length(p);
    float depth = smoothstep(1.4, 0.2, dist);

    // =====================================================
    // �️ 5. SNOW OVERLAY
    // =====================================================
    float s1 = snow(uv, t);
    float s2 = snow(uv * 1.7 + 0.3, t * 1.3);

    float snowLayer = clamp(s1 + s2, 0.0, 1.0);

    vec3 snowColor = vec3(1.0) * snowLayer;

    // =====================================================
    // � 6. ICE COLOR (cold blue palette drift)
    // =====================================================
    float hue = 0.55 + 0.05 * sin(t + baseIce * 3.0);

    vec3 iceColor =
        vec3(0.3, 0.6, 1.0) * baseIce +
        vec3(0.1, 0.3, 0.6);

    // =====================================================
    // � 7. COMPOSITION
    // =====================================================
    vec3 color = aur * 0.6;               // aurora sky base

    color = mix(color, iceColor, baseIce); // frozen lake

    color = mix(color, vec3(0.8), crackMask * 0.6); // cracks

    color += snowColor * 0.6;             // snowfall overlay

    color *= depth;                       // depth fade

    FragColor = vec4(color, 1.0);
}