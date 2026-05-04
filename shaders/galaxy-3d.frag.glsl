#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// =====================================================
// HASH / NOISE
// =====================================================
float hash(vec3 p)
{
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z);
}

float noise(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(
            mix(hash(i), hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x),
            f.y
        ),
        mix(
            mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x),
            f.y
        ),
        f.z
    );
}

// =====================================================
// ROTATION
// =====================================================
mat2 rot(float a)
{
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

// =====================================================
// SINGLE GALAXY DENSITY
// =====================================================
float galaxy(vec3 p)
{
    float r = length(p.xz);

    float angle = atan(p.z, p.x);

    // spiral arms
    float arms = sin(5.0 * angle + r * 3.0);
    arms = smoothstep(0.2, 0.8, arms);

    // disk
    float disk = exp(-r * 1.2) * exp(-abs(p.y) * 3.0);

    // core
    float core = exp(-r * 6.0);

    // noise breakup
    float n = noise(p * 2.0);

    return disk * (0.3 + arms) + core * 2.0 + n * 0.1;
}

// =====================================================
// STAR FIELD
// =====================================================
float stars(vec3 p)
{
    return step(0.997, hash(floor(p * 25.0)));
}

// =====================================================
// MULTI GALAXY SCENE
// =====================================================
float scene(vec3 p, out vec3 col)
{
    col = vec3(0.0);
    float density = 0.0;

    // galaxy centers
    vec3 gPos[4];
    gPos[0] = vec3(-3.0, 0.0, 0.0);
    gPos[1] = vec3( 3.0, 0.0, 1.5);
    gPos[2] = vec3( 0.0, 0.0, -3.5);
    gPos[3] = vec3( 1.5, 0.0, 3.0);

    for (int i = 0; i < 4; i++)
    {
        vec3 q = p - gPos[i];

        q.xz *= rot(uTime * 0.03 + float(i));

        float g = galaxy(q);

        vec3 c = vec3(0.2, 0.4, 1.0);

        if (i == 1) c = vec3(1.0, 0.5, 0.2);
        if (i == 2) c = vec3(0.6, 0.3, 1.0);
        if (i == 3) c = vec3(0.2, 1.0, 0.7);

        col += c * g;
        density += g;

        // stars inside galaxy
        col += vec3(1.0) * stars(q) * g;
    }

    return density;
}

// =====================================================
// MAIN
// =====================================================
void main()
{
    vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution.xy) / uResolution.y;

    vec3 ro = vec3(0.0, 0.0, -7.0);
    vec3 rd = normalize(vec3(uv, 1.5));

    vec3 col = vec3(0.0);

    float t = 0.0;

    for (int i = 0; i < 90; i++)
    {
        vec3 pos = ro + rd * t;

        vec3 c;
        float d = scene(pos, c);

        col += c * 0.018;

        t += 0.05;

        if (t > 10.0) break;
    }

    // tonemap
    col = 1.0 - exp(-col);

    // subtle contrast boost
    col *= vec3(1.1, 1.0, 1.2);

    FragColor = vec4(col, 1.0);
}