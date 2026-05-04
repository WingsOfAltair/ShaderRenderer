#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// ---------------- NOISE ----------------
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

// ---------------- LIGHTNING ----------------
float lightningEvent(float t)
{
    float n = noise(vec2(floor(t * 2.0), 0.0));
    float trigger = step(0.97, n);

    float flicker = exp(-fract(t * 2.0) * 10.0);

    return trigger * flicker;
}

// ---------------- CLOUD SKY ----------------
float clouds(vec2 p, float t)
{
    float n = 0.0;
    n += noise(p * 1.2 + t) * 0.6;
    n += noise(p * 2.5 - t * 0.5) * 0.3;
    n += noise(p * 5.0 + t * 0.2) * 0.1;
    return n;
}

// ---------------- ICE LAND ----------------
float ice(vec2 p, float t)
{
    float n =
        noise(p * 1.5) +
        noise(p * 3.0) * 0.5 +
        noise(p * 6.0) * 0.25;

    float cracks =
        abs(sin(p.x * 5.0)) +
        abs(sin(p.y * 4.0)) +
        abs(sin((p.x + p.y) * 3.0));

    cracks += noise(p * 5.0 + t) * 2.0;

    return mix(n, cracks * 0.5, 0.4);
}

// ---------------- SKY GRADIENT ----------------
vec3 skyColor(vec2 uv)
{
    return mix(
        vec3(0.02, 0.03, 0.06),
        vec3(0.1, 0.15, 0.25),
        uv.y * 0.5 + 0.5
    );
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.4;

    // =====================================================
    // ⚡ GLOBAL LIGHTNING EVENT
    // =====================================================
    float flash = lightningEvent(uTime);
    float exposure = 1.0 + flash * 5.0;

    vec3 lightningColor = vec3(0.9, 0.95, 1.0);

    // =====================================================
    // � SKY
    // =====================================================
    vec2 skyUV = p;

    float c = clouds(skyUV * 1.2, t);
    float cloudMask = smoothstep(0.4, 0.8, c);

    vec3 sky = skyColor(uv);

    vec3 cloudCol = mix(
        vec3(0.05, 0.06, 0.08),
        vec3(0.25, 0.25, 0.3),
        cloudMask
    );

    sky = mix(sky, cloudCol, cloudMask);

    // lightning affects sky
    sky += lightningColor * flash * 3.0;

    // =====================================================
    // � LAND (bottom half)
    // =====================================================
    float landMask = step(0.0, -p.y);

    vec2 landUV = p * 2.0;

    float iceVal = ice(landUV, t);
    iceVal = smoothstep(0.2, 0.9, iceVal);

    vec3 iceColor = vec3(0.25, 0.55, 0.95) * iceVal;
    vec3 dark = vec3(0.02, 0.04, 0.08);

    vec3 land = mix(dark, iceColor, iceVal);

    // cracks brighten during lightning
    land += lightningColor * flash * iceVal * 1.5;

    // =====================================================
    // � BLEND SKY + LAND
    // =====================================================
    vec3 color;

    if (p.y > 0.0)
        color = sky;
    else
        color = land;

    // global exposure spike (lightning flash)
    color *= exposure;

    // horizon fog blend
    float horizon = smoothstep(-0.2, 0.2, p.y);
    color *= horizon + 0.3;

    FragColor = vec4(color, 1.0);
}