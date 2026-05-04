#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// --- safe noise ---
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

// HSV → RGB (this is what fixes your “stuck color” problem)
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.5;

    // � FLOW FIELD
    float n = noise(p * 2.5 + t);
    p += (n - 0.5) * 1.2;

    float field =
        sin(p.x * 3.0 + t) +
        sin(p.y * 3.0 - t) +
        sin((p.x + p.y) * 2.0 + t);

    field += noise(p * 3.0 + t) * 2.0;

    // � CRITICAL FIX: normalize to 0..1
    float f = smoothstep(-2.0, 2.0, field);

    // � TIME-DRIVEN COLOR SHIFT (THIS IS THE KEY FIX)
    float hue = fract(
        0.05 * uTime +   // slow global shift
        f * 0.6          // structure-based variation
    );

    float saturation = 1.0;
    float value = mix(0.3, 1.0, f);

    vec3 color = hsv2rgb(vec3(hue, saturation, value));

    // � lava glow emphasis
    color *= mix(0.6, 1.2, f);

    FragColor = vec4(color, 1.0);
}