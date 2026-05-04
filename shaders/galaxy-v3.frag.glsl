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

    float n = mix(
        mix(
            mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
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

    return n;
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
// GALAXY DENSITY FUNCTION
// =====================================================
float galaxy(vec3 p)
{
    // rotate galaxy slowly
    p.xz *= rot(uTime * 0.05);

    float r = length(p.xz);

    // spiral angle
    float angle = atan(p.z, p.x);

    // spiral arms (log spiral)
    float arms = sin(5.0 * angle + r * 3.0 - uTime * 0.2);

    arms = smoothstep(0.2, 0.8, arms);

    // disk shape
    float disk = exp(-r * 1.2) * exp(-abs(p.y) * 3.0);

    // core
    float core = exp(-r * 6.0);

    // noise breakup
    float n = noise(p * 2.0 + uTime * 0.1);

    return disk * (arms * 0.8 + 0.2) + core * 1.5 + n * 0.15;
}

// =====================================================
// STAR FIELD INSIDE VOLUME
// =====================================================
float stars(vec3 p)
{
    float h = hash(floor(p * 20.0));
    return step(0.997, h);
}

// =====================================================
// CAMERA RAY
// =====================================================
void main()
{
    vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution.xy) / uResolution.y;

    vec3 ro = vec3(0.0, 0.0, -3.0); // camera
    vec3 rd = normalize(vec3(uv, 1.5));

    vec3 col = vec3(0.0);

    // =====================================================
    // RAYMARCH GALAXY VOLUME
    // =====================================================
    float t = 0.0;

    for (int i = 0; i < 64; i++)
    {
        vec3 pos = ro + rd * t;

        float d = galaxy(pos);

        // color palette (galaxy blues + warm core)
        vec3 c = vec3(0.2, 0.4, 1.0) * d;

        // core warm shift
        c += vec3(1.0, 0.6, 0.3) * exp(-length(pos.xz) * 2.0);

        // stars inside volume
        c += vec3(1.0) * stars(pos) * d;

        col += c * 0.03;

        t += 0.05;

        if (t > 6.0) break;
    }

    // =====================================================
    // FINAL COLOR GRADING
    // =====================================================
    col = 1.0 - exp(-col); // HDR tone mapping

    col *= vec3(1.1, 1.0, 1.2);

    FragColor = vec4(col, 1.0);
}