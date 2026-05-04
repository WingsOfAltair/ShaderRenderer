#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

// =====================================================
// GRID COORDINATES (chip layout)
// =====================================================
vec2 grid(vec2 uv)
{
    return fract(uv * 20.0);
}

float hash(vec2 p)
{
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

// =====================================================
// ELECTRIC POTENTIAL FIELD (voltage simulation)
// =====================================================
float potential(vec2 uv)
{
    // clock pulse (CPU clock signal)
    float clock = sin(uTime * 2.0);

    // signal wave across chip
    float wave = sin(uv.x * 10.0 + uTime * 3.0)
               * cos(uv.y * 10.0 - uTime * 2.0);

    // transistor switching noise
    float noise = hash(floor(uv * 20.0));

    return clock * 0.5 + wave * 0.4 + noise * 0.1;
}

// =====================================================
// CURRENT FLOW (gradient of potential)
// =====================================================
vec2 current(vec2 uv)
{
    float e = 0.01;

    float p  = potential(uv);
    float px = potential(uv + vec2(e,0.0));
    float py = potential(uv + vec2(0.0,e));

    return normalize(vec2(px - p, py - p));
}

// =====================================================
// ELECTRON DENSITY VISUALIZATION
// =====================================================
float electrons(vec2 uv)
{
    vec2 c = current(uv);

    // flow streaks (like electron drift)
    float flow = sin(dot(uv, c) * 40.0 + uTime * 5.0);

    return smoothstep(0.2, 0.8, flow);
}

// =====================================================
// TRANSISTOR GRID (logic switching layer)
// =====================================================
float transistor(vec2 uv)
{
    vec2 id = floor(uv * 20.0);
    float h = hash(id);

    float pulse = sin(uTime * 5.0 + h * 10.0);

    return step(0.7, pulse);
}

// =====================================================
// WIRE STRUCTURE (chip routing visualization)
// =====================================================
float wires(vec2 uv)
{
    vec2 g = fract(uv * 10.0);

    float x = smoothstep(0.48, 0.5, abs(g.x - 0.5));
    float y = smoothstep(0.48, 0.5, abs(g.y - 0.5));

    return 1.0 - min(x,y);
}

// =====================================================
// COLOR MAPPING (physics-inspired visualization)
// =====================================================
vec3 colorize(float p, float e, float w)
{
    vec3 cold = vec3(0.1,0.2,1.0);  // low activity
    vec3 hot  = vec3(1.0,0.2,0.0);  // high current

    vec3 col = mix(cold, hot, e);

    col += vec3(0.2,1.0,0.6) * w; // wiring glow

    col *= 0.5 + p;

    return col;
}

// =====================================================
// MAIN
// =====================================================
void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution.xy;
    uv = uv * 2.0 - 1.0;
    uv.x *= uResolution.x / uResolution.y;

    // chip scale
    uv *= 2.0;

    float p = potential(uv);
    vec2 c = current(uv);
    float e = electrons(uv);
    float w = wires(uv);
    float t = transistor(uv);

    vec3 col = colorize(p, e, w);

    // transistor activity overlay
    col += vec3(1.0,0.8,0.2) * t * 0.3;

    // flow visualization (current direction glow)
    col += vec3(0.3,0.6,1.0) * length(c) * 0.2;

    FragColor = vec4(col,1.0);
}