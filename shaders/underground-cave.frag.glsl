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

// ---------------- HSV ----------------
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.4;

    // =====================================================
    // � 1. CAVE STRUCTURE (rock walls)
    // =====================================================
    float rock =
        noise(p * 2.0) +
        noise(p * 4.0) * 0.5 +
        noise(p * 8.0) * 0.25;

    rock = smoothstep(0.4, 0.7, rock);

    // =====================================================
    // � 2. LAVA CRACK NETWORK
    // =====================================================
    vec2 warp = vec2(
        noise(p * 2.5 + t),
        noise(p * 2.5 - t)
    );

    p += (warp - 0.5) * 0.9;

    float cracks =
        abs(sin(p.x * 4.0 + t)) +
        abs(sin(p.y * 4.0 - t)) +
        abs(sin((p.x + p.y) * 3.0));

    cracks += noise(p * 5.0 + t) * 2.0;

    float lavaMask = smoothstep(1.0, 2.5, cracks);

    // =====================================================
    // � 3. LAVA FLOW + HEAT
    // =====================================================
    float flow =
        sin(p.x * 3.0 + t) +
        sin(p.y * 3.0 - t) +
        sin((p.x + p.y) * 2.0 + t);

    flow += noise(p * 3.0 + t) * 2.0;

    float lava = smoothstep(-1.5, 2.0, flow);

    // =====================================================
    // � 4. DEPTH / CAVE DARKNESS
    // =====================================================
    float dist = length(p);
    float depth = smoothstep(1.5, 0.2, dist);

    // =====================================================
    // � 5. TIME-CHANGING COLOR PALETTE
    // =====================================================
    float hue =
        0.04 * uTime +          // global drift
        lava * 0.3 +            // lava-driven hue
        0.1 * sin(uTime + lava * 6.0);

    float sat = 0.9;
    float val = lava;

    vec3 lavaColor = hsv2rgb(vec3(hue, sat, val));

    // rock color (dark cave)
    vec3 rockColor = vec3(0.03, 0.02, 0.025);

    // =====================================================
    // � 6. COMPOSITION
    // =====================================================
    vec3 color = rockColor;

    // lava veins inside rock
    color = mix(color, lavaColor, lava * lavaMask);

    // glowing hot pockets
    color += vec3(1.0, 0.3, 0.0) * lava * 0.3;

    // cave depth shading
    color *= depth;

    FragColor = vec4(color, 1.0);
}