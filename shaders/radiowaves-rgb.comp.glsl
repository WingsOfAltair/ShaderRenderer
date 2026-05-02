#version 430 core

layout(local_size_x = 16, local_size_y = 16) in;

layout(rgba32f, binding = 0) uniform image2D img;

uniform float uTime;
uniform vec2 uResolution;

void main()
{
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

    if (pixel.x >= int(uResolution.x) || pixel.y >= int(uResolution.y))
        return;

    vec2 uv = vec2(pixel) / uResolution;
    vec2 p = uv * 2.0 - 1.0;

    float r = length(p);
    float a = atan(p.y, p.x);

    // animated wave pattern
    float wave = sin(10.0 * r - uTime * 3.0);
    float ring = smoothstep(0.4, 0.39, abs(wave));

    vec3 color = vec3(
        0.5 + 0.5 * cos(uTime + a + vec3(0.0, 2.0, 4.0))
    );

    color *= ring;
    color *= exp(-2.0 * r);

    imageStore(img, pixel, vec4(color, 1.0));
}