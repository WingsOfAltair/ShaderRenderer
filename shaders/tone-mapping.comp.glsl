#version 460 core

layout(local_size_x = 8, local_size_y = 8) in;

layout(rgba32f, binding = 0) uniform image2D textureIn;
layout(rgba32f, binding = 1) uniform image2D textureOut;

uniform float exposure;
uniform float white;
uniform bool toneMappingOnRGB;
uniform int toneMappingType;
uniform float gamma;

vec3 rgb2xyz(vec3 rgb) {
    return vec3(
        dot(vec3(0.4124564, 0.3575761, 0.1804375), rgb),
        dot(vec3(0.2126729, 0.7151522, 0.0721750), rgb),
        dot(vec3(0.0193339, 0.1191920, 0.9503041), rgb)
    );
}

vec3 xyz2rgb(vec3 xyz) {
    return vec3(
        dot(vec3(3.2404542, -1.5371385, -0.4985314), xyz),
        dot(vec3(-0.9692660, 1.8760108, 0.0415560), xyz),
        dot(vec3(0.0556434, -0.2040259, 1.0572252), xyz)
    );
}

vec3 rgb2Yxy(vec3 rgb) {
    vec3 xyz = rgb2xyz(rgb);
    float sum = xyz.x + xyz.y + xyz.z;
    if (sum == 0.0) return vec3(0.0);
    return vec3(xyz.y, xyz.x / sum, xyz.y / sum);
}

vec3 Yxy2rgb(vec3 Yxy) {
    float Y = Yxy.x;
    float x = Yxy.y;
    float y = Yxy.z;

    if (y == 0.0) return vec3(0.0);

    float X = (x * Y) / y;
    float Z = ((1.0 - x - y) * Y) / y;

    return xyz2rgb(vec3(X, Y, Z));
}

// Tone mapping functions
float linear(float x) { return x; }
float reinhard(float x) { return x / (1.0 + x); }

float ACES(float x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return (x * (a * x + b)) / (x * (c * x + d) + e);
}

float uchimura(float x) {
    const float P = 1.0;
    const float a = 1.0;
    const float m = 0.22;
    const float l = 0.4;
    const float c = 1.33;
    const float b = 0.0;

    float l0 = ((P - m) * l) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    float w0 = 1.0 - smoothstep(0.0, m, x);
    float w2 = step(m + l0, x);
    float w1 = 1.0 - w0 - w2;

    float T = m * pow(x / m, c) + b;
    float S = P - (P - S1) * exp(CP * (x - S0));
    float L = m + a * (x - m);

    return T * w0 + L * w1 + S * w2;
}

float toneMapping(float x) {
    if (toneMappingType == 0) return linear(x);
    if (toneMappingType == 1) return reinhard(x);
    if (toneMappingType == 2) return ACES(x);
    if (toneMappingType == 3) return uchimura(x);

    return x; // ✅ REQUIRED fallback
}

void main() {
    ivec2 gidx = ivec2(gl_GlobalInvocationID.xy);

    // ✅ SAFE: avoid out-of-bounds
    ivec2 size = imageSize(textureOut);
    if (gidx.x >= size.x || gidx.y >= size.y)
        return;

    vec3 rgb = imageLoad(textureIn, gidx).xyz;

    if (toneMappingOnRGB) {
        rgb.r = toneMapping(exposure * rgb.r);
        rgb.g = toneMapping(exposure * rgb.g);
        rgb.b = toneMapping(exposure * rgb.b);
    } else {
        vec3 Yxy = rgb2Yxy(rgb);
        Yxy.x = toneMapping(exposure * Yxy.x);
        rgb = Yxy2rgb(Yxy);
    }

    // gamma correction
    rgb = pow(rgb, vec3(1.0 / gamma));

    imageStore(textureOut, gidx, vec4(rgb, 1.0));
}