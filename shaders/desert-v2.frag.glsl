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

float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;

    for(int i = 0; i < 5; i++)
    {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// ------------------------
// DUNES
// ------------------------
float dunes(vec2 uv)
{
    float t = uTime * 0.05;

    uv.y += sin(uv.x * 1.5 + t * 2.0) * 0.3;
    uv.x += cos(uv.y * 1.2 + t) * 0.2;

    float d = fbm(uv * 2.0 + t);
    return smoothstep(0.25, 0.85, d);
}

// ------------------------
// HEAT HAZE
// ------------------------
float heatHaze(vec2 uv)
{
    float t = uTime * 1.5;
    float n = fbm(uv * vec2(3.0, 8.0) + t);
    return sin(n * 10.0 + t) * 0.015;
}

// ------------------------
// SKY COLOR GRADIENT
// ------------------------
vec3 sky(vec2 uv)
{
    // vertical sky gradient
    float h = smoothstep(0.0, 1.0, uv.y);

    vec3 horizonColor = vec3(0.95, 0.65, 0.35); // warm desert horizon
    vec3 skyColor     = vec3(0.25, 0.45, 0.85); // deep blue sky
    vec3 topColor     = vec3(0.05, 0.10, 0.25); // deep space blue

    vec3 col = mix(horizonColor, skyColor, h);
    col = mix(col, topColor, h * h);

    return col;
}

// ------------------------
// SUN
// ------------------------
float sun(vec2 uv)
{
    vec2 sunPos = vec2(0.2, 0.75);
    float d = distance(uv, sunPos);
    return smoothstep(0.12, 0.0, d);
}

// ------------------------
// CLOUDS (very subtle desert haze clouds)
// ------------------------
float clouds(vec2 uv)
{
    float t = uTime * 0.02;
    uv.x += t;

    float n = fbm(uv * 3.0);
    return smoothstep(0.5, 0.8, n);
}

// ------------------------
// MAIN
// ------------------------
void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution.xy;

    // aspect correction for sky movement
    vec2 centered = uv * 2.0 - 1.0;
    centered.x *= uResolution.x / uResolution.y;

    // apply heat distortion only near ground
    float haze = heatHaze(uv);
    uv.x += haze;

    // split sky / ground
    float horizon = smoothstep(0.45, 0.55, uv.y);

    // -------- SKY --------
    vec3 skyCol = sky(uv);

    float s = sun(uv);
    skyCol += vec3(1.0, 0.7, 0.3) * s * 0.6;

    float cl = clouds(uv);
    skyCol = mix(skyCol, skyCol + 0.15, cl * 0.2);

    // -------- GROUND --------
    float d = dunes(uv * 3.0);

    vec3 sand1 = vec3(0.76, 0.62, 0.42);
    vec3 sand2 = vec3(0.93, 0.80, 0.55);
    vec3 sand3 = vec3(0.55, 0.40, 0.25);

    vec3 groundCol = mix(sand1, sand2, d);
    groundCol = mix(groundCol, sand3, fbm(uv * 6.0));

    // horizon glow (important for realism)
    groundCol += vec3(1.0, 0.5, 0.2) * (1.0 - abs(uv.y - 0.5)) * 0.15;

    // -------- BLEND SKY + GROUND --------
    vec3 col = mix(groundCol, skyCol, horizon);

    // slight gamma correction
    col = pow(col, vec3(0.95));

    FragColor = vec4(col, 1.0);
}