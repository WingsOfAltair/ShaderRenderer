#version 120

uniform vec2 iResolution;
uniform float iTime;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

void main()
{
    vec2 res = (iResolution.x > 0.0) ? iResolution : vec2(800.0, 600.0);

    vec2 uv = gl_FragCoord.xy / res;

    float t = iTime * 0.05;

    // center + aspect fix
    uv = uv * 2.0 - 1.0;
    uv.x *= res.x / res.y;

    // movement
    uv += vec2(t, -t * 0.3);

    // ===== NEBULA (make it visible) =====
    float n = noise(uv * 3.0 + t);

    vec3 col = vec3(0.02, 0.02, 0.05);
    col += vec3(0.3, 0.0, 0.5) * n;
    col += vec3(0.0, 0.3, 0.6) * noise(uv * 2.0 - t);

    // ===== STARS (much higher density) =====
    vec2 gv = fract(uv * 60.0) - 0.5;
    vec2 id = floor(uv * 60.0);

    float h = hash(id);

    float star = smoothstep(0.2, 0.0, length(gv)) * step(0.7, h);

    col += star * 1.5; // brighter stars

    // gamma boost (IMPORTANT for "blackish" look)
    col = pow(col, vec3(0.8));

    gl_FragColor = vec4(col, 1.0);
}