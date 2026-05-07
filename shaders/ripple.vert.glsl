
#version 330 core

layout(location = 0) in vec2 aPos;

out vec2 uv;
out vec2 texCoords;
out vec4 vertTexCoord;

void main()
{
    uv = aPos * 0.5 + 0.5; // convert -1..1 → 0..1
    texCoords = uv;
    vertTexCoord = vec4(uv, 0.0, 1.0);
    gl_Position = vec4(aPos, 0.0, 1.0);
}
