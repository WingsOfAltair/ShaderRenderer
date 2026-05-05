#version 330 core

in vec2 uv;
out vec4 FragColor;

uniform sampler2D densityTex;
uniform float gateVoltage;

void main()
{
    float d = texture(densityTex, uv).r;

    // MOSFET regions
    vec3 color = vec3(0.0);

    // Source (left)
    if(uv.x < 0.1)
        color = vec3(0.2, 0.8, 1.0);

    // Drain (right)
    else if(uv.x > 0.9)
        color = vec3(1.0, 0.3, 0.2);

    // Gate (top stripe)
    else if(uv.y > 0.6 && uv.y < 0.7)
        color = vec3(0.8, 0.8, 0.2) * gateVoltage;

    // Channel region
    else
    {
        // Electron density glow
        color = vec3(d * 0.2, d * 0.7, d);

        // Add subtle glow
        color += pow(d, 3.0) * vec3(0.3, 0.6, 1.0);
    }

    FragColor = vec4(color, 1.0);
}