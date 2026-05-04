#version 330 core

in vec2 vUV;
out vec4 FragColor;

uniform float uTime;

// -------------------- HASH --------------------
float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// -------------------- NOISE --------------------
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

// -------------------- ELECTRIC LINE --------------------
float electricLine(float coord, float x, float t)
{
    float wave = sin(x * 10.0 + t * 3.0);
    float distortion = noise(vec2(x * 2.0, t * 0.5)) * 0.3;

    float line = abs(coord - (wave * 0.05 + distortion));
    return smoothstep(0.02, 0.0, line);
}

// -------------------- CHARGE FIELD --------------------
float chargeField(vec2 uv, float t)
{
    float c = 0.0;

    for (float i = 1.0; i < 5.0; i++)
    {
        vec2 pos = vec2(
            0.5 + sin(t * 0.7 + i) * 0.3,
            0.5 + cos(t * 0.9 + i * 1.3) * 0.3
        );

        float d = distance(uv, pos);
        c += 0.03 / (d + 0.05); // avoid infinity
    }

    return clamp(c, 0.0, 1.0);
}

// -------------------- MAIN --------------------
void main()
{
    vec2 uv = vUV;
    float t = uTime;

    vec2 p = uv - 0.5;

    // animated electric grid
    float lines =
        electricLine(p.y, p.x, t) +
        electricLine(p.x, p.y, t * 1.2);

    // moving charge field
    float charge = chargeField(uv, t);

    vec3 cold = vec3(0.1, 0.6, 1.0);
    vec3 hot  = vec3(1.0, 0.3, 0.1);
    vec3 neon = mix(cold, hot, charge);

    float glow = lines * (0.6 + charge * 1.5);

    vec3 color = neon * glow;

    // flicker animation
    color += vec3(0.2, 0.5, 1.0) *
             noise(uv * 10.0 + vec2(t * 2.0, t * 1.5)) * 0.2;

    FragColor = vec4(color, 1.0);
}