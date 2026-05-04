#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// =====================================================
// SIMPLE NOISE (stable, fast)
// =====================================================
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
    float b = hash(i + vec2(1, 0));
    float c = hash(i + vec2(0, 1));
    float d = hash(i + vec2(1, 1));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

// =====================================================
// ELECTRIC FIELD (MOSFET-like channel)
// =====================================================
float electricField(vec2 uv, float time)
{
    // gate voltage pulse
    float gate = smoothstep(0.2, 0.8, sin(time * 0.6) * 0.5 + 0.5);

    // channel shape
    float channel = smoothstep(0.45, 0.5, abs(uv.y));

    // drain-source bias flow
    float flow = uv.x + time * 0.5;

    // noise perturbation (electron scattering)
    float n = noise(uv * 20.0 + time);

    return gate * (1.0 - channel) * (1.0 + 0.5 * n) * sin(flow * 10.0);
}

// =====================================================
// ELECTRON PARTICLE FIELD
// =====================================================
float electrons(vec2 uv, float time)
{
    vec2 p = uv;

    // drift toward drain
    p.x += time * 0.3;

    float n = noise(p * 30.0);

    // particle density
    float e = step(0.92, n);

    // channel confinement
    float channel = smoothstep(0.3, 0.5, abs(uv.y));

    return e * (1.0 - channel);
}

// =====================================================
// FIELD LINES
// =====================================================
vec3 fieldLines(vec2 uv, float time)
{
    float f = electricField(uv, time);

    float glow = abs(sin(f * 6.0));

    vec3 color = vec3(0.1, 0.6, 1.0) * glow;

    return color;
}

// =====================================================
// MAIN
// =====================================================
void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= uResolution.x / uResolution.y;

    float t = uTime;

    // base semiconductor substrate
    vec3 base = vec3(0.02, 0.03, 0.05);

    // MOSFET channel glow
    float field = electricField(uv, t);
    vec3 channelGlow = vec3(0.1, 0.7, 1.0) * abs(field);

    // electron flow
    float e = electrons(uv, t);
    vec3 electronColor = vec3(0.0, 1.0, 0.3) * e;

    // field visualization
    vec3 lines = fieldLines(uv, t);

    // drain/source glow
    float drain = smoothstep(0.2, 0.0, abs(uv.y - 0.5));
    float source = smoothstep(0.2, 0.0, abs(uv.y + 0.5));

    vec3 contactGlow = vec3(1.0, 0.6, 0.1) * (drain + source);

    // final composition
    vec3 col = base;
    col += channelGlow * 0.8;
    col += electronColor * 1.5;
    col += lines * 0.6;
    col += contactGlow;

    // mild bloom
    col = 1.0 - exp(-col);

    FragColor = vec4(col, 1.0);
}