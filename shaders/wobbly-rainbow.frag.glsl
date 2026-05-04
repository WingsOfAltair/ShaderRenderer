#version 330 core

out vec4 FragColor;

uniform float uTime;
uniform vec2 uResolution;

void main()
{
    // Normalized coordinates (safe, single step)
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 pos = uv * 2.0 - 1.0;
    pos.x *= uResolution.x / uResolution.y;

    float t = uTime * 0.8;

    // Soft procedural motion (no explosions)
    pos += 0.25 * vec2(
        sin(t + pos.y * 2.0),
        cos(t + pos.x * 2.0)
    );

    // Distance field (SAFE: no division)
    float dist = length(pos);

    // Wave field (bounded values only)
    float wave =
        sin(pos.x * 3.0 + t) +
        sin(pos.y * 3.0 - t) +
        sin((pos.x + pos.y) * 2.0 + t * 0.5);

    // Soft radial falloff (smoothstep instead of division = SAFE)
    float mask = 1.0 - smoothstep(0.3, 1.2, dist);

    // Stable color palette
    vec3 color = 0.5 + 0.5 * cos(
        vec3(0.0, 2.0, 4.0) + wave + t
    );

    // Gentle glow (clamped, no inverse math)
    float glow = smoothstep(1.0, 0.0, dist);

    color *= (0.6 + 0.4 * glow);
    color *= mask;

    FragColor = vec4(color, 1.0);
}