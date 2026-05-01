
#version 330 core
out vec4 FragColor;
uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uMouse;

void main() {
    vec2 uv = gl_FragCoord.xy / uResolution;
    vec2 pos = uv * 2.0 - 1.0;
    float radius = length(pos);
    vec3 color = 0.5 + 0.5 * cos(vec3(0.0, 2.0, 4.0) + pos.xyx * 3.0 + uTime);
    color *= 1.0 - smoothstep(0.5, 0.9, radius);
    FragColor = vec4(color, 1.0);
}
