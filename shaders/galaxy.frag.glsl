#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// =====================================================
// HASH (stars only)
// =====================================================
float hash(vec2 p)
{
    p = fract(p * vec2(123.34, 456.21));
    return fract(p.x * p.y);
}

// =====================================================
// STAR FIELD (UNCHANGED, CLEAN)
// =====================================================
float stars(vec2 uv, float t)
{
    vec2 gv = fract(uv * 120.0) - 0.5;
    vec2 id = floor(uv * 120.0);

    float rnd = hash(id);

    float star = step(0.9985, rnd);

    float dist = length(gv);

    float twinkle = 0.6 + 0.4 * sin(t + rnd * 50.0);

    return star * twinkle * smoothstep(0.5, 0.0, dist);
}

// =====================================================
// FIXED GALAXY (NO CONTINUOUS WAVE)
// =====================================================
float galaxy(vec2 p)
{
    // controlled jitter (float ONLY)
    float j = hash(floor(p * 2.0)) - 0.5;
    p.y += j * 0.25;

    float d = abs(p.y);

    float core = exp(-d * 4.5);

    float breaks = hash(vec2(floor(p.x * 3.0), 0.0)) *
                   hash(vec2(floor(p.x * 7.0), 1.0));

    float structure = mix(0.4, 1.0, breaks);

    return core * structure;
}

// =====================================================
// VERY SUBTLE NEBULA (NO PATTERNS)
// =====================================================
vec3 nebula(vec2 p, float t)
{
    float n =
        hash(floor(p * 2.0)) +
        0.5 * hash(floor(p * 4.0 + 10.0));

    float v = smoothstep(0.2, 0.8, n);

    return vec3(0.25, 0.2, 0.5) * v;
}

// =====================================================
// SKY BASE
// =====================================================
vec3 sky(vec2 uv)
{
    float h = uv.y;

    return mix(
        vec3(0.005, 0.005, 0.02),
        vec3(0.03, 0.03, 0.07),
        h
    );
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.1;

    // =====================================================
    // BASE SKY
    // =====================================================
    vec3 col = sky(uv);

    // =====================================================
    // GALAXY (NOW BROKEN + STRUCTURED)
    // =====================================================
    float g = galaxy(p * 0.8);

    col += vec3(0.7, 0.5, 1.0) * g * 2.2;
    col += vec3(0.2, 0.6, 1.0) * g * 0.8;

    // =====================================================
    // NEBULA (VERY SOFT BACKGROUND ONLY)
    // =====================================================
    col += nebula(p * 0.6, t) * 0.5;

    // =====================================================
    // STARS
    // =====================================================
    float s = stars(uv, t);

    col += vec3(1.0) * s * 1.3;
    col += vec3(0.7, 0.8, 1.0) * pow(s, 4.0) * 2.0;

    FragColor = vec4(col, 1.0);
}