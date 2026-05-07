#version 330 core

in vec2 vUV;
out vec4 FragColor;

uniform float time;
uniform float interval;

void main()
{
    vec2 p = vUV;

    float dist = length(p - vec2(0.5));

    float scaledInterval = interval * 10.0;
    float t = mod(time, scaledInterval);
    float life = t / scaledInterval;

    float radius = life * 0.8;

    float ripple = 0.0;

    // -----------------------------
    // MULTI-FREQUENCY WAVES
    // -----------------------------

    // low frequency (large slow waves)
    ripple += sin((dist - radius) * 15.0 + time * 1.5) * 0.6;

    // mid frequency (normal ripples)
    ripple += sin((dist - radius) * 35.0 + time * 3.0) * 0.3;

    // high frequency (surface noise)
    ripple += sin((dist - radius) * 70.0 + time * 6.0) * 0.1;

    // shape waves into rings
    float ring = exp(-pow((dist - radius) * 12.0, 2.0));

    ripple *= ring;

    // fade over time
    ripple *= exp(-life * 2.0);

    // normalize to visible range
    ripple = 0.5 + 0.5 * ripple;

    vec3 oceanColor = vec3(0.1, 0.5, 0.9);

    FragColor = vec4(oceanColor * ripple, 1.0);
}