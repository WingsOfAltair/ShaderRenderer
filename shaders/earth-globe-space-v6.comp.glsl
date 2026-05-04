
#version 430 core
layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba32f, binding = 0) uniform image2D img;
uniform float uTime;
uniform vec2 uResolution;

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (pixel.x >= int(uResolution.x) || pixel.y >= int(uResolution.y)) {
        return;
    }
    vec2 uv = vec2(pixel) / uResolution;
    vec3 color = 0.5 + 0.5 * cos(uTime + uv.xyx * 6.2831853 + vec3(0.0, 2.0, 4.0));
    imageStore(img, pixel, vec4(color, 1.0));
}
