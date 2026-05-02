#version 460 core

layout(r8ui, binding = 0) uniform uimage2D cells;

uniform vec2 offset;
uniform float scale;

out vec4 fragColor;

void main()
{
    ivec2 size = imageSize(cells);

    ivec2 idx = ivec2(gl_FragCoord.xy / scale) + ivec2(offset);

    // wrap instead of clamp (consistent CA behavior)
    idx = (idx % size + size) % size;

    uint status = imageLoad(cells, idx).x;

    vec3 col = mix(vec3(0.0), vec3(0.0, 1.0, 0.0), float(status));

    fragColor = vec4(col, 1.0);
}