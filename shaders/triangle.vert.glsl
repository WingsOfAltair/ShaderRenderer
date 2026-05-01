#version 330 core

layout (location = 0) in vec3 aPos;

out vec2 vPos;

void main()
{
    vPos = aPos.xy; // pass raw position
    gl_Position = vec4(aPos, 1.0);
}