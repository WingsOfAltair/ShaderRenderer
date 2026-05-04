#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

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

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 pos = uv * 2.0 - 1.0;
    pos.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.4;

    // Domain warp (makes motion organic)
    vec2 warp;
    warp.x = noise(pos * 2.0 + t);
    warp.y = noise(pos * 2.0 - t);

    pos += (warp - 0.5) * 1.2;

    // Radial structure + flow
    float d = length(pos);

    float field =
        sin(pos.x * 3.0 + t)
      + sin(pos.y * 3.0 - t)
      + sin((pos.x + pos.y) * 2.5);

    field += noise(pos * 3.0 + t * 0.5) * 2.0;

    // Smooth falloff
    float mask = smoothstep(1.5, 0.2, d);

    // Color palette (smooth cycling neon)
    vec3 col = 0.5 + 0.5 * cos(
        vec3(0.0, 2.0, 4.0)
        + field
        + t
    );

    // Extra color depth
    col.r += noise(pos + t) * 0.2;
    col.g += noise(pos - t) * 0.2;

    col *= mask;

    FragColor = vec4(col, 1.0);
}