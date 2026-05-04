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

// ---------------- ICE COLOR SYSTEM ----------------
vec3 icePalette(float t)
{
    // cold blues + slight cyan shift
    return vec3(
        0.6 + 0.2 * sin(t),
        0.8 + 0.1 * sin(t + 2.0),
        1.0
    );
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.25;

    // =====================================================
    // � 1. RIVER FLOW FIELD (smooth directional motion)
    // =====================================================
    float flow1 = noise(p * 1.5 + vec2(t, 0.0));
    float flow2 = noise(p * 2.5 - vec2(t * 0.7, t));

    vec2 flow = vec2(flow1, flow2) - 0.5;

    // gentle river current distortion
    p += flow * 0.8;

    // =====================================================
    // � 2. ICE LAYER STRUCTURE (frozen streaks)
    // =====================================================
    float streaks =
        sin(p.x * 3.0 + t * 0.5) * 0.5 +
        sin(p.y * 2.0 + t * 0.3) * 0.5;

    streaks += noise(p * 4.0 + t) * 0.6;

    float ice = smoothstep(-0.2, 1.2, streaks);

    // =====================================================
    // � 3. DEPTH (river thickness illusion)
    // =====================================================
    float dist = length(p);
    float depth = smoothstep(1.5, 0.2, dist);

    // =====================================================
    // ❄️ 4. SUBSURFACE CURRENT (under ice movement)
    // =====================================================
    float current =
        sin(p.x * 2.5 + t) +
        sin(p.y * 2.0 - t) +
        noise(p * 3.0 + t) * 2.0;

    current = smoothstep(-1.0, 2.0, current);

    // =====================================================
    // � 5. TIME-VARYING ICE COLOR
    // =====================================================
    float hueShift = 0.1 * uTime + ice * 0.2;

    vec3 iceColor = icePalette(hueShift);

    // darker deep water under ice
    vec3 deepWater = vec3(0.02, 0.05, 0.12);

    // =====================================================
    // � 6. COMPOSITION
    // =====================================================
    vec3 color = deepWater;

    // ice surface layer
    color = mix(color, iceColor, ice);

    // flowing subsurface streaks
    color += vec3(0.2, 0.4, 0.8) * current * 0.4;

    // soft frost brightness
    color *= 0.8 + 0.2 * depth;

    FragColor = vec4(color, 1.0);
}