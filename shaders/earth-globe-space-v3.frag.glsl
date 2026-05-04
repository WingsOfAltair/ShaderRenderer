#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

// ----------------------------------------------------
// HASH / NOISE
// ----------------------------------------------------
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

// ----------------------------------------------------
// CAMERA LENS DISTORTION (wide space lens)
// ----------------------------------------------------
vec2 lensDistortion(vec2 uv)
{
    float r2 = dot(uv, uv);
    uv *= 1.0 + 0.12 * r2;
    return uv;
}

// ----------------------------------------------------
// ROTATION
// ----------------------------------------------------
mat2 rot(float a)
{
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// ----------------------------------------------------
// SPHERE INTERSECTION
// ----------------------------------------------------
float sphere(vec3 ro, vec3 rd, float r)
{
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r * r;
    float h = b * b - c;
    if(h < 0.0) return -1.0;
    return -b - sqrt(h);
}

// ----------------------------------------------------
// EARTH PROCEDURAL
// ----------------------------------------------------
vec3 earth(vec3 p)
{
    float lat = asin(p.y);
    float lon = atan(p.z, p.x);

    vec2 uv = vec2(lon, lat);

    uv.x += uTime * 0.03;

    float land = noise(uv * 6.0);
    float detail = noise(uv * 20.0);

    float c = smoothstep(0.45, 0.65, land);

    vec3 ocean = vec3(0.02, 0.06, 0.22);
    vec3 landC = vec3(0.05, 0.28, 0.10);

    vec3 col = mix(ocean, landC, c);
    col += detail * 0.04;

    return col;
}

// ----------------------------------------------------
// ATMOSPHERE (NASA-style glow)
// ----------------------------------------------------
vec3 atmosphere(vec3 n, vec3 viewDir)
{
    float fresnel = pow(1.0 - max(dot(n, -viewDir), 0.0), 4.0);

    vec3 sky = vec3(0.3, 0.6, 1.2);
    vec3 rim = sky * fresnel;

    return rim;
}

// ----------------------------------------------------
// CLOUDS
// ----------------------------------------------------
float clouds(vec3 p)
{
    vec2 uv = vec2(atan(p.z, p.x), asin(p.y));
    uv.x += uTime * 0.01;

    return smoothstep(0.55, 0.75, noise(uv * 10.0));
}

// ----------------------------------------------------
// CITY LIGHTS (night side)
// ----------------------------------------------------
float lights(vec3 p, float nightMask)
{
    vec2 uv = vec2(atan(p.z, p.x), asin(p.y));
    uv.x += uTime * 0.02;

    float n = noise(uv * 50.0);

    return smoothstep(0.65, 0.9, n) * nightMask;
}

// ----------------------------------------------------
// STARFIELD (depth layers)
// ----------------------------------------------------
float stars(vec2 uv, float scale)
{
    vec2 gv = fract(uv * scale) - 0.5;
    vec2 id = floor(uv * scale);

    float h = hash(id);
    float d = length(gv);

    return smoothstep(0.02, 0.0, d) * step(0.97, h);
}

// ----------------------------------------------------
// GALAXY
// ----------------------------------------------------
vec3 galaxy(vec2 uv, vec2 center, vec3 color)
{
    vec2 p = uv - center;

    float r = length(p);
    float a = atan(p.y, p.x);

    float arms = sin(3.0 * a + r * 8.0 - uTime * 0.1);
    float glow = exp(-r * 2.5);
    float core = exp(-r * 12.0);

    float g = glow * (0.6 + 0.4 * arms) + core;

    return color * g;
}

// ----------------------------------------------------
// CAMERA SHAKE (ISS jitter feel)
// ----------------------------------------------------
vec2 cameraShake()
{
    float t = uTime * 10.0;

    return vec2(
        noise(vec2(t, 1.0)) - 0.5,
        noise(vec2(t, 2.0)) - 0.5
    ) * 0.01;
}

// ----------------------------------------------------
// MAIN
// ----------------------------------------------------
void main()
{
    vec2 uv = (gl_FragCoord.xy / uResolution.xy) * 2.0 - 1.0;
    uv.x *= uResolution.x / uResolution.y;

    // lens distortion (space camera)
    uv = lensDistortion(uv);

    // camera jitter
    uv += cameraShake();

    vec3 ro = vec3(0.0, 0.0, 3.0);
    vec3 rd = normalize(vec3(uv, -1.5));

    float t = uTime * 0.15;

    // slow orbital drift + mismatch rotation
    ro.xz *= rot(t);
    rd.xz *= rot(t * 0.8);

    float hit = sphere(ro, rd, 1.0);

    vec3 col = vec3(0.0);

    // ---------------- EARTH ----------------
    if(hit > 0.0)
    {
        vec3 p = ro + rd * hit;
        vec3 n = normalize(p);

        vec3 e = earth(n);

        vec3 lightDir = normalize(vec3(1.0, 0.3, 0.2));
        float diff = max(dot(n, lightDir), 0.0);

        float night = 1.0 - diff;

        float city = lights(n, night);
        float cl = clouds(n);

        vec3 finalCol = e * (0.25 + diff);

        finalCol += vec3(1.0, 0.85, 0.6) * city;

        finalCol = mix(finalCol, vec3(1.0), cl * 0.25);

        // atmospheric scattering (KEY NASA LOOK)
        finalCol += atmosphere(n, rd);

        col = finalCol;
    }
    else
    {
        // ---------------- SPACE ----------------
        vec3 space = vec3(0.0);

        // deep star layers
        space += vec3(1.0) * stars(uv + uTime * 0.01, 60.0);
        space += vec3(1.0) * stars(uv + uTime * 0.02, 140.0);
        space += vec3(1.0) * stars(uv + uTime * 0.03, 300.0);

        // galaxies
        space += galaxy(uv, vec2(-0.6, 0.3), vec3(0.7, 0.4, 1.0));
        space += galaxy(uv, vec2(0.7, -0.4), vec3(1.0, 0.6, 0.3));

        col = space;
    }

    FragColor = vec4(col, 1.0);
}