#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

// ---------------- SAFE NOISE ----------------
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

// ---------------- CLOUD LAYERS ----------------
float clouds(vec2 p, float t)
{
    float n = 0.0;

    n += noise(p * 1.0 + t) * 0.5;
    n += noise(p * 2.0 - t * 0.5) * 0.25;
    n += noise(p * 4.0 + t * 0.2) * 0.125;

    return n;
}

// ---------------- LIGHTNING BRANCH ----------------
float lightning(vec2 p, float t)
{
    // time-sliced random strike events
    float event = step(0.97, noise(vec2(floor(t * 2.0), 0.0)));

    // vertical channel shape
    float channel =
        smoothstep(0.2, 0.0, abs(p.x + noise(vec2(t, 0.0)) * 0.3));

    // flicker decay
    float flicker = exp(-fract(t * 2.0) * 8.0);

    return event * channel * flicker;
}

// ---------------- SKY GRADIENT ----------------
vec3 skyGradient(vec2 uv)
{
    return mix(
        vec3(0.02, 0.03, 0.06), // night
        vec3(0.1, 0.15, 0.25),  // horizon glow
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
    // ☁️ 1. CLOUD FIELD (fake volumetric layers)
    // =====================================================
    float c = clouds(p * 1.2, t);

    float cloudMask = smoothstep(0.4, 0.8, c);

    vec3 cloudColor = mix(
        vec3(0.05, 0.06, 0.08),
        vec3(0.2, 0.2, 0.25),
        cloudMask
    );

    // =====================================================
    // ⚡ 2. LIGHTNING SYSTEM
    // =====================================================
    float flash = lightning(p, uTime);

    vec3 lightningColor = vec3(0.9, 0.95, 1.0);

    // global flash (whole sky brightens)
    vec3 skyFlash = lightningColor * flash * 3.0;

    // local bolt glow inside clouds
    cloudColor += lightningColor * flash * cloudMask * 2.0;

    // =====================================================
    // � 3. BASE SKY
    // =====================================================
    vec3 sky = skyGradient(uv);

    // clouds over sky
    sky = mix(sky, cloudColor, cloudMask);

    // lightning overlay
    sky += skyFlash;

    // =====================================================
    // � 4. ATMOSPHERIC FOG / DEPTH
    // =====================================================
    float horizonFade = smoothstep(1.0, -0.2, p.y);
    sky *= horizonFade;

    // =====================================================
    // FINAL
    // =====================================================
    FragColor = vec4(sky, 1.0);
}