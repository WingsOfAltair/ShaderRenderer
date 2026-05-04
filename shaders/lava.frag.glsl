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
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.6;

    // Flowing distortion (lava movement)
    float n1 = noise(p * 2.0 + t);
    float n2 = noise(p * 3.0 - t);

    p.x += (n1 - 0.5) * 0.8;
    p.y += (n2 - 0.5) * 0.8;

    // Radial heat structure
    float d = length(p);

    float heat =
        sin(p.x * 4.0 + t)
      + sin(p.y * 4.0 - t)
      + sin((p.x + p.y) * 3.0);

    heat += noise(p * 4.0 + t) * 2.0;

    // Convert to banded levels (IMPORTANT for "solid lava look")
    float bands = floor((heat + 2.0) * 2.5) / 5.0;

    // Optional soft interpolation between bands
    float smoothBands = mix(bands, heat * 0.25, 0.2);

    // Lava color ramp (solid shifting palette)
    vec3 lava =
        smoothstep(0.2, 0.8, smoothBands) * vec3(1.0, 0.2, 0.0) +
        smoothstep(0.5, 1.0, smoothBands) * vec3(1.0, 0.6, 0.0) +
        smoothstep(0.8, 1.2, smoothBands) * vec3(1.0, 1.0, 0.2);

    // Cooling edges
    float edge = smoothstep(1.5, 0.2, d);

    lava *= edge;

    FragColor = vec4(lava, 1.0);
}