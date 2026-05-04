#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

// ------------------------
// HASH / NOISE
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
// ROTATION
// ------------------------
mat2 rot(float a)
{
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// ------------------------
// SPHERE INTERSECTION
// ------------------------
float sphere(vec3 ro, vec3 rd, float r)
{
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r * r;
    float h = b * b - c;
    if(h < 0.0) return -1.0;
    return -b - sqrt(h);
}

// ------------------------
// EARTH PROCEDURAL
// ------------------------
vec3 earth(vec3 p)
{
    float lat = asin(p.y);
    float lon = atan(p.z, p.x);

    vec2 uv = vec2(lon, lat);

    uv.x += uTime * 0.05;

    float land = noise(uv * 6.0);
    float detail = noise(uv * 20.0);

    float c = smoothstep(0.45, 0.65, land);

    vec3 ocean = vec3(0.02, 0.05, 0.2);
    vec3 landC = vec3(0.05, 0.25, 0.08);

    vec3 col = mix(ocean, landC, c);
    col += detail * 0.05;

    return col;
}

// ------------------------
// CLOUDS
// ------------------------
float clouds(vec3 p)
{
    vec2 uv = vec2(atan(p.z, p.x), asin(p.y));
    uv.x += uTime * 0.02;

    return smoothstep(0.55, 0.75, noise(uv * 8.0));
}

// ------------------------
// CITY LIGHTS
// ------------------------
float lights(vec3 p)
{
    vec2 uv = vec2(atan(p.z, p.x), asin(p.y));
    uv.x += uTime * 0.05;

    return smoothstep(0.6, 0.9, noise(uv * 40.0));
}

// ------------------------
// STARFIELD (3 LAYERS = DEPTH)
// ------------------------
float stars(vec2 uv, float scale, float speed)
{
    vec2 gv = fract(uv * scale) - 0.5;
    vec2 id = floor(uv * scale);

    float h = hash(id);
    float d = length(gv);

    float star = smoothstep(0.02, 0.0, d) * step(0.97, h);

    return star;
}

// ------------------------
// GALAXY SPIRAL
// ------------------------
vec3 galaxy(vec2 uv, vec2 center, vec3 color)
{
    vec2 p = uv - center;

    float r = length(p);
    float a = atan(p.y, p.x);

    // spiral arms
    float arms = sin(3.0 * a + r * 10.0 - uTime * 0.2);

    float glow = exp(-r * 3.0);
    float core = exp(-r * 15.0);

    float g = glow * (0.6 + 0.4 * arms) + core;

    return color * g;
}

// ------------------------
// NEBULA
// ------------------------
vec3 nebula(vec2 uv)
{
    float n = noise(uv * 2.0 + uTime * 0.02);
    return vec3(0.1, 0.2, 0.5) * smoothstep(0.4, 0.8, n);
}

// ------------------------
// MAIN
// ------------------------
void main()
{
    vec2 uv = (gl_FragCoord.xy / uResolution.xy) * 2.0 - 1.0;
    uv.x *= uResolution.x / uResolution.y;

    vec3 ro = vec3(0.0, 0.0, 3.0);
    vec3 rd = normalize(vec3(uv, -1.5));

    float t = uTime * 0.2;

    ro.xz *= rot(t);
    rd.xz *= rot(t);

    float hit = sphere(ro, rd, 1.0);

    vec3 col = vec3(0.0);

    // ---------------- EARTH ----------------
    if(hit > 0.0)
    {
        vec3 p = ro + rd * hit;
        vec3 n = normalize(p);

        n.xz *= rot(t);

        vec3 e = earth(n);

        vec3 lightDir = normalize(vec3(1.0, 0.3, 0.2));
        float diff = max(dot(n, lightDir), 0.0);

        float night = 1.0 - diff;

        float city = lights(n) * night;
        float cl = clouds(n);

        col = e * (0.3 + diff);
        col += vec3(1.0, 0.8, 0.5) * city;

        col = mix(col, vec3(1.0), cl * 0.3);

        float rim = pow(1.0 - abs(dot(n, vec3(0.0, 0.0, 1.0))), 3.0);
        col += vec3(0.3, 0.5, 1.0) * rim * 0.4;
    }
    else
    {
        // ---------------- SPACE ----------------

        vec3 space = vec3(0.0);

        // multi-depth stars
        space += vec3(1.0) * stars(uv + uTime * 0.01, 50.0, 0.1);
        space += vec3(1.0) * stars(uv + uTime * 0.02, 120.0, 0.2);
        space += vec3(1.0) * stars(uv + uTime * 0.03, 250.0, 0.3);

        // galaxies
        space += galaxy(uv, vec2(-0.6, 0.3), vec3(0.6, 0.4, 1.0));
        space += galaxy(uv, vec2(0.7, -0.4), vec3(1.0, 0.6, 0.3));

        // nebula clouds
        space += nebula(uv);

        col = space;
    }

    FragColor = vec4(col, 1.0);
}