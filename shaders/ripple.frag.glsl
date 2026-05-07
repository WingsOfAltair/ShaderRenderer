#version 330 core

in vec2 uv;
out vec4 FragColor;

uniform float time;
uniform vec2 center;

void main()
{
    vec2 p = uv;
    float dist = distance(p, center);

    float speed = 0.6;

    // convert space into moving wave phase
    float wave = sin(dist * 40.0 - time * 6.0);

    // fade from center outward
    float attenuation = 1.0 / (1.0 + 8.0 * dist);

    float ripple = wave * attenuation;

    vec3 color = vec3(0.0, 0.5, 1.0) * ripple;

    FragColor = vec4(color, 1.0);
}