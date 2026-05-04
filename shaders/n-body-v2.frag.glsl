#version 330 core

out vec4 FragColor;

uniform sampler2D prevFrame;
uniform vec2 uResolution;
uniform float uTime;

float sample(vec2 uv)
{
    return texture(prevFrame, uv).r;
}

float rand(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main()
{
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 px = 1.0 / uResolution;

    float center = sample(uv);

    // diffusion
    float lap =
        sample(uv + vec2(px.x, 0.0)) +
        sample(uv - vec2(px.x, 0.0)) +
        sample(uv + vec2(0.0, px.y)) +
        sample(uv - vec2(0.0, px.y)) -
        4.0 * center;

    // MOSFET gate control (dynamic channel opening)
    float gate = smoothstep(0.3, 0.7, sin(uTime * 0.8) * 0.5 + 0.5);

    // source injection (VERY IMPORTANT — prevents black screen)
    float source = step(uv.x, 0.02) * gate;

    // drain sink
    float drain = step(0.98, uv.x) * center * 0.8;

    // noise seed (IMPORTANT — prevents dead state)
    float noise = (rand(uv + uTime) - 0.5) * 0.02;

    float dn =
        0.20 * lap +
        source -
        drain +
        noise;

    float next = center + dn * 0.8;
    next = clamp(next, 0.0, 1.0);

    vec3 col;

    // electron current visualization
    col = vec3(0.0, 1.0, 0.3) * next;

    // electric field glow
    float field = abs(dn) * 3.0;
    col += vec3(0.2, 0.6, 1.0) * field;

    FragColor = vec4(col, 1.0);
}