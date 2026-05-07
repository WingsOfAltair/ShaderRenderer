#version 330 core

layout(location = 0) in vec2 aPos;

// We only need one output for the coordinates
out vec2 vTexCoord;

void main()
{
    // Convert clip space (-1 to 1) to UV space (0 to 1)
    vTexCoord = aPos * 0.5 + 0.5; 
    gl_Position = vec4(aPos, 0.0, 1.0);
}