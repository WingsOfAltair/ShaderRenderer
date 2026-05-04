#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// =====================================================
// HASH (stable 3D noise seed)
// =====================================================
float hash(vec3 p)
{
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z);
}

// =====================================================
// 3D NOISE (cheap but smooth enough)
// =====================================================
float noise(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);

    float a = hash(i + vec3(0,0,0));
    float b = hash(i + vec3(1,0,0));
    float c = hash(i + vec3(0,1,0));
    float d = hash(i + vec3(1,1,0));
    float e = hash(i + vec3(0,0,1));
    float f1 = hash(i + vec3(1,0,1));
    float g = hash(i + vec3(0,1,1));
    float h = hash(i + vec3(1,1,1));

    vec3 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(mix(a,b,u.x), mix(c,d,u.x), u.y),
        mix(mix(e,f1,u.x), mix(g,h,u.x), u.y),
        u.z
    );
}

// =====================================================
// STAR FIELD IN 3D SPACE
// =====================================================
float stars(vec3 p)
{
    vec3 id = floor(p * 2.0);
    float r = hash(id);

    return step(0.995, r);
}

// =====================================================
// GALAXY DENSITY FIELD (3D)
// =====================================================
float galaxy(vec3 p)
{
    float r = length(p.xz);

    float band = exp(-abs(p.y) * 2.5);

    float swirl =
        sin(p.x * 1.5 + uTime * 0.1) +
        cos(p.z * 1.3 - uTime * 0.1);

    swirl = swirl * 0.5 + 0.5;

    return band * swirl * exp(-r * 0.5);
}

// =====================================================
// NEBULA VOLUME
// =====================================================
float nebula(vec3 p)
{
    float n =
        noise(p * 0.8) +
        0.5 * noise(p * 1.6) +
        0.25 * noise(p * 3.2);

    return n;
}

// =====================================================
// CAMERA RAY
// =====================================================
void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.5;

    // =====================================================
    // CAMERA
    // =====================================================
    vec3 ro = vec3(0.0, 0.0, uTime * 2.0);
    vec3 rd = normalize(vec3(p.x, p.y, -1.2));

    vec3 col = vec3(0.0);

    // =====================================================
    // RAYMARCH (cheap universe sampling)
    // =====================================================
    float dist = 0.0;

    for (int i = 0; i < 64; i++)
    {
        vec3 pos = ro + rd * dist;

        float dStar = stars(pos);
        float dGal  = galaxy(pos);
        float dNeb  = nebula(pos);

        vec3 starCol = vec3(1.0) * dStar;
        vec3 galCol  = vec3(0.6, 0.4, 1.0) * dGal;
        vec3 nebCol  = vec3(0.2, 0.5, 1.0) * dNeb * 0.3;

        col += (starCol + galCol + nebCol) * 0.03;

        dist += 0.2;
    }

    // =====================================================
    // COLOR GRADING (space depth)
    // =====================================================
    col = pow(col, vec3(1.2));

    FragColor = vec4(col, 1.0);
}