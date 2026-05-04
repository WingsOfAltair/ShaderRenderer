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
// ROTATION MATRIX
// ------------------------
mat2 rot(float a)
{
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

// ------------------------
// SPHERE RAY INTERSECTION
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
// EARTH TEXTURE (procedural fake map)
// ------------------------
vec3 earthColor(vec3 p)
{
    // convert to spherical coords
    float lat = asin(p.y);
    float lon = atan(p.z, p.x);

    vec2 uv = vec2(lon, lat);

    // rotation "spy satellite scan"
    uv.x += uTime * 0.05;

    float land = noise(uv * 6.0);
    float detail = noise(uv * 20.0);

    float continent = smoothstep(0.45, 0.65, land);

    vec3 ocean = vec3(0.02, 0.05, 0.2);
    vec3 landCol = vec3(0.05, 0.25, 0.08);

    vec3 col = mix(ocean, landCol, continent);

    // add terrain variation
    col += detail * 0.05;

    return col;
}

// ------------------------
// CLOUD LAYER
// ------------------------
float clouds(vec3 p)
{
    float lat = asin(p.y);
    float lon = atan(p.z, p.x);

    vec2 uv = vec2(lon, lat);
    uv.x += uTime * 0.02;

    float c = noise(uv * 8.0);
    return smoothstep(0.55, 0.75, c);
}

// ------------------------
// CITY LIGHTS (night side)
// ------------------------
float lights(vec3 p)
{
    float lat = asin(p.y);
    float lon = atan(p.z, p.x);

    vec2 uv = vec2(lon, lat);
    uv.x += uTime * 0.05;

    float n = noise(uv * 40.0);

    return smoothstep(0.6, 0.9, n);
}

// ------------------------
// STAR FIELD
// ------------------------
float stars(vec2 uv)
{
    vec2 gv = fract(uv * 200.0) - 0.5;
    vec2 id = floor(uv * 200.0);

    float h = hash(id);
    float d = length(gv);

    return smoothstep(0.02, 0.0, d) * step(0.98, h);
}

// ------------------------
// MAIN
// ------------------------
void main()
{
    vec2 uv = (gl_FragCoord.xy / uResolution.xy) * 2.0 - 1.0;
    uv.x *= uResolution.x / uResolution.y;

    // camera (spy satellite angle)
    vec3 ro = vec3(0.0, 0.0, 3.0);
    vec3 rd = normalize(vec3(uv, -1.5));

    // slow Earth rotation (main effect)
    float t = uTime * 0.2;

    ro.xz *= rot(t);
    rd.xz *= rot(t);

    // sphere intersection
    float hit = sphere(ro, rd, 1.0);

    vec3 col = vec3(0.0);

    if(hit > 0.0)
    {
        vec3 pos = ro + rd * hit;
        vec3 nor = normalize(pos);

        // rotate Earth surface
        nor.xz *= rot(t);

        // base earth
        vec3 earth = earthColor(nor);

        // lighting (sun direction fixed)
        vec3 lightDir = normalize(vec3(1.0, 0.2, 0.3));
        float diff = max(dot(nor, lightDir), 0.0);

        // night side
        float night = 1.0 - diff;

        // city lights
        float city = lights(nor) * night;

        // clouds
        float cl = clouds(nor);

        vec3 cloudCol = vec3(1.0);
        vec3 sunCol = vec3(1.0, 0.8, 0.6);

        col = earth * (0.4 + diff);

        // add lights glow
        col += vec3(1.0, 0.9, 0.6) * city * 0.8;

        // clouds overlay
        col = mix(col, cloudCol, cl * 0.35);

        // atmospheric rim glow
        float rim = pow(1.0 - abs(dot(nor, vec3(0.0, 0.0, 1.0))), 3.0);
        col += vec3(0.3, 0.5, 1.0) * rim * 0.4;
    }
    else
    {
        // SPACE BACKGROUND
        float s = stars(uv + uTime * 0.01);
        col = vec3(0.0);
        col += vec3(1.0) * s;

        // faint nebula glow
        float n = noise(uv * 3.0 + uTime * 0.02);
        col += vec3(0.1, 0.2, 0.5) * n * 0.2;
    }

    FragColor = vec4(col, 1.0);
}