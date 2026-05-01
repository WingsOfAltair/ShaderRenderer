#version 330 core

in vec2 vUV;
out vec4 FragColor;

void main()
{
    // Map UV → complex plane
    vec2 c = (vUV - vec2(0.5)) * 3.0;

    vec2 z = vec2(0.0, 0.0);

    int maxIter = 100;
    int i;

    for (i = 0; i < maxIter; i++)
    {
        // z = z^2 + c
        z = vec2(
            z.x * z.x - z.y * z.y,
            2.0 * z.x * z.y
        ) + c;

        if (dot(z, z) > 4.0)
            break;
    }

    float t = float(i) / float(maxIter);

    // Color palette (simple smooth gradient)
    vec3 color = vec3(t * 0.2, t * 0.6, t);

    FragColor = vec4(color, 1.0);
}