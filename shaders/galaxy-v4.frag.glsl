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
    f = f*f*(3.0 - 2.0*f);

    return mix(
        mix(
            mix(hash(i), hash(i+vec3(1,0,0)), f.x),
            mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x),
            f.y
        ),
        mix(
            mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x),
            mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x),
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
    return mat2(c,-s,s,c);
}

// =====================================================
// BLACK HOLE LENSING (fake GR distortion)
// =====================================================
vec3 lens(vec3 ro, vec3 rd, vec3 center, float strength)
{
    vec3 toCenter = center - ro;
    float dist = length(toCenter);

    float influence = strength / (1.0 + dist * dist);

    vec3 axis = normalize(toCenter);

    // bend ray toward center
    rd = normalize(mix(rd, axis, influence));

    return rd;
}

// =====================================================
// SINGLE GALAXY FIELD
// =====================================================
float galaxy(vec3 p)
{
    float r = length(p.xz);

    float angle = atan(p.z, p.x);

    float arms = sin(5.0 * angle + r * 3.0);

    arms = smoothstep(0.2, 0.8, arms);

    float disk = exp(-r * 1.2) * exp(-abs(p.y) * 3.0);

    float core = exp(-r * 6.0);

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
// SCENE: MULTI GALAXY + BLACK HOLES
// =====================================================
float scene(vec3 p, out vec3 col)
{
    col = vec3(0.0);
    float density = 0.0;

    // 3 galaxies in cluster
    vec3 gPos[3];
    gPos[0] = vec3(-2.5, 0.0, 0.0);
    gPos[1] = vec3( 2.5, 0.0, 1.5);
    gPos[2] = vec3( 0.0, 0.0, -3.0);

    for (int i = 0; i < 3; i++)
    {
        vec3 q = p - gPos[i];

        q.xz *= rot(uTime * 0.05 + float(i));

        float g = galaxy(q);

        vec3 c = vec3(0.2, 0.4, 1.0);

        if (i == 1) c = vec3(1.0, 0.5, 0.2); // orange galaxy
        if (i == 2) c = vec3(0.6, 0.3, 1.0); // purple galaxy

        col += c * g;
        density += g;

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

    vec3 ro = vec3(0.0, 0.0, -6.0);
    vec3 rd = normalize(vec3(uv, 1.5));

    vec3 col = vec3(0.0);

    // =====================================================
    // BLACK HOLES (cluster center distortions)
    // =====================================================
    vec3 bh1 = vec3(-2.5, 0.0, 0.0);
    vec3 bh2 = vec3( 2.5, 0.0, 1.5);
    vec3 bh3 = vec3( 0.0, 0.0, -3.0);

    rd = lens(ro, rd, bh1, 2.0);
    rd = lens(ro, rd, bh2, 1.8);
    rd = lens(ro, rd, bh3, 2.5);

    // =====================================================
    // RAYMARCH VOLUME
    // =====================================================
    float t = 0.0;

    for (int i = 0; i < 80; i++)
    {
        vec3 pos = ro + rd * t;

        vec3 c;
        float d = scene(pos, c);

        col += c * 0.02;

        // accretion glow near black holes
        float bhGlow =
            exp(-length(pos - bh1) * 3.0) +
            exp(-length(pos - bh2) * 3.0) +
            exp(-length(pos - bh3) * 3.0);

        col += vec3(1.0, 0.6, 0.3) * bhGlow * 0.2;

        t += 0.06;

        if (t > 8.0) break;
    }

    // =====================================================
    // TONEMAP
    // =====================================================
    col = 1.0 - exp(-col);

    FragColor = vec4(col, 1.0);
}