#version 330 core
out vec4 FragColor;
uniform sampler2D uTexture;

void main()
{
    FragColor = texelFetch(uTexture, ivec2(gl_FragCoord.xy), 0);
}