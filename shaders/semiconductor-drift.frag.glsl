#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

// =====================================================
// GRID
// =====================================================
vec2 uv;

float hash(vec2 p)
{
    p = fract(p * vec2(123.34, 345.45));
    return fract(p.x * p.y);
}

// =====================================================
// ELECTRIC POTENTIAL FIELD (Poisson-like approximation)
// =====================================================
float potential(vec2 p)
{
    // injected voltage regions (contacts)
    float left  = smoothstep(-1.0, -0.8, p.x);
    float right = smoothstep(0.8, 1.0, p.x);

    float bias = left - right;

    // internal charge perturbation
    float wave = sin(p.y * 6.0 + uTime * 2.0) * 0.3;

    return bias + wave;
}

// =====================================================
// ELECTRIC FIELD (E = -∇V)
// =====================================================
vec2 electricField(vec2 p)
{
    float e = 0.01;

    float vx = potential(p + vec2(e,0)) - potential(p - vec2(e,0));
    float vy = potential(p + vec2(0,e)) - potential(p - vec2(0,e));

    return -vec2(vx, vy);
}

// =====================================================
// ELECTRON DENSITY (n)
// =====================================================
float electrons(vec2 p)
{
    float noise = hash(floor(p * 20.0));

    float base = exp(-p.x * p.x * 2.0);

    float injection = smoothstep(-0.9, -0.6, p.x);

    float diffusion = sin(p.y * 4.0 + uTime * 3.0) * 0.2;

    return base + injection + diffusion + noise * 0.1;
}

// =====================================================
// HOLE DENSITY (p-type carriers)
// =====================================================
float holes(vec2 p)
{
    float noise = hash(floor(p * 30.0));

    float base = exp(-p.x * p.x * 1.5);

    float recombination = 1.0 - electrons(p);

    return base * recombination + noise * 0.05;
}

// =====================================================
// DRIFT TERM (μ E)
// =====================================================
vec2 drift(vec2 E, float mobility)
{
    return mobility * E;
}

// =====================================================
// DIFFUSION TERM (∇n smoothing)
// =====================================================
vec2 diffusion(vec2 p)
{
    float e = 0.01;

    float n  = electrons(p);
    float nx = electrons(p + vec2(e,0));
    float ny = electrons(p + vec2(0,e));

    return vec2(nx - n, ny - n);
}

// =====================================================
// CURRENT DENSITY (J)
// =====================================================
vec3 current(vec2 p)
{
    vec2 E = electricField(p);

    vec2 driftVel = drift(E, 1.0);

    vec2 diffVel = diffusion(p) * 0.5;

    vec2 J = driftVel + diffVel;

    float magnitude = length(J);

    return vec3(J, magnitude);
}

// =====================================================
// SEMICONDUCTOR MATERIAL STRUCTURE
// =====================================================
float lattice(vec2 p)
{
    vec2 g = fract(p * 20.0) - 0.5;
    return smoothstep(0.05, 0.0, length(g));
}

// =====================================================
// COLOR MAPPING (physics visualization)
// =====================================================
vec3 colorize(float n, float p, vec2 J)
{
    float e = length(J);

    vec3 electronColor = vec3(0.2,0.6,1.0);
    vec3 holeColor     = vec3(1.0,0.4,0.2);

    vec3 col = mix(holeColor, electronColor, n);

    col += vec3(0.0,1.0,0.5) * e; // current flow glow

    return col;
}

// =====================================================
// MAIN
// =====================================================
void main()
{
    uv = gl_FragCoord.xy / uResolution.xy;
    uv = uv * 2.0 - 1.0;
    uv.x *= uResolution.x / uResolution.y;

    vec2 p = uv;

    float n = electrons(p);
    float h = holes(p);

    vec3 J = current(p);

    vec3 col = colorize(n, h, J.xy);

    // crystal lattice structure
    col += vec3(0.3) * lattice(p);

    // electric field visualization
    col += vec3(0.2,0.5,1.0) * length(electricField(p)) * 0.2;

    FragColor = vec4(col,1.0);
}