#version 330 core

in vec2 vPos;
out vec4 FragColor;

// Signed distance to triangle (approx for equilateral triangle)
float sdTriangle(vec2 p)
{
    const float k = sqrt(3.0);
    p.x = abs(p.x) - 1.0;
    p.y = p.y + 1.0 / k;

    if (p.x + k * p.y > 0.0)
        p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;

    p.x -= clamp(p.x, -2.0, 0.0);
    return -length(p) * sign(p.y);
}

void main()
{
    // Scale coordinates so triangle fits nicely
    vec2 p = vPos * 1.5;

    float d = sdTriangle(p);

    // Triangle mask
    float inside = step(d, 0.0);

    // Red triangle
    vec3 red = vec3(1.0, 0.0, 0.0) * inside;

    // Blue glow (outside edges)
    float glow = exp(-5.0 * abs(d));
    vec3 blueGlow = vec3(0.0, 0.4, 1.0) * glow;

    // Combine: red core + blue glow
    vec3 color = red + blueGlow;

    // Force black background
    if (inside < 0.01 && glow < 0.01)
        color = vec3(0.0);

    FragColor = vec4(color, 1.0);
}