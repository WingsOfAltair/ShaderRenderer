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

// ---------------- LIGHTNING FUNCTION ----------------
float lightningBurst(float t)
{
    // sparse random flashes
    float n = noise(vec2(floor(t * 2.0), 0.0));

    float flash = step(0.92, n); // rare event

    // sharp decay pulse
    float pulse = exp(-fract(t * 2.0) * 10.0);

    return flash * pulse;
}

// ---------------- WIND / SNOW ----------------
float snow(vec2 uv, float t)
{
    uv *= 60.0;
    uv.y += t * 2.5;
    uv.x += sin(t + uv.y * 0.1) * 2.0;

    return step(0.985, noise(uv));
}

// ---------------- AURORA ----------------
vec3 aurora(vec2 p, float t)
{
    float w =
        sin(p.x * 2.0 + t) +
        sin(p.x * 3.0 - t * 0.7);

    float n = noise(p * 2.0 + t);

    float i = smoothstep(-1.5, 2.0, w + n * 2.0);

    return vec3(0.1, 0.7, 0.6) * i +
           vec3(0.2, 0.4, 1.0) * i * 0.6;
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.5;

    // =====================================================
    // ⚡ LIGHTNING SYSTEM (GLOBAL FLASH EVENT)
    // =====================================================
    float flash = lightningBurst(uTime);

    // brighten whole scene during lightning
    float exposure = 1.0 + flash * 4.0;

    // =====================================================
    // ❄️ ICE BASE (cold surface)
    // =====================================================
    float ice =
        noise(p * 1.5) +
        noise(p * 3.0) * 0.5;

    ice = smoothstep(0.2, 0.8, ice);

    // =====================================================
    // � FOG / STORM DENSITY
    // =====================================================
    float dist = length(p);
    float fog = smoothstep(1.6, 0.2, dist);

    float stormFog = 0.6 + 0.4 * sin(uTime * 0.2);
    fog *= stormFog;

    // =====================================================
    // � SNOW BLIZZARD
    // =====================================================
    float s1 = snow(uv, t);
    float s2 = snow(uv * 1.5 + 0.2, t * 1.3);

    float snowLayer = clamp(s1 + s2, 0.0, 1.0);

    // =====================================================
    // � AURORA (suppressed by storm + lightning)
    // =====================================================
    vec3 aur = aurora(p * 0.8, t);

    aur *= (1.0 - fog) * (1.0 - flash * 0.8);

    // =====================================================
    // � BASE COLORS
    // =====================================================
    vec3 iceColor = vec3(0.25, 0.55, 0.95) * ice;
    vec3 deep = vec3(0.02, 0.04, 0.08);

    vec3 color = deep;

    // ice layer
    color = mix(color, iceColor, ice);

    // aurora sky glow
    color += aur * 0.5;

    // snow overlay
    color = mix(color, vec3(1.0), snowLayer * 0.5);

    // =====================================================
    // ⚡ LIGHTNING ILLUMINATION (THIS IS THE KEY PART)
    // =====================================================
    vec3 lightningColor = vec3(0.9, 0.95, 1.0);

    color += lightningColor * flash * 2.5;

    // freeze-frame effect during lightning (ice becomes brighter)
    color = mix(color, vec3(0.8, 0.9, 1.0), flash * ice);

    // =====================================================
    // � FINAL FOG + EXPOSURE
    // =====================================================
    color *= fog;
    color *= exposure;

    FragColor = vec4(color, 1.0);
}