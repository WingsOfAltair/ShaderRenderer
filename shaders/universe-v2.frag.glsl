#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// =====================================================
// HASH / NOISE
// =====================================================
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

// =====================================================
// STARFIELD
// =====================================================
float stars(vec2 uv)
{
    vec2 gv = fract(uv * 200.0);
    vec2 id = floor(uv * 200.0);

    float r = hash(id);

    float star = step(0.995, r);

    float flicker = sin(uTime * 2.0 + r * 10.0) * 0.5 + 0.5;

    float d = length(gv - 0.5);

    return star * smoothstep(0.5, 0.0, d) * flicker;
}

// =====================================================
// NEBULA
// =====================================================
vec3 nebula(vec2 uv)
{
    float n = noise(uv * 3.0 + uTime * 0.02);
    float n2 = noise(uv * 6.0 - uTime * 0.01);

    vec3 col = vec3(0.1, 0.2, 0.4);
    col += vec3(0.3, 0.1, 0.5) * n;
    col += vec3(0.1, 0.4, 0.6) * n2;

    return col * 0.6;
}

// =====================================================
// SHOOTING STARS
// =====================================================
float shootingStars(vec2 uv)
{
    float t = uTime;

    float result = 0.0;

    for (int i = 0; i < 6; i++)
    {
        float fi = float(i);

        vec2 seed = vec2(fi * 12.9898, fi * 78.233);
        float rnd = hash(seed);

        float startTime = fract(rnd + floor(t * 0.2)) * 10.0;

        float life = t - startTime;

        vec2 start = vec2(hash(seed + 1.0), hash(seed + 2.0)) * 2.0 - 1.0;
        vec2 dir = normalize(vec2(hash(seed + 3.0), hash(seed + 4.0)) * 2.0 - 1.0);

        vec2 pos = start + dir * life * 0.4;

        float d = length(cross(vec3(pos - uv, 0.0), vec3(dir, 0.0)).z);

        float trail = smoothstep(0.02, 0.0, d);

        float fade = smoothstep(0.0, 2.0, life) * smoothstep(6.0, 3.0, life);

        result += trail * fade;
    }

    return result;
}

// =====================================================
// ASTEROIDS (moving particles)
// =====================================================
float asteroids(vec2 uv)
{
    float t = uTime;

    float a = 0.0;

    for (int i = 0; i < 12; i++)
    {
        float fi = float(i);

        vec2 id = vec2(fi * 19.19, fi * 7.13);

        vec2 pos = vec2(
            hash(id),
            hash(id + 1.0)
        ) * 2.0 - 1.0;

        vec2 vel = normalize(vec2(
            hash(id + 2.0),
            hash(id + 3.0)
        ) * 2.0 - 1.0) * 0.2;

        pos += vel * t;

        pos = fract(pos * 0.5 + 0.5) * 2.0 - 1.0;

        float d = length(uv - pos);

        float rock = smoothstep(0.02, 0.0, d);

        a += rock;
    }

    return a;
}

// =====================================================
// MAIN
// =====================================================
void main()
{
    vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution.xy) / uResolution.y;

    // background
    vec3 col = nebula(uv);

    // stars
    float s = stars(uv);
    col += vec3(1.0) * s;

    // shooting stars
    float sh = shootingStars(uv);
    col += vec3(1.0, 0.8, 0.6) * sh;

    // asteroids
    float a = asteroids(uv);
    col += vec3(0.6, 0.6, 0.7) * a;

    // subtle glow
    col *= 1.2;

    FragColor = vec4(col, 1.0);
}