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

// ---------------- WIND FIELD ----------------
vec2 wind(vec2 p, float t)
{
    float w1 = noise(p * 1.5 + t);
    float w2 = noise(p * 2.0 - t);

    return vec2(w1, w2) - 0.5;
}

// ---------------- AURORA ----------------
vec3 aurora(vec2 p, float t)
{
    float wave =
        sin(p.x * 2.0 + t) +
        sin(p.x * 3.0 - t * 0.7) +
        sin(p.y * 1.5 + t * 0.5);

    float n = noise(p * 2.0 + t);

    float i = smoothstep(-1.5, 2.0, wave + n * 2.0);

    return vec3(0.1, 0.7, 0.6) * i +
           vec3(0.2, 0.4, 1.0) * i * 0.6;
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.4;

    // =====================================================
    // �️ 1. STORM INTENSITY (global weather system)
    // =====================================================
    float storm = 0.5 + 0.5 * sin(uTime * 0.15);

    // stronger storm = more distortion + snow + crack speed
    float windStrength = mix(0.3, 1.5, storm);

    // =====================================================
    // �️ 2. WIND DISTORTION (affects EVERYTHING)
    // =====================================================
    vec2 w = wind(p * 2.0, t);
    p += w * windStrength;

    // =====================================================
    // � 3. ICE STRESS FIELD (crack buildup over time)
    // =====================================================
    float stress =
        noise(p * 1.5 + t) +
        noise(p * 3.0 - t) * 0.6 +
        noise(p * 6.0) * 0.3;

    stress += storm * 0.8; // storm increases cracking

    float cracks =
        abs(sin(p.x * 5.0)) +
        abs(sin(p.y * 4.0)) +
        abs(sin((p.x + p.y) * 3.0));

    cracks += stress * 2.0;

    float crackMask = smoothstep(1.0, 2.5, cracks);

    // =====================================================
    // � 4. ICE BREAK ZONES (weak points forming over time)
    // =====================================================
    float weakZones =
        noise(p * 1.2 + t * 0.5) +
        noise(p * 2.5 - t * 0.3);

    weakZones = smoothstep(0.6, 1.0, weakZones + storm * 0.3);

    crackMask += weakZones * 0.4;

    // =====================================================
    // �️ 5. SNOW STORM (wind-driven particles)
    // =====================================================
    vec2 snowUV = uv * 50.0;

    snowUV.y += uTime * (1.5 + windStrength);
    snowUV.x += sin(uTime + snowUV.y * 0.1) * 2.0 * windStrength;

    float snow = step(0.98, noise(snowUV));

    // layered snow
    vec2 snowUV2 = uv * 80.0 + 0.3;
    snowUV2.y += uTime * 2.5;

    snow += step(0.985, noise(snowUV2));

    snow = clamp(snow, 0.0, 1.0);

    // =====================================================
    // � 6. ICE BASE
    // =====================================================
    float ice =
        noise(p * 1.5) +
        noise(p * 3.0) * 0.5 +
        noise(p * 6.0) * 0.25;

    ice = smoothstep(0.2, 0.8, ice);

    // =====================================================
    // � 7. AURORA (reduced during storm)
    // =====================================================
    vec3 aur = aurora(p * 0.8, t);

    aur *= mix(1.0, 0.3, storm); // storm hides aurora

    // =====================================================
    // � 8. DEPTH FOG
    // =====================================================
    float dist = length(p);
    float fog = smoothstep(1.6, 0.2, dist);

    // =====================================================
    // � 9. COLOR SYSTEM
    // =====================================================
    vec3 iceColor = vec3(0.25, 0.55, 0.9) * ice;
    vec3 deepWater = vec3(0.02, 0.05, 0.12);
    vec3 crackGlow = vec3(0.8, 0.9, 1.0);

    vec3 color = deepWater;

    // ice layer
    color = mix(color, iceColor, ice);

    // cracks (bright fracture lines)
    color = mix(color, crackGlow, crackMask * 0.6);

    // aurora sky bleed
    color += aur * 0.5;

    // snow overlay (white noise accumulation)
    color = mix(color, vec3(1.0), snow * 0.5);

    // fog + storm whitening
    color *= fog;
    color = mix(color, vec3(0.8), storm * 0.2);

    FragColor = vec4(color, 1.0);
}