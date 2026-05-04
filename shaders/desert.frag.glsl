#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

// ------------------------
// HASH + NOISE
// ------------------------
float hash(vec2 p)
{
    p = fract(p * vec2(123.34, 345.45));
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

    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

// ------------------------
// FBM (fractal noise)
// ------------------------
float fbm(vec2 p)
{
    float value = 0.0;
    float amp = 0.5;

    for(int i = 0; i < 5; i++)
    {
        value += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return value;
}

// ------------------------
// DESERT DUNES FUNCTION
// ------------------------
float dunes(vec2 uv)
{
    float t = uTime * 0.05;

    uv.y += sin(uv.x * 1.5 + t * 2.0) * 0.3;
    uv.x += cos(uv.y * 1.2 + t) * 0.2;

    float d = fbm(uv * 2.0 + t);

    // sharpen dune ridges
    d = smoothstep(0.2, 0.8, d);

    return d;
}

// ------------------------
// HEAT HAZE
// ------------------------
float heatHaze(vec2 uv)
{
    float t = uTime * 2.0;

    float n = fbm(uv * vec2(3.0, 8.0) + t);
    return sin(n * 10.0 + t) * 0.02;
}

// ------------------------
// MAIN
// ------------------------
void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution.xy;
    vec2 centered = uv * 2.0 - 1.0;
    centered.x *= uResolution.x / uResolution.y;

    // apply heat distortion near horizon
    float haze = heatHaze(uv);
    uv.x += haze;

    float d = dunes(uv * 3.0);

    // sand colors (warm desert palette)
    vec3 sand1 = vec3(0.76, 0.62, 0.42);
    vec3 sand2 = vec3(0.93, 0.80, 0.55);
    vec3 sand3 = vec3(0.55, 0.40, 0.25);

    vec3 col = mix(sand1, sand2, d);
    col = mix(col, sand3, fbm(uv * 6.0));

    // sun bleaching (top glow)
    float sun = smoothstep(1.2, -0.2, centered.y);
    col += vec3(1.0, 0.7, 0.4) * sun * 0.25;

    // horizon haze
    float horizon = exp(-abs(centered.y) * 2.5);
    col += vec3(0.9, 0.6, 0.3) * horizon * 0.15;

    // subtle brightness clamp
    col = pow(col, vec3(0.95));

    FragColor = vec4(col, 1.0);
}